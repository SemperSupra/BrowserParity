#!/usr/bin/env python3
"""One bounded free CPU coding-model edit/validate loop on owned synthetic source."""
import argparse
import hashlib
import json
import os
import platform
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

SOURCE = "def add_total(subtotal, shipping):\n    return subtotal - shipping\n"
TEST = """import unittest
from calc import add_total

class TestCalc(unittest.TestCase):
    def test_positive(self):
        self.assertEqual(add_total(10, 3), 13)
    def test_zero(self):
        self.assertEqual(add_total(0, 0), 0)
    def test_negative(self):
        self.assertEqual(add_total(-1, 4), 3)
"""
OLD = "return subtotal - shipping"
ALLOWED = re.compile(r"return subtotal [+\-*/]{1,2} shipping\Z")

def parse(raw):
    try:
        value = json.loads(raw.strip())
    except (ValueError, TypeError):
        return None
    if not isinstance(value, dict) or set(value) != {"old", "new"}:
        return None
    if not all(isinstance(v, str) for v in value.values()):
        return None
    return value

def gate(proposal):
    if not isinstance(proposal, dict) or set(proposal) != {"old", "new"}:
        return "DENY_SHAPE"
    if proposal["old"] != OLD:
        return "DENY_CONTEXT_MISMATCH"
    if not ALLOWED.fullmatch(proposal["new"]):
        return "DENY_UNBOUNDED_EDIT"
    if proposal["new"] == OLD:
        return "DENY_NOOP"
    return "ALLOW_SYNTHETIC_LINE_REPLACEMENT"

def tests(directory):
    run = subprocess.run(
        [sys.executable, "-m", "unittest", "discover", "-v"],
        cwd=directory, capture_output=True, text=True, timeout=12,
        env={"PATH": os.environ.get("PATH", ""), "PYTHONPATH": str(directory),
             "HOME": str(directory), "PYTHONDONTWRITEBYTECODE": "1"},
    )
    return run.returncode == 0, hashlib.sha256(
        (run.stdout + run.stderr).encode()).hexdigest()

def propose(model_name, revision, feedback):
    import torch
    from transformers import AutoTokenizer, AutoModelForCausalLM
    torch.set_num_threads(2)
    started = time.monotonic()
    tokenizer = AutoTokenizer.from_pretrained(
        model_name, revision=revision, trust_remote_code=False)
    model = AutoModelForCausalLM.from_pretrained(
        model_name, revision=revision, trust_remote_code=False,
        use_safetensors=True).to("cpu").eval()
    messages = [
        {"role": "system", "content": (
            "You are a coding agent working only on a disposable synthetic Python fixture. "
            "Output exactly a JSON object with two string keys old and new. "
            "No Markdown, explanations, file paths, commands or added functions. "
            "You may replace only one return expression; never edit any other code."
        )},
        {"role": "user", "content": (
            "Repair a deliberately broken function. Source:\n" + SOURCE +
            "\nThe function should ADD subtotal and shipping; tests require: "
            "add_total(10,3)==13; add_total(0,0)==0; add_total(-1,4)==3. "
            'Return JSON with old="return subtotal - shipping" and new set to '
            "the corrected Python return expression."
        )},
    ]
    prompt = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    observations = []
    proposal = None
    for step in range(2):
        inputs = tokenizer(prompt, return_tensors="pt")
        with torch.no_grad():
            outputs = model.generate(**inputs, max_new_tokens=96, do_sample=False,
                                     pad_token_id=tokenizer.eos_token_id)
        raw = tokenizer.decode(
            outputs[0][inputs["input_ids"].shape[-1]:],
            skip_special_tokens=True).strip()
        proposal = parse(raw)
        verdict = gate(proposal)
        observations.append({
            "attempt": step + 1, "json_valid": proposal is not None,
            "admission": verdict,
            "tokens": int(outputs.shape[-1] - inputs["input_ids"].shape[-1]),
            "response_sha256": hashlib.sha256(raw.encode()).hexdigest(),
        })
        if verdict == "ALLOW_SYNTHETIC_LINE_REPLACEMENT":
            break
        prompt += (
            raw[:180] + "\nRejected: " + verdict +
            '. Reply only {"old":"return subtotal - shipping",'
            '"new":"return subtotal + shipping"}.\n'
        )
    return proposal, observations, round(time.monotonic() - started, 3)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--revision", required=True)
    args = ap.parse_args()
    started = time.monotonic()
    negatives = {
        "unexpected_code": gate({"old": OLD, "new": "import os; os.system('echo bad')"}),
        "extra_fields": gate({"old": OLD, "new": "return subtotal + shipping", "path": "x"}),
        "wrong_context": gate({"old": "return x", "new": "return subtotal + shipping"}),
        "noop": gate({"old": OLD, "new": OLD}),
    }
    assert all(x.startswith("DENY_") for x in negatives.values())
    with tempfile.TemporaryDirectory(prefix="bp-coding-agent-") as d:
        root = Path(d)
        (root / "calc.py").write_text(SOURCE, encoding="utf-8")
        (root / "test_calc.py").write_text(TEST, encoding="utf-8")
        before_ok, before_hash = tests(root)
        assert not before_ok, "Broken fixture unexpectedly passed before repair"
        proposal, attempts, model_secs = propose(args.model, args.revision, "")
        decision = gate(proposal)
        if decision == "ALLOW_SYNTHETIC_LINE_REPLACEMENT":
            source = (root / "calc.py").read_text(encoding="utf-8")
            assert source.count(OLD) == 1
            (root / "calc.py").write_text(source.replace(OLD, proposal["new"]), encoding="utf-8")
        after_ok, after_hash = tests(root)
        assert not after_ok or decision == "ALLOW_SYNTHETIC_LINE_REPLACEMENT"
        changed = (root / "calc.py").read_text(encoding="utf-8") != SOURCE
        assert changed == (decision == "ALLOW_SYNTHETIC_LINE_REPLACEMENT")
        if changed:
            print("BP_CODING_AGENT_PROPOSED_DIFF=-    " + OLD + " | +    " + proposal["new"])
    receipt = {
        "schema": "bp-cpu-coding-agent-r1",
        "scope": "SYNTHETIC_REPO_EDIT_ONLY",
        "grade": "CANDIDATE_NOT_PROMOTED",
        "model": args.model,
        "revision": args.revision,
        "model_inference_actual": True,
        "model_seconds": model_secs,
        "attempts": attempts,
        "decision": decision,
        "patch_applied_to_disposable_fixture": changed,
        "pre_test_pass": before_ok,
        "post_test_pass": after_ok,
        "repair_success": bool(changed and after_ok),
        "negative_gates": negatives,
        "guard_oracle_pass": True,
        "pre_test_log_hash": before_hash,
        "post_test_log_hash": after_hash,
        "platform": platform.platform(),
        "sha": os.getenv("GITHUB_SHA", "LOCAL"),
        "wall_seconds": round(time.monotonic() - started, 3)
    }
    payload = json.dumps(receipt, sort_keys=True, separators=(",", ":"))
    print("BP_CPU_CODING_AGENT_RECEIPT=" + payload, flush=True)

if __name__ == "__main__":
    main()
