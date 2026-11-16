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
<script>document.querySelector("#act").addEventListener("click",()=>document.querySelector("#out").textContent="${label.split(' ').at(-1).toUpperCase()}_EFFECT_CONFIRMED");</script>
</body></html>`;
const httpServer=http.createServer((req,res)=>{
 const route=new URL(req.url,'http://localhost').pathname;
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
