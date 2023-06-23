from __future__ import print_function
import logging
import os
import sys
import traceback

try:
    _debug_env = int(os.environ.get("DEBUG"))
except (TypeError, ValueError):
    _debug_env = 0

try:
    _nested_env = int(os.environ.get("LVL"))
except (TypeError, ValueError):
    _nested_env = 0

os.environ["LVL"] = str(_nested_env + 1)

class Core(object):
    LOG_FATAL   = 0
    LOG_ERROR   = 1
    LOG_WARNING = 2
    LOG_NOTICE  = 3
    LOG_INFO    = 4
    LOG_DEBUG   = 5
    LOG_TRACE   = 6

    _levels = {
        LOG_FATAL:      ("fatal",   "\033[1;31m"),
        LOG_ERROR:      ("error",   "\033[1;31m"),
        LOG_WARNING:    ("warning", "\033[1;33m"),
        LOG_NOTICE:     ("notice",  "\033[1;35m"),
        LOG_INFO:       ("info",    "\033[1;34m"),
        LOG_DEBUG:      ("debug",   "\033[1;36m"),
        LOG_TRACE:      ("trace",   "\033[36m"),
    }

    # internal state

    _log_level = LOG_INFO + _debug_env
    _log_pre_hook = None
    _log_post_hook = None
    _num_warnings = 0
    _num_errors = 0

    # public constants

    arg0 = sys.argv[0].split("/")[-1]

    # logging functions

    @classmethod
    def set_log_level(self, level):
        self._log_level = level

    @classmethod
    def raise_log_level(self, level):
        self._log_level = max(self._log_level, level)

    @classmethod
    def _in_debug_mode(self):
        return self._log_level >= self.LOG_DEBUG

    @classmethod
    def _log(self, level, msg, *args,
             log_prefix=None, log_color=None,
             fmt_prefix=None, fmt_color=None,
             mod_name=None, func_name=None,
             skip=0):

        level = min(max(level, 0), self.LOG_TRACE)
        if level > self._log_level:
            return
        debug = (self._log_level >= self.LOG_DEBUG)
        fh = sys.stderr
        colors = getattr(fh, "isatty", lambda: False)()
        output = []

        if debug or _nested_env:
            output.append(self.arg0)
            if debug:
                output.append("[%d]" % os.getpid())
            output.append(": ")

        prefix = log_prefix or self._levels[level][0]
        color = log_color or self._levels[level][1]

        if fmt_prefix and not debug:
            if colors:
                output.append(fmt_color or color)
            output.append(fmt_prefix)
            if colors:
                output.append("\033[m")
            output.append(" ")
        else:
            if colors:
                output.append(color)
            output.append(prefix)
            output.append(": ")
            if colors:
                output.append("\033[m")

        if self._log_level >= self.LOG_DEBUG:
            if not func_name:
                frame = traceback.extract_stack()[-(skip+3)]
                mod_name = os.path.basename(frame[0])
                if mod_name == "__init__.py":
                    mod_name = os.path.basename(os.path.dirname(frame[0]))
                func_name = frame[2]
            if mod_name and mod_name != Core.arg0:
                func_name = "%s:%s" % (mod_name, func_name)
            if colors:
                output.append("\033[38;5;60m")
            output.append("(%s) " % func_name)
            if colors:
                output.append("\033[m")

        if args:
            msg = msg % args

        output.append(msg)

        if self._log_pre_hook:
            self._log_pre_hook()

        print("".join(output), file=fh)

        if self._log_post_hook:
            self._log_post_hook()

    @classmethod
    def trace(self, msg, *args, **kwargs):
        self._log(self.LOG_TRACE, msg, *args, **kwargs)

    @classmethod
    def debug(self, msg, *args, **kwargs):
        self._log(self.LOG_DEBUG, msg, *args, **kwargs)

    @classmethod
    def say(self, msg, *args, **kwargs):
        if self._log_level >= self.LOG_DEBUG:
            self._log(self.LOG_INFO, msg, *args, **kwargs)
        elif self._log_level >= self.LOG_INFO:
            if args:
                msg = msg %args
            print(msg)

    @classmethod
    def info(self, msg, *args, **kwargs):
        self._log(self.LOG_INFO, msg, *args, **kwargs)

    @classmethod
    def notice(self, msg, *args, **kwargs):
        self._log(self.LOG_NOTICE, msg, *args, **kwargs)

    @classmethod
    def warn(self, msg, *args, **kwargs):
        self._num_warnings += 1
        self._log(self.LOG_WARNING, msg, *args, **kwargs)

    @classmethod
    def err(self, msg, *args, **kwargs):
        self._num_errors += 1
        self._log(self.LOG_ERROR, msg, *args, **kwargs)
        return False

    @classmethod
    def die(self, msg, *args, status=1, **kwargs):
        self._num_errors += 1
        self._log(self.LOG_FATAL, msg, *args, **kwargs)
        sys.exit(status)

    @classmethod
    def exit(self):
        sys.exit(self._num_errors > 0)

    @classmethod
    def fini(self):
        sys.exit(self._num_errors > 0)

    @classmethod
    def exit_if_errors(self):
        if self._num_errors > 0:
            sys.exit(1)

    def __enter__(self):
        self._num_errors = 0

    def __exit__(self, *args):
        if self._num_errors > 0:
            sys.exit(1)

class LogHandler(logging.Handler):
    def emit(self, record):
        func = None
        if record.levelno >= logging.CRITICAL:
            func = Core.err
        elif record.levelno >= logging.ERROR:
            func = Core.err
        elif record.levelno >= logging.WARNING:
            func = Core.warn
        elif record.levelno >= logging.INFO:
            func = Core.info
        elif record.levelno >= logging.DEBUG:
            func = Core.debug
        else:
            func = Core.trace
        func("%s", self.format(record),
             mod_name=record.name,
             func_name=record.funcName)

class Env(object):
    vendor = "nullroute.eu.org"

    @classmethod
    def home(self):
        return os.environ.get("HOME", os.path.expanduser("~"))

    @classmethod
    def xdg_cache_home(self):
        return os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))

    @classmethod
    def xdg_config_home(self):
        return os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))

    @classmethod
    def xdg_data_home(self):
        return os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))

    @classmethod
    def find_cache_file(self, name):
        return os.path.join(self.xdg_cache_home(), self.vendor, name)

    @classmethod
    def find_config_file(self, name):
        paths = [
            os.path.join(self.xdg_config_home(), self.vendor, name),
            os.path.join(self.xdg_config_home(), self.vendor, "synced", name),
        ]

        for path in paths:
            if os.path.exists(path):
                return path
        else:
            return paths[0]
