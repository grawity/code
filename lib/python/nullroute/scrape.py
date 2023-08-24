import email.message
import email.utils
import http.cookiejar
from nullroute.core import Core, Env
from nullroute.file import set_file_attrs, set_file_mtime
from nullroute.ui.progressbar import ProgressBar
import os
import requests
from urllib.parse import urljoin

def _file_nonempty(path):
    try:
        return os.stat(path).st_size > 0
    except FileNotFoundError:
        return False

def _fmt_params(d):
    if d:
        return "?" + "&".join(["%s=%s" % (k, v) for (k, v) in sorted(d.items())])
    else:
        return ""

def _http_date_to_unix(text):
    t = email.utils.parsedate_tz(text)
    t = email.utils.mktime_tz(t)
    return t

def _http_header_param(hdr, param, default=None):
    #email.utils.decode_rfc2231(...)
    msg = email.message.Message()
    msg.set_raw("dummy", hdr)
    val = msg.get_param(param, default, "dummy")
    if type(val) == tuple:
        val = email.utils.collapse_rfc2231_value(val)
    return val

def file_ext_from_url(url):
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

def _progress_bar(iterable, max_bytes, chunk_size, *, hide_complete=True):
    bar = ProgressBar(max_value=max_bytes)
    bar.incr(0)
    for i in iterable:
        yield i
        bar.incr(len(i))
    bar.end(hide_complete)

class Scraper(object):
    def __init__(self, output_dir="."):
        self.dir = output_dir
        if self.dir:
            os.makedirs(self.dir, exist_ok=True)

        self.ua = requests.Session()
        self.ua.mount("http://", requests.adapters.HTTPAdapter(max_retries=3))
        self.ua.mount("https://", requests.adapters.HTTPAdapter(max_retries=3))
        # unfortunately case-sensitive
        # https://www.modpagespeed.com/doc/experiment
        # currently only used by GamerCat scraper
        self.ua.headers["PageSpeed"] = "off"
        #self.ua.headers["X-PSA-Client-Options"] = "m=1"

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
        Core.debug("fetching %r",
                   url + _fmt_params(kwargs.get("params")),
                   skip=1)
        resp = self.ua.get(url, *args, **kwargs)
        resp.raise_for_status()
        return resp

    def get_page(self, url, *args, **kwargs):
        import bs4
        Core.debug("fetching %r",
                   url + _fmt_params(kwargs.get("params")),
                   skip=1)
        resp = self.ua.get(url, *args, **kwargs)
        resp.raise_for_status()
        page = bs4.BeautifulSoup(resp.content, "lxml")
        return page

    def save_file(self, url,
                        name=None,
                        referer=None,
                        output_dir=None, clobber=False,
                        progress=False, save_msg=None,
                        keep_name=False, keep_mtime=False):

        # TODO: I'm not sure if it's safe to allow guessing the name from URL, so
        #       let's first check if we have any callers like this.
        if not (name or keep_name):
            raise Exception("save_file() wasn't given a 'name=', check if this is OK")

        # TODO: I suspect that if 'name' is a path, then keep_name will choose the
        #       wrong output directory, so check if we ever call it like that
        #       (even if the caller doesn't use keep_name).
        if name and "/" in name:
            raise Exception("save_file() was given a path in 'name=', check if this is OK")

        # Guess file name from URL (TODO: if we forbid name=None, this can be simplified)
        file_name = name or os.path.basename(url)
        file_name = file_name.strip(". ")
        if output_dir:
            output_file = os.path.join(output_dir, file_name)
        else:
            output_file = file_name

        if not clobber:
            if keep_name:
                # Might be worth checking later? But for sites like Dynasty,
                # it will still consume a download count so who cares.
                raise ValueError("keep_name only works with clobber")

            if _file_nonempty(output_file):
                Core.debug("skipping %r as local file exists" % url)
                return output_file

        hdr = {"Referer": referer or url}
        resp = self.get(url, headers=hdr, stream=True)

        if keep_name:
            hdr = resp.headers.get("content-disposition")
            if hdr:
                Core.trace("getting original name from content disposition: %r", hdr)
                file_name = _http_header_param(hdr, "filename")
            else:
                Core.trace("content disposition header not present")

            if file_name:
                Core.trace("got original name: %r", file_name)
                file_name = os.path.basename(file_name)
                file_name = file_name.strip(". ")
                if type(keep_name) == str:
                    file_name = keep_name % (file_name,)
                if output_dir:
                    output_file = os.path.join(output_dir, file_name)
                else:
                    output_file = file_name
            else:
                raise Exception("with keep_name, could not determine original name")

        output_part = output_file + ".part"

        with open(output_part, "wb") as fh:
            if progress:
                num_bytes = resp.headers.get("content-length")
                if num_bytes is not None:
                    num_bytes = int(num_bytes)
                chunk_size = 1024
                for chunk in _progress_bar(resp.iter_content(chunk_size),
                                           max_bytes=num_bytes,
                                           chunk_size=chunk_size):
                    fh.write(chunk)
            else:
                chunk_size = 65536
                for chunk in resp.iter_content(chunk_size):
                    fh.write(chunk)

        set_file_attrs(output_part, {
            "xdg.origin.url": resp.url,
            "xdg.referrer.url": resp.request.headers.get("Referer"),
            "http.ETag": resp.headers.get("ETag"),
            "http.Last-Modified": resp.headers.get("Last-Modified"),
        })

        if keep_mtime:
            if mtime := resp.headers.get("Last-Modified"):
                set_file_mtime(output_part, _http_date_to_unix(mtime))

        os.rename(output_part, output_file)

        if save_msg is True:
            Core.info("saved '%s'", output_file)
        elif save_msg:
            Core.info(save_msg)

        return output_file
