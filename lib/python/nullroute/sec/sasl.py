from nullroute.core import Core

def sasl_gs2_escape(text):
    return text.replace("=", "=3D").replace(",", "=2C")

class MechanismFailure(Exception):
    pass

class SaslMechanism():
    def __init__(self):
        self.step = 0

    def respond(self, challenge):
        self.step += 1
        if self.step == 1 and self.client_first and challenge:
            raise MechanismFailure("unexpected initial challenge for a client-first mechanism")
        response = self._respond(challenge)
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

    def _respond(self, challenge):
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

    def _respond(self, challenge):
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

    def _respond(self, challenge):
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

        # We don't need to do any hostname canonicalization, as .canonicalize() will do that for us.
        # [imap@mail, hostbased] -> [imap/wolke@NULLROUTE, kerberos]
        # We also don't need to call it manually, either.
        #self.server_name = self.server_name.canonicalize(gssapi.MechType.kerberos)

        Core.debug("authenticating to %r", str(self.server_name))
        self.ctx = gssapi.SecurityContext(name=self.server_name, mech=gssapi.MechType.kerberos, usage="initiate")
        self.done = False

    def _respond(self, challenge):
        assert(not self.done)
        Core.trace("SASL challenge: %r", challenge)
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
            Core.debug("SASL-GSSAPI server token: %r (encrypted=%r, QoP=%r)", server_token, encrypted, qop)
            assert(len(server_token) == 4)
            # bitmask security_layers [1 byte], uint max_msg_size [3 bytes]
            # We only set bit '1' (no security layers).
            client_token = b'\x01' + b'\xFF\xFF\xFF' + (self.authz_id or "").encode("utf-8")
            Core.debug("SASL-GSSAPI client token: %r", client_token)
            response, _ = self.ctx.wrap(client_token, encrypted)
            self.done = True
        Core.trace("SASL response: %r", response)
        return response
