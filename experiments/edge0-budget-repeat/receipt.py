#!/usr/bin/env python3
"""Repeat exact upstream Edge0 resident-weight budget oracle in fresh processes."""
import argparse
import hashlib
import json
import os
import pathlib
import platform
import subprocess
import time

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--binary", required=True)
    p.add_argument("--repetitions", type=int, default=20)
    args = p.parse_args()
    assert 1 <= args.repetitions <= 30
    binary = pathlib.Path(args.binary).resolve()
    assert binary.is_file()
    cases = []
    started = time.monotonic()
    for phase in ("default", "single-arena"):
        for index in range(args.repetitions):
            env = os.environ.copy()
            if phase == "single-arena":
                env["MALLOC_ARENA_MAX"] = "1"
            try:
                child = subprocess.run([str(binary)], capture_output=True,
                    text=True, timeout=10, env=env)
                code = child.returncode
                summary = (child.stdout + child.stderr)
            except subprocess.TimeoutExpired:
                code, summary = 124, "TIMEOUT"
            cases.append({
                "phase": phase, "rep": index + 1, "exit_code": code,
                "log_sha256": hashlib.sha256(summary.encode()).hexdigest(),
                "failure_excerpt": summary.strip()[:200] if code else None,
            })
    failures = [x for x in cases if x["exit_code"] != 0]
    receipt = {
        "schema": "bp-edge0-weight-accounting-repeat/v1",
        "scope": "PUBLIC_UPSTREAM_SOURCE_UNIT_ONLY",
        "upstream_sha": os.environ.get("EDGE0_SHA"),
        "gha_sha": os.environ.get("GITHUB_SHA"),
        "runner_label": os.environ.get("CENSUS_RUNNER_LABEL"),
        "architecture": platform.machine(),
        "repetitions_total": len(cases),
        "passed": len(cases)-len(failures),
        "failed": len(failures),
        "classification": "ALL_PASS" if not failures else
            ("ALL_FAIL" if len(failures) == len(cases) else "VARIABLE_FAILURE"),
        "phase_summary": [
            {"phase": phase,
             "passed": sum(x["exit_code"]==0 for x in cases if x["phase"]==phase),
             "failed": sum(x["exit_code"]!=0 for x in cases if x["phase"]==phase)}
            for phase in ("default", "single-arena")
        ],
        "samples": failures[:6],
        "wall_seconds": round(time.monotonic()-started,3),
        "full_model_assets": False,
        "model_qualified": False,
    }
    line = "BP_EDGE0_BUDGET_REPEAT_RECEIPT=" + json.dumps(receipt, separators=(",", ":"),sort_keys=True)
    print(line, flush=True)
    with open(os.environ.get("GITHUB_STEP_SUMMARY", "/dev/null"), "a") as out:
        out.write(line + "\n")
    assert not failures, "At least one actual upstream resident-weight budget oracle failed"

if __name__ == "__main__":
    main()
