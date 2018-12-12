from math import ceil, floor
from nullroute.string import fmt_size_short
import time

class ProgressBar():
    def __init__(self, max_bytes):
        self.bar_width = 40
        self.cur_bytes = 0
        self.max_bytes = max_bytes
        self._max_fmt = fmt_size_short(max_bytes)

        self.delay = 0
        self.throttle = 0.1
        self._first_in = 0
        self._last_out = 0

    def print(self):
        cur_percent = 100 * self.cur_bytes / self.max_bytes
        cur_width = self.bar_width * self.cur_bytes / self.max_bytes
        cur_fmt = fmt_size_short(self.cur_bytes)
        bar = "#" * ceil(cur_width) + " " * floor(self.bar_width - cur_width)
        bar = "%3.0f%% [%s] %s of %s" % (cur_percent, bar, cur_fmt, self._max_fmt)
        print(bar, end="\033[K\r", flush=True)

    def _maybe_print(self):
        now = time.time()
        if not self._first_in:
            self._first_in = now
        if 0 <= (self.cur_bytes - self.max_bytes) <= delta:
            self._last_out = 0
        if now - self._first_in >= self.delay and \
           now - self._last_out >= self.throttle:
            self.print()
            self._last_out = now

    def incr(self, delta):
        self.cur_bytes += delta
        self._maybe_print()

    def end(self, hide=False):
        print("\033[K" if hide else "", end="", flush=True)
