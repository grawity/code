#!/usr/bin/env python3
from nullroute.scrape import Scraper
import requests
import sys
import os
import time

class HlsRipper(Scraper):
    def rip(self, url):
        base = os.path.dirname(url)
        while True:
            resp = self.ua.get(url)
            for line in resp.content.splitlines():
                if line.startswith(b"#"):
                    continue
                else:
                    segment = line.decode()
                    if not os.path.exists(segment):
                        print(segment)
                        seg_url = os.path.join(base, segment)
                        self.save_file(seg_url, segment, progress=True)
            time.sleep(1)

rip = HlsRipper()
rip.rip(sys.argv[1])
