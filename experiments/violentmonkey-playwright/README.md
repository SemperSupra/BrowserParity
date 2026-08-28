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

## Success ladder

The test records each stage independently:

1. extension service worker observed;
2. `.user.js` navigation intercepted by Violentmonkey;
3. installation UI completed using ordinary visible browser UI;
4. installed probe executes on the fixture page;
5. `GM_addStyle` changes computed page style.

A failure at a later stage does not erase evidence from earlier stages.

## Interpretation

A green run means only that this pinned public probe worked through the pinned Violentmonkey/Playwright combination on the GitHub-hosted runner. It does **not** validate private userscripts, live ChatGPT behavior, or a release candidate.

A red run is also useful if the evidence identifies the unsupported or brittle boundary. The experiment should be stopped rather than expanded if passing requires patching Violentmonkey, private source/credentials, undocumented profile database edits, or extensive automation of browser-internal settings pages.

## Local shape

The GitHub Actions workflow builds Violentmonkey separately and exposes its unpacked `dist/` directory through `VM_EXTENSION_PATH`. The Playwright test runs a loopback HTTP fixture server, serves `probe.user.js`, and never injects the probe with Playwright APIs.
