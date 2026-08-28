# Violentmonkey + Playwright headless acceptance experiment

Tracking issue: #2

## Question

Can a GitHub-hosted Ubuntu runner use supported Playwright extension mechanisms to load a pinned real Violentmonkey build, install a trivial userscript through Violentmonkey, and observe that script execute on a controlled page?

This directory is deliberately a **spike**, not a reusable test framework.

## Pinned inputs

- Violentmonkey: `a3ed56b838798cca5241483a97911dabe9bce7a8` (upstream version 2.48.0)
- Violentmonkey build: `pnpm build:mv3`
- Node.js: 24
- pnpm: 11.20.0
- Playwright Test: 1.62.1

## Experimental attempts

### Attempt 1 — direct `.user.js` navigation

GitHub Actions run `33196647384` proved that the pinned MV3 extension builds and loads under Playwright headless Chromium: its real extension service worker was observed. Direct navigation to the loopback `probe.user.js` URL then became a Chromium download before a Violentmonkey installation page appeared.

That is evidence against the original assumption that direct `.user.js` navigation is a reliable install trigger in this exact headless MV3 configuration. The result is preserved rather than hidden by a workaround.

### Attempt 2 — supported Violentmonkey `Install from URL`

Violentmonkey's own Installed view exposes `New` -> `Install from URL`, which calls its internal `ConfirmInstall` path. Attempt 2 uses that ordinary visible manager UI. This still tests the real manager and does not inject the probe with Playwright.

The revised success ladder is:

1. extension service worker observed;
2. Violentmonkey's supported `Install from URL` flow opens its confirmation UI for the probe;
3. installation completes through the visible `Confirm installation` control;
4. installed probe executes on the fixture page;
5. `GM_addStyle` changes computed page style.

A failure at a later stage does not erase evidence from earlier stages.

## Interpretation

A green run means only that this pinned public probe worked through the pinned Violentmonkey/Playwright combination on the GitHub-hosted runner. It does **not** validate private userscripts, live ChatGPT behavior, or a release candidate.

A red run is also useful if the evidence identifies the unsupported or brittle boundary. The experiment should be stopped rather than expanded if passing requires patching Violentmonkey, private source/credentials, undocumented profile database edits, or extensive automation of browser-internal settings pages.

## Local shape

The GitHub Actions workflow builds Violentmonkey separately and exposes its unpacked `dist-mv3/` directory through `VM_EXTENSION_PATH`. The Playwright test runs a loopback HTTP fixture server, serves `probe.user.js`, and never injects the probe with Playwright APIs.
