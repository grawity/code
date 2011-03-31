#!python
from __future__ import print_function
import os
import sys
import subprocess
import win32api as api
import win32con as con
import win32gui as gui
import win32ts as ts

# window messages
WM_WTSSESSION_CHANGE		= 0x2B1

# WM_WTSSESSION_CHANGE events (wparam)
WTS_CONSOLE_CONNECT		= 0x1
WTS_CONSOLE_DISCONNECT		= 0x2
WTS_REMOTE_CONNECT		= 0x3
WTS_REMOTE_DISCONNECT		= 0x4
WTS_SESSION_LOGON		= 0x5
WTS_SESSION_LOGOFF		= 0x6
WTS_SESSION_LOCK		= 0x7
WTS_SESSION_UNLOCK		= 0x8
WTS_SESSION_REMOTE_CONTROL	= 0x9

class WTSMonitor():
	className = "WTSMonitor"
	wndName = "WTS Event Monitor"
	def __init__(self):
		wc = gui.WNDCLASS()
		wc.hInstance = hInst = api.GetModuleHandle(None)
		wc.lpszClassName = self.className
		wc.lpfnWndProc = self.WndProc
		self.classAtom = gui.RegisterClass(wc)

		style = 0
		self.hWnd = gui.CreateWindow(self.classAtom, self.wndName,
			style, 0, 0, con.CW_USEDEFAULT, con.CW_USEDEFAULT,
			0, 0, hInst, None)
		gui.UpdateWindow(self.hWnd)

		# you can optionally use ts.NOTIFY_FOR_ALL_SESSIONS
		ts.WTSRegisterSessionNotification(self.hWnd, ts.NOTIFY_FOR_THIS_SESSION)
	
	def start(self):
		gui.PumpMessages()

	def WndProc(self, hWnd, message, wParam, lParam):
		if message == WM_WTSSESSION_CHANGE:
			self.OnSession(wParam, lParam)
		elif message == con.WM_CLOSE:
			gui.DestroyWindow(hWnd)
		elif message == con.WM_DESTROY:
			gui.PostQuitMessage(0)
		elif message == con.WM_QUERYENDSESSION:
			return True

	def OnSession(self, event, sessionID):
		print("event 0x%x on session %d" % (event, sessionID))

		#if sessionID == ts.ProcessIdToSessionId(os.getpid()):

		# Since you already have a Python script, you can use it here directly.
		# Otherwise, replace this with something involving subprocess.Popen()

if __name__ == '__main__':
	m = WTSMonitor()
	m.start()
