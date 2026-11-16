# Public CPU coding-agent qualification (non-promoting)

Question: can a truly free/open-weight code-instruction model run inside a standard public GitHub Actions runner and accomplish a small bounded code edit, then run real tests before anyone accepts the result?

R1 executes exact-revision Apache-2.0 Qwen2.5-Coder-1.5B-Instruct on CPU. It sees a deliberately broken **synthetic** Python function plus test assertions, proposes an old/new single-line replacement, and an independent strict admission layer checks exact shape/context/allowed expression before applying it to a disposable temporary directory. Actual unittest execution must fail before the patch and is rerun afterward. The result records model success separately from the guard/oracle. No model-generated arbitrary Python is executed without the restrictive replacement gate. It tests a tiny coding-model primitive, **not** a full autonomous software engineer or a working Aider/OpenCode/Goose replacement.

This lane has no private source, account data, tokens, secrets, provider login, or authenticated browser. Checkout cannot push, workflow does not persist the candidate patch to Git, and all effects are isolated to temp. The printed diff and JSON receipt are review evidence only. The repository, PR and private DLE remain the authority for promotion and adoption.

Receipt prefix: BP_CPU_CODING_AGENT_RECEIPT. Model commit, actual inference, pre/post tests, bounded proposal attempts, denial oracle, duration and exact Git commit identify evidence. A green CI run means the safety oracle held; only repair_success=true proves the synthetic coding task was completed.

Possible follow-up: compare actual Aider/OpenCode/Goose adapters using the same bounded public fixture, and only then allow a scope-limited code patch proposal in a draft PR after independent review. Do not inject a weak free model into private BrowserParity or permit authenticated effects.
