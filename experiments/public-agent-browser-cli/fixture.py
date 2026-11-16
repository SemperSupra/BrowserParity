"""Synthetic localhost portal for donor CLI testing: no real accounts or secrets."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        label = "Alpha" if path == "/alpha" else "Beta" if path == "/beta" else None
        if path == "/session/login":
            self.send_response(200)
            self.send_header("Set-Cookie","bp_fixture=ok; HttpOnly; SameSite=Lax; Path=/")
            result = "<h1>SYNTHETIC_APPROVED</h1>"
        elif path == "/session/status":
            self.send_response(200)
            if "bp_fixture=ok" in self.headers.get("Cookie", ""):
                result = "<h1>SYNTHETIC_READY</h1>"
            else:
                result = "<h1>SYNTHETIC_AUTH_REQUIRED</h1>"
        elif label:
            self.send_response(200)
            result = f"""<h1>Owned {label} Tab</h1>
<button id="act">Increment</button><output id="counter" aria-live="polite">0</output>
<script>document.querySelector('#act').onclick=()=>{{const x=document.querySelector('#counter'); x.textContent=String(+x.textContent+1)}};</script>"""
        else:
            self.send_error(404)
            return
        payload=("<!doctype html><html lang='en'><body><main>"+result+"</main></body></html>").encode()
        self.send_header("Content-Type","text/html; charset=utf-8")
        self.send_header("Cache-Control","no-store")
        self.send_header("Content-Length",str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args):
        pass

server=ThreadingHTTPServer(("127.0.0.1",0),Handler)
print("http://127.0.0.1:"+str(server.server_port),flush=True)
server.serve_forever()
