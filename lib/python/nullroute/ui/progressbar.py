from math import ceil, floor
from nullroute.string import fmt_size_short
import sys
import time

class ProgressBar():
    def __init__(self, max_value, *, file=None, fmt_func=None):
        self.bar_width = 40
        self.cur_value = 0
        self.max_value = max_value or 0
        self._fmt_func = fmt_func or fmt_size_short
        self._max_fmt = self._fmt_func(self.max_value)

        self.output_fh = file or sys.stderr
        self.delay = 0
        self.throttle = 0.1
        self._first_in = 0
        self._last_out = 0

    def print(self):
        cur_percent = 100 * self.cur_value / self.max_value
        cur_width = self.bar_width * self.cur_value / self.max_value
        cur_fmt = self._fmt_func(self.cur_value)
        bar = "#" * ceil(cur_width) + " " * floor(self.bar_width - cur_width)
        bar = "%3.0f%% [%s] %s of %s" % (cur_percent, bar, cur_fmt, self._max_fmt)
        print(bar, end="\033[K\r", file=self.output_fh, flush=True)

    def incr(self, delta):
        self.cur_value += delta

        now = time.time()
        if not self._first_in:
            self._first_in = now
        if 0 <= (self.cur_value - self.max_value) <= delta:
            self._last_out = 0
        if now - self._first_in >= self.delay and \
           now - self._last_out >= self.throttle:
            self.print()
            self._last_out = now

    def end(self, hide=False):
        print("\033[K" if hide else "", end="", file=self.output_fh, flush=True)

    @classmethod
    def iter(self, iterable, *args, **kwargs):
        bar = self(*args, **kwargs)
        for item in iterable:
            yield item
            bar.incr(1)
        bar.end(True)

class IndefiniteProgressBar(ProgressBar):
    def __init__(self, *args, **kwargs):
        super().__init__(0, *args, **kwargs)

    def print(self):
        ship = "-=-"
        tmp = self.bar_width - len(ship)
        cur_width = tmp - abs(self.cur_value % (tmp * 2) - tmp)
        cur_fmt = self._fmt_func(self.cur_value)
        bar = " " * ceil(cur_width) + ship
        bar = " ??%% [%*s] %s" % (-self.bar_width, bar, cur_fmt)
        print(bar, end="\033[K\r", file=self.output_fh, flush=True)

    def incr(self, delta):
        self.cur_value += 1

        now = time.time()
        if not self._first_in:
            self._first_in = now
        if now - self._first_in >= self.delay and \
           now - self._last_out >= self.throttle:
            self.print()
            self._last_out = now

class ProgressText(ProgressBar):
    def __init__(self, *args, fmt="%s/%s", **kwargs):
        super().__init__(*args, **kwargs)
        self.fmt = fmt
        self.throttle = 0

    def print(self):
        cur_fmt = self._fmt_func(self.cur_value)
        bar = self.fmt % (cur_fmt, self._max_fmt)
        print(bar, end="\033[K\r", file=self.output_fh, flush=True)

class IndefiniteProgressText(ProgressBar):
    def __init__(self, *args, fmt="%s", **kwargs):
        super().__init__(*args, max_value=0, **kwargs)
        self.fmt = fmt
        self.throttle = 0

    def print(self):
        cur_fmt = self._fmt_func(self.cur_value)
        bar = self.fmt % (cur_fmt,)
        print(bar, end="\033[K\r", file=self.output_fh, flush=True)

def progress_iter(iterable, *args, **kwargs):
    bar = ProgressBar(*args, **kwargs)
    for item in iterable:
        yield item
        bar.incr(1)
    bar.end(True)
