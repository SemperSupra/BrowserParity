#!/usr/bin/env python3
"""Source-pinned Edge0 JSON finite-double candidate A/B test."""
import argparse, hashlib, json, os, platform, subprocess, sys
from pathlib import Path
OLD="        if(roundtrip==d) break;"
NEW="        if(!check.fail() && roundtrip==d) break;"
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--patch-source")
    ap.add_argument("--checker")
    ap.add_argument("--baseline")
    ap.add_argument("--candidate")
    a=ap.parse_args()
    if a.patch_source:
        path=Path(a.patch_source);src=path.read_text()
        assert src.count(OLD)==1, "Expected exactly one source occurrence"
        path.write_text(src.replace(OLD,NEW))
        print("BP_EDGE0_JSON_TEMP_PATCH=check stream failure")
        return
    assert a.checker and a.baseline and a.candidate
    def test(exe):
        r=subprocess.run([sys.executable,a.checker,exe],capture_output=True,text=True,timeout=90)
        s=r.stdout+r.stderr
        return {"exit":r.returncode,"sha256":hashlib.sha256(s.encode()).hexdigest(),"excerpt":s.strip()[-420:]}
    original=test(a.baseline);candidate=test(a.candidate)
    receipt={"schema":"bp-edge0-json-overflow/v1",
      "scope":"PUBLIC_SOURCE_NUMERIC_ONLY","upstream_sha":os.getenv("EDGE0_SHA"),
      "gha_sha":os.getenv("GITHUB_SHA"),"runner":os.getenv("CENSUS_RUNNER_LABEL"),
      "architecture":platform.machine(),"original":original,"candidate":candidate,
      "real_model_weights":False,"promotable":False}
    line="BP_EDGE0_JSON_ORACLE="+json.dumps(receipt,sort_keys=True,separators=(",",":"))
    print(line,flush=True)
    with open(os.environ.get("GITHUB_STEP_SUMMARY","/dev/null"),"a") as f:f.write(line+"\n")
    assert original["exit"]!=0 and "2e+308" in original["excerpt"],"No original max-finite defect observed"
    assert candidate["exit"]==0,"Candidate failed real upstream randomized numeric oracle"
if __name__=="__main__":main()
