from math import ceil, floor
from nullroute.string import fmt_size_short
import time

class ProgressBar():
    def __init__(self, max_bytes):
        self.throttle = 0.1
        self.bar_width = 40
        self.cur_bytes = 0
        self.max_bytes = max_bytes
        self._max_fmt = fmt_size_short(max_bytes)
        self._last_out = 0

    def print(self):
        cur_percent = 100 * self.cur_bytes / self.max_bytes
        cur_width = self.bar_width * self.cur_bytes / self.max_bytes
        cur_fmt = fmt_size_short(self.cur_bytes)
        bar = "#" * ceil(cur_width) + " " * floor(self.bar_width - cur_width)
        bar = "%3.0f%% [%s] %s of %s" % (cur_percent, bar, cur_fmt, self._max_fmt)
        print(bar, end="\033[K\r", flush=True)

    def incr(self, delta):
        self.cur_bytes += delta

        now = time.time()
        if now - self._last_out >= self.throttle:
            self.print()
            self._last_out = now
