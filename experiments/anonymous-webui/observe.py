#!/usr/bin/env python3
"""Bounded, secret-free anonymous WebUI observer for BrowserParity.

This public experiment captures only public-safe metadata. It does not retain
cookies, authorization headers, request/response bodies, page text, credentials,
screenshots, or reusable session material. Provider boundaries are observations
to record, not obstacles to bypass.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
from playwright.sync_api import sync_playwright

SCHEMA_VERSION = "browserparity.anonymous-webui.observation/v2"
SUMMARY_SCHEMA_VERSION = "browserparity.anonymous-webui.summary/v2"


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8", errors="replace")).hexdigest()


def sanitize_url(url: str) -> dict[str, Any]:
    try:
        parts = urlsplit(url)
        return {
            "scheme": parts.scheme,
            "hostname": parts.hostname,
            "port": parts.port,
            "path_sha256": sha256_text(parts.path or "/"),
            "has_query": bool(parts.query),
        }
    except Exception:
        return {"parse_error": True, "raw_sha256": sha256_text(url)}


def _fetch_json(url: str) -> dict[str, Any]:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "BrowserParity-anonymous-observer/2"},
    )
    with urllib.request.urlopen(req, timeout=8) as response:
        return json.load(response)


def fetch_runner_network_provenance() -> dict[str, Any]:
    """Best-effort public egress provenance; never retain the raw IP."""
    attempts: list[dict[str, Any]] = []
    providers = [
        ("cloudflare", "https://speed.cloudflare.com/meta"),
        ("ipapi", "https://ipapi.co/json/"),
    ]
    for name, url in providers:
        try:
            data = _fetch_json(url)
            if name == "cloudflare":
                ip = str(data.get("clientIp", ""))
                record = {
                    "source": name,
                    "country": data.get("country"),
                    "region": data.get("region"),
                    "city": data.get("city"),
                    "colo": data.get("colo"),
                    "asn": data.get("asn"),
                    "as_organization": data.get("asOrganization"),
                }
            else:
                ip = str(data.get("ip", ""))
                record = {
                    "source": name,
                    "country": data.get("country_code"),
                    "region": data.get("region"),
                    "city": data.get("city"),
                    "colo": None,
                    "asn": data.get("asn"),
                    "as_organization": data.get("org"),
                }
            record.update(
                {
                    "ok": True,
                    "client_ip_sha256": sha256_text(ip) if ip else None,
                    "attempts": attempts,
                }
            )
            return record
        except Exception as exc:
            attempts.append({"source": name, "error_type": type(exc).__name__})
    return {"ok": False, "source": None, "attempts": attempts}


def body_fingerprint(page) -> dict[str, Any]:
    try:
        text = page.locator("body").inner_text(timeout=5000)
    except Exception:
        text = ""
    return {"text_length": len(text), "text_sha256": sha256_text(text)}


def classify_boundary_text(page) -> dict[str, bool]:
    try:
        text = page.locator("body").inner_text(timeout=5000).lower()
    except Exception:
        text = ""
    challenge_terms = (
        "captcha",
        "verify you are human",
        "checking your browser",
        "unusual traffic",
        "security check",
        "cloudflare challenge",
    )
    login_terms = (
        "sign in",
        "log in",
        "login",
        "create an account",
        "continue with google",
        "continue with apple",
        "continue with microsoft",
    )
    return {
        "challenge_text_present": any(term in text for term in challenge_terms),
        "login_text_present": any(term in text for term in login_terms),
    }


def safe_interactive_inventory(page) -> list[dict[str, Any]]:
    """Public UI semantics only; no element values or page-body text."""
    try:
        return page.locator(
            'textarea,input,[contenteditable="true"],button,[role="button"],[role="textbox"]'
        ).evaluate_all(
            """els => els.slice(0, 100).map(e => {
                const r = e.getBoundingClientRect();
                const s = getComputedStyle(e);
                return {
                    tag: e.tagName.toLowerCase(),
                    role: e.getAttribute('role'),
                    type: e.getAttribute('type'),
                    ariaLabel: e.getAttribute('aria-label'),
                    placeholder: e.getAttribute('placeholder'),
                    contentEditable: e.getAttribute('contenteditable'),
                    disabled: !!e.disabled,
                    visible: r.width > 0 && r.height > 0 &&
                             s.display !== 'none' && s.visibility !== 'hidden'
                };
            })"""
        )
    except Exception:
        return []


def storage_metadata(page) -> dict[str, Any]:
    try:
        data = page.evaluate(
            """() => ({
                local: Object.keys(localStorage),
                session: Object.keys(sessionStorage)
            })"""
        )
        return {
            "local_storage_key_count": len(data.get("local", [])),
            "local_storage_key_hashes": [
                sha256_text(k) for k in sorted(data.get("local", []))
            ],
            "session_storage_key_count": len(data.get("session", [])),
            "session_storage_key_hashes": [
                sha256_text(k) for k in sorted(data.get("session", []))
            ],
        }
    except Exception as exc:
        return {"error_type": type(exc).__name__}


def _candidate_metadata(candidate) -> dict[str, Any]:
    return candidate.evaluate(
        """e => {
            const r = e.getBoundingClientRect();
            const s = getComputedStyle(e);
            return {
                tag: e.tagName.toLowerCase(),
                type: e.getAttribute('type'),
                placeholder: (e.getAttribute('placeholder') || '').toLowerCase(),
                ariaLabel: (e.getAttribute('aria-label') || '').toLowerCase(),
                disabled: !!e.disabled,
                visible: r.width > 0 && r.height > 0 &&
                         s.display !== 'none' && s.visibility !== 'hidden' &&
                         s.opacity !== '0'
            };
        }"""
    )


def find_prompt_input(page):
    """Find a non-auth text input using DOM-computed visibility, not Playwright heuristics."""
    selectors = [
        'textarea:not([disabled])',
        '[role="textbox"][contenteditable="true"]',
        '[contenteditable="true"]',
        'input[type="text"]:not([disabled])',
    ]
    auth_terms = ("email", "username", "password", "phone", "verification", "code")
    diagnostics: list[dict[str, Any]] = []
    for selector in selectors:
        locator = page.locator(selector)
        try:
            count = min(locator.count(), 20)
        except Exception as exc:
            diagnostics.append({"selector": selector, "error_type": type(exc).__name__})
            continue
        for index in range(count):
            candidate = locator.nth(index)
            try:
                meta = _candidate_metadata(candidate)
                diagnostics.append(
                    {
                        "selector": selector,
                        "index": index,
                        "visible": meta.get("visible"),
                        "disabled": meta.get("disabled"),
                    }
                )
                if not meta.get("visible") or meta.get("disabled"):
                    continue
                joined = f"{meta.get('placeholder', '')} {meta.get('ariaLabel', '')}"
                if any(term in joined for term in auth_terms):
                    continue
                return candidate, selector, meta, diagnostics
            except Exception as exc:
                diagnostics.append(
                    {
                        "selector": selector,
                        "index": index,
                        "error_type": type(exc).__name__,
                    }
                )
    return None, None, None, diagnostics


def attempt_single_prompt(
    page,
    prompt: str,
    post_submit_seconds: int,
    network_events: list[dict[str, Any]],
) -> dict[str, Any]:
    result: dict[str, Any] = {
        "prompt_attempted": False,
        "prompt_submitted": False,
        "prompt_input_found": False,
    }
    locator, selector, meta, diagnostics = find_prompt_input(page)
    result["prompt_locator_diagnostics"] = diagnostics
    if locator is None:
        return result

    result["prompt_input_found"] = True
    result["prompt_input_selector_class"] = selector
    result["prompt_input_metadata"] = meta
    before = body_fingerprint(page)
    network_before = len(network_events)

    try:
        result["prompt_attempted"] = True
        tag = locator.evaluate("e => e.tagName.toLowerCase()")
        if tag in ("textarea", "input"):
            locator.fill(prompt, timeout=5000)
        else:
            locator.click(timeout=5000)
            page.keyboard.insert_text(prompt)
        locator.press("Enter", timeout=5000)
        result["prompt_submitted"] = True
    except Exception as exc:
        result["submit_error_type"] = type(exc).__name__
        return result

    time.sleep(max(0, post_submit_seconds))
    after = body_fingerprint(page)
    result.update(
        {
            "body_changed": before["text_sha256"] != after["text_sha256"],
            "body_length_delta": after["text_length"] - before["text_length"],
            "network_event_delta": len(network_events) - network_before,
        }
    )
    return result


def classify_initial_http(status: int | None) -> str | None:
    if status is None or status < 400:
        return None
    if status == 401:
        return "HTTP_UNAUTHORIZED_401"
    if status == 403:
        return "HTTP_BLOCKED_403"
    if status == 429:
        return "HTTP_RATE_LIMITED_429"
    if status == 451:
        return "HTTP_UNAVAILABLE_LEGAL_451"
    if 400 <= status < 500:
        return f"HTTP_CLIENT_ERROR_{status}"
    return f"HTTP_SERVER_ERROR_{status}"


def observe_target(
    browser,
    target: dict[str, Any],
    task: dict[str, Any],
    provenance: dict[str, Any],
    output_dir: Path,
) -> dict[str, Any]:
    started = utc_now()
    network_events: list[dict[str, Any]] = []
    max_events = int(task.get("max_network_events", 300))
    context = browser.new_context()
    page = context.new_page()

    def on_request(request) -> None:
        if len(network_events) >= max_events:
            return
        network_events.append(
            {
                "phase": "request",
                "method": request.method,
                "resource_type": request.resource_type,
                **sanitize_url(request.url),
            }
        )

    def on_response(response) -> None:
        if len(network_events) >= max_events:
            return
        network_events.append(
            {
                "phase": "response",
                "status": response.status,
                **sanitize_url(response.url),
            }
        )

    page.on("request", on_request)
    page.on("response", on_response)

    result: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "target_id": target["id"],
        "provider": target["provider"],
        "requested_url": sanitize_url(target["url"]),
        "started_at": started,
        "runner_network": provenance,
        "browser_context": {
            "cookies_recorded": False,
            "request_headers_recorded": False,
            "response_bodies_recorded": False,
            "page_text_recorded": False,
            "screenshots_recorded": False,
        },
    }

    try:
        response = page.goto(
            target["url"], wait_until="domcontentloaded", timeout=45000
        )
        time.sleep(int(task.get("landing_settle_seconds", 4)))
        initial_status = response.status if response else None
        http_class = classify_initial_http(initial_status)
        boundary_before = classify_boundary_text(page)
        result.update(
            {
                "navigation": {
                    "ok": True,
                    "initial_status": initial_status,
                    "final_url": sanitize_url(page.url),
                    "title_sha256": sha256_text(page.title()),
                },
                "landing": body_fingerprint(page),
                "boundary_before_prompt": boundary_before,
                "interactive_inventory": safe_interactive_inventory(page),
                "storage": storage_metadata(page),
            }
        )

        if http_class is not None:
            prompt_result = {
                "prompt_attempted": False,
                "prompt_submitted": False,
                "prompt_input_found": False,
                "skipped_reason": "initial_http_boundary",
            }
        elif boundary_before["challenge_text_present"]:
            prompt_result = {
                "prompt_attempted": False,
                "prompt_submitted": False,
                "prompt_input_found": False,
                "skipped_reason": "challenge_boundary",
            }
        else:
            prompt_result = attempt_single_prompt(
                page,
                str(task["prompt"]),
                int(task.get("post_submit_seconds", 10)),
                network_events,
            )
        result["prompt"] = prompt_result
        boundary_after = classify_boundary_text(page)
        result["boundary_after_prompt"] = boundary_after

        if http_class is not None:
            classification = http_class
        elif boundary_after["challenge_text_present"]:
            classification = "BOT_CHALLENGE"
        elif prompt_result.get("prompt_submitted") and prompt_result.get(
            "body_changed"
        ):
            classification = "ANONYMOUS_INTERACTION_OBSERVED"
        elif prompt_result.get("prompt_submitted"):
            classification = "INTERACTION_UNCONFIRMED"
        elif boundary_after["login_text_present"] and not prompt_result.get(
            "prompt_input_found"
        ):
            classification = "LOGIN_REQUIRED_OR_GATED"
        else:
            classification = "LANDING_ONLY"
        result["classification"] = classification

    except PlaywrightTimeoutError:
        result.update(
            {
                "classification": "NAVIGATION_TIMEOUT",
                "navigation": {
                    "ok": False,
                    "error_type": "PlaywrightTimeoutError",
                },
            }
        )
    except Exception as exc:
        result.update(
            {
                "classification": "ERROR",
                "navigation": {"ok": False, "error_type": type(exc).__name__},
            }
        )
    finally:
        result["network_events"] = network_events
        result["network_event_count"] = len(network_events)
        result["finished_at"] = utc_now()
        context.close()

    output_dir.mkdir(parents=True, exist_ok=True)
    with (output_dir / f"{target['id']}.json").open("w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2, sort_keys=True)
    return result


def write_summary(
    results: list[dict[str, Any]],
    output_dir: Path,
    provenance: dict[str, Any],
    browser_version: str,
) -> None:
    summary = {
        "schema_version": SUMMARY_SCHEMA_VERSION,
        "generated_at": utc_now(),
        "runner": {
            "os": platform.platform(),
            "python": sys.version.split()[0],
            "browser_engine": "chromium",
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
                "initial_status": (item.get("navigation") or {}).get("initial_status"),
                "network_event_count": item.get("network_event_count"),
            }
            for item in results
        ],
    }
    with (output_dir / "summary.json").open("w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=2, sort_keys=True)

    lines = [
        "# BrowserParity anonymous WebUI observation",
        "",
        f"Generated: `{summary['generated_at']}`",
        f"Chromium: `{browser_version}`",
        (
            f"Runner country: `{provenance.get('country') or 'unknown'}`; "
            f"region: `{provenance.get('region') or 'unknown'}`; "
            f"ASN: `{provenance.get('asn') or 'unknown'}`"
        ),
        "",
        "| Target | Classification | HTTP | Network events |",
        "|---|---|---:|---:|",
    ]
    for item in summary["results"]:
        lines.append(
            f"| {item['target_id']} | {item['classification']} | "
            f"{item['initial_status'] if item['initial_status'] is not None else ''} | "
            f"{item['network_event_count'] or 0} |"
        )
    lines.extend(
        [
            "",
            (
                "Public-safe slice: no cookies, authorization headers, "
                "request/response bodies, page text, credentials, screenshots, "
                "or reusable session material are retained."
            ),
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
    targets = [
        target for target in manifest["targets"] if target.get("enabled", False)
    ]
    if args.target != "all":
        targets = [target for target in targets if target["id"] == args.target]
        if not targets:
            raise SystemExit(f"unknown or disabled target: {args.target}")

    provenance = fetch_runner_network_provenance()
    results: list[dict[str, Any]] = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        browser_version = browser.version
        try:
            for target in targets:
                results.append(
                    observe_target(browser, target, task, provenance, output_dir)
                )
        finally:
            browser.close()

    write_summary(results, output_dir, provenance, browser_version)
    print((output_dir / "summary.md").read_text(encoding="utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
