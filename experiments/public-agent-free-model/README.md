# Public free/open-weight model agent workcell — R1

An independent, non-promoting research rep for private DLE BrowserParity #25 (agent-assisted discovery), #76 (observation/intervention), and #109 (ChatGPT-shaped MVP acceptance). GitHub DLE is authoritative; this directory does not redefine policy or become the new browser agent product.

## What runs
Two independent public standard Ubuntu GitHub Actions jobs. Each loads and actually invokes an Apache-2.0 small model on CPU with no inference API key: HuggingFaceTB/SmolLM2-135M-Instruct and 360M-Instruct, pinned to explicit Hugging Face model commits. One disposable Chromium process hosts two in-memory tabs. PyTorch, Transformers and Playwright supply the actual inference, browser and observations.

The model selects a two-field JSON action proposal; a deterministic independent gate restricts it to a named synthetic button in selected tab a with the correct, unrevoked, unused generation grant. The gate rejects stale, revoked, wrong-tab, target-not-observed, navigation, malformed and replay proposals. The page contains an untrusted prompt-injection string, but no secrets or real services.

## Evidence
CI receipt prefix: BP_FREE_MODEL_AGENT_RECEIPT. Fields distinguish actual model inference, proposal validity, two-cycle correction attempts, authorization decision, observed selected-tab effect, adjacent-tab isolation, negative policy-oracle coverage, model task success, timing, model revision and CI commit. The CI job fails for any policy/effect/isolation violation; model incompetence remains visible as agent_task_success=false even with passing guardrail tests. No artifact retention, persistent model caches, production promotion or authenticated use.

Human operators can review the run summary; automation can parse one-line JSON; agents are constrained to the same action/grant vocabulary. This is SYNTHETIC_ONLY evidence. It does not qualify any real ChatGPT account/tab, private profile, CAC/OTP handling, or deterministic promotion under #56. HIL requires the separate existing-tab consent/admission and #2/#3 policy gates.

Bounded at two parallel jobs with 20-minute job ceilings; public standard runners only. First assess the receipts before expanding to larger models or real integration.
