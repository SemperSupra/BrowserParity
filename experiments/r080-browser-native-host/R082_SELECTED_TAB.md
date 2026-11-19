# R082 — actual disposable Chromium two-tab scope and Stop/reconnect

This public research workcell extends the separately completed R080/R081 real Chromium nativeMessaging experiment. It tests a **new boundary**: two real, run-owned loopback browser tabs and a synthetic in-service-worker read-only metadata capability. There is no connection to ChatGPT, no user profile, private BrowserParity source, host installation, external auth issuer or real human grant.

The MV3 extension gets only `tabs`, `scripting`, `nativeMessaging` (inherited from the prior experiment) and a loopback `http://127.0.0.1/*` host permission. A Playwright harness explicitly chooses a disposable active tab. A synthetic in-worker test API issues an epoch-scoped lease tied to exact tab ID, window ID, origin, URL and active status; it is intentionally **not an IPC grant issuer**. The test reads only the exact selected page's URL, origin and title using `chrome.scripting.executeScript`. It never exports body content, cookies, storage, password fields, tokens, network traffic or ChatGPT messages.

Independent actual Windows 2022 and 2025 public GHA runners execute and record whether the real browser:
- Denies any request without a synthetic lease.
- Refuses an inactive adjacent tab's attempted grant; permits exact active selected tab A only.
- Refuses adjacent tab B, without changing its owned DOM counter or exporting its content sentinel.
- Revokes after same-origin URL drift to a different page.
- Rejects stale epoch after explicit regrant, active-tab focus drift and an explicit Stop.
- Rejects all old grants after the entire disposable Chromium process closes and reopens with the same test profile.

A successful receipt is **R082_SYNTHETIC_SELECTED_TAB_ONLY**, not a qualified private BrowserParity tab selection or authorization system. This tests the transport/extension primitive at real Chromium integration level and supplies negative acceptance criteria for owner #81/#109. It does not implement an independent #3 issuer, #56 signer/receiver, Windows H0 operator approval, native-host active-port Stop, protected Chrome/Edge user session or M2. Both browser engines and source code are disposable, fully public and test-only; no public registry writes or private GHA minutes.

**Provenance:** Base exact prior public R081 research commit `09a19ec2a213a65adae0b4c1ead5f48de3823370`; R081 demonstrated that unregistering the native host does not revoke an already-connected port. R082 tests a distinct actual tab-scoped metadata capability. Protect source/CI/negative failures in a draft evidence PR and close unmerged after terminal GHA results and reconciliation to private DLE #109/#76/#81.
