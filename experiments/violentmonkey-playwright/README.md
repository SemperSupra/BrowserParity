# Violentmonkey + Playwright headless acceptance experiment

Tracking issue: #2

## Question

Can a GitHub-hosted Ubuntu runner use supported Playwright extension mechanisms to load a pinned real Violentmonkey build, install a trivial userscript through Violentmonkey, and observe that script execute on a controlled page?

This directory is deliberately a **spike**, not a reusable test framework.

## Conclusion

**Stop / do not promote this spike into a public CI framework for real Violentmonkey execution.**

The experiment established that GitHub-hosted Playwright can build and load the real pinned Violentmonkey MV3 extension and can drive its ordinary installation UI. It also found the decisive boundary: in the fresh headless Chromium profile used by GitHub Actions, `chrome.userScripts` is unavailable until the browser's per-extension **Allow User Scripts** setting is enabled by the user. Violentmonkey detects the same condition and displays its own instruction to enable that setting in `chrome://extensions`.

Automating or editing browser-internal permission state merely to obtain a green CI result would cross the experiment's kill criterion and would test a synthetic permission bypass rather than the normal fresh-install user experience. The remaining exact-private-userscript acceptance should therefore stay with a real browser/profile where that permission has been intentionally enabled.

This is a useful negative result, not a failed attempt to build a framework.

## Pinned inputs

- Violentmonkey: `a3ed56b838798cca5241483a97911dabe9bce7a8` (upstream version 2.48.0)
- Violentmonkey build: `pnpm build:mv3`
- Node.js: 24
- pnpm: 11.20.0
- Playwright Test: 1.62.1
- Attempt 3 Chromium: Chrome for Testing `151.0.7922.34`

## Experimental attempts

### Attempt 1 — direct `.user.js` navigation

GitHub Actions run `33196647384` proved that the pinned MV3 extension builds and loads under Playwright headless Chromium: its real extension service worker was observed. Direct navigation to the loopback `probe.user.js` URL then became a Chromium download before a Violentmonkey installation page appeared.

Result: direct `.user.js` navigation is not a reliable installation trigger in this exact headless MV3 configuration.

### Attempt 2 — supported Violentmonkey `Install from URL`

GitHub Actions run `33196961814` used Violentmonkey's ordinary Installed view: `New` -> `Install from URL`. That path successfully opened the real Violentmonkey confirmation UI for the public probe. The test stopped because it expected the wrong accessible label for the confirmation control; the UI visibly exposed an Install control.

Result: real Violentmonkey manager UI is automatable in headless Playwright without injecting the userscript directly.

### Attempt 3 — installation/execution gate probe

GitHub Actions run `33197157318`, exact experiment head `b9ca2722cb18ebfc5e0286e80c4c9353d73a4197`, added a direct observation from Violentmonkey's extension service worker before installation:

- real service worker loaded: `chrome-extension://affmbpbncgahdhkicdoalhdcndfopmoe/sw.js`;
- `typeof chrome.userScripts` was `undefined`;
- `userScriptsApiAvailable` was `false`;
- headless user agent was Chrome 151;
- Violentmonkey's Installed page displayed: `Please enable "Allow User Scripts" in details for Violentmonkey in chrome://extensions and reload the tab`;
- `Install from URL` still opened the real confirmation page containing the probe source and metadata.

The test also discovered that the Install control's accessible name is `Install (Ctrl-Enter)`, not the visible-text-only name used by the selector. That selector mismatch is incidental: the measured `chrome.userScripts` state means the execution rung cannot succeed in this fresh profile until the user-controlled browser permission is enabled.

Artifact for Attempt 3: GitHub Actions artifact `9696244033`, digest `sha256:566d2b784d58f2831a24e792c3c274ef50efae5d8692dbd732897697d4cb5a2f`.

## What the experiment proved

Supported with direct evidence:

1. Pinned Violentmonkey MV3 can be built reproducibly enough for this spike on GitHub-hosted Ubuntu.
2. Playwright headless Chromium can load the real unpacked Violentmonkey extension and observe its service worker.
3. Violentmonkey's own `Install from URL` UI can fetch and display a controlled public userscript in headless CI.
4. A fresh current Chromium profile does not expose the MV3 `chrome.userScripts` API to the extension until the per-extension Allow User Scripts permission is enabled.
5. Violentmonkey itself detects and reports that permission boundary.

Not proved and intentionally not claimed:

- execution of the probe through Violentmonkey on the GitHub-hosted fresh profile;
- `GM_addStyle` execution in that profile;
- validation of any private userscript or PR;
- live ChatGPT behavior;
- release readiness;
- a production CI architecture;
- cross-browser equivalence.

## Decision

Do **not** grow this into a framework merely to automate `chrome://extensions` or mutate Chromium profile permission state. Preserve the spike and its artifacts as evidence that public CI can cover extension build/load and manager-UI behavior, but the final execution acceptance belongs in a real profile after explicit user permission.

If a future supported Chromium/Playwright mechanism permits declaring this permission without browser-internal automation, the experiment can be revisited. That would be a new hypothesis, not a reason to keep this spike alive indefinitely.
