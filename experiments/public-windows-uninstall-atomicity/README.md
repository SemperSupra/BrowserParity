# R077 public-only real Windows uninstall ordering and recovery falsifier

Owning private work: [BrowserParity-private #81](https://github.com/SemperSupra/BrowserParity-private/issues/81), canonical parent #109. This research file contains **no private BrowserParity source or actual native host configuration**. The test performs synthetic effects only on a uniquely random `HKCU:\Software\R077-Synthetic-<guid>\Disposable` key and `RUNNER_TEMP` directory, with a **four-byte inert binary file that is never executed**.

## Hypothesis

An "unregister first, then discover unknown file" installer removal path can leave an orphan, unexpectedly change the registered state, and make retries non-idempotent. Preflight the entire exact known registration **before any mutation**, reject unexpected binary digest, manifest bytes, nested directory, foreign named registry value and arbitrary extra content; recognize only genuine fully removed or exact-source orphan states as safe retriable cleanup.

## Bounded actual qualification

The Windows PowerShell 5.1 script `r077.ps1` executes as two independent free public GitHub-hosted jobs: Windows 2022 and Windows 2025. It deliberately runs a **red control** reproducing unregister-first on a synthetic fixture, records `R077_EXPECTED_RED=UNREGISTER_FIRST_LEFT_ORPHAN`, then tests the safe green two-phase path. Negative cases include missing operator approval, unknown file, substituted four-byte host digest, foreign registry default binding, foreign named registry value, mutated manifest, nested directory and registry without managed files. Positive cases include complete removal, repeated idempotent removal and recovery after simulated interrupted unregister. Tests require exact SHA-256, origin-marked synthetic JSON and no leftover run-owned state.

The workflow uses one `pull_request` trigger only, 8m cap per image, least-privileged read-only token, pinned checkout and no secret or external network interaction. It must preserve initial source failures and accept only actual 5.1 output with clear `PASS`, observed check count and absent synthetic state.

**Scope/nonclaims:** Passing qualifies generic Windows Registry provider and filesystem semantics on the observed images. It cannot independently qualify private `windows_native_host.ps1`, private binary origin/signature, nativeMessaging permission, Chrome-launched host, operator consent, real selected authenticated ChatGPT M2, #56 source trust or product release. The private implementation PR remains **DRAFT** until separately tested in a qualified private Windows venue. All research artifacts remain public-safe, with no private source projected.

The positive grade `REAL_WINDOWS_SYNTHETIC_TWO_PHASE_UNINSTALL` explicitly advertises `private_source_executed=false`, `browser_hil=false`, `promotion_authorized=false`. No real keys, credentials, profile, browser or private hosted Actions are involved.
