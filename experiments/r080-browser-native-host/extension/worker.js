/* Public R082 disposable Chromium selected-tab read-only scope oracle.
 * This is an in-process TEST fixture; a Playwright harness can invoke its synthetic
 * grant function. It is NOT a human grant issuer, product integration or signed authority.
 */
let lease = null;
let epochCounter = 0;
const fixtureOrigin = "http://127.0.0.1";
const DENY = reason => ({status:"DENY",reason,metadata:null,promotion_authorized:false});

async function snapshotTab(tabId) {
  if (!Number.isSafeInteger(tabId) || tabId < 0) return null;
  try {
    const tab=await chrome.tabs.get(tabId);
    if (!tab || !tab.url || !tab.active) return null;
    const parsed=new URL(tab.url);
    if (parsed.protocol !== "http:" || parsed.hostname !== "127.0.0.1") return null;
    return {id:tab.id,url:tab.url,origin:parsed.origin,windowId:tab.windowId,active:tab.active};
  } catch { return null; }
}
async function grantSynthetic(tabId) {
  // No actor has real operator authority here; the test harness controls which
  // disposable synthetic tab is chosen. A production adapter MUST NOT expose this.
  const tab=await snapshotTab(tabId);
  if (!tab) return DENY("NO_ACTIVE_SYNTHETIC_TAB");
  epochCounter++;
  lease={tabId:tab.id,url:tab.url,origin:tab.origin,windowId:tab.windowId,epoch:epochCounter};
  return {status:"SYNTHETIC_GRANT",tab_id:tabId,epoch:epochCounter,promotion_authorized:false};
}
async function observeMetadata(tabId,epoch) {
  const l=lease;
  if (!l) return DENY("NO_LEASE");
  if (tabId!==l.tabId || epoch!==l.epoch) return DENY("FOREIGN_OR_STALE_TAB_OR_EPOCH");
  const tab=await snapshotTab(tabId);
  if (!tab || tab.windowId!==l.windowId || tab.url!==l.url || tab.origin!==l.origin) {
    lease=null;
    return DENY("NAVIGATION_FOCUS_OR_WINDOW_DRIFT");
  }
  // Only URL/origin/title are read in actual page context, never body, cookies,
  // storage, credentials or text from a ChatGPT conversation.
  let metadata;
  try {
    const rs=await chrome.scripting.executeScript({
      target:{tabId},
      func:()=>({url:window.location.href,origin:window.location.origin,title:document.title})
    });
    if (rs.length!==1 || !rs[0].result) return DENY("NO_EXACT_TAB_RESULT");
    metadata=rs[0].result;
  } catch {
    lease=null;
    return DENY("CONTENT_PROBE_FAILED");
  }
  // Recheck after the asynchronous read. A stale read is not a grant for
  // redirected origin or another tab.
  const after=await snapshotTab(tabId);
  if (lease!==l || !after || after.url!==l.url ||
      after.windowId!==l.windowId ||
      metadata.url!==l.url || metadata.origin!==l.origin ||
      Object.keys(metadata).sort().join(",")!=="origin,title,url") {
    lease=null;
    return DENY("POST_OBSERVATION_DRIFT");
  }
  return {status:"READ_ONLY_METADATA",metadata,epoch:l.epoch,
          promotion_authorized:false,actual_operator_approval:false};
}
function stopSynthetic() {
  lease=null;
  epochCounter++;
  return {status:"STOPPED",epoch:epochCounter,promotion_authorized:false};
}
// This public fixture API exists only in the isolated service-worker evaluation
// context, is not a Chrome extension message/IPC grant endpoint.
globalThis.__r082Fixture = {
  grantSynthetic,observeMetadata,stopSynthetic,
  current:()=>({has_lease:!!lease,epoch:epochCounter})
};
chrome.runtime.onInstalled.addListener(()=>{});
chrome.runtime.onStartup.addListener(()=>{lease=null;epochCounter++});
