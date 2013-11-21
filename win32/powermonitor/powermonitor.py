#!python
from __future__ import print_function

import os, sys

from win32con import *
from win32gui import *

import win32service as svc
import win32serviceutil as svcutil
import servicemanager as smgr

try:
    import actions
except ImportError:
    print("You need to create an actions.py file first.")
    sys.exit(1)

class PowerMonitor():
    def __init__(self, name="Power event monitor", classname="PowerMonitor"):
        wc = WNDCLASS()
        wc.hInstance = hInst = GetModuleHandle(None)
        wc.lpszClassName = classname
        wc.lpfnWndProc = self.WndProc
        self.classAtom = RegisterClass(wc)

        style = 0
        self.hWnd = CreateWindow(self.classAtom, name,
            style, 0, 0, CW_USEDEFAULT, CW_USEDEFAULT,
            0, 0, hInst, None)
        UpdateWindow(self.hWnd)

    def start(self):
        self.log("info", "Starting main loop")
        PumpMessages()

    def stop(self):
        PostQuitMessage(0)

    def log(self, type, message):
        print("[%s] %s" % (type, message))

    def WndProc(self, hWnd, message, wParam, lParam):
        if message == WM_POWERBROADCAST:
            if wParam == PBT_APMSUSPEND:
                self.OnSuspend(hWnd, message, wParam, lParam)
            elif wParam == PBT_APMRESUMESUSPEND:
                self.OnResume(hWnd, message, wParam, lParam)
        elif message == WM_CLOSE:
            DestroyWindow(hWnd)
        elif message == WM_DESTROY:
            PostQuitMessage(0)
        elif message == WM_QUERYENDSESSION:
            return True

    def OnSuspend(self, hWnd, message, wParam, lParam):
        self.log("info", "APM suspend event received")
        reload(actions).Suspend()

    def OnResume(self, hWnd, message, wParam, lParam):
        self.log("info", "APM resume event received")
        reload(actions).Resume()

class PowerMonitorService(svcutil.ServiceFramework, PowerMonitor):
    _svc_name_ = "PowerMonitor"
    _svc_display_name_ = "Power event watcher"

    def __init__(self, args):
        svcutil.ServiceFramework.__init__(self, args)
        PowerMonitor.__init__(self, name=self._svc_display_name_,
            classname=self._svc_name_)

    def log(self, priority, message):
        if priority == "error":
            logger = smgr.LogErrorMsg
        elif priority == "warning":
            logger = smgr.LogWarningMsg
        else:
            logger = smgr.LogInfoMsg
        logger(message)

    def SvcDoRun(self):
        self.start()

    def SvcStop(self):
        self.ReportServiceStatus(svc.SERVICE_STOP_PENDING)
        self.stop()
        self.ReportServiceStatus(svc.SERVICE_STOPPED)

if __name__ == '__main__':
    svcutil.HandleCommandLine(PowerMonitorService)
