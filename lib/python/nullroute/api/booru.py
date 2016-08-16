import bs4
import lxml.etree
from pprint import pprint
import requests

def strip_prefix(string, prefix, strict=True):
    if string.startswith(prefix):
        return string[len(prefix):]
    elif strict:
        raise ValueError("input %r does not match prefix %r" % (string, prefix))
    else:
        return string

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
                return m.group(1)

    def match_post_url(self, url):
        for pat in self.URL_RE:
            m = pat.match(url)
            if m:
                return m.group(1)

    def find_posts(self, tags, page=1, limit=100):
        ...

    def find_posts_by_md5(self, md5):
        yield from self.find_posts("md5:%s" % md5)

    def scrape_post_info(self, post_id):
        ...

    def get_post_tags(self, post_id):
        info = self.scrape_post_info(post_id)

        tags = []
        for kind in ("artist", "copyright", "character"):
            _tags = info["tags"][kind]
            if kind == "character":
                if len(_tags) > 2:
                    continue
                _suffixes = [" (%s)" % s for s in info["tags"]["copyright"]]
                _tags = [strip_suffixes(t, _suffixes) for t in _tags]
            tags += sorted(_tags)

        if self.tag_filter:
            tags = self.tag_filter.filter(tags)

        return tags

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

    def scrape_post_info(self, post_id):
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
        re.compile(r"^https://chan\.sankakucomplex\.com/post/show/(\d+)"),
        re.compile(r"^https://cs\.sankakucomplex\.com/data/\w+/\w+/\w+.\w+?(\d+)"),
    ]
    ID_PREFIX = "san%s"
    TAG_SCRAPE = True

    # API has been blocked a long time ago; resort to scraping
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
        post_ids = []
        next_url = True
        page = 1

        while next_url:
            Core.debug("scraping %r (page %d)" % (query, page))
            args = {"tags": query,
                    "page": page}
            resp = self._fetch_url(self.SITE_URL, params=args)
            page = bs4.BeautifulSoup(resp.content, "lxml")
            body = page.find("div", {"class": "content"})
            body = body.find("div")
            post_ids = []
            for post_span_t in body.find_all("span", {"id": True}):
                post_id = post_span_t["id"].lstrip("p")
                post_ids.append(post_id)
                if len(post_ids) >= limit:
                    break
            next_url = body.get("next-page-url")
            page += 1

        for post_id in post_ids:
            yield {"id": post_id}

    def scrape_post_info(self, post_id):
        resp = self._fetch_url(self.POST_URL % post_id)
        resp.raise_for_status()

        page = bs4.BeautifulSoup(resp.content, "lxml")
        sidebar = page.select_one("ul#tag-sidebar")

        post = {"id": post_id,
                "tags": defaultdict(set)}

        for tag_li in sidebar.find_all("li"):
            tag_type = tag_li["class"][0]
            tag_type = strip_prefix(tag_type, "tag-type-")

            tag_link = tag_li.find_all("a", {"itemprop": "keywords"})[0]
            tag_value = tag_link.get_text()

            post["tags"][tag_type].add(tag_value)

        return post

## Yande.re

class YandereApi(BooruApi):
    SITE_URL = "https://yande.re"
    POST_URL = "https://yande.re/post/show/%s"
    URL_RE = [
        re.compile(r"^https://yande\.re/post/show/(\d+)"),
    ]
    ID_PREFIX = "y%s"
    TAG_SCRAPE = True

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

    def scrape_post_info(self, post_id):
        resp = self._fetch_url(self.POST_URL % post_id)
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
