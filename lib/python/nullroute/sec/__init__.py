import json
import subprocess

from nullroute.core import Core

def store_libsecret(label, secret, attributes):
    Core.trace("libsecret store: %r %r", label, attributes)
    cmd = ["secret-tool", "store", "--label=%s" % label]
    for k, v in attributes.items():
        cmd += [str(k), str(v)]

    r = subprocess.run(cmd, input=secret.encode(),
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    if r.returncode != 0:
        raise IOError("libsecret store failed: (%r, %r)" % (r.returncode,
                                                            r.stderr.decode()))

def get_libsecret(attributes):
    Core.trace("libsecret query: %r", attributes)
    cmd = ["secret-tool", "lookup"]
    for k, v in attributes.items():
        cmd += [str(k), str(v)]

    r = subprocess.run(cmd, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    if r.returncode != 0:
        raise KeyError("libsecret lookup failed: %r" % r.stderr.decode())

    return r.stdout.decode()

def clear_libsecret(attributes):
    Core.trace("libsecret clear: %r", attributes)
    cmd = ["secret-tool", "clear"]
    for k, v in attributes.items():
        cmd += [str(k), str(v)]

    r = subprocess.run(cmd, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    if r.returncode != 0:
        raise KeyError("libsecret clear failed: %r" % r.stderr.decode())

class TokenCache(object):
    TOKEN_SCHEMA = "org.eu.nullroute.BearerToken"
    TOKEN_PROTO = "cookie"
    TOKEN_NAME = "Auth token for %s"

    def __init__(self, domain, display_name=None, user_name=None):
        self.domain = domain
        self.display_name = display_name or domain
        self.user_name = user_name
        self.match_fields = {"xdg:schema": self.TOKEN_SCHEMA,
                             "protocol": self.TOKEN_PROTO,
                             "domain": self.domain}
        if self.user_name:
            self.match_fields = {**self.match_fields,
                                 "username": self.user_name}

    def load_token(self):
        Core.debug("loading auth token for %r", self.domain)
        try:
            Core.trace("trying to load token from libsecret: %r", self.match_fields)
            data = get_libsecret(self.match_fields)
            Core.trace("loaded token: %r", data)
            return json.loads(data)
        except KeyError:
            Core.debug("not found in libsecret")
            return None

    def store_token(self, data):
        Core.debug("storing auth token for %r", self.domain)
        try:
            store_libsecret(self.TOKEN_NAME % self.display_name,
                            json.dumps(data),
                            self.match_fields)
        except Exception as e:
            Core.debug("could not access libsecret: %r", e)

    def forget_token(self):
        Core.debug("flushing auth tokens for %r", self.domain)
        clear_libsecret(self.match_fields)

class OAuthTokenCache(TokenCache):
    TOKEN_SCHEMA = "org.eu.nullroute.OAuthToken"
    TOKEN_PROTO = "oauth"
    TOKEN_NAME = "OAuth token for %s"

def get_netrc(machine, login=None, service=None):
    if service:
        machine = "%s/%s" % (service, machine)

    keys = ["%m", "%l", "%p", "%a"]
    cmd = ["getnetrc", "-d", "-n", "-f", "\n".join(keys), machine]
    if login:
        cmd.append(login)

    r = subprocess.run(cmd, stdout=subprocess.PIPE)
    if r.returncode != 0:
        raise KeyError("~/.netrc lookup for %r failed" % machine)

    keys = ["machine", "login", "password", "account"]
    vals = r.stdout.decode().split("\n")
    if len(keys) != len(vals):
        raise IOError("'getnetrc' returned weird data %r" % r)

    return dict(zip(keys, vals))

def get_netrc_service(machine, service, **kw):
    return get_netrc("%s/%s" % (service, machine), **kw)

def seal_windpapi(secret: bytes, entropy=None) -> bytes:
    import win32crypt
    sealed = win32crypt.CryptProtectData(secret,
                                         None, # description
                                         entropy,
                                         None, # reserved
                                         None, # prompt
                                         0x01) # flags
    return sealed

def unseal_windpapi(sealed: bytes, entropy=None) -> bytes:
    import win32crypt
    (desc, secret) = win32crypt.CryptUnprotectData(sealed,
                                                   entropy,
                                                   None, # reserved
                                                   None, # prompt
                                                   0x01) # flags
    return secret
