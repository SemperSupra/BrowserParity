# R078 — NTFS junction ancestor containment / regular-leaf falsifier

Owning private DLE: BrowserParity-private #81 and #109. This public-only research workcell contains **no private source code**, host name, extension, account, credentials, provider browser data, or working native host.

## Why it matters

Windows PowerShell path validation that checks a purported EXE is drive rooted, has the correct extension, is not a reparse point **itself**, and has a valid SHA-256 may still accept an NTFS **junction in a parent directory**. A path under an application-owned directory can then resolve to another directory despite the leaf appearing regular. That defeats a simplistic managed-directory ownership boundary.

The direct experiment creates a uniquely named fixture under GHA RUNNER_TEMP, including two random run-owned directories, two four-byte inert EXE files **never executed**, and a disposable NTFS junction to one directory using mklink /J. It reproduces the unsafe leaf-only acceptance as an intentional RED and compares an independent existing-ancestor reparse-point checker. The checker rejects the junction itself and regular/missing leaves beneath it, plus UNC, drive/root-relative, and lexical dot-segment paths; a direct regular local path is admitted. Teardown uses nonrecursive, named-only deletion of the junction, then verifies its target remains intact, and ensures no run-owned contents remain.

## Independent Windows qualification

Public workflow at .github/workflows/public-windows-junction-r078.yml: one pull_request trigger, pinned checkout, contents: read, isolated Windows-2022 and Windows-2025 jobs, up to eight minutes each, no secrets, no external model/API, no private repository checkout. Qualification requires native **Windows PowerShell 5.1**, expected RED, green candidate denial reasons, success exit, no unexpected files, no target deletion, and exact post-cleanup machine-readable receipt.

**Evidence grade on pass:** PUBLIC_REAL_WINDOWS_NTFS_JUNCTION_ANCESTOR_DIFFERENTIAL. This is meaningful **OS/NTFS behavior only**: it does not execute or independently qualify the private installer, Chrome/Edge Native Messaging grant, source-built Go host, a user's authenticated ChatGPT selected tab, operator consent, Stop/revocation, signer/receiver provenance, or release.

Keep this a reviewable public RESEARCH draft; any portable adaptation must be independently source-reviewed in private and tested in an admitted private Windows H0.
