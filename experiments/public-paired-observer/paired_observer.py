"""Public-safe paired observer-effect experiment, not private BrowserParity source.

For each real engine, compare a human-like uninstrumented context with an
instrumented context using the same deterministic owned fixture and action.
Measure DOM, accessibility, screenshots, normalized browser network events,
server-confirmed effects, and a mutation-positive control. No auth or secrets.
"""
import hashlib
import http.server
import json
import os
import threading
from urllib.parse import urlsplit

from playwright.sync_api import sync_playwright


PAGE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Owned Observer Fixture</title>
<style>body{font-family:Arial,sans-serif;margin:32px;background:#fff;color:#101010}
main{max-width:640px}button{font-size:18px;padding:8px 16px}</style></head>
<body><main><h1>Owned Observation Fixture</h1>
<button id="commit">Commit synthetic increment</button>
<output id="counter" aria-live="polite">0</output></main>
<script>
document.getElementById('commit').addEventListener('click', async () => {
  const response = await fetch('/commit', {method:'POST',
    headers:{'Content-Type':'application/json'},body:'{"fixture":"owned"}'});
  if (!response.ok) return;
  const receipt = await response.json();
  document.getElementById('counter').textContent = String(receipt.count);
});
</script></body></html>"""


class Fixture(http.server.ThreadingHTTPServer):
    def __init__(self):
        super().__init__(("127.0.0.1", 0), Handler)
        self.commit_count = 0

    @property
    def url(self):
        return f"http://127.0.0.1:{self.server_port}"


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if urlsplit(self.path).path != "/page":
            self.send_error(404)
            return
        body = PAGE.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if urlsplit(self.path).path != "/commit":
            self.send_error(404)
            return
        n = int(self.headers.get("Content-Length", "0"))
        if n > 4096:
            self.send_error(413)
            return
        self.rfile.read(n)
        self.server.commit_count += 1
        body = json.dumps({"count": self.server.commit_count}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def digest(x):
    return hashlib.sha256(x if isinstance(x, bytes) else x.encode()).hexdigest()


def capture(page):
    return {
        "body_dom": page.locator("body").evaluate("(body) => body.outerHTML"),
        "a11y": page.locator("main").aria_snapshot(),
        "png_sha256": digest(page.screenshot(animations="disabled")),
        "counter": page.locator("#counter").inner_text(),
    }


def run_lane(browser, fixture, mode):
    context = browser.new_context(
        viewport={"width": 800, "height": 600}, device_scale_factor=1,
        locale="en-US", reduced_motion="reduce", color_scheme="light")
    requests = []
    replies = []
    if mode == "instrumented":
        # Read-only, runtime-only probe; MUST not change DOM, requests or clicks.
        context.add_init_script("Object.defineProperty(window,'__bpSyntheticProbe',{value:{mode:'observed',version:1}});")
    if mode == "mutation-positive-control":
        # Intentional benign test mutation; qualification MUST detect it.
        context.add_init_script("document.addEventListener('DOMContentLoaded',()=>document.body.setAttribute('data-perturbed','true'));")
    context.on("request", lambda req: requests.append((req.method, urlsplit(req.url).path))
               if urlsplit(req.url).path in ("/page", "/commit") else None)
    context.on("response", lambda res: replies.append((res.status, urlsplit(res.url).path))
               if urlsplit(res.url).path in ("/page", "/commit") else None)
    try:
        page = context.new_page()
        page.goto(fixture.url + "/page", wait_until="load", timeout=12000)
        before = capture(page)
        probe = page.evaluate("!!window.__bpSyntheticProbe")
        if mode != "mutation-positive-control":
            page.get_by_role("button", name="Commit synthetic increment").click()
            page.wait_for_function("document.querySelector('#counter').textContent === '1'")
        after = capture(page)
        return {
            "before": before, "after": after, "probe": probe,
            "requests": requests, "responses": replies,
            "server_commit_count": fixture.commit_count
        }
    finally:
        context.close()


def main():
    engine = os.getenv("BROWSER_ENGINE", "chromium")
    servers = [Fixture() for _ in range(3)]
    threads = [threading.Thread(target=s.serve_forever, daemon=True) for s in servers]
    for t in threads:
        t.start()
    checks = []
    try:
        with sync_playwright() as pw:
            browser = getattr(pw, engine).launch(headless=True)
            try:
                baseline = run_lane(browser, servers[0], "baseline")
                observed = run_lane(browser, servers[1], "instrumented")
                mutated = run_lane(browser, servers[2], "mutation-positive-control")
            finally:
                browser.close()
        def check(name, condition):
            checks.append({"name": name, "pass": bool(condition)})
            assert condition, name

        check("probe_only_in_instrumented_lane",
              not baseline["probe"] and observed["probe"])
        for stage in ("before", "after"):
            for field in ("body_dom", "a11y", "png_sha256", "counter"):
                check(f"{stage}_{field}_equivalence",
                      baseline[stage][field] == observed[stage][field])
        check("network_request_equivalence",
              baseline["requests"] == observed["requests"] and
              baseline["requests"] == [("GET", "/page"), ("POST", "/commit")])
        check("network_reply_equivalence",
              baseline["responses"] == observed["responses"] and
              baseline["responses"] == [(200, "/page"), (200, "/commit")])
        check("exactly_one_effect_per_owned_lane",
              baseline["server_commit_count"] == observed["server_commit_count"] == 1)
        check("intentionally_mutating_probe_detected",
              mutated["before"]["body_dom"] != baseline["before"]["body_dom"])
        check("nonvisual_mutation_does_not_imply_visual_change",
              mutated["before"]["png_sha256"] == baseline["before"]["png_sha256"])
        check("test_mutation_performed_no_server_commit",
              mutated["server_commit_count"] == 0)
        receipt = {
            "engine": engine, "grade": "REAL_BROWSER_OWNED_SYNTHETIC_PAIRED_OBSERVER",
            "checks": checks, "normalized_request_sequence": baseline["requests"],
            "baseline_effect_count": baseline["server_commit_count"],
            "instrumented_effect_count": observed["server_commit_count"],
            "runtime_probe_affected_dom_a11y_visual_network_or_effects": False,
            "intentional_dom_mutation_detected": True,
            "limitations": [
                "One deterministic synthetic page per engine, not a realistic human or provider HIL",
                "Byte-identical screenshots within one runner do not establish all observer perturbation is absent",
                "No credentials, identity provider, CAC, selected-tab grant, signer, or evidence promotion"
            ]
        }
        print("BP_PAIRED_OBSERVER_RECEIPT=" + json.dumps(receipt, sort_keys=True))
    finally:
        for s in servers:
            s.shutdown()
            s.server_close()
        for t in threads:
            t.join(timeout=3)


if __name__ == "__main__":
    main()
