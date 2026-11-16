// Exact-source public Playwright MCP donor qualification against 127.0.0.1 only.
// No BrowserParity private data, provider credentials or personal profiles.
// Evidence: DONOR_SYNTHETIC_TOOL_INTEGRATION, not selected-tab authority or human HIL.
import assert from 'node:assert/strict';
import http from 'node:http';
import { performance } from 'node:perf_hooks';
import path from 'node:path';
import process from 'node:process';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const html = (label) => `<!doctype html><html lang="en"><head><title>${label}</title></head><body>
<main><h1>${label}</h1><button id="increment">Increment</button>
<output id="counter" aria-live="polite">0</output></main>
<script>let n=0;document.querySelector("#increment").addEventListener("click",()=>{document.querySelector("#counter").textContent=String(++n)})</script>
</body></html>`;
const server = http.createServer((req,res)=>{
  const pathname = new URL(req.url,'http://localhost').pathname;
  if (pathname === '/session/start' || pathname === '/session/status') {
    const isLogin = pathname === '/session/start';
    const authenticated = (req.headers.cookie || '').includes('bp_synthetic_session=approved');
    if (isLogin) res.setHeader('Set-Cookie','bp_synthetic_session=approved; HttpOnly; SameSite=Lax; Path=/');
    res.writeHead(200,{'content-type':'text/html; charset=utf-8','cache-control':'no-store'});
    res.end('<!doctype html><html lang="en"><body><main><h1>'+(
      isLogin ? 'SYNTHETIC_APPROVED' : authenticated ? 'SYNTHETIC_READY' : 'SYNTHETIC_AUTH_REQUIRED'
    )+'</h1></main></body></html>');
    return;
  }
  const label = pathname === '/one' ? 'Owned tab one' : pathname === '/two' ? 'Owned tab two' : null;
  if (!label) {res.writeHead(404,{'content-type':'text/plain'});res.end('missing');return;}
  res.writeHead(200,{'content-type':'text/html; charset=utf-8','cache-control':'no-store'});res.end(html(label));
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const base='http://127.0.0.1:'+server.address().port;
const transport = new StdioClientTransport({
  command: process.execPath,
  args: [path.resolve('cli.js'),'--headless','--browser=chromium','--isolated','--no-webmcp'],
  env: {...process.env, PLAYWRIGHT_MCP_IGNORE_ROOTS:'true'},
  stderr: 'pipe'
});
let stderr='';
transport.stderr?.on('data',d=>{stderr+=String(d).slice(0,3000);});
const client = new Client({name:'browserparity-synthetic-donor-probe',version:'0.1.0'});
const receipt={donor:'microsoft/playwright-mcp',evidence_grade:'DONOR_SYNTHETIC_TOOL_INTEGRATION',
  upstream_sha:process.env.DONOR_SHA||'UNKNOWN',tests:[],tool_count:0,latencies_ms:[],limitations:[
  'Owned disposable synthetic tabs only; not real selected-tab human grant or Stop/revoke.',
  'A successful raw MCP tab switch is NOT evidence of operation authorization.',
  'No provider session, identity, CAC, MFA, or assistive technology HIL.'
]};
const t=(name,ok,detail)=>{receipt.tests.push({name,result:ok?'PASS':'FAIL',detail});assert.ok(ok,`${name}: ${detail}`);};
const asText=r=>(r.content||[]).filter(c=>c.type==='text').map(c=>c.text).join('\n');
async function call(name,args={}) {
 const started=performance.now();
 const r=await client.callTool({name,arguments:args});
 receipt.latencies_ms.push({tool:name,elapsed:Math.round(performance.now()-started)});
 if (r.isError) throw new Error(name+' failed: '+asText(r).slice(0,700));
 return asText(r);
}
try {
 await client.connect(transport);
 const {tools}=await client.listTools();
 receipt.tool_count=tools.length;
 for (const name of ['browser_navigate','browser_snapshot','browser_click','browser_tabs']) {
   t('tool_available_'+name,tools.some(x=>x.name===name),'expected official named tool in listTools');
 }
 const n=await call('browser_navigate',{url:base+'/one'});
 t('navigate_owned_one',n.includes('Owned tab one'),'actual native MCP navigation output contained owned target');
 const s=await call('browser_snapshot');
 t('snapshot_accessible_name',s.includes('Increment')&&s.includes('Owned tab one'),'snapshot captured accessible text');
 const c=await call('browser_click',{target:'#increment'});
 t('owned_one_click',c.includes('1'),'actual tool call changed owned page counter to 1');
 const tabs1=await call('browser_tabs',{action:'new',url:base+'/two'});
 t('new_owned_tab',tabs1.includes('Owned tab two')||tabs1.includes('/two'),'second tab advertised by browser_tabs');
 await call('browser_tabs',{action:'select',index:1});
 const s2=await call('browser_snapshot');
 t('second_tab_visible',s2.includes('Owned tab two')&&s2.includes('0'),'second tab independently visible');
 const c2=await call('browser_click',{target:'#increment'});
 t('second_tab_independent_effect',c2.includes('1'),'second tab incremented by actual raw MCP operation');
 await call('browser_tabs',{action:'select',index:0});
 const s1=await call('browser_snapshot');
 t('first_tab_retained',s1.includes('Owned tab one')&&s1.includes('1'),'first tab count survived tab switch');

 // SECURITY-NEGATIVE OBSERVATION ONLY: no operator authorization wrapper exists.
 // A snapshot obtained on tab one is NOT bound by the raw MCP API to a later click.
 // Switch the underlying selected page to owned tab two, then act using a
 // stale selector from tab one. Both pages belong to this synthetic test.
 await call('browser_tabs',{action:'select',index:0});
 const staleSnapshot=await call('browser_snapshot');
 t('stale_snapshot_was_tab_one',staleSnapshot.includes('Owned tab one'),'observe tab one before synthetic scope switch');
 await call('browser_tabs',{action:'select',index:1});
 await call('browser_click',{target:'#increment'});
 const switchedEffect=await call('browser_snapshot');
 await call('browser_tabs',{action:'select',index:0});
 const unchangedOne=await call('browser_snapshot');
 t('raw_mcp_stale_snapshot_target_not_bound',
   switchedEffect.includes('Owned tab two') && switchedEffect.includes('2') &&
   unchangedOne.includes('Owned tab one') && unchangedOne.includes('1'),
   'raw tool operates current selected tab, not the prior snapshot tab; requires independent mediator');
 receipt.stale_snapshot_caution_observed=true;

 // Synthetic login involves no password, user, credential or external identity provider.
 // What matters is whether the donor's browser contexts actually isolate test cookies.
 await call('browser_tabs',{action:'new',url:base+'/session/start'});
 await call('browser_tabs',{action:'select',index:2});
 const loggedIn=await call('browser_snapshot');
 t('default_context_synthetic_login',loggedIn.includes('SYNTHETIC_APPROVED'),'synthetic login only');
 await call('browser_tabs',{action:'new',url:base+'/session/status'});
 await call('browser_tabs',{action:'select',index:3});
 const shared=await call('browser_snapshot');
 t('default_context_cookie_reused',shared.includes('SYNTHETIC_READY'),'second default-context tab receives simulated login state');
 await call('browser_tabs',{action:'new',url:base+'/session/status',isolatedContext:'bp-test-independent'});
 await call('browser_tabs',{action:'select',index:4});
 const isolatedBefore=await call('browser_snapshot');
 t('separate_context_cookie_denied',isolatedBefore.includes('SYNTHETIC_AUTH_REQUIRED'),'named independent context lacks default cookie');
 await call('browser_tabs',{action:'new',url:base+'/session/start',isolatedContext:'bp-test-independent'});
 await call('browser_tabs',{action:'select',index:5});
 const isolatedLogin=await call('browser_snapshot');
 t('separate_context_synthetic_login',isolatedLogin.includes('SYNTHETIC_APPROVED'),'separate context can establish its own synthetic session');
 await call('browser_tabs',{action:'new',url:base+'/session/status',isolatedContext:'bp-test-independent'});
 await call('browser_tabs',{action:'select',index:6});
 const isolatedAfter=await call('browser_snapshot');
 t('separate_context_cookie_shared_within_context',isolatedAfter.includes('SYNTHETIC_READY'),'same named context reuses its own synthetic cookie');
 receipt.synthetic_auth_isolation_observed=true;
 receipt.raw_mcp_cross_tab_mutation_observed=true;
 console.log('BP_DONOR_RECEIPT='+JSON.stringify(receipt));
} catch(err) {
 receipt.failure=String(err);
 receipt.stderr_tail=stderr.slice(-1500).replaceAll(base,'[SYNTHETIC_LOOPBACK]');
 console.error('BP_DONOR_RECEIPT='+JSON.stringify(receipt));
 process.exitCode=1;
} finally {
 await client.close().catch(()=>{});
 await new Promise(resolve=>server.close(resolve));
}
