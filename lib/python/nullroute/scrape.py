import email.utils
import http.cookiejar
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

def file_ext(url):
    # throw away HTTP query, anchor
    if "#" in url:
        url = url.split("#")[0]
    if "?" in url:
        url = url.split("?")[0]
    # default for directories
    if url.endswith("/"):
        return "html"
    # get the basename
    url = url.split("/")[-1]
    url = url.split(".")
    if len(url) >= 3 and url[-2] == "tar":
        return url[-2] + "." + url[-1]
    elif len(url) >= 2:
        return url[-1]
    else:
        return "bin"

class Scraper(object):
    def __init__(self, output_dir="."):
        self.dir = output_dir
        os.makedirs(self.dir, exist_ok=True)

        self.ua = requests.Session()
        self.ua.mount("http://", requests.adapters.HTTPAdapter(max_retries=3))
        self.ua.mount("https://", requests.adapters.HTTPAdapter(max_retries=3))

        self.subclass_init()

    def subclass_init(self):
        pass

    def load_cookies(self, name):
        path = Env.find_cache_file("cookies/%s.txt" % name)
        Core.debug("loading cookies from %r" % path)
        cjar = http.cookiejar.LWPCookieJar(path)
        try:
            cjar.load()
        except FileNotFoundError:
            os.makedirs(os.path.dirname(path), exist_ok=True)
        self.ua.cookies = cjar

    def store_cookies(self):
        self.ua.cookies.save()

    def get(self, url, *args, **kwargs):
        Core.debug("fetching %r" % url, skip=1)
        resp = self.ua.get(url, *args, **kwargs)
        resp.raise_for_status()
        return resp

    def save_file(self, url, name=None, referer=None,
                             output_dir=None, clobber=False,
                             save_msg=None):
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
        if r.headers.get("ETag"):
            set_file_attr(name, "org.eu.nullroute.ETag", r.headers["ETag"])
        if r.headers.get("Last-Modified"):
            set_file_attr(name, "org.eu.nullroute.Last-Modified",
                                r.headers["Last-Modified"])
            set_file_mtime(name, _http_date_to_unix(r.headers["Last-Modified"]))

        if save_msg:
            Core.info(save_msg)
        return name
