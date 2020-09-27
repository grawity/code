# Client SASL mechanism implementations
#
# (c) Mantas Mikulėnas <grawity@gmail.com>
# Released under the MIT License <https://spdx.org/licenses/MIT>

import base64
import hashlib
import hmac
import json
from nullroute.core import Core

def sasl_gs2_escape(text):
    return text.replace("=", "=3D").replace(",", "=2C")

def base64_encode(text):
    return base64.b64encode(text).decode()

class MechanismFailure(Exception):
    pass

class TooManyStepsError(MechanismFailure):
    def __init__(self):
        super().__init__("SASL mechanism is already finished")

class SaslMechanism():
    def __init__(self):
        self.step = 0

    def respond(self, challenge):
        self.step += 1
        Core.trace("SASL challenge (#%d): %r", self.step, challenge)
        if self.step == 1 and self.client_first and challenge:
            raise MechanismFailure("unexpected initial challenge for a client-first mechanism")
        response = self.do_client_step(challenge)
        Core.trace("SASL response (#%d): %r", self.step, response)
        if response is None:
            raise MechanismFailure("unexpected step or other internal error")
        return response

    def __call__(self, challenge):
        # For compatibility with imaplib, which requires a callable.
        return self.respond(challenge)

class SaslPLAIN(SaslMechanism):
    mech_name = "PLAIN"
    client_first = True

    def __init__(self, user, password, authz_id=None):
        super().__init__()
        self.user = user
        self.password = password
        self.authz_id = authz_id

    def do_client_step(self, challenge):
        if self.step == 1:
            if challenge:
                return None
            # https://tools.ietf.org/html/rfc4616#section-2
            response = "%s\0%s\0%s" % (self.authz_id or "", self.user, self.password)
            return response.encode("utf-8")

class SaslXOAUTH2(SaslMechanism):
    mech_name = "XOAUTH2"
    client_first = True

    def __init__(self, access_token, authz_id=None):
        super().__init__()
        self.access_token = access_token
        self.authz_id = authz_id
        if not self.authz_id:
            raise MechanismFailure("Google XOAUTH2 requires an authz_id")

    def do_client_step(self, challenge):
        if self.step == 1:
            if challenge:
                return None
            # https://developers.google.com/gmail/imap/xoauth2-protocol
            http_authz = "Bearer %s" % self.access_token
            response = "user=%s\1auth=%s\1\1" % (self.authz_id, http_authz)
            return response.encode("utf-8")

class SaslOAUTHBEARER(SaslMechanism):
    mech_name = "OAUTHBEARER"
    client_first = True

    def __init__(self, access_token, authz_id=None):
        super().__init__()
        self.access_token = access_token
        self.authz_id = authz_id

    def do_client_step(self, challenge):
        if self.step == 1:
            if challenge:
                return None
            # https://tools.ietf.org/html/rfc5801#section-4
            gs2_header = "n,a=%s," % sasl_gs2_escape(self.authz_id) if self.authz_id else "n,,"
            # https://tools.ietf.org/html/rfc6750#section-2.1
            http_authz = "Bearer %s" % self.access_token
            # https://tools.ietf.org/html/rfc7628#section-3.1
            response = "%s\1auth=%s\1\1" % (gs2_header, http_authz)
            return response.encode("utf-8")
        else:
            if challenge:
                data = json.loads(challenge)
                raise MechanismFailure("error response: %r" % data)
            else:
                raise MechanismFailure("unexpected step")

class SaslGSSAPI(SaslMechanism):
    # https://tools.ietf.org/html/rfc4752
    mech_name = "GSSAPI"
    client_first = True

    SEC_NONE = 0x01             # don't wrap
    SEC_INTEGRITY = 0x02        # wrap(conf=False)
    SEC_CONFIDENTIALITY = 0x04  # wrap(conf=True)

    def __init__(self, host, service, authz_id=None):
        import gssapi

        super().__init__()
        self.server_name = gssapi.Name("%s@%s" % (service, host), gssapi.NameType.hostbased_service)
        self.authz_id = authz_id

        # We don't need to do any hostname canonicalization, as GSSAPI will do that for us.
        # [imap@mail, hostbased] -> [imap/wolke@NULLROUTE, kerberos]
        # We also don't need to call .canonicalize() manually, either.
        #self.server_name = self.server_name.canonicalize(gssapi.MechType.kerberos)

        Core.debug("authenticating to %r", str(self.server_name))
        self.ctx = gssapi.SecurityContext(name=self.server_name,
                                          mech=gssapi.MechType.kerberos,
                                          usage="initiate")
        self._done = False

    def do_client_step(self, challenge):
        if self._done:
            raise TooManyStepsError("SASL mechanism is already finished")
        if not self.ctx.complete:
            response = self.ctx.step(challenge)
            if self.ctx.complete:
                # The final call always returns None in Kerberos, though it
                # *may* return an actual response in some other mechanisms.
                response = response or b""
                Core.trace("GSSAPI: finished")
            else:
                Core.trace("GSSAPI: continue needed")
        else:
            server_token, encrypted, qop = self.ctx.unwrap(challenge)
            Core.trace("SASL-GSSAPI server token: %r (encrypted=%r, QoP=%r)", server_token, encrypted, qop)
            if len(server_token) != 4:
                raise MechanismFailure("incorrect length for SASL-GSSAPI server token")
            if not (server_token[0] & self.SEC_NONE):
                raise MechanismFailure("server doesn't support not having a SASL security layer")
            # bitmask security_layers [1 byte], uint max_msg_size [3 bytes]
            # We only set bit '1' (no security layers).
            client_token = b'\x01' + b'\xFF\xFF\xFF' + (self.authz_id or "").encode("utf-8")
            Core.trace("SASL-GSSAPI client token: %r", client_token)
            response, _ = self.ctx.wrap(client_token, encrypted)
            self._done = True
        return response

class SaslSCRAM(SaslMechanism):
    # https://tools.ietf.org/html/rfc5802
    # XXX: Completely untested.
    # XXX: see ~/Attic/Misc/2016/hacks/sasl.py
    mech_name = "SCRAM"
    client_first = True

    @staticmethod
    def _parse_attributes(buf):
        attrs = {}
        for token in buf.split(b","):
            if token[1] != b"=":
                return None
            k = token[0]
            v = token[2:]
            attrs[k] = v
        return attrs

    def __init__(self, digest, user, password, authz_id=None):
        self.user = user
        self.password = password
        self.authz_id = authz_id

        if digest == "SHA-1":
            self.mech_name = "SCRAM-SHA-1"
            self._hash_name = "sha1"
        elif digest == "SHA-256":
            self.mech_name = "SCRAM-SHA-256"
            self._hash_name = "sha256"
        else:
            raise ValueError("mechanism SCRAM-%s is not yet supported" % digest.upper())

        self._gs2_header = None
        self._nonce = None
        self._init_msg = None

    def digest(self, data):
        return hashlib.new(self._hash_name, data).digest()

    def hmac(self, data, key):
        return hmac.HMAC(key, msg=data, digestmod=self._hash_name).digest()

    def pbkdf2(self, password, salt, iter_count):
        return hashlib.pbkdf2_hmac(self._hash_name, password, salt, iter_count)

    def xor_buffer(self, a, b):
        if len(a) != len(b):
            raise ValueError("buffers have different lengths (%d vs %d)" % (len(a), len(b)))
        return bytes([a[i] ^ b[i] for i in range(len(a))])

    def do_client_step(self, challenge):
        if self.step == 1:
            if challenge:
                return None

            # https://tools.ietf.org/html/rfc5801#section-4
            gs2_header = "n,a=%s," % sasl_gs2_escape(self.authz_id) if self.authz_id else "n,,"
            # https://tools.ietf.org/html/rfc5802#section-5.1
            nonce = base64_encode(os.urandom(18))
            # https://tools.ietf.org/html/rfc5802#section-5.1
            init_msg = "n=%s,r=%s" % (sasl_gs2_escape(self.user), nonce)

            self._gs2_header = gs2_header
            self._nonce = nonce
            self._init_msg = init_msg
            return (gs2_header + init_msg).encode("utf-8")

        elif self.step == 2:
            attrs = self._parse_attributes(challenge)
            if "m" in attrs:
                raise MechanismFailure("unsupported extension attribute in SCRAM challenge")
            if not attrs.get("i"):
                raise MechanismFailure("iteration count missing from SCRAM challenge")
            if not attrs.get("r"):
                raise MechanismFailure("server nonce missing from SCRAM challenge")
            if not attrs.get("s"):
                raise MechanismFailure("salt missing from SCRAM challenge")

            s_nonce = attrs["r"]
            c_nonce = self._nonce
            if len(s_nonce) <= len(c_nonce):
                raise MechanismFailure("server nonce truncated in SCRAM challenge")
            if not s_nonce.startswith(c_nonce):
                raise MechanismFailure("server/client nonce prefix mismatch in SCRAM challenge")

            # produce client_key, server_key
            if self.password.startswith("scram:"):
                pwd = self._parse_attributes(self.password[6:])
                if pwd.get("a") != self._hash_name:
                    raise ValueError("provided SCRAM token has wrong algorithm")
                if pwd.get("s") != attrs["s"] or pwd.get("i") != attrs["i"]:
                    raise ValueError("provided SCRAM token has mismatching salt and/or itercount")
                if pwd.get("C") and pwd.get("S"):
                    client_key = base64.b64decode(pwd["C"])
                    server_key = base64.b64decode(pwd["S"])
                elif pwd.get("H"):
                    salted_password = base64.b64decode(pwd["H"])
                    client_key = self.hmac(b"Client Key", key=salted_password)
                    server_key = self.hmac(b"Server Key", key=salted_password)
                else:
                    raise ValueError("provided SCRAM token is missing required attributes")
            else:
                s_salt = attrs["s"]
                if not s_salt:
                    raise MechanismFailure("server sent invalid salt in SCRAM challenge")

                try:
                    s_iter = int(attrs["i"])
                except:
                    raise MechanismFailure("server sent invalid iteration count in SCRAM challenge")
                if not (500 <= s_iter <= 65535):
                    raise MechanismFailure("server sent unsupported iteration count in SCRAM challenge")

                salted_password = self.pbkdf2(self.password, s_salt, s_iter)
                client_key = self.hmac(b"Client Key", key=salted_password)
                server_key = self.hmac(b"Server Key", key=salted_password)
                # XXX: I am still undecided as to whether C/S or the original H should be cached;
                #      the spec allows doing it either way, and differences in security are
                #      unclear to me.
                #self.password = "scram:a=%s,s=%s,i=%s,H=%s" % (self._hash_name,
                #                                               s_salt,
                #                                               s_iter,
                #                                               base64_encode(salted_password))
                self.password = "scram:a=%s,s=%s,i=%s,C=%s,S=%s" % (self._hash_name,
                                                                    s_salt,
                                                                    s_iter,
                                                                    base64_encode(client_key),
                                                                    base64_encode(server_key))
                # Note: This is an entirely proprietary 'token' format, previously invented for
                # my Tcl SCRAM implementation (g_scram.tcl) but not used by anything else.

            gs2_header = self._gs2_header
            c_init_msg = self._init_msg
            s_first_msg = challenge
            c_final_msg_bare = "c=%s,r=%s" % (base64_encode(gs2_header), nonce)
            auth_msg = "%s,%s,%s" % (c_init_msg, s_first_msg, c_final_msg_bare)

            stored_key = self.digest(client_key)
            client_sig = self.hmac(auth_msg, key=stored_key)
            server_sig = self.hmac(auth_msg, key=server_key)

            client_proof = self.xor_buffer(client_key, client_sig)
            c_final_msg = "%s,p=%s" % (c_final_msg_bare, base64_encode(client_proof))

            self._server_sig = server_sig
            return c_final_msg.encode("utf-8")

        elif self.step == 3:
            if not challenge:
                raise MechanismFailure()

            attrs = self._parse_attributes(challenge)
            if "e" in attrs:
                raise MechanismFailure("server returns authentication error %r" % attrs["e"])
            if "m" in attrs:
                raise MechanismFailure("unsupported extension attribute in SCRAM challenge")
            if not attrs.get("v"):
                raise MechanismFailure("server verifier missing from challenge")

            s_verifier = base64.b64decode(attrs["v"])
            server_sig = self._server_sig
            if s_verifier != server_sig:
                raise MechanismFailure("received server signature does not match computed")
            return b""
        else:
            raise TooManyStepsError()
