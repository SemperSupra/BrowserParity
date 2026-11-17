#!/usr/bin/env python3
"""Apply two exact experimental Edge0 source candidates in disposable source only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import xml.etree.ElementTree as ET

UPSTREAM_SHA="f6bfa5546bcf89919f86946ec669bcc7f4cd526d"
REPLACEMENTS = (
    ("src/model/json.cpp",
     "        if(roundtrip==d) break;",
     "        if(!check.fail() && roundtrip==d) break;"),
    ("src/weights/runtime.cpp",
     "[this,file,identity,offset,slice,regions,hook,allocation,staged] {\n            (void)allocation;",
     "[this,file,identity,offset,slice,regions,hook,allocation,staged]() mutable {\n            auto hold_until_task_returns = std::move(allocation);")
)

def patch(root):
    for rel,old,new in REPLACEMENTS:
        f=root/rel
        src=f.read_text()
        if src.count(old)!=1 or new in src:
            raise RuntimeError("exact pinned upstream patch hunk mismatch "+rel)
        f.write_text(src.replace(old,new))
        print("BP_EDGE0_EXACT_SOURCE_CANDIDATE="+rel,flush=True)

def verify(root):
    log=Path(os.environ.get("RUNNER_TEMP","/tmp"))/"combined-l1-junit.xml"
    cmd=["ctest","--preset","cpu","-L","L0|L1","--parallel","2",
         "--timeout","120","--output-on-failure","--output-junit",str(log)]
    run=subprocess.run(cmd,cwd=root,text=True,stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,timeout=650)
    print(run.stdout,flush=True)
    if not log.is_file():
        raise RuntimeError("No real JUnit result from CTest")
    cases=ET.parse(log).getroot().findall(".//testcase")
    failures=[c.attrib.get("name","") for c in cases
              if c.find("failure") is not None or c.find("error") is not None]
    skips=[c.attrib.get("name","") for c in cases if c.find("skipped") is not None]
    receipt={
        "schema":"bp-edge0-combined-l1-candidates/v1",
        "upstream_sha":UPSTREAM_SHA,
        "project_head":os.environ.get("GITHUB_SHA"),
        "runner":os.environ.get("RUNNER_LABEL"),
        "architecture":platform.machine(),
        "test_count":len(cases),
        "passed":len(cases)-len(failures)-len(skips),
        "failed":failures,
        "skipped":skips,
        "ctest_exit":run.returncode,
        "temporary_source_patches":["json_finite_stream_failbit","async_allocation_capture_lifetime"],
        "upstream_test_assertions_modified":False,
        "model_weights_downloaded":False,
        "qualified_for_product":False
    }
    print("BP_EDGE0_COMBINED_L1_RECEIPT="+json.dumps(receipt,sort_keys=True,separators=(",",":")),flush=True)
    with open(os.environ.get("GITHUB_STEP_SUMMARY","/dev/null"),"a") as out:
        out.write("BP_EDGE0_COMBINED_L1_RECEIPT="+json.dumps(receipt,sort_keys=True)+"\n")
    if len(cases)<90:
        raise RuntimeError("Insufficient CTest L0/L1 test coverage")
    if run.returncode or failures:
        raise RuntimeError("Real upstream tests still fail; candidate cannot be accepted")

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--source",type=Path,required=True)
    x=p.add_mutually_exclusive_group(required=True)
    x.add_argument("--patch",action="store_true")
    x.add_argument("--test",action="store_true")
    args=p.parse_args()
    if args.patch:patch(args.source)
    else:verify(args.source)
if __name__=="__main__":main()
