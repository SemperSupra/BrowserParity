#!/usr/bin/env python3
"""Test-only correction to Edge0 Linux process-memory oracle with native baseline A/B."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess

BASE = """#else
    CHECK(!before.rss.values && !before.rss.reason.empty());
    CHECK(!before.physical.values && !before.physical.reason.empty());
#endif"""
FIX = """#elif defined(__linux__)
    // The Linux runtime already reports /proc/self/status RSS and
    // /proc/self/smaps_rollup PSS; preserve the unsupported fallback below.
    CHECK(before.rss.source == "proc_status" && before.physical.source == "pss");
    CHECK(before.rss.values && before.physical.values);
    CHECK(before.rss.reason.empty() && before.physical.reason.empty());
    CHECK(before.rss.values->current_bytes && *before.rss.values->current_bytes > 0);
    CHECK(before.rss.values->peak_bytes);
    CHECK(*before.rss.values->peak_bytes >= *before.rss.values->current_bytes);
    CHECK(before.physical.values->current_bytes);
    CHECK(!before.physical.values->peak_bytes && !before.physical.values->peak_reason.empty());
    constexpr std::size_t size=16*1024*1024;
    auto allocation=std::make_unique<unsigned char[]>(size);
    volatile unsigned char* bytes=allocation.get();
    for(std::size_t i=0;i<size;i+=4096) bytes[i]=static_cast<unsigned char>(i/4096);
    const auto after=edge0::platform::process_memory();
    CHECK(after.rss.values && after.physical.values);
    CHECK(after.rss.values->current_bytes && after.rss.values->peak_bytes);
    CHECK(*after.rss.values->current_bytes >= *before.rss.values->current_bytes+size/2);
    CHECK(*after.rss.values->peak_bytes >= *after.rss.values->current_bytes);
    CHECK(after.physical.values->current_bytes);
    CHECK(*after.physical.values->current_bytes >= *before.physical.values->current_bytes+size/2);
    CHECK(!after.physical.values->peak_bytes && !after.physical.values->peak_reason.empty());
#else
    CHECK(!before.rss.values && !before.rss.reason.empty());
    CHECK(!before.physical.values && !before.physical.reason.empty());
#endif"""

def patch(path):
    p=Path(path);s=p.read_text()
    if s.count(BASE)!=1 or FIX in s:
        raise RuntimeError("pinned upstream unit-test expectation changed")
    p.write_text(s.replace(BASE,FIX))
    print("BP_EDGE0_MEMORY_TEST_PATCH=Linux proc metrics, preserved unknown platform fallback")

def trials(binary,n):
    bad=[]
    for i in range(n):
        try:
            r=subprocess.run([str(Path(binary).resolve())],capture_output=True,
                             text=True,timeout=15)
            err=r.returncode;output=r.stdout+r.stderr
        except subprocess.TimeoutExpired:
            err=124;output="TIMEOUT"
        if err:
            bad.append({"trial":i+1,"exit_code":err,
                "log_sha256":hashlib.sha256(output.encode()).hexdigest(),
                "excerpt":output.strip()[-240:]})
    return {"trials":n,"passed":n-len(bad),"failed":len(bad),"failure_samples":bad[:4]}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--patch-test")
    ap.add_argument("--baseline")
    ap.add_argument("--candidate")
    ap.add_argument("--reps",type=int,default=20)
    args=ap.parse_args()
    if args.patch_test:
        patch(args.patch_test)
        return
    if not args.baseline or not args.candidate or not 1<=args.reps<=30:
        raise RuntimeError("invalid A/B arguments")
    baseline=trials(args.baseline,args.reps)
    candidate=trials(args.candidate,args.reps)
    receipt={
      "schema":"bp-edge0-linux-proc-memory-test-oracle/v1",
      "gha_sha":os.getenv("GITHUB_SHA"),
      "upstream_sha":os.getenv("EDGE0_SHA"),
      "runner":os.getenv("RUNNER_LABEL"),
      "architecture":platform.machine(),
      "original":baseline,
      "corrected_test":candidate,
      "source_runtime_code_modified":False,
      "runtime_semantics_verified":False,
      "real_model_weights":False,
      "eligible_for_product_promotion":False,
    }
    line="BP_EDGE0_LINUX_MEMORY_TEST_RECEIPT="+json.dumps(receipt,sort_keys=True,separators=(",",":"))
    print(line,flush=True)
    with open(os.getenv("GITHUB_STEP_SUMMARY","/dev/null"),"a") as f:f.write(line+"\n")
    if baseline["failed"]!=args.reps:
        raise RuntimeError("Pinned original unsupported-Linux assertion not reliably red")
    if candidate["failed"]:
        raise RuntimeError("Corrected Linux process-memory test still failed")
if __name__=="__main__":main()
