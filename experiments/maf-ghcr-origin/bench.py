#!/usr/bin/env python3
"""Exploratory end-to-end verified byte acquisition: approved MAF GHCR vs exact HF origin."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import urllib.request

MAF_SHA = "6bc5750dcd947cbbf8b3a11e80afbabd81c19ed6"
DIGEST = "sha256:f2d664ae986b0b0598037a9f0b929fd0b0b748871474a06c84658c1f2a1a4b42"
LOGICAL_ID = "asr/faster-whisper/tiny"
CANDIDATE = Path("candidates/asr-faster-whisper-tiny/d90ca5fe260221311c53c58e660288d3deb8d356/6ef51b0bfbb727b85fa00b65f7d70eacd378f01e.json")
EXPECTED = {"config.json", "model.bin", "tokenizer.json", "vocabulary.txt"}

def check(path, row):
    if not path.is_file() or path.is_symlink():
        raise RuntimeError("missing or nonregular source file")
    if path.stat().st_size != row["size_bytes"]:
        raise RuntimeError("source byte size mismatch")
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    if h.hexdigest() != row["sha256"]:
        raise RuntimeError("source SHA-256 mismatch")

def approved():
    cat = json.loads(Path("catalog/approved.json").read_text())["artifacts"][LOGICAL_ID]
    evidence = json.loads(CANDIDATE.read_text())
    if cat["approved_digest"] != DIGEST or cat["oci_repository"] != "ghcr.io/sempersupra/model-artifact-foundry":
        raise RuntimeError("approved catalog has changed")
    if evidence["oci"]["digest"] != DIGEST or evidence["logical_id"] != LOGICAL_ID:
        raise RuntimeError("immutable candidate digest mismatch")
    if evidence["upstream"]["exact_revision"] != cat["upstream_exact_revision"]:
        raise RuntimeError("source revision mismatch")
    if evidence["upstream"]["repository"] != "Systran/faster-whisper-tiny":
        raise RuntimeError("origin provider mismatch")
    if evidence["license"]["redistribution_verified"] is not True:
        raise RuntimeError("origin redistribution no longer verified")
    files = evidence["files"]
    if {x["path"] for x in files} != EXPECTED or len(files) != len(EXPECTED):
        raise RuntimeError("model file allowlist changed")
    return evidence, files

def do_ghcr(root, files):
    cache = root / "foundry-cache"
    start = time.perf_counter()
    proc = subprocess.run([sys.executable, "tools/hydrate.py", "--catalog", "catalog/approved.json",
            "--id", LOGICAL_ID, "--cache-root", str(cache)], capture_output=True, text=True, timeout=300)
    if proc.returncode:
        raise RuntimeError("digest-pinned public GHCR hydration failed: " + proc.stderr[-350:])
    model = Path(proc.stdout.strip().splitlines()[-1])
    if not model.is_dir() or set(x.name for x in model.iterdir()) != EXPECTED:
        raise RuntimeError("hydration inventory mismatch")
    for row in files:
        check(model / row["path"], row)
    elapsed = time.perf_counter() - start
    # Read-only offline repeat should NOT require a registry client or network.
    again = subprocess.run([sys.executable, "tools/hydrate.py", "--catalog", "catalog/approved.json",
            "--id", LOGICAL_ID, "--cache-root", str(cache), "--oras", "/bin/false"],
            capture_output=True, text=True, timeout=90)
    if again.returncode or again.stdout.strip().splitlines()[-1] != str(model):
        raise RuntimeError("same-run offline GHCR hydration failed")
    return {"seconds": round(elapsed, 3), "verified_bytes": sum(x["size_bytes"] for x in files),
            "offline_second_read": True, "all_source_sha256_pass": True}

def do_origin(root, evidence, files):
    dst = root / "hf-origin"
    dst.mkdir(mode=0o700, exist_ok=False)
    rev = evidence["upstream"]["exact_revision"]
    start = time.perf_counter()
    for row in files:
        name = row["path"]
        url = "https://huggingface.co/Systran/faster-whisper-tiny/resolve/" + rev + "/" + name + "?download=true"
        req = urllib.request.Request(url, headers={"User-Agent":"SemperSupra-MAF-BrowserParity-Qualification/1"})
        with urllib.request.urlopen(req, timeout=120) as response, (dst / name).open("wb") as output:
            shutil.copyfileobj(response, output, length=1024 * 1024)
        check(dst / name, row)
    elapsed = time.perf_counter() - start
    if {x.name for x in dst.iterdir()} != EXPECTED:
        raise RuntimeError("origin file inventory mismatch")
    return {"seconds": round(elapsed, 3), "verified_bytes": sum(x["size_bytes"] for x in files),
            "all_source_sha256_pass": True}

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--order", choices=["ghcr-first", "origin-first"], required=True)
    args = p.parse_args()
    source_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    if source_sha != MAF_SHA:
        raise SystemExit("Foundry source checkout is not pinned")
    evidence, rows = approved()
    workspace = Path(os.environ["RUNNER_TEMP"]) / "origin-ghcr-bench"
    workspace.mkdir(mode=0o700, exist_ok=False)
    initial_free = shutil.disk_usage(workspace).free
    if initial_free < 2_500_000_000:
        raise SystemExit("insufficient public runner disk headroom")
    order = ["ghcr", "origin"] if args.order == "ghcr-first" else ["origin", "ghcr"]
    results = {}
    for source in order:
        results[source] = (do_ghcr(workspace, rows) if source == "ghcr"
                            else do_origin(workspace, evidence, rows))
    receipt = {
        "schema":"bp-maf-ghcr-versus-origin/v1",
        "github_sha":os.environ.get("BP_GHA_SHA", ""),
        "maf_sha":MAF_SHA, "approved_digest":DIGEST,
        "order":args.order, "runner":os.environ.get("RUNNER_LABEL", ""),
        "verified_model_bytes":sum(x["size_bytes"] for x in rows),
        "disk_free_before":initial_free,
        "disk_free_after":shutil.disk_usage(workspace).free,
        "github_container_registry":results["ghcr"],
        "huggingface_origin":results["origin"],
        "promoted":False, "ghcr_pushed":False, "cache_persistent_between_jobs":False,
        "real_model_inference":False, "is_repeated_speed_study":False,
    }
    line = "BP_MAF_SOURCE_BAKEOFF_RECEIPT=" + json.dumps(receipt, sort_keys=True, separators=(",",":"))
    print(line, flush=True)
    with open(os.environ.get("GITHUB_STEP_SUMMARY", "/dev/null"), "a") as out:
        out.write(line + "\n")

if __name__ == "__main__":
    main()
