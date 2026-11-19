// Public synthetic Windows+Chromium nativeMessaging integration. No user browser or private source.
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {existsSync, readFileSync, writeFileSync, mkdirSync, mkdtempSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {chromium} from 'playwright';

const HOST = 'com.sempersupra.r080synthetic';
const registryKeys = [
  'HKCU\\Software\\Chromium\\NativeMessagingHosts\\'+HOST,
  'HKCU\\Software\\Google\\Chrome\\NativeMessagingHosts\\'+HOST
];
const extDir = path.resolve('extension');
const temp = process.env.RUNNER_TEMP || tmpdir();
const root = mkdtempSync(path.join(temp,'r080-owned-browser-'));
const profile = path.join(root,'chromium-owned-profile');
const hostExe = process.env.R080_SYNTHETIC_EXE;
const audit = path.join(root,'synthetic-host-audit.jsonl');
const manifestPath = path.join(root,'owned-native-host.json');
const sleep = ms => new Promise(resolve=>setTimeout(resolve,ms));
let registered = false;
let context;
let testStatus = 'FAIL_CLOSED';

function reg(args) {
  return execFileSync('reg.exe',args,{encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim();
}
function keyExists(key) {
  try {reg(['query',key]);return true;} catch {return false;}
}
function assertClean() {
  for(const key of registryKeys) assert.equal(keyExists(key),false,'foreign/preexisting native messaging registration: '+key);
}
function register(allowedOrigin) {
  assertClean();
  const payload={name:HOST,description:'R080 disposable no-credential native host',path:hostExe,type:'stdio',allowed_origins:[allowedOrigin]};
  writeFileSync(manifestPath,JSON.stringify(payload,null,2)+'\n',{encoding:'utf8',flag:'w'});
  for(const key of registryKeys) reg(['add',key,'/ve','/t','REG_SZ','/d',manifestPath,'/f']);
  registered = true;
}
function unregister() {
  for(const key of registryKeys){
    if(keyExists(key)) reg(['delete',key,'/f']);
  }
  registered=false;
  assertClean();
}
function readAudit() {
  if(!existsSync(audit)) return [];
  return readFileSync(audit,'utf8').trim().split(/\r?\n/).filter(Boolean).map(v=>JSON.parse(v));
}
async function waitAudit(kind,atLeast,limit=6000) {
  const start=Date.now();
  while(Date.now()-start<limit){
    if(readAudit().filter(x=>x.kind===kind).length>=atLeast)return;
    await sleep(70);
  }
  throw new Error('real native host did not record '+kind+' '+atLeast);
}
async function message(worker,kind,nonce) {
  return await worker.evaluate(({host,kind,nonce}) => new Promise(resolve=>{
    const p=chrome.runtime.connectNative(host);
    let done=false;
    const timer=setTimeout(()=>{
      if(!done){done=true;p.disconnect();resolve({kind:'TIMEOUT'})}
    },6000);
    function finish(v){
      if(done)return;
      done=true;clearTimeout(timer);p.disconnect();resolve(v);
    }
    p.onMessage.addListener(m=>finish({kind:'MESSAGE',payload:m}));
    p.onDisconnect.addListener(()=>finish({kind:'DISCONNECT',error:chrome.runtime.lastError?.message||'disconnected'}));
    try {p.postMessage({kind,nonce})} catch(e){finish({kind:'ERROR',error:String(e)})}
  }),{host:HOST,kind,nonce});
}
async function holdAndStop(worker) {
  return await worker.evaluate(host=>new Promise(resolve=>{
    const p=chrome.runtime.connectNative(host);
    let messageCount=0;
    p.onMessage.addListener(()=>messageCount++);
    p.postMessage({kind:'hold',nonce:'stop-before-reply'});
    setTimeout(()=>{
      p.disconnect();
      setTimeout(()=>resolve({messages:messageCount,disconnected:true}),120);
    },120);
  }),HOST);
}
const receipt={
  schema:'bp-r080-real-chromium-native-message/v1',
  github_sha:process.env.GITHUB_SHA||'',
  runner_os:process.env.ImageOS||process.platform,
  source_public_only:true,extension_synthetic:true,
  native_host_registered:false,real_browser_native_host_launched:false,
  actual_operator_approved:false,selected_tab_hil:false,
  user_profile_accessed:false,provider_login:false,
  promotion_authorized:false
};
try {
  assert(hostExe && existsSync(hostExe),'no synthetic host executable');
  assertClean();
  mkdirSync(profile,{recursive:true});
  context = await chromium.launchPersistentContext(profile,{
    channel:'chromium',headless:true,
    args:['--disable-extensions-except='+extDir,'--load-extension='+extDir]
  });
  let worker=context.serviceWorkers()[0];
  if(!worker) worker=await context.waitForEvent('serviceworker',{timeout:20000});
  const workerUrl=worker.url();
  assert(workerUrl.startsWith('chrome-extension://'),'extension service worker not loaded');
  const id=workerUrl.split('/')[2];
  assert.match(id,/^[a-p]{32}$/);
  const trustedOrigin='chrome-extension://'+id+'/';
  // Wrong allowed origin should fail before the native host ever launches.
  register('chrome-extension://'+'a'.repeat(32)+'/');
  if(trustedOrigin==='chrome-extension://'+'a'.repeat(32)+'/')throw new Error('negative origin accidentally matches');
  let denied=await message(worker,'ping','wrong-origin');
  assert.notEqual(denied.kind,'MESSAGE','forged origin launched forbidden host');
  assert.equal(readAudit().length,0,'host ran despite mismatched allowed_origins');
  unregister();
  // Exact immutable discovery ID allowed; real browser must spawn the host and exchange framed bytes.
  register(trustedOrigin);
  const good=await message(worker,'ping','owned-synthetic-nonce');
  assert.equal(good.kind,'MESSAGE','browser failed nativeMessage connection: '+JSON.stringify(good));
  assert.equal(good.payload?.kind,'pong');
  assert.equal(good.payload?.nonce,'owned-synthetic-nonce');
  assert.equal(good.payload?.origin,trustedOrigin);
  await waitAudit('launch',1);
  await waitAudit('exit',1);
  receipt.real_browser_native_host_launched=true;
  receipt.positive_exact_origin_frame_reply=true;
  // Browser port disconnect must close the pending, nonresponding host.
  const noLate=await holdAndStop(worker);
  assert.equal(noLate.messages,0,'late response after caller Stop');
  await waitAudit('launch',2);
  await waitAudit('exit',2);
  receipt.disconnect_pending_no_late_message=true;
  // A removed host must not be reachable even if extension remains loaded.
  unregister();
  const priorLaunches=readAudit().filter(x=>x.kind==='launch').length;
  const afterRemove=await message(worker,'ping','host-unregistered');
  assert.notEqual(afterRemove.kind,'MESSAGE','unregistered host was still reachable');
  await sleep(250);
  assert.equal(readAudit().filter(x=>x.kind==='launch').length,priorLaunches,'removed host was launched after removal');
  receipt.deny_wrong_origin=true;
  receipt.deny_after_unregister=true;
  receipt.synthetic_host_exit_count=readAudit().filter(x=>x.kind==='exit').length;
  receipt.synthetic_host_launch_count=priorLaunches;
  receipt.chromium_version=context.browser()?.version()||'unknown';
  testStatus='PASS';
} finally {
  if(registered){unregister()}
  if(context){await context.close()}
  assertClean();
  receipt.native_host_registered=false;
  receipt.registry_cleanup_verified=true;
  receipt.status=testStatus;
  // No audit file upload: synthetic ephemeral source and exact local evidence only.
  console.log('BP_R080_BROWSER_NATIVE_HOST_RECEIPT='+JSON.stringify(receipt));
}
if(testStatus!=='PASS') process.exitCode=1;
