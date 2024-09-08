from math import ceil, floor
from nullroute.string import fmt_size_short
from shutil import get_terminal_size
import sys
import time

class ProgressBar():
    def __init__(self, max_value, *, file=None, fmt_func=None):
        self.bar_width = 40
        self.num_incrs = 0
        self.cur_value = 0
        self.max_value = max_value or 0
        self._fmt_func = fmt_func or fmt_size_short

        self.output_fh = file or sys.stderr
        self.delay = 0
        self.throttle = 0.1
        self._first_in = 0
        self._last_out = 0
        self._last_val = 0

        if self.output_fh == sys.stderr:
            self.bar_width = get_terminal_size().columns
            self.bar_width -= len("###% [" + "] ###.#x of ###.#x (at ~###.#x/s)")
            self.bar_width = max(3, self.bar_width)
            self.bar_width = min(self.bar_width, 40)

    def print(self):
        cur_fmt = self._fmt_func(self.cur_value)
        if self.max_value:
            max_fmt = self._fmt_func(self.max_value)
            cur_percent = 100 * self.cur_value / self.max_value
            cur_width = self.bar_width * self.cur_value / self.max_value
            bar = "#" * ceil(cur_width) + " " * floor(self.bar_width - cur_width)
            bar = "%3.0f%% [%s] %s of %s" % (cur_percent, bar, cur_fmt, max_fmt)
        else:
            space, ship = "-", "=#="
            tmp = self.bar_width - len(ship)
            cur_width = tmp - abs(self.num_incrs % (tmp * 2) - tmp)
            bar = space * cur_width + ship + space * (tmp - cur_width)
            bar = " ??%% [%s] %s" % (bar, cur_fmt)

        if self._last_out and self._fmt_func == fmt_size_short:
            Δtime = time.time() - self._last_out
            Δvalue = self.cur_value - self._last_val
            speed = self._fmt_func(Δvalue/Δtime)
            bar += " (at ~%s/s)" % speed

        print(bar, end="\033[K\r", file=self.output_fh, flush=True)

    def incr(self, delta=1):
        self.num_incrs += 1
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
            self._last_val = self.cur_value

    def end(self, hide=False):
        print("\033[K" if hide else "\n", end="", file=self.output_fh, flush=True)

    @classmethod
    def iter(self, iterable, *args, **kwargs):
        bar = self(*args, **kwargs)
        for item in iterable:
            yield item
            bar.incr(1)
        bar.end(True)

class ProgressText(ProgressBar):
    def __init__(self, *args, fmt="%s/%s", **kwargs):
        super().__init__(*args, **kwargs)
        self.fmt = fmt
        self.throttle = 0

    def print(self):
        cur_fmt = self._fmt_func(self.cur_value)
        max_fmt = self._fmt_func(self.max_value)
        bar = self.fmt % (cur_fmt, max_fmt)
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
