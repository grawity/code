import bs4
from collections import defaultdict
from functools import lru_cache
import lxml.etree
from nullroute.core import Core
from nullroute.scrape import urljoin
import nullroute.sec
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

def _strip_prefix(arg, prefix, strict=True):
    if arg.startswith(prefix):
        return arg[len(prefix):]
    elif strict:
        raise ValueError("input %r does not match prefix %r" % (arg, prefix))
    else:
        return arg

def _strip_suffixes(arg, sfs):
    for sf in sfs:
        if arg.endswith(sf):
            return arg[:-len(sf)]
    return arg

class BooruApi(object):
    NAME_RE = []
    URL_RE = []

    HASH_SUFFIX = True

    def __init__(self, tag_filter=None):
        self.tag_filter = tag_filter
        self.ua = requests.Session()

    def match_file_name(self, name):
        for pat in self.NAME_RE:
            m = pat.match(name)
            if m:
                return m.group("id")

    def match_post_url(self, url):
        for pat in self.URL_RE:
            m = pat.match(url)
            if m:
                return m.group("id")

    def find_posts(self, tags, page=1, limit=100):
        raise NotImplementedError

    def find_post_by_id(self, post_id):
        return next(self.find_posts("id:%s" % post_id, limit=1))

    def find_posts_by_md5(self, md5):
        yield from self.find_posts("md5:%s" % md5)

    def get_post_info(self, post_id):
        info = self.find_post_by_id(post_id)
        return info

    def get_post_tags(self, post_id):
        raise NotImplementedError

    def get_post_original(self, post_id):
        raise NotImplementedError

    def sort_tags(self, raw_tags, skip_character_tags=False):
        all_tags = []
        for key in ("artist", "copyright", "character"):
            val = [t.replace(" ", "_") for t in raw_tags[key]]
            if key == "character" and skip_character_tags:
                continue
            if key == "character" and len(val) <= 2:
                bad_suffixes = ["_(%s)" % s for s in raw_tags["copyright"]]
                val = [_strip_suffixes(t, bad_suffixes) for t in val]
            if key == "character" and len(val) > 8:
                val = []
            all_tags += sorted(val)
        if self.tag_filter:
            all_tags = self.tag_filter.filter(all_tags)
        return all_tags

## Danbooru

class DanbooruApi(BooruApi):
    SITE_URL = "https://danbooru.donmai.us"
    URL_RE = [
        re.compile(r"https?://danbooru.donmai.us/posts/(?P<id>\d+)"),
        #re.compile(r"https?://danbooru\.donmai\.us/data/.+__(?<md5>[^_]+)\.\w+$"),
    ]
    ID_PREFIX = "db%s"
    HASH_SUFFIX = True

    _cache = {}

    def __init__(self, *args, **kwargs):
        from requests.auth import HTTPBasicAuth
        super().__init__(*args, **kwargs)

        try:
            creds = nullroute.sec.get_netrc("danbooru.donmai.us", service="api")
        except KeyError:
            Core.debug("Danbooru API key not found")
        else:
            Core.debug("Danbooru API key for %r found", creds["login"])
            self.ua.auth = HTTPBasicAuth(creds["login"], creds["password"])

    def find_posts(self, tags, page=1, limit=100):
        ep = "/posts.xml"
        args = {"tags": tags,
                "page": page,
                "limit": limit}

        resp = self.ua.get(self.SITE_URL + ep, params=args)
        resp.raise_for_status()

        tree = lxml.etree.XML(resp.content)
        for item in tree.xpath("/posts/post"):
            attrib = {child.tag.replace("-", "_"): child.text
                      for child in item.iterchildren()}
            attrib = {"tags": {}}
            for child in item.iterchildren():
                key = child.tag.replace("-", "_")
                val = child.text
                attrib[key] = val
                if key.startswith("tag_string_"):
                    kind = _strip_prefix(key, "tag_string_")
                    attrib["tags"][kind] = val.split() if val else []
            #pprint(attrib)
            if "id" not in attrib:
                print("BUG: missing id in %r", attrib)
            self._cache["id:%(id)s" % attrib] = attrib
            yield attrib

    def get_post_tags(self, post_id):
        key = "id:%s" % post_id
        post = self._cache.get(key)
        if not post:
            posts = self.find_posts(key)
            try:
                post = next(posts)
            except StopIteration:
                raise KeyError("post %r not found" % key)
        return post["tags"]

## Gelbooru

class GelbooruApi(BooruApi):
    SITE_URL = "https://gelbooru.com/"
    POST_URL = "https://gelbooru.com/index.php?page=post&s=view&id=%s"
    ID_PREFIX = "g%s"
    TAG_SCRAPE = True

    def __init__(self, *args, **kwargs):
        from requests.auth import HTTPBasicAuth
        super().__init__(*args, **kwargs)

        try:
            creds = nullroute.sec.get_netrc("gelbooru.com", service="api")
        except KeyError:
            Core.debug("Gelbooru API key not found")
            self._apikey_params = {}
        else:
            Core.debug("Gelbooru API key for %r found", creds["login"])
            self._apikey_params = {"user_id": creds["login"],
                                   "api_key": creds["password"]}

    def _fetch_url(self, url, *args, **kwargs):
        Core.debug("fetching %r %r %r", url, args, kwargs)
        resp = self.ua.get(url, *args, **kwargs)
        resp.raise_for_status()
        return resp

    def find_posts(self, query, limit=100):
        args = {"page": "dapi", "s": "post", "q": "index",
                "tags": query, "limit": limit, "json": 1}
        resp = self.ua.get(self.SITE_URL, params={**args, **self._apikey_params})
        resp.raise_for_status()
        if resp.content.startswith(b"["):
            yield from resp.json()
        elif resp.content == b"":
            Core.debug("API query returned empty body")
        else:
            raise ValueError(resp.content)

    def _scrape_post_info(self, post_id):
        args = {"page": "post", "s": "view", "id": post_id}
        resp = self.ua.get(self.SITE_URL, params=args)
        resp.raise_for_status()

        page = bs4.BeautifulSoup(resp.content, "lxml")

        post = {"id": post_id,
                "tags": defaultdict(set)}

        for tag_li in page.select("li[class^='tag-type-']"):
            tag_type = _grep(r"^tag-type-(.+)", tag_li["class"])
            tag_value = tag_li.find_all("a")[-1].get_text()
            post["tags"][tag_type].add(tag_value)

        return post

    def get_post_tags(self, post_id):
        info = self._scrape_post_info(post_id)
        return info["tags"]

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

class MoebooruApi(BooruApi):
    # official API

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

    def list_pool(self, pool_id, page=1):
        ep = "/pool/show.xml"
        args = {"id": pool_id,
                "page": page}

        resp = self.ua.get(self.SITE_URL + ep, params=args)
        resp.raise_for_status()

        tree = lxml.etree.XML(resp.content)
        for item in tree.xpath("/pool/posts/post"):
            yield dict(item.attrib)

    # information unavailable via API (tag types)

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

    def get_post_original(self, post_id):
        info = self.find_post_by_id(post_id)
        return urljoin(self.SITE_URL, info["file_url"])

class KonachanApi(MoebooruApi):
    SITE_URL = "http://konachan.com/"
    POST_URL = "http://konachan.com/post/show/%s"
    URL_RE = [
        re.compile(r"^https?://konachan\.com/post/show/(?P<id>\d+)"),
        re.compile(r"^https?://konachan\.com/image/(?P<md5>\w+)/Konachan.com - (?P<id>\d+) "),
    ]
    ID_PREFIX = "kona%s"

class YandereApi(MoebooruApi):
    SITE_URL = "https://yande.re"
    POST_URL = "https://yande.re/post/show/%s"
    URL_RE = [
        re.compile(r"^https://yande\.re/post/show/(?P<id>\d+)"),
        re.compile(r"^https://files\.yande\.re/image/(?P<md5>\w+)/yande.re (?P<id>\d+) "),
    ]
    ID_PREFIX = "yande.re %s"
    HASH_SUFFIX = False

apis = {
    "gelbooru": GelbooruApi,
    "sankaku": SankakuApi,
    "danbooru": DanbooruApi,
    "yandere": YandereApi,
    "konachan": KonachanApi,
}
