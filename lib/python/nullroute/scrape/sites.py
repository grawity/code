import bs4
import json
from nullroute.core import Core
from nullroute.scrape import Scraper, file_ext
import os

class ComicControlScraper(Scraper):
    def save_post_incremental(self, url, page_idx):
        resp = self.get(url)
        page = bs4.BeautifulSoup(resp.content, "lxml")

        img = page.select_one("img#cc-comic")
        if not img:
            Core.err("no <img> in page %r" % url)
            return None

        self.save_file(img["src"],
                       name="%04d_%s.%s" % (page_idx,
                                            os.path.basename(url),
                                            file_ext(img["src"])),
                       output_dir=self.dir,
                       referer=url,
                       save_msg="saved post %d %r" % (page_idx,
                                                      os.path.basename(url)))

        a = page.select_one(".nav a.next")
        if not a or url == a["href"]:
            Core.debug("no .next link in page %r" % url)
            Core.info("finishing at last page")
            return None

        return a["href"], page_idx+1

    def save_all(self, first_page):
        state_file = "%s/state.json" % self.dir

        try:
            with open(state_file, "r") as fh:
                url, page_idx = json.load(fh)
        except FileNotFoundError:
            url, page_idx = first_page, 1

        Core.info("continuing at post %d %r" % (page_idx,
                                                os.path.basename(url)))

        r = True
        while r:
            r = self.save_post_incremental(url, page_idx)
            if r:
                url, page_idx = r
                with open(state_file, "w") as fh:
                    json.dump([url, page_idx], fh)
