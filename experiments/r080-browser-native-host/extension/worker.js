/* R080 synthetic fixture: never reads tabs, cookies, page DOM or user browser state. */
chrome.runtime.onInstalled.addListener(() => {});
chrome.runtime.onStartup.addListener(() => {});
