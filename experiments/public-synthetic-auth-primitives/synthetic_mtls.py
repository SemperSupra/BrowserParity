"""Synthetic local TLS client-certificate qualification only.

Generate disposable test CA/server/client certificates in an isolated runner,
exercise real Chromium -> HTTPS client-certificate challenge, and verify an
unconfigured/foreign browser context is denied. No CAC/PIV, PIN, DoD cert,
hardware private-key extraction, real domain or user session.
"""
import http.server
import json
import os
import ssl
import subprocess
import tempfile
import threading
from pathlib import Path

from playwright.sync_api import Error as PlaywrightError
from playwright.sync_api import sync_playwright


def openssl(*args):
    subprocess.run(["openssl", *map(str, args)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def make_ca(root, name):
    stem = root / name
    openssl("req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
            "-subj", f"/CN={name}", "-keyout", stem.with_suffix(".key"),
            "-out", stem.with_suffix(".crt"))
    return stem


def make_leaf(root, ca, name, eku, san=None):
    stem = root / name
    openssl("req", "-newkey", "rsa:2048", "-nodes",
            "-subj", f"/CN={name}", "-keyout", stem.with_suffix(".key"),
            "-out", stem.with_suffix(".csr"))
    ext = stem.with_suffix(".ext")
    lines = ["basicConstraints=CA:FALSE", "keyUsage=digitalSignature,keyEncipherment",
             f"extendedKeyUsage={eku}"]
    if san:
        lines.append("subjectAltName=DNS:localhost,IP:127.0.0.1")
    ext.write_text("\n".join(lines) + "\n", encoding="ascii")
    openssl("x509", "-req", "-sha256", "-days", "1",
            "-in", stem.with_suffix(".csr"), "-CA", ca.with_suffix(".crt"),
            "-CAkey", ca.with_suffix(".key"), "-CAcreateserial",
            "-extfile", ext, "-out", stem.with_suffix(".crt"))
    return stem


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        peer = self.connection.getpeercert()
        subject = dict(item[0] for item in peer.get("subject", ())) if peer else {}
        approved = subject.get("commonName") == "BP-SYNTHETIC-CLIENT"
        body = ("SYNTHETIC_MTLS_APPROVED" if approved else "SYNTHETIC_MTLS_REJECTED").encode()
        self.send_response(200 if approved else 403)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def denied(browser, url, cert=None):
    options = {"ignore_https_errors": True}
    if cert is not None:
        options["client_certificates"] = [{
            "origin": url,
            "certPath": str(cert.with_suffix(".crt")),
            "keyPath": str(cert.with_suffix(".key")),
        }]
    ctx = browser.new_context(**options)
    try:
        page = ctx.new_page()
        try:
            response = page.goto(url, wait_until="load", timeout=12000)
            return response is None or response.status != 200 or "SYNTHETIC_MTLS_APPROVED" not in page.locator("body").inner_text()
        except PlaywrightError:
            return True
    finally:
        ctx.close()


def main():
    with tempfile.TemporaryDirectory(prefix="bp-public-synthetic-mtls-") as tmp:
        root = Path(tmp)
        ca = make_ca(root, "BP-SYNTHETIC-CA")
        server_cert = make_leaf(root, ca, "localhost", "serverAuth", san=True)
        client_cert = make_leaf(root, ca, "BP-SYNTHETIC-CLIENT", "clientAuth")
        wrongca = make_ca(root, "BP-FOREIGN-CA")
        wrong_cert = make_leaf(root, wrongca, "BP-SYNTHETIC-CLIENT", "clientAuth")

        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        tls.load_cert_chain(str(server_cert.with_suffix(".crt")), str(server_cert.with_suffix(".key")))
        tls.load_verify_locations(cafile=str(ca.with_suffix(".crt")))
        tls.verify_mode = ssl.CERT_REQUIRED
        server.socket = tls.wrap_socket(server.socket, server_side=True)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        url = "https://localhost:" + str(server.server_address[1])
        receipt = {"grade": "SYNTHETIC_MTLS_BROWSER_HIL", "browser": "chromium",
                   "real_cac": False, "real_private_key_extraction": False,
                   "tests": []}
        try:
            with sync_playwright() as pw:
                browser = pw.chromium.launch(headless=True)
                try:
                    no_cert = denied(browser, url)
                    assert no_cert, "browser without configured client certificate unexpectedly authenticated"
                    receipt["tests"].append("PASS:no_certificate_denied")
                    foreign = denied(browser, url, wrong_cert)
                    assert foreign, "foreign test CA unexpectedly authenticated"
                    receipt["tests"].append("PASS:foreign_ca_denied")
                    ctx = browser.new_context(ignore_https_errors=True, client_certificates=[{
                        "origin": url,
                        "certPath": str(client_cert.with_suffix(".crt")),
                        "keyPath": str(client_cert.with_suffix(".key")),
                    }])
                    try:
                        page = ctx.new_page()
                        response = page.goto(url, timeout=12000)
                        assert response is not None and response.status == 200
                        assert page.locator("body").inner_text() == "SYNTHETIC_MTLS_APPROVED"
                        receipt["tests"].append("PASS:configured_client_certificate_accepted")
                    finally:
                        ctx.close()
                    again = denied(browser, url)
                    assert again, "client cert was reused across unrelated browser context"
                    receipt["tests"].append("PASS:client_cert_context_isolation")
                finally:
                    browser.close()
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)
        print("BP_MTLS_RECEIPT=" + json.dumps(receipt, sort_keys=True))


if __name__ == "__main__":
    main()
