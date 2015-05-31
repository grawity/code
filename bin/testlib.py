#!/usr/bin/env python3
import os
from nullroute import Core
import sys

def forked(func):
    if os.fork():
        os.wait()
    else:
        func()
        sys.exit()

def foo(): bar()

def bar(): baz()

def baz(): test_log()

def test_log():
    Core.trace("trace message")
    Core.debug("debug message")
    Core.info("info message")
    Core.notice("notice message")
    Core.warn("warning message")
    Core.err("error message")
    Core.die("fatal message", status=0)

print("\n-- messages --\n")

forked(foo)

print("\n-- messages ($DEBUG) --\n")

Core.raise_log_level(Core.LOG_TRACE)

forked(foo)
