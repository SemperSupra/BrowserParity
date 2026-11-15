"""Public-source-only synthetic browser benchmark; never contacts real providers.

Evidence grade: SYNTHETIC_BROWSER. This exercises actual browser engines and a
reference grant oracle, NOT a vendor MCP's authorization, real MFA, or CAC HIL.
"""
import http.server
import os
import threading
import unittest
from urllib.parse import urlsplit

from playwright.sync_api import sync_playwright


FIXTURE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Public synthetic fixture</title></head>
<body><main><h1>Owned synthetic tab</h1>
<button id="increment">Increment</button>
<output id="counter" aria-live="polite">0</output>
<script>
let count = 0;
document.getElementById('increment').addEventListener('click', () => {
  document.getElementById('counter').textContent = String(++count);
});
</script>
</main></body></html>"""


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        route = self.path.split("?")[0]
        if route in ("/one", "/two", "/foreign"):
            payload = FIXTURE.encode()
        elif route == "/auth":
            payload = ("""<!doctype html><html lang="en"><body>
                <form action="/login" method="post">
                <button type="submit">Synthetic sign in</button></form>
                </body></html>""").encode()
        elif route == "/signed-in":
            authorized = "session=synthetic-only" in self.headers.get("Cookie", "")
            payload = ("AUTH_OK" if authorized else "AUTH_REQUIRED").encode()
        else:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_POST(self):
        if self.path != "/login":
            self.send_error(404)
            return
        self.send_response(303)
        self.send_header("Location", "/signed-in")
        self.send_header("Set-Cookie", "session=synthetic-only; HttpOnly; SameSite=Lax; Path=/")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, fmt, *args):
        return


class RefGrant:
    """Test-only reference oracle, NOT the BrowserParity production policy."""

    def __init__(self, page, actor, origin, generation=1):
        self.page = page
        self.actor = actor
        self.origin = origin
        self.generation = generation
        self.revoked = False

    def allows(self, page, actor, generation):
        parsed = urlsplit(page.url)
        origin = f"{parsed.scheme}://{parsed.hostname}:{parsed.port}"
        return (not self.revoked and page is self.page
                and actor == self.actor and generation == self.generation
                and origin == self.origin)


class BrowserSynthetic(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.servers = []
        for _ in range(2):
            server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            cls.servers.append((server, thread))
        cls.home = f"http://127.0.0.1:{cls.servers[0][0].server_address[1]}"
        cls.other = f"http://127.0.0.1:{cls.servers[1][0].server_address[1]}"

    @classmethod
    def tearDownClass(cls):
        for server, thread in cls.servers:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)

    def setUp(self):
        self.pw = sync_playwright().start()
        engine = os.getenv("BROWSER_ENGINE", "chromium")
        self.browser = getattr(self.pw, engine).launch(headless=True)

    def tearDown(self):
        self.browser.close()
        self.pw.stop()

    def test_real_browser_two_tabs_and_accessibility_feedback(self):
        ctx = self.browser.new_context()
        selected, adjacent = ctx.new_page(), ctx.new_page()
        selected.goto(self.home + "/one")
        adjacent.goto(self.home + "/two")
        selected.get_by_role("button", name="Increment").click()
        self.assertEqual(selected.locator("#counter").inner_text(), "1")
        self.assertEqual(adjacent.locator("#counter").inner_text(), "0")
        self.assertEqual(selected.locator("#counter").get_attribute("aria-live"), "polite")
        ctx.close()

    def test_selected_tab_grant_fails_closed_across_context_and_revocation(self):
        ctx = self.browser.new_context()
        selected, adjacent = ctx.new_page(), ctx.new_page()
        selected.goto(self.home + "/one")
        adjacent.goto(self.home + "/two")
        grant = RefGrant(selected, actor="actor-a", origin=self.home)
        self.assertTrue(grant.allows(selected, "actor-a", 1))
        self.assertFalse(grant.allows(adjacent, "actor-a", 1))
        self.assertFalse(grant.allows(selected, "actor-b", 1))
        self.assertFalse(grant.allows(selected, "actor-a", 2))
        selected.goto(self.other + "/foreign")
        self.assertFalse(grant.allows(selected, "actor-a", 1))
        selected.goto(self.home + "/one")
        grant.revoked = True
        self.assertFalse(grant.allows(selected, "actor-a", 1))
        ctx.close()

    def test_synthetic_login_shared_in_context_not_other_context(self):
        shared = self.browser.new_context()
        page = shared.new_page()
        page.goto(self.home + "/auth")
        page.get_by_role("button", name="Synthetic sign in").click()
        self.assertIn("/signed-in", page.url)
        self.assertEqual(page.locator("body").inner_text(), "AUTH_OK")
        neighboring = shared.new_page()
        neighboring.goto(self.home + "/signed-in")
        self.assertEqual(neighboring.locator("body").inner_text(), "AUTH_OK")
        independent = self.browser.new_context()
        independent_page = independent.new_page()
        independent_page.goto(self.home + "/signed-in")
        self.assertEqual(independent_page.locator("body").inner_text(), "AUTH_REQUIRED")
        independent.close()
        shared.close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
