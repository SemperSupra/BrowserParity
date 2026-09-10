# Anonymous WebUI observation experiment

This is the public, disposable execution slice for BrowserParity's anonymous/no-login AI WebUI baseline.

## Purpose

Run the same bounded observation task against representative public AI WebUIs from GitHub-hosted Chromium, then retain only public-safe metadata suitable for later differential comparison with authenticated sessions.

The public runner is an **execution materialization**, not the BrowserParity authority plane. Private analysis, Provider Surface Model synthesis, authorization decisions, and authenticated-session work remain outside this repository.

## Safety and information boundary

The observer intentionally does **not** retain:

- cookies or cookie values;
- authorization/request headers;
- request or response bodies;
- page-body text;
- credentials or reusable session material;
- screenshots in this first slice.

It may retain public UI semantics (element tag/role/type/labels/placeholders), hashed page/storage/path fingerprints, response status codes, hostnames, resource types, content-free input/focus state, bounded post-submit event counts, and runner/browser provenance.

A login wall, CAPTCHA/bot challenge, regional restriction, payment requirement, HTTP block, or browser-control incompatibility is recorded as an observation. The runner does not bypass it.

## First-wave targets

Enabled targets are defined in `targets.json`. The initial P0 cohort is ChatGPT, Duck.ai, Perplexity, Microsoft Copilot, and Gemini. Pi and Meta AI are recorded as P1 candidates but disabled until the P0 runner is proven.

The shared task is one deterministic prompt after a landing-state observation. Runs use ordinary single-user pacing and do not stress quotas.

## Execution

`.github/workflows/anonymous-webui-observe.yml` supports:

- `pull_request` execution when this experiment changes, providing proving reps before merge;
- `workflow_dispatch` after the workflow exists on the default branch, accepting `all` or one enabled target id.

The workflow uses a standard `ubuntu-latest` GitHub-hosted runner, creates an isolated Python environment, installs pinned Playwright `1.62.0` and its corresponding Chromium build, executes the observer, writes a concise job summary, and uploads seven-day public-safe evidence artifacts.

Runner geography is **observed, never assumed**. Best-effort Cloudflare network metadata records country/region/colo/ASN where available and a hash of the ephemeral egress IP; a second Cloudflare trace endpoint is used as a bounded fallback. No VPN/proxy mechanism is included.

## Result classifications

The first slice can emit:

- `ANONYMOUS_INTERACTION_OBSERVED` — prompt submission plus an observed page/body transition;
- `ANONYMOUS_SUBMISSION_OBSERVED` — conservative evidence that a prompt submission produced an effect, without claiming a rendered response was observed;
- `INTERACTION_UNCONFIRMED` — a submission command was emitted but its effect could not be established;
- `CONTROL_SURFACE_UNACTIONABLE` — an apparent input control was discovered but ordinary browser/user-level actuation could not use it in this executor;
- `HTTP_BLOCKED` — landing transport returned a blocking status such as 401/403/407/429/451 before interaction;
- `HTTP_ERROR` — another >=400 landing status prevented interaction;
- `LOGIN_REQUIRED_OR_GATED`;
- `BOT_CHALLENGE`;
- `LANDING_ONLY`;
- `NAVIGATION_TIMEOUT`;
- `ERROR`.

These are observations of a particular provider surface, runner, browser, version, region, and instrumentation configuration—not durable provider capability claims. Later BrowserParity processing should normalize evidence into the Provider Surface Model and compare semantic capabilities across access classes.
