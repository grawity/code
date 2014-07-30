#!python
from __future__ import print_function

import os, sys

import win32con
from win32con import *
from win32gui import *

def lookup_const(value, prefix=""):
	for name, val in globals().items():
		if val == value and name.startswith(prefix):
			return name

wmConstants = {v: k for k, v in globals().items() if k.startswith("WM_")}

windows = {}
wndCount = 0

def WindowProc(hWnd, msg, wParam, lParam):
	global wndCount
	
	wndName = windows.get(hWnd, "%08x" % hWnd)
	msgName = wmConstants.get(msg, "%08x" % msg)
	log = "WndProc(%s, %s, %08x, %08x)" % (wndName, msgName, wParam, lParam)
	
	if msg == WM_CLOSE:
		print(log)
		DestroyWindow(hWnd)
	elif msg == WM_DESTROY:
		print(log)
		wndCount -= 1
		if wndCount == 0:
			print("No windows left")
			#PostQuitMessage(0)
	else:
		if msg not in (
			WM_GETICON,
			WM_MOUSEFIRST,
			WM_NCHITTEST,
			WM_PAINT,
			WM_SETCURSOR,
			WM_ACTIVATE,
			WM_NCPAINT,
			):
			print(log)
		return DefWindowProc(hWnd, msg, wParam, lParam)

wc			= WNDCLASS()
wc.hInstance		= GetModuleHandle(None)
wc.lpfnWndProc		= WindowProc
wc.lpszClassName	= "TestWindowClass"
wcAtom			= RegisterClass(wc)

style			= WS_CAPTION | WS_SYSMENU
#exStyle			= 

hWnd_one = CreateWindow(wcAtom, "Test window one",
			style, 0, 0, CW_USEDEFAULT, CW_USEDEFAULT,
			0, 0, wc.hInstance, None)

windows[hWnd_one] = "aaa"
wndCount += 1

hWnd_two = CreateWindow(wcAtom, "TestWindowTwo",
			style, 0, 0, CW_USEDEFAULT, CW_USEDEFAULT,
			0, 0, wc.hInstance, None)
			
windows[hWnd_two] = "XXX"
wndCount += 1

ShowWindow(hWnd_one, SW_SHOWNORMAL)

ShowWindow(hWnd_two, SW_SHOWNORMAL)

print("Starting main loop")
PumpMessages()
