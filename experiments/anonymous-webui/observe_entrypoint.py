#!/usr/bin/env python3
"""Validated entrypoint composition for anonymous WebUI observation.

Rep 2 showed Copilot's prompt textarea was correctly identified but Playwright's
normal actionability path timed out before submission. Rep 3 then showed that
our capped retained network-event list could saturate during landing, making a
post-submit network delta falsely read zero. Keep the generic, provider-neutral
locator and interaction fallback, but confirm submission effects with ephemeral
counters and non-content input state.

No additional trace payload is retained: counters contain only event counts, and
input state contains only empty/non-empty/length metadata. No page text,
request/response bodies, headers, cookies, credentials, screenshots, or reusable
session material are added.
"""

from __future__ import annotations

import time
from typing import Any

import observe_hardened as hardened

base = hardened.base


def _input_state(locator) -> dict[str, Any]:
    try:
        state = locator.evaluate(
            """e => {
                const value = (typeof e.value === 'string') ? e.value : (e.textContent || '');
                return {
                    attached: e.isConnected,
                    length: value.length,
                    nonempty: value.length > 0
                };
            }"""
        )
        return {
            "attached": bool(state.get("attached")),
            "length": int(state.get("length") or 0),
            "nonempty": bool(state.get("nonempty")),
        }
    except Exception as exc:
        return {"attached": False, "error_type": type(exc).__name__}


def robust_attempt_single_prompt(
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
    locator, selector, meta = base.find_prompt_input(page)
    if locator is None:
        return result

    result["prompt_input_found"] = True
    result["prompt_input_selector_class"] = selector
    result["prompt_input_metadata"] = meta
    before = base.body_fingerprint(page)
    network_before = len(network_events)
    result["prompt_attempted"] = True

    # First retain normal Playwright semantics. If actionability times out on an
    # element independently proven visible/enabled/editable, focus that same
    # element and generate ordinary keyboard input. No alternate element,
    # hidden API, script submission, or provider-specific bypass is used.
    try:
        locator.fill(prompt, timeout=2500)
        result["input_method"] = "playwright_fill"
    except Exception as exc:
        result["fill_error_type"] = type(exc).__name__
        try:
            locator.evaluate("e => e.focus()")
            page.keyboard.press("Control+A")
            page.keyboard.insert_text(prompt)
            result["input_method"] = "dom_focus_keyboard"
        except Exception as fallback_exc:
            result["input_fallback_error_type"] = type(fallback_exc).__name__
            return result

    result["input_before_submit"] = _input_state(locator)

    # These handlers count only activity after the submit attempt. They are
    # intentionally independent of the base recorder's bounded retained list,
    # which may already be full on busy landing pages. No URL/header/body is
    # retained by these counters.
    post_submit_counts = {"requests": 0, "responses": 0}

    def count_request(_request) -> None:
        post_submit_counts["requests"] += 1

    def count_response(_response) -> None:
        post_submit_counts["responses"] += 1

    page.on("request", count_request)
    page.on("response", count_response)

    try:
        # The selected element is now focused by either fill() or the fallback.
        # Keyboard submission avoids a second actionability wait on the locator.
        page.keyboard.press("Enter")
        result["submit_method"] = "focused_keyboard_enter"
        result["prompt_submitted"] = True
        time.sleep(max(0, post_submit_seconds))
    except Exception as exc:
        result["submit_error_type"] = type(exc).__name__
        return result
    finally:
        try:
            page.remove_listener("request", count_request)
            page.remove_listener("response", count_response)
        except Exception:
            # Listener cleanup is hygiene only; the page/context is destroyed at
            # the end of each target observation regardless.
            pass

    after = base.body_fingerprint(page)
    result["input_after_submit"] = _input_state(locator)
    result["post_submit_request_count"] = post_submit_counts["requests"]
    result["post_submit_response_count"] = post_submit_counts["responses"]
    result["network_event_delta"] = len(network_events) - network_before
    result["body_changed"] = before["text_sha256"] != after["text_sha256"]
    result["body_length_delta"] = after["text_length"] - before["text_length"]

    before_input = result.get("input_before_submit") or {}
    after_input = result.get("input_after_submit") or {}
    input_cleared = bool(before_input.get("nonempty")) and (
        not after_input.get("attached", True)
        or not after_input.get("nonempty", False)
    )
    result["input_cleared_after_submit"] = input_cleared

    # A body transition is already strong evidence of an interaction. When body
    # text does not change, require both an input state transition and outbound
    # network activity before claiming that a submission effect was observed.
    result["submission_effect_observed"] = bool(result["body_changed"]) or (
        input_cleared and post_submit_counts["requests"] > 0
    )
    return result


_original_observe_target = base.observe_target


def robust_observe_target(browser, target, task, provenance, output_dir):
    result = _original_observe_target(browser, target, task, provenance, output_dir)
    prompt = result.get("prompt") or {}
    if (
        result.get("classification") == "INTERACTION_UNCONFIRMED"
        and prompt.get("submission_effect_observed")
    ):
        result["classification"] = "ANONYMOUS_SUBMISSION_OBSERVED"
    return result


# ``observe_hardened.main`` replaces the locator with the rep-2 DOM-consistent
# implementation. Install the complementary interaction and classification
# functions here before handing control to the hardened main path.
base.attempt_single_prompt = robust_attempt_single_prompt
base.observe_target = robust_observe_target


if __name__ == "__main__":
    raise SystemExit(hardened.main())
