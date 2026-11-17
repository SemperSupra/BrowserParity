#!/usr/bin/env python3
"""Execute selected upstream Edge0 L2 tests; emit honest JUnit-grade receipt."""
import argparse
import json
import os
import pathlib
import platform
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

PATTERN = r"^moe_test_edge0_35b_slots$"

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--model-root", required=True)
    p.add_argument("--ctest-dir", required=True)
    args = p.parse_args()
    junit = pathlib.Path(os.environ.get("RUNNER_TEMP", "/tmp")) / "edge0-l2.xml"
    cmd = ["ctest", "--test-dir", args.ctest_dir, "-L", "L2", "-LE", "device",
           "-R", PATTERN, "--parallel", "1", "--timeout", "240",
           "--output-on-failure", "--output-junit", str(junit)]
    run = subprocess.run(cmd, text=True, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, timeout=720)
    print(run.stdout, flush=True)
    if not junit.exists():
        raise SystemExit("CTest did not create a JUnit receipt")
    root = ET.parse(junit).getroot()
    cases = root.findall(".//testcase")
    failed = [c.attrib.get("name", "") for c in cases
              if c.find("failure") is not None or c.find("error") is not None]
    skipped = [c.attrib.get("name", "") for c in cases if c.find("skipped") is not None]
    sizes = {}
    for item in ("tiny-a", "tiny-b"):
        d = pathlib.Path(args.model_root) / item
        sizes[item] = sum(x.stat().st_size for x in d.rglob("*") if x.is_file()) if d.is_dir() else 0
    receipt = {
        "schema": "bp-edge0-tiny-l2/v1", "scope": "RANDOM_WEIGHT_NOT_REAL_35B",
        "upstream_sha": os.getenv("EDGE0_SHA"), "gha_sha": os.getenv("GITHUB_SHA"),
        "runner_label": os.getenv("CENSUS_RUNNER_LABEL"),
        "architecture": platform.machine(), "actual_cases": len(cases),
        "failed": failed, "skipped": skipped,
        "passed": len(cases)-len(failed)-len(skipped),
        "junit_ctest_exit": run.returncode, "tiny_fixture_bytes": sizes,
        "real_model_checkpoint_downloaded": False, "model_task_qualified": False,
    }
    print("BP_EDGE0_TINY_L2_RECEIPT=" + json.dumps(receipt, sort_keys=True), flush=True)
    summary = pathlib.Path(os.environ.get("GITHUB_STEP_SUMMARY", "/dev/null"))
    with summary.open("a") as out:
        out.write("BP_EDGE0_TINY_L2_RECEIPT=" + json.dumps(receipt, sort_keys=True) + "\n")
    assert len(cases) == 1 and all(sizes.values()), "Targeted x64 slot oracle did not execute exactly once"
    assert not failed and run.returncode == 0, "Selected upstream L2 tests failed"

if __name__ == "__main__":
    main()
