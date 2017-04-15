import hashlib
import json
import os
import time
import xdg.BaseDirectory

class JsonCache(object):
    cache_dir = xdg.BaseDirectory.save_cache_path("nullroute.eu.org/url")

    def __init__(self, expiry=0):
        self.expiry = expiry or 86400

    def get_path(self, name):
        name = hashlib.sha1(name.encode("utf-8")).hexdigest()
        return os.path.join(self.cache_dir, "%s.json" % name)

    def load(self, name):
        path = self.get_path(name)
        try:
            with open(path, "r") as fh:
                package = json.load(fh)
            if package.get("expire", 0) >= time.time():
                return package["data"]
            else:
                os.unlink(path)
        except FileNotFoundError:
            pass
        return None

    def save(self, name, data):
        path = self.get_path(name)
        package = {
            "source": name,
            "obtain": time.time(),
            "expire": time.time() + self.expiry,
            "data": data,
        }
        with open(path, "w") as fh:
            json.dump(package, fh)

    def drop(self):
        os.unlink(self.get_path())
