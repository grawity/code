import json
from nullroute.core import Core, Env
import nullroute.sec

class PersistentAuthBase():
    TOKEN_SCHEMA = None
    TOKEN_NAME = None
    TOKEN_DOMAIN = None
    TOKEN_PATH = None

    def _load_token(self):
        try:
            data = nullroute.sec.get_libsecret({"xdg:schema": self.TOKEN_SCHEMA,
                                                "domain": self.TOKEN_DOMAIN})
            Core.debug("found %s in keyring", self.TOKEN_NAME)
            return json.loads(data)
        except KeyError:
            if self.TOKEN_PATH:
                try:
                    with open(self.TOKEN_PATH, "r") as fh:
                        data = json.load(fh)
                    Core.debug("found %s in filesystem", self.TOKEN_NAME)
                    return data
                except FileNotFoundError:
                    pass
                except Exception as e:
                    Core.debug("could not load %r: %r", self.TOKEN_PATH, e)
                    self._forget_token()
        return None

    def _store_token(self, data, extra=None):
        extra = (extra or {})
        Core.debug("storing %s in keyring", self.TOKEN_NAME)
        nullroute.sec.store_libsecret(self.TOKEN_NAME,
                                      json.dumps(data),
                                      {"xdg:schema": self.TOKEN_SCHEMA,
                                       "domain": self.TOKEN_DOMAIN,
                                       **extra})
        if self.TOKEN_PATH:
            Core.debug("storing %s in filesystem", self.TOKEN_NAME)
            try:
                with open(self.TOKEN_PATH, "w") as fh:
                    json.dump(data, fh)
            except Exception as e:
                Core.warn("could not write %r: %r", self.TOKEN_PATH, e)
                return False
        return True

    def _forget_token(self):
        Core.debug("flushing auth tokens")
        nullroute.sec.clear_libsecret({"xdg:schema": self.TOKEN_SCHEMA,
                                       "domain": self.TOKEN_DOMAIN})
        if self.TOKEN_PATH:
            os.unlink(self.TOKEN_PATH)
