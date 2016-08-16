import bs4
import lxml.etree
from pprint import pprint
import requests


class BooruApi(object):
    NAME_RES = []
    URL_RES = []

    def __init__(self, tag_filter=None):
        self.tag_filter = tag_filter
        self.ua = requests.Session()

    def match_file_name(self, name):
        for re in self.NAME_RE:
            m = re.match(name)
            if m:
                return m.group(1)

    def match_post_url(self, url):
        for re in self.URL_RE:
            m = re.match(url)
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

## Yande.re

class YandereApi(BooruApi):
    SITE_URL = "https://yande.re"
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
