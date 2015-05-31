from __future__ import print_function
import os
import sys
import traceback

try:
    _debug_env = int(os.environ.get("DEBUG"))
except:
    _debug_env = 0

try:
    _nested_env = int(os.environ.get("LVL"))
except:
    _nested_env = 0

os.environ["LVL"] = str(_nested_env + 1)

arg0 = sys.argv[0].split("/")[-1]
debug = _debug_env

class Core(object):
    _levels = {
        "fatal":    0,
        "error":    1,
        "warning":  2,
        "notice":   3,
        "info":     4,
        "debug":    5,
        "trace":    6,
    }

    _level_colors = {
        "trace":    "\033[36m",
        "debug":    "\033[1;36m",
        "info":     "\033[1;34m",
        "notice":   "\033[1;35m",
        "warning":  "\033[1;33m",
        "error":    "\033[1;31m",
        "fatal":    "\033[1;31m",
    }

    _log_level = _levels["info"] + max(_debug_env, 0)

    _num_warnings = 0
    _num_errors = 0

    @classmethod
    def _log(self, prefix, msg, severity=0, skip=0):
        fh = sys.stderr

        if not severity:
            severity = self._levels.get(prefix, self._levels["info"])

        if self._log_level < severity:
            return

        debug = (self._log_level >= self._levels["debug"])

        color = None
        output = []

        if debug or _nested_env:
            output.append(arg0)
            if debug:
                output.append("[%d]" % os.getpid())
            output.append(": ")

        if getattr(fh, "isatty", lambda: False)():
            color = self._level_colors.get(prefix)

        if color:
            output.append(color)
        output.append(prefix)
        output.append(": ")
        if color:
            output.append("\033[m")

        if severity >= self._levels["debug"]:
            func = traceback.extract_stack()[-(skip+3)][2]
            output.append("(%s) " % func)

        output.append(msg)

        print("".join(output), file=fh)

    @classmethod
    def trace(self, msg, **kwargs):
        self._log("trace", msg, **kwargs)

    @classmethod
    def debug(self, msg, **kwargs):
        self._log("debug", msg, **kwargs)

    @classmethod
    def info(self, msg, **kwargs):
        self._log("info", msg, **kwargs)

    @classmethod
    def notice(self, msg, **kwargs):
        self._log("notice", msg, **kwargs)

    @classmethod
    def warn(self, msg, **kwargs):
        self._num_warnings += 1
        self._log("warning", msg, **kwargs)

    @classmethod
    def err(self, msg, **kwargs):
        self._num_errors += 1
        self._log("error", msg, **kwargs)
        return False

    @classmethod
    def die(self, msg, status=1, **kwargs):
        self._num_errors += 1
        self._log("fatal", msg, **kwargs)
        sys.exit(status)

    @classmethod
    def exit(self):
        sys.exit(self._num_errors > 0)
