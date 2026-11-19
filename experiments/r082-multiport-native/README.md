# BrowserParity R082 — Actual Chromium multiport/Stop/adjacent-tab authority falsifier

**Source-only, free-tier Windows research.** This independent experiment extends the R080/R081 public synthetic real-browser/host observations, without copying private BrowserParity product source, introducing a new control plane, or touching a real user browser.

## New acceptance question

When a real Chromium MV3 service worker may launch a native messaging host, is that extension origin authorization inherently scoped to one human-selected tab? And does disconnecting **one** native messaging port revoke all other active ports? Neither outcome should be assumed from `allowed_origins` or HKCU host unregistration.

Using **actual Playwright Chromium** on standard free public Windows-2022 and Windows-2025 runners, a local HTTP server creates two disposable synthetic HTML tabs. The synthetic extension has `tabs` and `nativeMessaging` permissions and sees only those owned test tabs. The worker independently connects to the Go stdlib test host for both tab IDs. The host manifest knows the extension origin, not a separately approved tab identity; synthetic tab ID/nonce values are extension-controlled and never count as trusted authorization.

Negative sequence: close port A while port B stays active; remove the test-owned HKCU registration and prove new connections are refused **while port B survives**; explicitly disconnect all active ports, verify all native processes exited, repeat Stop idempotently, and refuse post-Stop reconnection. Any unexpected behavior fails the GHA experiment rather than becoming a product claim.

## Trust and evidence boundary

Transport behavior only — **not** selected-tab authorization or real user consent. Public temporary Chromium profile, localhost-only HTML, unique temporary HKCU native-host registration, no real ChatGPT, Chrome/Edge branded user sessions, credentials, CAC, cookies, private source, registry entries outside test-owned names, or shell elevation. No production model or browser code merged. All test entries are removed and disposable runners are destroyed.

DLE authority: BrowserParity-private #109 MVP G1, #76 architecture, #81 draft #179 native-host owner, #2/#3 operation issuer, #56 evidence/signer/receiver. Source-only branches and terminal GHA evidence must remain distinct from trusted-local product H0/H1/H2, human-authorized selected ChatGPT M2, M3 effects and G6 release. This source-only workcell may be closed unmerged when evidence is reconciled.
