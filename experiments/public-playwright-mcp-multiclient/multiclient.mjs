// Source-safe multi-client isolated MCP HTTP qualification. No human browser.
// Exact upstream source is pinned by the workflow checkout.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import http from 'node:http';
import path from 'node:path';
import process from 'node:process';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';

const site=http.createServer((req,res)=>{
 const pathname=new URL(req.url,'http://127.0.0.1').pathname;
 let content,headers={};
 if(pathname==='/a'||pathname==='/b'){
  const title=pathname==='/a'?'Alpha owner':'Beta owner';
  content=`<h1>${title}</h1><button id="act">Increment</button><output id="counter" aria-live="polite">0</output>
<script>document.getElementById('act').onclick=()=>{const x=document.getElementById('counter');x.textContent=String(Number(x.textContent)+1)}</script>`;
 }else if(pathname==='/login'){
  headers['Set-Cookie']='bp_fixture=synthetic; HttpOnly; SameSite=Lax; Path=/';
  content='<h1>SYNTHETIC_APPROVED</h1>';
 }else if(pathname==='/status'){
  content=req.headers.cookie?.includes('bp_fixture=synthetic')?'<h1>SYNTHETIC_READY</h1>':'<h1>SYNTHETIC_AUTH_REQUIRED</h1>';
 }else{res.writeHead(404);res.end();return;}
 res.writeHead(200,{'content-type':'text/html; charset=utf-8','cache-control':'no-store',...headers});
 res.end('<!doctype html><html lang="en"><body><main>'+content+'</main></body></html>');
});
await new Promise(resolve=>site.listen(0,'127.0.0.1',resolve));
const siteUrl='http://127.0.0.1:'+site.address().port;
let child;
let stderr='';
let clientSlots=[];
const receipt={donor:'microsoft/playwright-mcp',evidence_grade:'ACTUAL_HTTP_MULTICLIENT_SYNTHETIC',
 upstream_sha:process.env.DONOR_SHA||'UNKNOWN',checks:[],limits:[
 'Test-only MCP HTTP server on loopback, isolated contexts, no existing profile',
 'A client session is not a proven operator grant; transport not production authorization',
 'No physical human Stop action, real MFA/CAC/provider login or trusted P0 evidence'
]};
function check(name,ok,detail){receipt.checks.push({name,result:ok?'PASS':'FAIL',detail});assert.ok(ok,name+': '+detail);}
const out=x=>(x.content||[]).filter(p=>p.type==='text').map(p=>p.text).join('\n');
async function call(c,name,args={}){
 const x=await c.callTool({name,arguments:args});
 if(x.isError)throw Error(name+' error: '+out(x).slice(0,900));
 return out(x);
}
async function connect(label,base){
 const transport=new StreamableHTTPClientTransport(new URL('/mcp',base));
 const client=new Client({name:'bp-synthetic-'+label,version:'0.1.0'});
 await client.connect(transport);
 clientSlots.push({transport,client,label});
 return client;
}
async function disconnect(label){
 const slot=clientSlots.find(s=>s.label===label);
 if(!slot)return;
 await slot.transport.terminateSession();
 await slot.client.close();
 clientSlots=clientSlots.filter(s=>s!==slot);
}
async function launchServer(){
 return await new Promise((resolve,reject)=>{
   let resolved=false;
   const timeout=setTimeout(()=>{if(!resolved)reject(Error('MCP HTTP server not ready: '+stderr.slice(-1200)));},30000);
   child=spawn(process.execPath,[path.resolve('cli.js'),'--port=0','--host=127.0.0.1',
    '--headless','--browser=chromium','--isolated','--no-webmcp'],{cwd:process.cwd(),
       env:{...process.env,PLAYWRIGHT_MCP_IGNORE_ROOTS:'true'},stdio:['ignore','pipe','pipe']});
   child.stderr.on('data',data=>{
      stderr=(stderr+data.toString()).slice(-4000);
      const m=stderr.match(/Listening on (http:\/\/[^\s]+)/);
      if(m&&!resolved){resolved=true;clearTimeout(timeout);resolve(m[1]);}
   });
   child.once('error',e=>{if(!resolved){clearTimeout(timeout);reject(e);}});
   child.once('exit',(code,signal)=>{if(!resolved){clearTimeout(timeout);reject(Error('MCP exited before listen '+code+'/'+signal));}});
 });
}
try {
 const endpoint=await launchServer();
 const a=await connect('A',endpoint);
 const b=await connect('B',endpoint);
 const res=await Promise.all([
   call(a,'browser_navigate',{url:siteUrl+'/a'}),
   call(b,'browser_navigate',{url:siteUrl+'/b'})
 ]);
 receipt.parallel_navigation_response_contains_page_title=res.map((x,i)=>x.includes(i===0?'Alpha owner':'Beta owner'));
 // Browser navigation replies need not carry a full page tree; observe the
 // postcondition independently via an actual snapshot in each HTTP client.
 const [sa,sb]=await Promise.all([call(a,'browser_snapshot'),call(b,'browser_snapshot')]);
 check('parallel_distinct_pages',sa.includes('Alpha owner')&&sb.includes('Beta owner'),
  'post-navigation independent snapshot in each of two concurrent HTTP clients');
 check('client_a_document',sa.includes('Alpha owner')&&!sa.includes('Beta owner'),'A sees A');
 check('client_b_document',sb.includes('Beta owner')&&!sb.includes('Alpha owner'),'B sees B');
 await call(a,'browser_click',{target:'#act'});
 const sa1=await call(a,'browser_snapshot');
 const sb0=await call(b,'browser_snapshot');
 check('a_mutation_not_in_b',sa1.includes('1')&&sb0.includes('0'),'actual A effect does not modify B');
 await call(a,'browser_navigate',{url:siteUrl+'/login'});
 await call(a,'browser_navigate',{url:siteUrl+'/status'});
 await call(b,'browser_navigate',{url:siteUrl+'/status'});
 const [aAuth,bAnon]=await Promise.all([call(a,'browser_snapshot'),call(b,'browser_snapshot')]);
 check('synthetic_session_cookie_separation',aAuth.includes('SYNTHETIC_READY')&&bAnon.includes('SYNTHETIC_AUTH_REQUIRED'),
   'test login in A is absent from B');
 await disconnect('A');
 await call(b,'browser_navigate',{url:siteUrl+'/b'});
 const bAgain=await call(b,'browser_snapshot');
 check('b_survives_a_termination',bAgain.includes('Beta owner'),'B continues after A session terminated');
 const c=await connect('C',endpoint);
 await call(c,'browser_navigate',{url:siteUrl+'/status'});
 const cAnon=await call(c,'browser_snapshot');
 check('new_client_not_inheriting_a_cookie',cAnon.includes('SYNTHETIC_AUTH_REQUIRED'),'new HTTP MCP client has no A cookie');
 await disconnect('B');
 await call(c,'browser_navigate',{url:siteUrl+'/a'});
 const cStill=await call(c,'browser_snapshot');
 check('c_survives_b_termination',cStill.includes('Alpha owner'),'C continues after B disconnected');
 await disconnect('C');
 receipt.http_mcp_session_isolation_observed=true;
 console.log('BP_MULTICLIENT_RECEIPT='+JSON.stringify(receipt));
}catch(e){
 receipt.failure=String(e);
 receipt.stderr_tail=stderr.replaceAll(siteUrl,'[OWNED_LOOPBACK]').slice(-1200);
 console.error('BP_MULTICLIENT_RECEIPT='+JSON.stringify(receipt));
 process.exitCode=1;
}finally{
 await Promise.allSettled(clientSlots.map(async slot=>{await slot.transport.terminateSession().catch(()=>{});await slot.client.close().catch(()=>{});}));
 child?.kill('SIGTERM');
 await new Promise(resolve=>site.close(resolve));
}
