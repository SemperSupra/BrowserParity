// Public, synthetic-only Chrome DevTools MCP actual tool-call test.
// This measures raw MCP reach and output fidelity, NOT human tab authorization.
import http from 'node:http';
import assert from 'node:assert/strict';
import process from 'node:process';
import path from 'node:path';
import { performance } from 'node:perf_hooks';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const html=label=>`<!doctype html><html lang="en"><head><title>${label}</title></head><body>
<h1>${label}</h1><button id="act">Increment</button>
<output aria-label="Click outcome" id="out" aria-live="polite">UNCHANGED</output>
<script>let count=0;document.querySelector("#act").addEventListener("click",()=>document.querySelector("#out").textContent="${label.split(' ').at(-1).toUpperCase()}_EFFECT_CONFIRMED_"+(++count));</script>
</body></html>`;
const httpServer=http.createServer((req,res)=>{
 const route=new URL(req.url,'http://localhost').pathname;
 if(route==='/session/start'||route==='/session/status'){
  const login=route==='/session/start';
  const accepted=(req.headers.cookie||'').includes('bp_synthetic_session=approved');
  if(login)res.setHeader('Set-Cookie','bp_synthetic_session=approved; HttpOnly; SameSite=Lax; Path=/');
  res.writeHead(200,{'content-type':'text/html; charset=utf-8','cache-control':'no-store'});
  res.end('<!doctype html><html lang="en"><body><h1>'+
    (login?'SYNTHETIC_APPROVED':accepted?'SYNTHETIC_READY':'SYNTHETIC_AUTH_REQUIRED')+'</h1></body></html>');
  return;
 }
 const label=route==='/one'?'Owned tab one':route==='/two'?'Owned tab two':null;
 if(!label){res.writeHead(404);res.end();return;}
 res.writeHead(200,{'content-type':'text/html; charset=utf-8','cache-control':'no-store'});
 res.end(html(label));
});
await new Promise(resolve=>httpServer.listen(0,'127.0.0.1',resolve));
const base='http://127.0.0.1:'+httpServer.address().port;
const client=new Client({name:'browserparity-cdp-synthetic',version:'0.1.0'});
const transport=new StdioClientTransport({
 command:process.execPath,
 args:[path.resolve('node_modules/chrome-devtools-mcp/out/Default/gen/src/bin/chrome-devtools-mcp.js'),
  '--headless','--isolated','--no-usage-statistics','--no-performance-crux'],
 env:{...process.env,CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS:'1',CI:'1'},
 stderr:'pipe'
});
let stderr='';
transport.stderr?.on('data',d=>stderr=(stderr+String(d)).slice(-2500));
const result={donor:'chrome-devtools-mcp',distribution_version:'1.13.0',
 github_source_hint:'4c6c767ddb4332f6334980fec57ebf3ea502ffb8',
 grade:'DONOR_SYNTHETIC_TOOL_INTEGRATION',tests:[],tool_count:0,
 latencies_ms:[],limitations:['No existing human browser or selected-tab grant; both tabs synthetic and owned',
 'Raw tool capability does not establish user authorization','No real identity, MFA, PIN, CAC, provider or AT HIL']};
const text=r=>(r.content||[]).filter(c=>c.type==='text').map(c=>c.text).join('\n');
function check(name,ok,detail){result.tests.push({name,result:ok?'PASS':'FAIL',detail});assert.ok(ok,name+': '+detail);}
async function call(name,args={}){const start=performance.now();const reply=await client.callTool({name,arguments:args});result.latencies_ms.push({tool:name,elapsed:Math.round(performance.now()-start)});if(reply.isError)throw Error(name+': '+text(reply).slice(0,700));return text(reply);}
function idFor(list,url) {
 const row=list.split('\n').find(l=>l.includes(url));
 if(!row)throw Error('list_pages omitted '+url+' '+list.slice(0,600));
 const m=row.match(/(?:^|[^\d])(\d+):\s/);
 if(!m)throw Error('unrecognized page id row: '+row);
 return Number(m[1]);
}
function uidFor(snapshot,word){
 const row=snapshot.split('\n').find(l=>l.includes(word)&&l.includes('uid='));
 if(!row)throw Error('missing element uid for '+word+': '+snapshot.slice(0,1000));
 const m=row.match(/uid=([a-zA-Z0-9_-]+)/);
 if(!m)throw Error('unparseable element uid: '+row);
 return m[1];
}
try{
 await client.connect(transport);
 const {tools}=await client.listTools();
 result.tool_count=tools.length;
 for(const name of ['new_page','list_pages','select_page','take_snapshot','click'])check('tool_'+name,tools.some(x=>x.name===name),'tool advertised via MCP listTools');
 await call('new_page',{url:base+'/one'});
 const list1=await call('list_pages');
 const id1=idFor(list1,base+'/one');
 const snap1=await call('take_snapshot',{pageId:id1});
 check('first_snapshot',snap1.includes('Owned tab one')&&snap1.includes('Increment'),'first owned tab appears in accessibility tree');
 await call('click',{pageId:id1,uid:uidFor(snap1,'Increment')});
 const changed1=await call('take_snapshot',{pageId:id1});
 check('first_click',changed1.includes('ONE_EFFECT_CONFIRMED'),'first page effect independently observed');
 await call('new_page',{url:base+'/two'});
 const list2=await call('list_pages');
 const id2=idFor(list2,base+'/two');
 check('distinct_page_ids',id1!==id2,'CDP offers two page targets');
 const snap2=await call('take_snapshot',{pageId:id2});
 check('second_snapshot',snap2.includes('Owned tab two')&&snap2.includes('UNCHANGED'),'second target observed independently');
 await call('click',{pageId:id2,uid:uidFor(snap2,'Increment')});
 const changed2=await call('take_snapshot',{pageId:id2});
 check('second_click',changed2.includes('TWO_EFFECT_CONFIRMED'),'second target effect independently observed');
 const still1=await call('take_snapshot',{pageId:id1});
 check('first_retained',still1.includes('ONE_EFFECT_CONFIRMED')&&!still1.includes('TWO_EFFECT_CONFIRMED'),'first target unaffected by second click');

 // Probe one owned tab's stale snapshot UID against a DIFFERENT explicitly
 // addressed owned page. The result is descriptive, not a production DENY.
 // A successful raw MCP effect is NOT a human authorization.
 const staleUid=uidFor(snap1,'Increment');
 const secondUid=uidFor(snap2,'Increment');
 const cross=await client.callTool({name:'click',arguments:{pageId:id2,uid:staleUid}});
 const afterStale=await call('take_snapshot',{pageId:id2});
 const didMutate=afterStale.includes('TWO_EFFECT_CONFIRMED_2');
 const retained=afterStale.includes('TWO_EFFECT_CONFIRMED_1');
 result.stale_uid_cross_page={
  identical_uids: staleUid===secondUid,
  tool_is_error: !!cross.isError,
  effect_observed: didMutate,
  preserved_first_effect: retained
 };
 check('stale_uid_cross_page_outcome_observed',
   didMutate!==retained,
   'actual second-page postcondition must identify whether stale source UID mutated the target');
 const firstAfterStale=await call('take_snapshot',{pageId:id1});
 check('stale_uid_unrelated_first_page_still_unchanged',
   firstAfterStale.includes('ONE_EFFECT_CONFIRMED_1'),
   'independent page-one state unchanged; no cross-page inference from call reply');
 check('stale_uid_call_result_classified',
   !cross.isError || retained || didMutate,
   'do not infer no effect from error without checking actual postcondition');

 // Only test-owned synthetic state and cookies; none are real user credentials.
 await call('new_page',{url:base+'/session/start'});
 let pages=await call('list_pages');
 const loggedInId=idFor(pages,base+'/session/start');
 const login=await call('take_snapshot',{pageId:loggedInId});
 check('default_context_synthetic_login',login.includes('SYNTHETIC_APPROVED'),'synthetic login fixture');
 await call('new_page',{url:base+'/session/status'});
 pages=await call('list_pages');
 const defaultStatusId=idFor(pages,base+'/session/status');
 const shared=await call('take_snapshot',{pageId:defaultStatusId});
 check('default_context_session_reuse',shared.includes('SYNTHETIC_READY'),'default context exposes owned test cookie');
 await call('new_page',{url:base+'/session/status?owner=independent',isolatedContext:'bp-test-independent'});
 pages=await call('list_pages');
 const isolatedBeforeId=idFor(pages,base+'/session/status?owner=independent');
 const before=await call('take_snapshot',{pageId:isolatedBeforeId});
 check('isolated_context_cookie_denied',before.includes('SYNTHETIC_AUTH_REQUIRED'),'named independent context lacks default session cookie');
 await call('new_page',{url:base+'/session/start?owner=independent',isolatedContext:'bp-test-independent'});
 pages=await call('list_pages');
 const independentLoginId=idFor(pages,base+'/session/start?owner=independent');
 const independentLogin=await call('take_snapshot',{pageId:independentLoginId});
 check('independent_context_login',independentLogin.includes('SYNTHETIC_APPROVED'),'named context can establish own synthetic session');
 await call('new_page',{url:base+'/session/status?owner=independent-verified',isolatedContext:'bp-test-independent'});
 pages=await call('list_pages');
 const independentStatusId=idFor(pages,base+'/session/status?owner=independent-verified');
 const independentStatus=await call('take_snapshot',{pageId:independentStatusId});
 check('independent_context_session_reuse',independentStatus.includes('SYNTHETIC_READY'),'same named context shares its own synthetic login');
 result.synthetic_auth_isolation_observed=true;
 result.raw_mcp_cross_tab_mutation_observed=true;
 console.log('BP_CDP_DONOR_RECEIPT='+JSON.stringify(result));
}catch(e){
 result.failure=String(e);
 result.stderr_tail=stderr.replaceAll(base,'[SYNTHETIC_LOOPBACK]');
 console.error('BP_CDP_DONOR_RECEIPT='+JSON.stringify(result));
 process.exitCode=1;
}finally{
 await client.close().catch(()=>{});
 await new Promise(resolve=>httpServer.close(resolve));
}
