#!/usr/bin/env python3
"""Validated entrypoint composition for anonymous WebUI observation.

Hosted reps exposed browser-control failure modes on framework-controlled inputs.
Keep the generic, provider-neutral locator and progress through increasingly
user-like bounded controls: normal Playwright fill first, then a real mouse click
at the independently proven visible textarea bounds followed by ordinary keyboard
key events. The observer requires evidence that the selected input actually
changed before it attempts submission.

Confirmation remains content-free: only focus booleans, input lengths/empty state,
and ephemeral post-submit request/response counts are retained. No page text,
prompt text, request/response bodies, headers, cookies, credentials, screenshots,
or reusable session material are added to evidence.
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
                    focused: document.activeElement === e,
                    length: value.length,
                    nonempty: value.length > 0
                };
            }"""
        )
        return {
            "attached": bool(state.get("attached")),
            "focused": bool(state.get("focused")),
            "length": int(state.get("length") or 0),
            "nonempty": bool(state.get("nonempty")),
        }
    except Exception as exc:
        return {"attached": False, "focused": False, "error_type": type(exc).__name__}


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
    initial_state = _input_state(locator)
    result["input_initial"] = initial_state

    try:
        locator.fill(prompt, timeout=2500)
        result["input_method"] = "playwright_fill"
    except Exception as exc:
        result["fill_error_type"] = type(exc).__name__
        try:
            box = locator.bounding_box(timeout=2500)
            if not box or box.get("width", 0) <= 0 or box.get("height", 0) <= 0:
                result["input_fallback_error"] = "no_positive_bounding_box"
                return result
            page.mouse.click(
                float(box["x"]) + float(box["width"]) / 2,
                float(box["y"]) + float(box["height"]) / 2,
            )
            time.sleep(0.15)
            focused_state = _input_state(locator)
            result["input_after_mouse_click"] = focused_state
            if not focused_state.get("focused"):
                result["input_fallback_error"] = "mouse_click_did_not_focus_target"
                return result
            page.keyboard.press("Control+A")
            page.keyboard.type(prompt, delay=8)
            result["input_method"] = "mouse_center_keyboard_type"
        except Exception as fallback_exc:
            result["input_fallback_error_type"] = type(fallback_exc).__name__
            return result

    entered_state = _input_state(locator)
    result["input_before_submit"] = entered_state
    initial_length = int(initial_state.get("length") or 0)
    entered_length = int(entered_state.get("length") or 0)
    input_effect_observed = bool(entered_state.get("nonempty")) and entered_length > initial_length + 4
    result["input_effect_observed"] = input_effect_observed
    if not input_effect_observed:
        result["input_error"] = "no_material_input_state_change"
        return result

    post_submit_counts = {"requests": 0, "responses": 0}

    def count_request(_request) -> None:
        post_submit_counts["requests"] += 1

    def count_response(_response) -> None:
        post_submit_counts["responses"] += 1

    page.on("request", count_request)
    page.on("response", count_response)

    try:
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
            pass

    after = base.body_fingerprint(page)
    result["input_after_submit"] = _input_state(locator)
    result["post_submit_request_count"] = post_submit_counts["requests"]
    result["post_submit_response_count"] = post_submit_counts["responses"]
    result["network_event_delta"] = len(network_events) - network_before
    result["body_changed"] = before["text_sha256"] != after["text_sha256"]
    result["body_length_delta"] = after["text_length"] - before["text_length"]

    after_input = result.get("input_after_submit") or {}
    input_cleared = bool(entered_state.get("nonempty")) and (
        not after_input.get("attached", True)
        or not after_input.get("nonempty", False)
        or int(after_input.get("length") or 0) < max(2, entered_length // 4)
    )
    result["input_cleared_after_submit"] = input_cleared
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
    elif (
        result.get("classification") == "LANDING_ONLY"
        and prompt.get("prompt_input_found")
        and prompt.get("prompt_attempted")
        and not prompt.get("prompt_submitted")
        and (
            prompt.get("input_fallback_error")
            or prompt.get("input_fallback_error_type")
            or prompt.get("input_error")
            or prompt.get("fill_error_type")
        )
    ):
        # A candidate UI control exists, but ordinary user-level interaction could
        # not actuate it in this executor. Preserve that executor/surface fact
        # instead of misreporting it as a generic landing-only observation.
        result["classification"] = "CONTROL_SURFACE_UNACTIONABLE"
    return result


base.attempt_single_prompt = robust_attempt_single_prompt
base.observe_target = robust_observe_target


if __name__ == "__main__":
    raise SystemExit(hardened.main())
