import email.utils
from nullroute.core import *
from nullroute.misc import set_file_attr, set_file_mtime
import os
import requests
from urllib.parse import urljoin

def _file_nonempty(path):
    try:
        return os.stat(path).st_size > 0
    except FileNotFoundError:
        return False

def _http_date_to_unix(text):
    t = email.utils.parsedate_tz(text)
    t = email.utils.mktime_tz(t)
    return t

class Scraper(object):
    def __init__(self, output_dir="."):
        self.ua = requests.Session()
        self.dir = output_dir

    def get(self, url, *args, **kwargs):
        Core.debug("fetching %r" % url, skip=1)
        r = self.ua.get(url, *args, **kwargs)
        r.raise_for_status()
        return r

    def save_file(self, url, name=None, referer=None, output_dir=None, clobber=False):
        if not name:
            name = os.path.basename(url)
        if output_dir:
            name = os.path.join(output_dir, name)

        if clobber:
            pass
        elif _file_nonempty(name):
            Core.debug("skipping %r" % url)
            return name

        hdr = {"Referer": referer or url}
        r = self.get(url, headers=hdr)
        with open(name, "wb") as fh:
            fh.write(r.content)

        set_file_attr(name, "xdg.origin.url", url)
        if referer:
            set_file_attr(name, "xdg.referrer.url", referer)
        if r.headers["ETag"]:
            set_file_attr(name, "org.eu.nullroute.ETag", r.headers["ETag"])
        if r.headers["Last-Modified"]:
            set_file_attr(name, "org.eu.nullroute.Last-Modified",
                                r.headers["Last-Modified"])
            set_file_mtime(name, _http_date_to_unix(r.headers["Last-Modified"]))
        return name
