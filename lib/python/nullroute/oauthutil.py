import errno
import http.server
import random
import urllib.parse

class OneshotHTTPServer():
    def __init__(self):
        self.port = None
        self.url = None
        self.server = None
        self.code = None

    def bind(self):
        class handler(http.server.BaseHTTPRequestHandler):
            parent = self

            def log_request(self, *args):
                pass

            def do_GET(self):
                u = urllib.parse.urlsplit(self.path)
                if u.path == "/":
                    query = urllib.parse.parse_qs(u.query)
                    if "code" in query:
                        self.parent.code = query["code"][0]
                        rcode, rtext = 200, "Code received\n"
                    else:
                        rcode, rtext = 400, "Missing 'code=' parameter\n"
                else:
                    rcode, rtext = 404, "Not found\n"

                self.send_response(rcode)
                self.end_headers()
                self.wfile.write(rtext.encode())
                self.wfile.flush()

        while True:
            self.port = random.randrange(49152, 65535)
            try:
                self.server = http.server.HTTPServer(("127.0.0.1", self.port), handler)
            except OSError as e:
                if e.errno == errno.EADDRINUSE:
                    continue
                raise
            self.url = "http://localhost:%d" % self.port
            return self.url

    def wait_for_code(self):
        while not self.code:
            self.server.handle_request()
        self.server.server_close()
        return self.code
