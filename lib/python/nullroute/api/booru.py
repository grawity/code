import bs4
from collections import defaultdict
from functools import lru_cache
import lxml.etree
from nullroute.core import *
from pprint import pprint
import re
import requests

FAKE_UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.84 Safari/537.36"

def _grep(pat, strings):
    pat = re.compile(pat)
    for string in strings:
        m = re.match(pat, string)
        if m:
            return m.group(1)
    raise IndexError("inputs %r do not match %r" % (strings, pat))

def _strip_suffixes(arg, sfs):
    for sf in sfs:
        if arg.endswith(sf):
            return arg[:-len(sf)]
    return arg

class BooruApi(object):
    NAME_RES = []
    URL_RES = []

    def __init__(self, tag_filter=None):
        self.tag_filter = tag_filter
        self.ua = requests.Session()

    def match_file_name(self, name):
        for pat in self.NAME_RE:
            m = pat.match(name)
            if m:
                return m.group("id") or m.group(1)

    def match_post_url(self, url):
        for pat in self.URL_RE:
            m = pat.match(url)
            if m:
                return m.group("id") or m.group(1)

    def find_posts(self, tags, page=1, limit=100):
        ...

    def find_posts_by_md5(self, md5):
        yield from self.find_posts("md5:%s" % md5)

    def get_post_tags(self, post_id):
        ...

    def get_post_tags_sorted(self, post_id):
        raw_tags = self.get_post_tags(post_id)
        all_tags = []

        for k in ("artist", "copyright", "character"):
            k_tags = raw_tags[k]
            if k == "character" and len(k_tags) <= 2:
                bad_suffixes = [" (%s)" % s for s in raw_tags["copyright"]]
                k_tags = [_strip_suffixes(t, bad_suffixes) for t in k_tags]
            all_tags += sorted(k_tags)

        if self.tag_filter:
            all_tags = self.tag_filter.filter(all_tags)

        return all_tags

## Danbooru

class DanbooruApi(BooruApi):
    SITE_URL = "https://danbooru.donmai.us"
    ID_PREFIX = "db%s"
    TAG_SCRAPE = False

    def find_posts(self, tags, page=1, limit=100):
        ep = "/posts.xml"
        args = {"tags": tags,
                "page": page,
                "limit": limit}

        resp = self.ua.get(self.SITE_URL + ep, params=args)
        resp.raise_for_status()

        tree = lxml.etree.XML(resp.content)
        for item in tree.xpath("/posts/post"):
            attrib = {}
            for child in item.iterchildren():
                key = child.tag.replace("-", "_")
                nil = child.attrib.get("nil")
                type = child.attrib.get("type")
                value = child.text
                if not nil:
                    if key.startswith("tag_string"):
                        key = key.replace("tag_string", "tags")
                        value = set(value.split() if value else [])
                    elif type == "boolean":
                        value = bool(value == "true")
                attrib[key] = value
            yield attrib

## Gelbooru

class GelbooruApi(BooruApi):
    API_ROOT = "http://gelbooru.com/index.php"
    ID_PREFIX = "g%s"
    TAG_SCRAPE = True

    def find_posts(self, tags, limit=100):
        args = {"page": "dapi",
                "s": "post",
                "q": "index",
                "tags": tags,
                "limit": limit}

        resp = self.ua.get(self.API_ROOT, params=args)
        resp.raise_for_status()

        tree = lxml.etree.XML(resp.content)
        for item in tree.xpath("/posts/post"):
            yield dict(item.attrib)

    def _scrape_post_info(self, post_id):
        args = {"page": "post",
                "s": "view",
                "id": post_id}

        resp = self.ua.get(self.API_ROOT, params=args)
        resp.raise_for_status()

        page = bs4.BeautifulSoup(resp.content, "lxml")
        sidebar = page.select_one("ul#tag-sidebar")

        post = {"id": post_id,
                "tags": defaultdict(set)}

        for tag_li in sidebar.find_all("li"):
            tag_type = tag_li["class"][0]
            tag_type = strip_prefix(tag_type, "tag-type-")

            tag_link = tag_li.find_all("a")[-1]
            tag_value = tag_link.get_text()

            post["tags"][tag_type].add(tag_value)

        return post

## Sankaku Complex

class SankakuApi(BooruApi):
    SITE_URL = "https://chan.sankakucomplex.com"
    POST_URL = "https://chan.sankakucomplex.com/post/show/%s"
    URL_RE = [
        re.compile(r"^https://chan\.sankakucomplex\.com/post/show/(?P<id>\d+)"),
        re.compile(r"^https://cs\.sankakucomplex\.com/data/\w+/\w+/(?P<md5>\w+)\.\w+\?(?P<id>\d+)"),
    ]
    ID_PREFIX = "san%s"

    def _fetch_url(self, *args, **kwargs):
        headers = kwargs.setdefault("headers", {})
        headers["User-Agent"] = FAKE_UA
        while True:
            resp = self.ua.get(*args, **kwargs)
            Core.debug("fetched %r" % resp.url)
            if resp.status_code == 503:
                Core.debug("error %r, retrying in 1s" % resp.status_code)
                time.sleep(1)
            else:
                resp.raise_for_status()
                return resp

    def find_posts(self, query, limit=20):
        # API has been blocked a long time ago; resort to scraping
        post_ids = []
        next_url = True
        page = 1

        while next_url:
            Core.debug("scraping %r (page %d)" % (query, page))
            args = {"tags": query,
                    "page": page}
            resp = self._fetch_url(self.SITE_URL, params=args)
            body = bs4.BeautifulSoup(resp.content, "lxml")
            div = body.select_one("div.content div")
            post_ids = []
            for span in div.find_all("span", {"id": True}):
                post_id = span["id"].lstrip("p")
                post_ids.append(post_id)
                if len(post_ids) >= limit:
                    break
            next_url = body.get("next-page-url")
            page += 1

        for post_id in post_ids:
            yield {"id": post_id}

    def _scrape_post_info(self, post_id):
        resp = self._fetch_url(self.POST_URL % post_id)
        resp.raise_for_status()

        page = bs4.BeautifulSoup(resp.content, "lxml")
        sidebar = page.select_one("ul#tag-sidebar")

        post = {"id": post_id,
                "tags": defaultdict(set)}

        for tag_li in sidebar.find_all("li"):
            tag_type = _grep(r"^tag-type-(.+)", tag_li["class"])
            tag_value = tag_li.select_one("a[itemprop='keywords']").get_text()
            post["tags"][tag_type].add(tag_value)

        return post

    def get_post_tags(self, post_id):
        info = self._scrape_post_info(post_id)
        return info["tags"]

## Yande.re

class YandereApi(BooruApi):
    SITE_URL = "https://yande.re"
    POST_URL = "https://yande.re/post/show/%s"
    URL_RE = [
        re.compile(r"^https://yande\.re/post/show/(?P<id>\d+)"),
        re.compile(r"^https://files\.yande\.re/image/(?P<md5>\w+)/yande.re (?P<id>\d+) "),
    ]
    ID_PREFIX = "y%s"

    def find_posts(self, tags, page=1, limit=100):
        ep = "/post.xml"
        args = {"tags": tags,
                "page": page,
                "limit": limit}

        resp = self.ua.get(self.SITE_URL + ep, params=args)
        resp.raise_for_status()

        tree = lxml.etree.XML(resp.content)
        for item in tree.xpath("/posts/post"):
            yield dict(item.attrib)

    @lru_cache(maxsize=1024)
    def _fetch_post_page(self, post_id):
        resp = self.ua.get(self.POST_URL % post_id)
        resp.raise_for_status()

        page = bs4.BeautifulSoup(resp.content, "lxml")
        return page

    def _scrape_post_info(self, post_id):
        page = self._fetch_post_page(post_id)
        sidebar = page.select_one("ul#tag-sidebar")

        post = {"id": post_id,
                "tags": defaultdict(set)}

        for tag_li in sidebar.find_all("li"):
            tag_type = _grep(r"^tag-type-(.+)", tag_li["class"])
            tag_value = tag_li.find_all("a")[-1].get_text()
            post["tags"][tag_type].add(tag_value)

        return post

    def get_post_tags(self, post_id):
        info = self._scrape_post_info(post_id)
        return info["tags"]
