def sasl_gs2_escape(text):
    return text.replace("=", "=3D").replace(",", "=2C")

class MechanismFailure(Exception):
    pass

class SaslMechanism():
    def __init__(self):
        self.step = 0

    def respond(self, challenge):
        self.step += 1
        response = self._respond(challenge)
        if response is None:
            raise MechanismFailure("unexpected step or other internal error")
        return response

class SaslPLAIN(SaslMechanism):
    def __init__(self, user, password, authzid=None):
        super().__init__()
        self.user = user
        self.password = password
        self.authzid = authzid

    def _respond(self, challenge):
        if self.step == 1:
            if challenge:
                return None
            # https://tools.ietf.org/html/rfc4616#section-2
            response = "%s\0%s\0%s" % (self.authzid or "", self.user, self.password)
            return response.encode("utf-8")

class SaslXOAUTH2(SaslMechanism):
    def __init__(self, access_token, authzid=None):
        super().__init__()
        self.access_token = access_token
        self.authzid = authzid
        if not self.authzid:
            raise MechanismFailure("Google XOAUTH2 requires an authzid")

    def _respond(self, challenge):
        if self.step == 1:
            if challenge:
                return None
            # https://developers.google.com/gmail/imap/xoauth2-protocol
            http_authz = "Bearer %s" % self.access_token
            response = "user=%s\1auth=%s\1\1" % (self.authzid, http_authz)
            return response.encode("utf-8")

class SaslOAUTHBEARER(SaslMechanism):
    def __init__(self, access_token, authzid=None):
        super().__init__()
        self.access_token = access_token
        self.authzid = authzid

    def _respond(self, challenge):
        if self.step == 1:
            if challenge:
                return None
            # https://tools.ietf.org/html/rfc5801#section-4
            gs2_header = "n,a=%s," % sasl_gs2_escape(self.authzid) if self.authzid else "n,,"
            # https://tools.ietf.org/html/rfc6750#section-2.1
            http_authz = "Bearer %s" % self.access_token
            # https://tools.ietf.org/html/rfc7628#section-3.1
            response = "%s\1auth=%s\1\1" % (gs2_header, http_authz)
            return response.encode("utf-8")
