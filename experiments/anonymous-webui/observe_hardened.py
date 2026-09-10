#!/usr/bin/env python3
"""Rep-2 hardening layer for the public anonymous WebUI observer.

This module deliberately reuses the proven v1 capture path in ``observe.py``
while tightening three evidence-quality defects found by the first hosted rep:

* prompt discovery must agree with the DOM inventory for visible textareas;
* HTTP blocking must not collapse into ``LANDING_ONLY``;
* runner/network and browser-version provenance should survive one sensor failure.

The information boundary remains unchanged: no cookies, authorization headers,
request/response bodies, page text, screenshots, credentials, or reusable
session material are retained.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import os
import platform
import sys
import urllib.request
from pathlib import Path
from typing import Any

import observe as base

SUMMARY_SCHEMA_VERSION = "browserparity.anonymous-webui.summary/v2"


def _sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8", errors="replace")).hexdigest()


def robust_find_prompt_input(page):
    """Find a visible, enabled non-credential text entry using DOM state.

    Rep 1 proved that Playwright's generic locator path could report no prompt
    even while the independently captured DOM inventory contained a visible,
    enabled ``textarea`` (Copilot).  Use the same DOM-computed visibility signal
    as the inventory so the two sensors cannot disagree for this reason.
    """

    selectors = [
        "textarea",
        '[role="textbox"][contenteditable="true"]',
        '[contenteditable="true"]',
        'input[type="text"]',
        'input:not([type])',
    ]
    credential_terms = ("email", "username", "password", "phone", "otp", "verification code")

    for selector in selectors:
        locator = page.locator(selector)
        try:
            count = min(locator.count(), 20)
        except Exception:
            continue

        for index in range(count):
            candidate = locator.nth(index)
            try:
                meta = candidate.evaluate(
                    """e => ({
                        tag: e.tagName.toLowerCase(),
                        type: (e.getAttribute('type') || '').toLowerCase(),
                        placeholder: (e.getAttribute('placeholder') || '').toLowerCase(),
                        ariaLabel: (e.getAttribute('aria-label') || '').toLowerCase(),
                        role: (e.getAttribute('role') || '').toLowerCase(),
                        disabled: !!e.disabled || e.getAttribute('aria-disabled') === 'true',
                        readOnly: !!e.readOnly || e.getAttribute('aria-readonly') === 'true',
                        visible: !!(e.offsetWidth || e.offsetHeight || e.getClientRects().length)
                    })"""
                )
            except Exception:
                continue

            if not meta.get("visible") or meta.get("disabled") or meta.get("readOnly"):
                continue
            if meta.get("type") in {"hidden", "password", "email", "tel"}:
                continue

            semantic_hint = " ".join(
                str(meta.get(key) or "")
                for key in ("placeholder", "ariaLabel", "role", "type")
            )
            if any(term in semantic_hint for term in credential_terms):
                continue

            public_meta = {
                "tag": meta.get("tag"),
                "type": meta.get("type"),
                "placeholder": meta.get("placeholder"),
                "ariaLabel": meta.get("ariaLabel"),
                "role": meta.get("role"),
                "visible": bool(meta.get("visible")),
                "disabled": bool(meta.get("disabled")),
                "readOnly": bool(meta.get("readOnly")),
            }
            return candidate, selector, public_meta

    return None, None, None


def _cloudflare_meta() -> dict[str, Any]:
    req = urllib.request.Request(
        "https://speed.cloudflare.com/meta",
        headers={"User-Agent": "BrowserParity-anonymous-observer/2"},
    )
    with urllib.request.urlopen(req, timeout=8) as response:
        data = json.load(response)
    client_ip = str(data.get("clientIp", ""))
    return {
        "ok": True,
        "source": "https://speed.cloudflare.com/meta",
        "country": data.get("country"),
        "region": data.get("region"),
        "city": data.get("city"),
        "colo": data.get("colo"),
        "asn": data.get("asn"),
        "as_organization": data.get("asOrganization"),
        "client_ip_sha256": _sha256_text(client_ip) if client_ip else None,
    }


def _cloudflare_trace() -> dict[str, Any]:
    req = urllib.request.Request(
        "https://www.cloudflare.com/cdn-cgi/trace",
        headers={"User-Agent": "BrowserParity-anonymous-observer/2"},
    )
    with urllib.request.urlopen(req, timeout=8) as response:
        text = response.read().decode("utf-8", errors="replace")
    fields: dict[str, str] = {}
    for line in text.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            fields[key.strip()] = value.strip()
    client_ip = fields.get("ip", "")
    return {
        "ok": True,
        "source": "https://www.cloudflare.com/cdn-cgi/trace",
        "country": fields.get("loc"),
        "region": None,
        "city": None,
        "colo": fields.get("colo"),
        "asn": None,
        "as_organization": None,
        "client_ip_sha256": _sha256_text(client_ip) if client_ip else None,
    }


def robust_runner_network_provenance() -> dict[str, Any]:
    """Try independent public-safe egress sensors and retain no raw IP."""

    errors: list[dict[str, str]] = []
    for sensor in (_cloudflare_meta, _cloudflare_trace):
        try:
            result = sensor()
            result["sensor_errors"] = errors
            return result
        except Exception as exc:
            errors.append({"sensor": sensor.__name__, "error_type": type(exc).__name__})
    return {"ok": False, "source": None, "sensor_errors": errors}


def normalize_classification(result: dict[str, Any]) -> dict[str, Any]:
    """Expose transport blocking distinctly from ordinary landing-only state."""

    navigation = result.get("navigation") or {}
    status = navigation.get("initial_status")
    prompt = result.get("prompt") or {}
    current = result.get("classification")

    if isinstance(status, int) and status >= 400 and not prompt.get("prompt_submitted"):
        if status in {401, 403, 407, 429, 451}:
            result["classification"] = "HTTP_BLOCKED"
        else:
            result["classification"] = "HTTP_ERROR"
        result["classification_detail"] = {"initial_http_status": status, "prior": current}
    return result


def rewrite_result(output_dir: Path, result: dict[str, Any]) -> None:
    path = output_dir / f"{result['target_id']}.json"
    path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_summary(
    results: list[dict[str, Any]],
    output_dir: Path,
    provenance: dict[str, Any],
    browser_version: str,
) -> None:
    summary = {
        "schema_version": SUMMARY_SCHEMA_VERSION,
        "generated_at": base.utc_now(),
        "runner": {
            "os": platform.platform(),
            "python": sys.version.split()[0],
            "playwright": importlib.metadata.version("playwright"),
            "browser_name": "chromium",
            "browser_version": browser_version,
            "github_run_id": os.getenv("GITHUB_RUN_ID"),
            "github_run_attempt": os.getenv("GITHUB_RUN_ATTEMPT"),
            "github_sha": os.getenv("GITHUB_SHA"),
            "github_ref": os.getenv("GITHUB_REF"),
        },
        "runner_network": provenance,
        "results": [
            {
                "target_id": item.get("target_id"),
                "provider": item.get("provider"),
                "classification": item.get("classification"),
                "initial_http_status": (item.get("navigation") or {}).get("initial_status"),
                "prompt_input_found": (item.get("prompt") or {}).get("prompt_input_found"),
                "prompt_submitted": (item.get("prompt") or {}).get("prompt_submitted"),
                "network_event_count": item.get("network_event_count"),
            }
            for item in results
        ],
    }
    (output_dir / "summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    lines = [
        "# BrowserParity anonymous WebUI observation",
        "",
        f"Generated: `{summary['generated_at']}`",
        f"Chromium: `{browser_version}`; Playwright: `{summary['runner']['playwright']}`",
        (
            "Runner country: "
            f"`{provenance.get('country') or 'unknown'}`; "
            f"colo: `{provenance.get('colo') or 'unknown'}`; "
            f"ASN: `{provenance.get('asn') or 'unknown'}`; "
            f"sensor: `{provenance.get('source') or 'unavailable'}`"
        ),
        "",
        "| Target | HTTP | Classification | Prompt found | Submitted | Network events |",
        "|---|---:|---|---|---|---:|",
    ]
    for item in summary["results"]:
        lines.append(
            f"| {item['target_id']} | {item['initial_http_status'] or ''} | "
            f"{item['classification']} | {item['prompt_input_found']} | "
            f"{item['prompt_submitted']} | {item['network_event_count'] or 0} |"
        )
    lines.extend(
        [
            "",
            "Public-safe slice: no cookies, authorization headers, request/response bodies, page text, credentials, screenshots, or reusable session material are retained.",
        ]
    )
    (output_dir / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--target", default="all", help="all or a target id")
    args = parser.parse_args()

    manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    task = manifest["task"]
    targets = [target for target in manifest["targets"] if target.get("enabled", False)]
    if args.target != "all":
        targets = [target for target in targets if target["id"] == args.target]
        if not targets:
            raise SystemExit(f"unknown or disabled target: {args.target}")

    # Reuse the proven capture path but replace the defective prompt sensor.
    base.find_prompt_input = robust_find_prompt_input

    provenance = robust_runner_network_provenance()
    results: list[dict[str, Any]] = []
    with base.sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        browser_version = browser.version
        try:
            for target in targets:
                result = base.observe_target(browser, target, task, provenance, output_dir)
                result["browser"] = {"name": "chromium", "version": browser_version}
                normalize_classification(result)
                rewrite_result(output_dir, result)
                results.append(result)
        finally:
            browser.close()

    write_summary(results, output_dir, provenance, browser_version)
    print((output_dir / "summary.md").read_text(encoding="utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
