#!/usr/bin/env python3

class StatusPrinter:
    def __init__(self):
        self.last_lines = 0

    def print(self, raw_msg, fmt_msg=None, fmt="%s"):
        out = ""
        if self.last_lines > 1:
            # Cursor up
            out += "\033[%dA" % (self.last_lines-1)
        # Cursor to column 1
        out += "\033[1G"
        # Erase below
        out += "\033[0J"
        out += fmt % (fmt_msg or raw_msg)
        self.last_lines = math.ceil(mbswidth(
