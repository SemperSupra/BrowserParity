// R082: actual disposable Chromium two-tab MV3 metadata-only boundary.
// Source-owned synthetic pages, no authenticated provider or private BrowserParity files.
import assert from "node:assert/strict";
import http from "node:http";
import {mkdirSync,mkdtempSync} from "node:fs";
import {tmpdir} from "node:os";
import path from "node:path";
import {chromium} from "playwright";

const root=mkdtempSync(path.join(process.env.RUNNER_TEMP||tmpdir(),"r082-disposable-"));
const profile=path.join(root,"profile");
const extension=path.resolve("extension");
const counts={a:0,b:0,moved:0,other:0};
const server=http.createServer((req,res)=>{
  const name=req.url?.split("?")[0].replace("/","")||"other";
  if(Object.hasOwn(counts,name)) counts[name]++; else counts.other++;
  res.writeHead(200,{"Content-Type":"text/html; charset=utf-8","Cache-Control":"no-store","X-Frame-Options":"DENY"});
  res.end("<!doctype html><html><head><title>Owned R082 "+name.toUpperCase()+"</title></head>"+
   "<body><h1>Owned synthetic "+name+"</h1><p id='sensitive-fixture'>BODY_SENTINEL_NEVER_EXPORT_R082</p>"+
   "<script>window.__r082OwnedMutationCount=0</script></body></html>");
});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
await new Promise((resolve,reject)=>{
  server.on("error",reject);
  server.listen(0,"127.0.0.1",resolve);
});
const port=server.address().port;
const base="http://127.0.0.1:"+port;
const receipt={
  schema:"bp-r082-synthetic-selected-tab-real-chromium/v1",
  source_sha:process.env.GITHUB_SHA||"",
  os:process.env.ImageOS||process.platform,
  browser:"playwright-bundled-chromium",
  public_owned_synthetic_only:true,
  real_provider_login:false,
  user_profile_accessed:false,
  actual_human_operator_grant:false,
  private_native_host_executed:false,
  ghcr_or_model_weights:false,
  promotion_authorized:false,
};
let context;
let stage="bootstrap";
let result="RED_UNVERIFIED";
async function startBrowser(){
  mkdirSync(profile,{recursive:true});
  return await chromium.launchPersistentContext(profile,{
    channel:"chromium",headless:true,
    args:["--disable-extensions-except="+extension,"--load-extension="+extension]
  });
}
async function getWorker(ctx){
  const found=ctx.serviceWorkers()[0];
  return found||await ctx.waitForEvent("serviceworker",{timeout:25000});
}
async function listSyntheticTabs(worker) {
  return worker.evaluate(async()=>{
    const ts=await chrome.tabs.query({});
    return ts.map(t=>({id:t.id,url:t.url||"",windowId:t.windowId,active:t.active}));
  });
}
async function activate(worker,id) {
  await worker.evaluate(async tabId=>await chrome.tabs.update(tabId,{active:true}),id);
  for(let i=0;i<25;i++){
    const tab=await worker.evaluate(async tabId=>await chrome.tabs.get(tabId),id);
    if(tab.active)return;
    await sleep(80);
  }
  throw Error("cannot activate selected owned tab");
}
async function call(worker,method,...values){
  return await worker.evaluate(async o=>{
    const api=globalThis.__r082Fixture;
    if(!api||typeof api[o.method]!=="function")throw Error("no exact synthetic worker API");
    return await api[o.method](...o.values);
  },{method,values});
}
function deny(r,label) {
  assert.equal(r?.status,"DENY",label+": expected DENY "+JSON.stringify(r));
  assert.equal(r?.metadata,null,label+": leaked metadata");
  return r.reason;
}
function metadata(r,url,title) {
  assert.equal(r?.status,"READ_ONLY_METADATA",JSON.stringify(r));
  assert.deepEqual(Object.keys(r.metadata).sort(),["origin","title","url"]);
  assert.equal(r.metadata.url,url);
  assert.equal(r.metadata.title,title);
  assert.equal(r.metadata.origin,base);
  assert.equal(r.actual_operator_approval,false);
  assert.equal(r.promotion_authorized,false);
  assert.equal(JSON.stringify(r).includes("BODY_SENTINEL_NEVER_EXPORT_R082"),false);
}
try {
  stage="open-two-tabs";
  context=await startBrowser();
  let worker=await getWorker(context);
  const a=await context.newPage();
  const b=await context.newPage();
  await Promise.all([a.goto(base+"/a"),b.goto(base+"/b")]);
  const tabs=await listSyntheticTabs(worker);
  const ta=tabs.find(t=>t.url===base+"/a");
  const tb=tabs.find(t=>t.url===base+"/b");
  assert(ta && tb && ta.id!==tb.id,"independent actual Chromium tabs not found");
  const originalMutations=await Promise.all([a.evaluate(()=>window.__r082OwnedMutationCount),
    b.evaluate(()=>window.__r082OwnedMutationCount)]);
  assert.deepEqual(originalMutations,[0,0]);
  receipt.actual_disposable_tabs=2;
  receipt.chromium_version=context.browser()?.version()||"unknown";
  stage="ungranted";
  deny(await call(worker,"observeMetadata",ta.id,1),"initial no grant");
  stage="operator-selected-synthetic-A";
  await activate(worker,ta.id);
  deny(await call(worker,"grantSynthetic",tb.id),"cannot grant inactive adjacent B");
  const grant=await call(worker,"grantSynthetic",ta.id);
  assert.equal(grant.status,"SYNTHETIC_GRANT");
  const g1=grant.epoch;
  metadata(await call(worker,"observeMetadata",ta.id,g1),base+"/a","Owned R082 A");
  deny(await call(worker,"observeMetadata",tb.id,g1),"adjacent B");
  receipt.selected_metadata_only=true;
  receipt.adjacent_tab_denied=true;
  stage="same-tab-redirect";
  await a.goto(base+"/moved");
  deny(await call(worker,"observeMetadata",ta.id,g1),"URL drift within same owned origin");
  receipt.url_drift_denied=true;
  await a.goto(base+"/a");
  await activate(worker,ta.id);
  const grant2=await call(worker,"grantSynthetic",ta.id);
  assert(grant2.epoch>g1,"epoch did not advance across navigation");
  deny(await call(worker,"observeMetadata",ta.id,g1),"replay old grant");
  metadata(await call(worker,"observeMetadata",ta.id,grant2.epoch),base+"/a","Owned R082 A");
  receipt.stale_epoch_denied=true;
  stage="focus-change";
  await activate(worker,tb.id);
  deny(await call(worker,"observeMetadata",ta.id,grant2.epoch),"selected tab no longer active");
  deny(await call(worker,"observeMetadata",tb.id,grant2.epoch),"adjacent cannot inherit grant");
  receipt.focus_change_denied=true;
  stage="visible-stop-model";
  await activate(worker,ta.id);
  const grant3=await call(worker,"grantSynthetic",ta.id);
  assert.equal(grant3.status,"SYNTHETIC_GRANT");
  const stopped=await call(worker,"stopSynthetic");
  assert.equal(stopped.status,"STOPPED");
  deny(await call(worker,"observeMetadata",ta.id,grant3.epoch),"Stop revocation");
  receipt.stop_denied=true;
  const adjacentMutations=await b.evaluate(()=>window.__r082OwnedMutationCount);
  assert.equal(adjacentMutations,0,"adjacent synthetic DOM unexpectedly mutated");
  stage="browser-restart-reconnect";
  await context.close();context=null;
  context=await startBrowser();
  worker=await getWorker(context);
  const after=await context.newPage();
  await after.goto(base+"/a");
  const again=(await listSyntheticTabs(worker)).find(t=>t.url===base+"/a");
  assert(again,"reconnected owned synthetic tab missing");
  await activate(worker,again.id);
  deny(await call(worker,"observeMetadata",again.id,grant3.epoch),"persisted stale grant after restart");
  const workerState=await call(worker,"current");
  assert.equal(workerState.has_lease,false,"lease persisted through full browser restart");
  receipt.browser_reconnect_stale_grant_denied=true;
  receipt.adjacent_dom_mutations=adjacentMutations;
  result="PASS";
} finally {
  if(context)await context.close();
  await new Promise(resolve=>server.close(resolve));
  receipt.stage=stage;
  receipt.status=result;
  console.log("BP_R082_SELECTED_TAB_RECEIPT="+JSON.stringify(receipt));
}
if(result!=="PASS")process.exitCode=1;
