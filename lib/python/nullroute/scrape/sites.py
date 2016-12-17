import bs4
import json
from nullroute.core import Core
from nullroute.scrape import Scraper, file_ext
import os

class ComicControlScraper(Scraper):
    def find_first_page(self, root_url):
        Core.debug("searching for first post URL")
        resp = self.get(url)
        page = bs4.BeautifulSoup(resp.content, "lxml")

        tag = page.select_one(".nav a.first")
        return tag["href"]

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

    def scrape_site(self, site_url):
        state_file = "%s/state.json" % self.dir

        try:
            with open(state_file, "r") as fh:
                next_url, page_idx = json.load(fh)
        except FileNotFoundError:
            next_url = self.find_first_page(site_url)
            page_idx = 1

        Core.info("continuing at post %d %r" % (page_idx,
                                                os.path.basename(next_url)))

        state = [next_url, page_idx]
        while state:
            state = self.save_post_incremental(*state)
            if state:
                with open(state_file, "w") as fh:
                    json.dump([*state], fh)
