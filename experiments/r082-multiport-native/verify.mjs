// R082 real Chromium multi-port authority boundary, synthetic pages and host only.
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {existsSync,readFileSync,writeFileSync,mkdirSync,mkdtempSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {createServer} from 'node:http';
import {chromium} from 'playwright';

const HOST='com.sempersupra.r082synthetic';
const keys=[
 'HKCU\\Software\\Chromium\\NativeMessagingHosts\\'+HOST,
 'HKCU\\Software\\Google\\Chrome\\NativeMessagingHosts\\'+HOST
];
const root=mkdtempSync(path.join(process.env.RUNNER_TEMP||tmpdir(),'r082-'));
const exe=process.env.R082_SYNTHETIC_EXE;
const audit=path.join(root,'owned-audit.jsonl');
const hostManifest=path.join(root,'owned-host.json');
const extensionDir=path.resolve('extension');
process.env.R080_SYNTHETIC_AUDIT=audit; // public Go native host audit environment only.
let context,server,registered=false,passed=false;
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
function reg(argv){return execFileSync('reg.exe',argv,{encoding:'utf8',stdio:['ignore','pipe','pipe']});}
function exists(key){try{reg(['query',key]);return true}catch{return false}}
function noHostKeys(){for(const k of keys)assert.equal(exists(k),false,'preexisting/foreign HKCU host registration: '+k)}
function install(origin){
 noHostKeys();
 writeFileSync(hostManifest,JSON.stringify({name:HOST,description:'R082 owned synthetic',
   path:exe,type:'stdio',allowed_origins:[origin]},null,2)+'\n');
 for(const k of keys) reg(['add',k,'/ve','/t','REG_SZ','/d',hostManifest,'/f']);
 registered=true;
}
function removeHost(){
 for(const k of keys)if(exists(k))reg(['delete',k,'/f']);
 registered=false;noHostKeys();
}
function auditEntries(){
 if(!existsSync(audit))return [];
 return readFileSync(audit,'utf8').split(/\r?\n/).filter(Boolean).map(line=>JSON.parse(line));
}
async function waitCount(kind,n,limit=6000){
 const deadline=Date.now()+limit;
 while(Date.now()<deadline){if(auditEntries().filter(e=>e.kind===kind).length>=n)return;await sleep(65)}
 throw Error('audit missing '+kind+' count '+n);
}
async function allTabs(worker,base){
 return await worker.evaluate(async(base)=>{
  const tabs=await chrome.tabs.query({});
  return tabs.filter(tab=>typeof tab.url==='string'&&tab.url.startsWith(base))
    .map(tab=>({id:tab.id,url:tab.url})).sort((a,b)=>a.url.localeCompare(b.url));
 },base);
}
async function openForOwnedTabs(worker,targets){
 return await worker.evaluate(async ({host,targets})=>{
  globalThis.__r082_active=[];
  const records=[];
  for(const target of targets){
   const port=chrome.runtime.connectNative(host);
   const nonce='owned-tab-'+target.id;
   const reply=await new Promise(resolve=>{
    let done=false;
    const timer=setTimeout(()=>finish({kind:'TIMEOUT'}),4500);
    function finish(value){if(done)return;done=true;clearTimeout(timer);resolve(value)}
    port.onMessage.addListener(m=>finish({kind:'MESSAGE',value:m}));
    port.onDisconnect.addListener(()=>finish({kind:'DISCONNECT',error:chrome.runtime.lastError?.message||''}));
    port.postMessage({kind:'ping',nonce});
   });
   if(reply.kind!=='MESSAGE')throw Error('native port not connected: '+JSON.stringify(reply));
   globalThis.__r082_active.push({port,tabId:target.id,nonce});
   records.push({tabId:target.id,nonce,origin:reply.value?.origin,pong:reply.value?.kind,echo:reply.value?.nonce});
  }
  return records;
 },{host:HOST,targets});
}
async function communicate(worker,indices){
 return await worker.evaluate(async indices=>{
  const result=[];
  for(const idx of indices){
   const item=globalThis.__r082_active[idx];
   if(!item)throw Error('missing opened port '+idx);
   const nonce='live-'+item.tabId+'-'+idx;
   const got=await new Promise(resolve=>{
    let done=false;
    const timer=setTimeout(()=>finish({kind:'TIMEOUT'}),4500);
    function finish(x){if(done)return;done=true;clearTimeout(timer);resolve(x)}
    const listener=m=>{item.port.onMessage.removeListener(listener);finish({kind:'MESSAGE',value:m})};
    item.port.onMessage.addListener(listener);
    item.port.onDisconnect.addListener(()=>finish({kind:'DISCONNECT',error:chrome.runtime.lastError?.message||''}));
    try{item.port.postMessage({kind:'ping',nonce})}catch(e){finish({kind:'ERROR',error:String(e)})}
   });
   result.push({idx,expected:nonce,got});
  }
  return result;
 },indices);
}
async function stopOne(worker,idx){
 return await worker.evaluate(idx=>{
  const item=globalThis.__r082_active[idx];
  if(!item)throw Error('missing port');
  item.port.disconnect();
  item.stopped=true;
  return true;
 },idx);
}
async function stopAll(worker){
 return await worker.evaluate(()=>{
  let closed=0;
  for(const item of globalThis.__r082_active||[]){
   if(!item.stopped){item.port.disconnect();item.stopped=true;closed++}
  }
  return closed;
 });
}
async function attemptNew(worker){
 return await worker.evaluate(host=>new Promise(resolve=>{
   const port=chrome.runtime.connectNative(host);
   let done=false;
   const timer=setTimeout(()=>finish('TIMEOUT'),4500);
   function finish(kind){if(done)return;done=true;clearTimeout(timer);try{port.disconnect()}catch{}resolve(kind)}
   port.onMessage.addListener(()=>finish('MESSAGE'));
   port.onDisconnect.addListener(()=>finish('DISCONNECT'));
   try{port.postMessage({kind:'ping',nonce:'after-unregister'})}catch{finish('ERROR')}
 }),HOST);
}

const receipt={schema:'bp-r082-browser-multiport-stop/v1',source:process.env.GITHUB_SHA,
 os_image:process.env.ImageOS,real_browser:true,private_product_source:false,
 profile:'ephemeral-test-only',actual_chatgpt:false,operator_approval:false,
 selected_tab_authority_qualified:false,promotion_authorized:false,
 registry_cleanup:false,status:'FAIL_CLOSED'};

try{
 assert(exe&&existsSync(exe),'missing temporary Go native host');
 noHostKeys();
 mkdirSync(path.join(root,'profile'),{recursive:true});
 server=createServer((request,response)=>{
  const u=request.url;
  if(u!=='/a'&&u!=='/b'){response.writeHead(404);response.end();return}
  response.writeHead(200,{'content-type':'text/html','cache-control':'no-store'});
  response.end('<!DOCTYPE html><title>R082 '+u+'</title><p>Owned synthetic tab '+u+'</p>');
 });
 await new Promise((resolve,reject)=>server.once('error',reject).listen(0,'127.0.0.1',resolve));
 const base='http://127.0.0.1:'+server.address().port+'/';
 context=await chromium.launchPersistentContext(path.join(root,'profile'),{
  headless:true,channel:'chromium',
  args:['--disable-extensions-except='+extensionDir,'--load-extension='+extensionDir]
 });
 const tabA=await context.newPage(),tabB=await context.newPage();
 await Promise.all([tabA.goto(base+'a'),tabB.goto(base+'b')]);
 let worker=context.serviceWorkers()[0];
 if(!worker)worker=await context.waitForEvent('serviceworker',{timeout:20000});
 const workerUrl=worker.url();
 assert(workerUrl.startsWith('chrome-extension://'));
 const id=workerUrl.split('/')[2];
 assert.match(id,/^[a-p]{32}$/);
 const origin='chrome-extension://'+id+'/';
 const owned=await allTabs(worker,base);
 assert.equal(owned.length,2,'exact owned A/B test tabs not exposed to synthetic extension');
 assert(owned.some(x=>x.url.endsWith('/a'))&&owned.some(x=>x.url.endsWith('/b')));
 receipt.owned_tabs_observed=owned.length;
 install(origin);
 // No nativeMessaging OS tab authority: the same extension origin can instantiate a port per tab.
 const initial=await openForOwnedTabs(worker,owned);
 assert.equal(initial.length,2);
 for(const x of initial){
  assert.equal(x.pong,'pong');
  assert.equal(x.echo,x.nonce);
  assert.equal(x.origin,origin);
 }
 await waitCount('launch',2);
 receipt.port_count_initial=initial.length;
 receipt.same_extension_origin_for_distinct_tabs=true;
 // Only closing one port must not terminate sibling host access.
 await stopOne(worker,0);
 await waitCount('exit',1);
 const survivor=await communicate(worker,[1]);
 assert.equal(survivor[0].got.kind,'MESSAGE');
 assert.equal(survivor[0].got.value.nonce,survivor[0].expected);
 receipt.stop_one_does_not_stop_sibling=true;
 // Registry removal prevents new launch, but must not be confused with active Stop.
 removeHost();
 const next=await attemptNew(worker);
 assert.notEqual(next,'MESSAGE','unauthorized new port after native host removal');
 assert.equal(auditEntries().filter(e=>e.kind==='launch').length,2);
 const existing=await communicate(worker,[1]);
 assert.equal(existing[0].got.kind,'MESSAGE','existing native host unexpectedly lost before explicit Stop');
 receipt.registry_unregistration_retains_active_port=true;
 receipt.new_port_denied_after_unregister=true;
 // Operator-style global Stop must close ALL active ports and be idempotent.
 assert.equal(await stopAll(worker),1);
 await waitCount('exit',2);
 assert.equal(await stopAll(worker),0);
 const after=await attemptNew(worker);
 assert.notEqual(after,'MESSAGE','reconnect admitted after unregister and Stop');
 assert.equal(auditEntries().filter(e=>e.kind==='launch').length,2);
 receipt.stop_all_idempotent=true;
 receipt.stop_all_terminated_all_hosts=true;
 receipt.post_stop_reconnect_denied=true;
 receipt.native_launches=auditEntries().filter(e=>e.kind==='launch').length;
 receipt.native_exits=auditEntries().filter(e=>e.kind==='exit').length;
 receipt.chromium_version=context.browser()?.version()||'unknown';
 passed=true;
}finally{
 if(registered)removeHost();
 if(context)await context.close();
 if(server)await new Promise(resolve=>server.close(resolve));
 noHostKeys();
 receipt.registry_cleanup=true;
 receipt.status=passed?'PASS':'FAIL_CLOSED';
 console.log('BP_R082_MULTIPORT_RECEIPT='+JSON.stringify(receipt));
}
if(!passed)process.exitCode=1;
