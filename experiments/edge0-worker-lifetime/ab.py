#!/usr/bin/env python3
"""Probe whether task-captured allocation releases AFTER future readiness."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import time

BEFORE = """[this,file,identity,offset,slice,regions,hook,allocation,staged] {
            (void)allocation;"""
AFTER = """[this,file,identity,offset,slice,regions,hook,allocation,staged]() mutable {
            // Release this captured ticket before packaged_task signals the future.
            // It remains live for the entire storage read, including error exits.
            auto hold_until_task_returns = std::move(allocation);"""

def patch_runtime(filename):
    path=Path(filename)
    source=path.read_text()
    assert source.count(BEFORE)==1, "Upstream read-task capture changed; no unreviewed patch"
    edited=source.replace(BEFORE,AFTER)
    path.write_text(edited)
    print("BP_EDGE0_LIFETIME_PATCH=one exact source span in disposable worktree; no API/policy/assertion changes")

def run(binary, attempts):
    fails=[]
    for i in range(attempts):
        try:
            r=subprocess.run([str(Path(binary).resolve())],capture_output=True,
                             text=True,timeout=10)
            rc=r.returncode;output=r.stdout+r.stderr
        except subprocess.TimeoutExpired:
            rc=124;output="TIMEOUT"
        if rc:
            fails.append({"rep":i+1,"exit":rc,
                          "output_sha256":hashlib.sha256(output.encode()).hexdigest(),
                          "assertion":output.strip()[-230:]})
    return {"trials":attempts,"failed":len(fails),"passed":attempts-len(fails),
            "samples":fails[:5]}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--patch-runtime")
    ap.add_argument("--baseline")
    ap.add_argument("--candidate")
    ap.add_argument("--reps",type=int,default=200)
    args=ap.parse_args()
    if args.patch_runtime:
        patch_runtime(args.patch_runtime)
        return
    assert args.baseline and args.candidate and 1<=args.reps<=300
    start=time.monotonic()
    baseline=run(args.baseline,args.reps)
    candidate=run(args.candidate,args.reps)
    receipt={
        "schema":"bp-edge0-worker-capture-lifetime/v1",
        "scope":"TEMPORARY_SOURCE_FIX_CANDIDATE",
        "upstream_sha":os.environ.get("EDGE0_SHA"),
        "gha_sha":os.environ.get("GITHUB_SHA"),
        "runner":os.environ.get("CENSUS_RUNNER_LABEL"),
        "architecture":platform.machine(),
        "baseline":baseline,
        "candidate":candidate,
        "classification":("CANDIDATE_ORACLE_PASS" if
            baseline["failed"]>0 and candidate["failed"]==0 else
            "UNRESOLVED_OR_INCONCLUSIVE"),
        "wall_seconds":round(time.monotonic()-start,3),
        "original_upstream_source_mutated":False,
        "model_inference_performed":False,
        "adoption_approved":False,
    }
    line="BP_EDGE0_WORKER_LIFETIME_RECEIPT="+json.dumps(receipt,sort_keys=True,separators=(",",":"))
    print(line,flush=True)
    with open(os.environ.get("GITHUB_STEP_SUMMARY","/dev/null"),"a") as f:
        f.write(line+"\n")
    assert baseline["failed"] > 0, "No baseline failure reproduced; candidate unqualified"
    assert candidate["failed"] == 0, "Candidate still fails, do not promote"

if __name__=="__main__":
    main()
