#!/usr/bin/env python3
"""Diagnostic-only instrumentation of exact Edge0 unit fixture; never production code."""
import argparse
import hashlib
import json
import os
import pathlib
import platform
import re
import subprocess
import time

A = "        CHECK(storage.size() == 1 && budget.current(exec::Purpose::resident_weights) == ggml_backend_buffer_get_size(storage.front()->allocation()->buffer));"
B = "        CHECK(budget.current(exec::Purpose::resident_weights) == ggml_backend_buffer_get_size(copies[0]->allocation()->buffer) + ggml_backend_buffer_get_size(copies[1]->allocation()->buffer));"
A_TRACE = """        std::cerr << "BP_TRACE_A count=" << storage.size() << " charged=" << budget.current(exec::Purpose::resident_weights)
            << " expected=" << (storage.empty() ? 0 : ggml_backend_buffer_get_size(storage.front()->allocation()->buffer)) << '\\n';
"""
B_TRACE = """        std::cerr << "BP_TRACE_B count=" << copies.size() << " charged=" << budget.current(exec::Purpose::resident_weights)
            << " expected=" << (copies.size() < 2 ? 0 : ggml_backend_buffer_get_size(copies[0]->allocation()->buffer) + ggml_backend_buffer_get_size(copies[1]->allocation()->buffer)) << '\\n';
"""
PATTERN = re.compile(r"BP_TRACE_(A|B) count=(\d+) charged=(\d+) expected=(\d+)")

def instrument(file):
    path = pathlib.Path(file)
    source = path.read_text()
    assert source.count(A) == 1 and source.count(B) == 1, "Pinned upstream test contract changed"
    after = source.replace(A, A_TRACE + A).replace(B, B_TRACE + B)
    assert after != source
    path.write_text(after)
    print("BP_TRACE_PATCHED=2 telemetry lines per test path, no assertion changed")

def exercise(binary, reps):
    observations = []
    for i in range(reps):
        try:
            r = subprocess.run([str(pathlib.Path(binary).resolve())],capture_output=True,
                               text=True,timeout=10)
            out = r.stdout + r.stderr
            code = r.returncode
        except subprocess.TimeoutExpired:
            code, out = 124, "TIMEOUT"
        traces = [{"stage": match.group(1), "count": int(match.group(2)),
                   "charged": int(match.group(3)), "expected": int(match.group(4))}
                  for match in PATTERN.finditer(out)]
        observations.append({
            "rep": i+1, "exit": code, "traces": traces,
            "log_sha256": hashlib.sha256(out.encode()).hexdigest(),
            "failure_excerpt": out.strip()[-240:] if code != 0 else None,
        })
    return observations

def summarize(cases):
    failed = [r for r in cases if r["exit"] != 0]
    anomalous = [r for r in cases if any(t["charged"] != t["expected"] or
                                           t["count"] != (1 if t["stage"]=="A" else 2)
                                           for t in r["traces"])]
    return {"trials": len(cases), "failed": len(failed),
            "trace_mismatches": len(anomalous),
            "failure_samples": failed[:6],
            "numeric_mismatch_samples": anomalous[:6]}

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--instrument-source")
    p.add_argument("--baseline")
    p.add_argument("--instrumented")
    p.add_argument("--reps",type=int,default=80)
    args=p.parse_args()
    if args.instrument_source:
        instrument(args.instrument_source)
        return
    assert args.baseline and args.instrumented and 1 <= args.reps <= 100
    start=time.monotonic()
    baseline=exercise(args.baseline,args.reps)
    instrumented=exercise(args.instrumented,args.reps)
    summary={
        "schema":"bp-edge0-accounting-instrumented/v1",
        "scope":"PUBLIC_PINNED_SOURCE_TEMPORARY_DIAGNOSTIC",
        "upstream_sha":os.getenv("EDGE0_SHA"),
        "gha_sha":os.getenv("GITHUB_SHA"),
        "runner":os.getenv("CENSUS_RUNNER_LABEL"),
        "architecture":platform.machine(),
        "baseline":summarize(baseline),
        "instrumented":summarize(instrumented),
        "wall_seconds":round(time.monotonic()-start,3),
        "production_source_mutated":False,
        "full_35b_model_tested":False,
        "candidate_qualified":False,
    }
    line="BP_EDGE0_ACCOUNTING_TRACE_RECEIPT="+json.dumps(summary,sort_keys=True,separators=(",",":"))
    print(line,flush=True)
    with open(os.environ.get("GITHUB_STEP_SUMMARY","/dev/null"),"a") as f:
        f.write(line+"\n")
    if summary["baseline"]["failed"] or summary["instrumented"]["failed"]:
        raise SystemExit("Native upstream memory accounting invariant failed; diagnostic preserved")

if __name__=="__main__":
    main()
