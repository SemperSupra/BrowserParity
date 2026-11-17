# Edge0 exact source-candidate combined native L0/L1 regression

Two previously proven *isolated* source-only fixes are tested together against the native upstream full L0/L1 test matrix: (1) JSON binary64 overflow stream failbit, and (2) async packaged-task allocation capture lifetime. Both are exact-string overlays applied to an ephemeral checkout of Edge0-AI/Edge0@f6bfa5546bcf89919f86946ec669bcc7f4cd526d. No upstream tests/assertions are changed; no release code is merged into BrowserParity.

Run native CMake CPU build and all actual L0/L1 CTests on independently parallel free public Ubuntu 24.04 x64 and ARM64 GHA runners with locked asset/dev Python dependencies. Emit JUnit and JSON receipts including pass/fail/skip names. This is a regression *investigation*, not a requirement to force all-green: the known upstream Linux `moe_test_platform_memory` expectation contradicts its current implementation and may remain a real red. The test fails CI if any unexpected or expected defect persists; no skips-as-pass.

Upstream main at bc2dc409d420097b4e864d511901180d7c2c6bac had identical blobs for these two source locations to the tested pinned upstream SHA. Existing isolated source candidates remain BrowserParity draft PR #27 (worker lifetime, x64 67/200 failures before, 0/200 after) and #28 (JSON 1,022/1,022 numeric comparisons after correction on x64 and ARM64). The combined test must not claim either fix is upstream-adopted, full-model inference-safe, or product-accepted.

Consumer authority BrowserParity-private #25/#56/#76/#109; generic runner census Agent Dispatch-private #223. No real 35B checkpoint, private code, credentials, paid/private minutes, GHCR model publish, or production browser authentication.

## Three-candidate final integration (stacked, separate GHA)

After exact A/B of Linux process-memory fixture in BrowserParity #32 (20/20 original FAIL vs 20/20 corrected PASS on each x64/ARM), this stacked branch overlays that exact source-only test amendment into the full native L0/L1 build with the two runtime source candidates. Only the Linux fixture's stale `__linux__` expectation is changed; other CTest test assertions and all production code except the two source candidate hunks remain untouched. Receipt explicitly sets `upstream_test_assertions_modified=true`. A green matrix qualifies the selected source/fixture regression combination, not 35B inference or implementation promotion.
