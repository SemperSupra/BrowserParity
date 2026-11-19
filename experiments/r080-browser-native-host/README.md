# R080 disposable real-Chromium Windows nativeMessaging acceptance precursor

**Purpose:** Fill a gap between synthetic native-host framed IPC process tests (BrowserParity public R079 GHA 44345856119) and actual trusted-local operator-admitted BrowserParity product G1. The experiment starts **actual Chromium bundled with Playwright** on two real public Windows GitHub Actions runners, loads a separately owned MV3 test extension in an isolated ephemeral profile, registers an explicitly synthetic Go Windows native-messaging executable under a unique **HKCU** host name, and verifies that Chromium itself launches the native process.

## Measured falsifiers

The fixture discovers its extension ID from the actual MV3 service-worker origin (rather than hard-coding an assumed extension ID), then tests: (1) wrong allowed_origins must not launch any native host; (2) an exact-origin permitted synthetic JSON ping must cause a real browser-initiated native process launch and full Windows little-endian framed reply; (3) an in-flight hold request must be disconnected without late message; (4) after removing only test-owned HKCU registry keys, further native connection must fail; (5) the host audit records launch and termination without revealing user/session/cookie/page content. The test refuses preexisting host keys and verifies cleanup.

**This is not a product implementation or a real BrowserParity trusted H0/H1/M2 pass.** It does NOT use private BrowserParity source, extension IDs, user/Chrome/Edge installation, real ChatGPT, cookies, credentials, CAC/OTP, shell elevation, or an approved human operator. It uses **unbranded Playwright Chromium** with an unpacked synthetic MV3 extension, because current Chrome and Microsoft Edge branded builds remove the command-line flags used for simple extension side loading in automation. It does not qualify those branded browsers or established user profiles.

## Reproducibility & gates

Two independent standard free public `windows-2022` and `windows-2025` runners, maximum parallelism 2, single push-branch workflow, read-only token, 18 minutes maximum per job. Node Playwright package pinned to `1.56.1`; public Go host uses standard library only. Outputs contain only synthetic status and reported real Chromium version. Native host registry entries are temporary, in current GHA runner HKCU, with fail-closed removal even if the test fails. No artifact uploading or public model bytes.

The existing private BrowserParity owner #109, #81 draft #179, #2/#3 authorization, #56 evidence and trusted local H0/M2 acceptance remain **HOLD**. Never reclassify a green synthetic Chromium integration test as selected-tab consent, positive authenticated evidence, independent issuer, or signed receiver acceptance. Do not merge research-only files to production `main`. Reconcile terminal exact SHA/job receipts and close research PR unmerged.
