#!/usr/bin/env python3
"""Bounded, secret-free anonymous WebUI observer for BrowserParity.

This public experiment intentionally captures only public-safe metadata. It does
not store cookies, authorization headers, request/response bodies, page text,
credentials, or reusable session material. Login, region, and bot-challenge
boundaries are observations to record, not obstacles to bypass.
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

SCHEMA_VERSION = "browserparity.anonymous-webui.observation/v1"


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


def fetch_runner_network_provenance() -> dict[str, Any]:
    """Best-effort public egress provenance without retaining the raw IP."""
    result: dict[str, Any] = {"source": "https://speed.cloudflare.com/meta", "ok": False}
    try:
        req = urllib.request.Request(
            "https://speed.cloudflare.com/meta",
            headers={"User-Agent": "BrowserParity-anonymous-observer/1"},
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.load(response)
        client_ip = str(data.get("clientIp", ""))
        result.update(
            {
                "ok": True,
                "country": data.get("country"),
                "region": data.get("region"),
                "city": data.get("city"),
                "colo": data.get("colo"),
                "asn": data.get("asn"),
                "as_organization": data.get("asOrganization"),
                "client_ip_sha256": sha256_text(client_ip) if client_ip else None,
            }
        )
    except Exception as exc:
        result["error_type"] = type(exc).__name__
    return result


def body_fingerprint(page) -> dict[str, Any]:
    try:
        text = page.locator("body").inner_text(timeout=5000)
    except Exception:
        text = ""
    return {
        "text_length": len(text),
        "text_sha256": sha256_text(text),
    }


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
    """Public UI semantics only; no values or page-body text."""
    try:
        return page.locator(
            'textarea,input,[contenteditable="true"],button,[role="button"],[role="textbox"]'
        ).evaluate_all(
            """els => els.slice(0, 100).map(e => ({
                tag: e.tagName.toLowerCase(),
                role: e.getAttribute('role'),
                type: e.getAttribute('type'),
                ariaLabel: e.getAttribute('aria-label'),
                placeholder: e.getAttribute('placeholder'),
                contentEditable: e.getAttribute('contenteditable'),
                disabled: !!e.disabled,
                visible: !!(e.offsetWidth || e.offsetHeight || e.getClientRects().length)
            }))"""
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
            "local_storage_key_hashes": [sha256_text(k) for k in sorted(data.get("local", []))],
            "session_storage_key_count": len(data.get("session", [])),
            "session_storage_key_hashes": [sha256_text(k) for k in sorted(data.get("session", []))],
        }
    except Exception as exc:
        return {"error_type": type(exc).__name__}


def find_prompt_input(page):
    selectors = [
        'textarea:not([disabled])',
        '[role="textbox"][contenteditable="true"]',
        '[contenteditable="true"]',
        'input[type="text"]:not([disabled])',
    ]
    for selector in selectors:
        locator = page.locator(selector)
        try:
            count = min(locator.count(), 12)
            for index in range(count):
                candidate = locator.nth(index)
                if not candidate.is_visible(timeout=500):
                    continue
                meta = candidate.evaluate(
                    """e => ({
                        tag: e.tagName.toLowerCase(),
                        type: e.getAttribute('type'),
                        placeholder: (e.getAttribute('placeholder') || '').toLowerCase(),
                        ariaLabel: (e.getAttribute('aria-label') || '').toLowerCase()
                    })"""
                )
                joined = f"{meta.get('placeholder', '')} {meta.get('ariaLabel', '')}"
                if any(term in joined for term in ("email", "username", "password", "phone")):
                    continue
                return candidate, selector, meta
        except Exception:
            continue
    return None, None, None


def attempt_single_prompt(page, prompt: str, post_submit_seconds: int, network_events: list[dict[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {
        "prompt_attempted": False,
        "prompt_submitted": False,
        "prompt_input_found": False,
    }
    locator, selector, meta = find_prompt_input(page)
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


def observe_target(browser, target: dict[str, Any], task: dict[str, Any], provenance: dict[str, Any], output_dir: Path) -> dict[str, Any]:
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
        response = page.goto(target["url"], wait_until="domcontentloaded", timeout=45000)
        time.sleep(int(task.get("landing_settle_seconds", 4)))
        landing = body_fingerprint(page)
        boundary_before = classify_boundary_text(page)
        result.update(
            {
                "navigation": {
                    "ok": True,
                    "initial_status": response.status if response else None,
                    "final_url": sanitize_url(page.url),
                    "title_sha256": sha256_text(page.title()),
                },
                "landing": landing,
                "boundary_before_prompt": boundary_before,
                "interactive_inventory": safe_interactive_inventory(page),
                "storage": storage_metadata(page),
            }
        )

        if boundary_before["challenge_text_present"]:
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

        if boundary_after["challenge_text_present"]:
            classification = "BOT_CHALLENGE"
        elif prompt_result.get("prompt_submitted") and prompt_result.get("body_changed"):
            classification = "ANONYMOUS_INTERACTION_OBSERVED"
        elif prompt_result.get("prompt_submitted"):
            classification = "INTERACTION_UNCONFIRMED"
        elif boundary_after["login_text_present"] and not prompt_result.get("prompt_input_found"):
            classification = "LOGIN_REQUIRED_OR_GATED"
        else:
            classification = "LANDING_ONLY"
        result["classification"] = classification

    except PlaywrightTimeoutError:
        result.update({"classification": "NAVIGATION_TIMEOUT", "navigation": {"ok": False, "error_type": "PlaywrightTimeoutError"}})
    except Exception as exc:
        result.update({"classification": "ERROR", "navigation": {"ok": False, "error_type": type(exc).__name__}})
    finally:
        result["network_events"] = network_events
        result["network_event_count"] = len(network_events)
        result["finished_at"] = utc_now()
        context.close()

    output_dir.mkdir(parents=True, exist_ok=True)
    with (output_dir / f"{target['id']}.json").open("w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2, sort_keys=True)
    return result


def write_summary(results: list[dict[str, Any]], output_dir: Path, provenance: dict[str, Any]) -> None:
    summary = {
        "schema_version": "browserparity.anonymous-webui.summary/v1",
        "generated_at": utc_now(),
        "runner": {
            "os": platform.platform(),
            "python": sys.version.split()[0],
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
        f"Runner country: `{provenance.get('country') or 'unknown'}`; colo: `{provenance.get('colo') or 'unknown'}`; ASN: `{provenance.get('asn') or 'unknown'}`",
        "",
        "| Target | Classification | Network events |",
        "|---|---|---:|",
    ]
    for item in summary["results"]:
        lines.append(f"| {item['target_id']} | {item['classification']} | {item['network_event_count'] or 0} |")
    lines.extend(
        [
            "",
            "Public-safe first slice: no cookies, authorization headers, request/response bodies, page text, credentials, screenshots, or reusable session material are retained.",
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

    provenance = fetch_runner_network_provenance()
    results: list[dict[str, Any]] = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        try:
            for target in targets:
                results.append(observe_target(browser, target, task, provenance, output_dir))
        finally:
            browser.close()

    write_summary(results, output_dir, provenance)
    print((output_dir / "summary.md").read_text(encoding="utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
