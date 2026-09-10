#!/usr/bin/env python3
"""Validated entrypoint composition for anonymous WebUI observation.

Rep 2 showed Copilot's prompt textarea was correctly identified but Playwright's
normal actionability path timed out before submission.  Keep the generic,
provider-neutral locator from ``observe_hardened`` and add one bounded fallback:
focus the already-qualified element through the DOM, type with ordinary browser
keyboard events, and press Enter.  This does not bypass provider gates or auth.
"""

from __future__ import annotations

import time
from typing import Any

import observe_hardened as hardened

base = hardened.base


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

    # First retain normal Playwright semantics.  If actionability times out on an
    # element independently proven visible/enabled/editable, focus that same
    # element and generate ordinary keyboard input.  No alternate element,
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

    try:
        # The selected element is now focused by either fill() or the fallback.
        # Keyboard submission avoids a second actionability wait on the locator.
        page.keyboard.press("Enter")
        result["submit_method"] = "focused_keyboard_enter"
        result["prompt_submitted"] = True
    except Exception as exc:
        result["submit_error_type"] = type(exc).__name__
        return result

    time.sleep(max(0, post_submit_seconds))
    after = base.body_fingerprint(page)
    result.update(
        {
            "body_changed": before["text_sha256"] != after["text_sha256"],
            "body_length_delta": after["text_length"] - before["text_length"],
            "network_event_delta": len(network_events) - network_before,
        }
    )
    return result


# ``observe_hardened.main`` replaces the locator with the rep-2 DOM-consistent
# implementation; install the complementary interaction function here.
base.attempt_single_prompt = robust_attempt_single_prompt


if __name__ == "__main__":
    raise SystemExit(hardened.main())
