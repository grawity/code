from __future__ import print_function
import os
import sys

_debug_env = os.environ.get("DEBUG", "")

try:
    _nested_env = int(os.environ.get("LVL"))
except:
    _nested_env = 0

os.environ["LVL"] = str(_nested_env + 1)

arg0 = sys.argv[0].split("/")[-1]

class Core(object):
    _num_warnings = 0
    _num_errors = 0

    _level_colors = {
        "warning": "1;33",
        "error": "1;31",
        "fatal": "1;31",
    }

    @classmethod
    def _log(self, level, msg):
        fh = sys.stderr

        if getattr(fh, "isatty", lambda: True)():
            color = self._level_colors.get(level)
        else:
            color = None

        prefix = level

        if color:
            text = "\033[%sm%s:\033[m %s" % (color, prefix, msg)
        else:
            text = "%s: %s" % (prefix, msg)

        print(text, file=fh)

    @classmethod
    def warn(self, msg):
        self._num_warnings += 1
        self._log("warning", msg)

    @classmethod
    def err(self, msg):
        self._num_errors += 1
        self._log("error", msg)
        return False

    @classmethod
    def die(self, msg):
        self._num_errors += 1
        self._log("fatal", msg)
        sys.exit(1)

    @classmethod
    def exit(self):
        sys.exit(self._num_errors > 0)
