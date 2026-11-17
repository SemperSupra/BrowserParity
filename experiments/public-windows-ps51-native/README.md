# R076 — Public synthetic Windows PowerShell 5.1 native-registration primitives

**Owner:** BrowserParity-private [#81](https://github.com/SemperSupra/BrowserParity-private/issues/81), MVP [#109](https://github.com/SemperSupra/BrowserParity-private/issues/109), from a **separate public-safe research workcell**. This experiment uses **no private source** and is not an installer, native Messaging host, authenticated browser HIL, production trust claim, or release.

## Purpose

Qualify the specific *generic OS primitives* on which a Windows native-host setup implementation could depend, before a trusted local actor can return:
- Real Windows PowerShell **5.1**, not PowerShell 7;
- the HKCU Registry provider, default-value `GetValue('')`, `New-Item`, `Remove-Item`;
- .NET `FileStream` CreateNew and UTF-8 **without BOM** for exact manifest bytes;
- SHA-256 binary checksum; exact single-origin JSON manifest format;
- fail-closed refusal on externally changed registry bindings and extra files;
- cleanup of a uniquely named **synthetic** test subtree under HKCU and the runner temporary directory.

The test uses a four-byte binary file **never executed**. Its registry subtree is `HKCU:\Software\R076Synthetic-<random UUID>\Disposable`, not Chrome, Edge or a production native messaging registry key. No extension ID from any private repository or actual browser grant is used. No secrets, browser processes, sessions, profiles, signers, user contents or injected commands.

## Reproducible qualifications

The only test entrypoint is `qualify.ps1` launched with the installed `powershell` shell (Windows PowerShell 5.1) on the two standard public GHA Windows image labels **windows-2022** and **windows-2025**, pinned checkout and read-only `contents: read` token. Workflow is `.github/workflows/public-windows-ps51-native.yml`; one source SHA per run. Runner timestamps and source commits are available in its action log.

The executable source deliberately runs **no build/install**. Its 13+ assertions test the phases and negatives, then verify the run-owned disposable registry/temp content is absent. If an error occurs, a guarded finally block cleans only known synthetic descendants. Any foreign unexpected state is an explicit fail; no recursive unknown-file removal is authorized.

**Grade on success:** `PUBLIC_SYNTHETIC_WINDOWS_PS51_NATIVE_SEMANTICS`, for that observed runner image and source only. **Cannot certify private #81 installer** because the complete private source is not transferred; private Windows PowerShell tests and human-selected browser grant remain required.

## Accept / reject decision

- ACCEPT as bounded factual evidence only if each Windows job concludes PASS, reports PS major 5, expected check count, no user-visible install or browser, and leaves no synthetic HKCU/temp artifacts.
- REVIEW if Windows-2022 and Windows-2025 disagree; do not silently prefer newer.
- REJECT or rework with preserved first RED if it fails, times out, cleans up unknown state, or the runner has no PS 5.1.
- No promotion of #81 M2 or #56 signer, no source export, no private billed Actions. Public CI results must be crossfed into the owning private #81 issue, not a new independent release authority.

## Qualification limitations

Registration here is a synthetic HKCU tree, **not** the actual Native Messaging host's scoped registry, extension package ID nor Go binary; `MessageBoxW`, optional nativeMessaging grant, Chrome-launched process stdin/stdout, Stop, and human consent are NOT RUN. If these generic primitives pass, it removes one environment uncertainty, not the authenticated-tab technical blocker.
