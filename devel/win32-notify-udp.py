#!/usr/bin/python
# Windows balloon notifications.
# state: working (kinda kludgy)

import os, sys

from win32api import *
from win32con import *
try:
	from winxpgui import *
except ImportError:
	print "No winxpgui"
	from win32gui import *

import SocketServer
import thread

NIN_BALLOONSHOW = WM_USER+2
NIN_BALLOONHIDE = WM_USER+3
NIN_BALLOONTIMEOUT = WM_USER+4
NIN_BALLOONUSERCLICK = WM_USER+5

NIIF_USER = 0x4
NIIF_NOSOUND = 0x10
NIIF_LARGE_ICON = 0x20
NIIF_RESPECT_QUIET_TIME = 0x80
NIIF_ICON_MASK = 0xF

def debug(name, *args, **kwargs):
	call = [repr(i) for i in args]
	call += ["%s=%s" % (k, repr(v)) for k, v in kwargs.items()]
	print name + "(" + ", ".join(call) + ")"

class MainWindow:
	icons = []
	queue = []
	
	def __init__(self):
		self.hInst = GetModuleHandle(None)
		debug("__init__", hInst=self.hInst)
		
		wc = WNDCLASS()
		wc.hInstance = self.hInst
		wc.lpszClassName = "PythonTaskbarDemo"
		wc.lpfnWndProc = {
			WM_DESTROY: self.OnDestroy,
			#WM_COMMAND: self.OnCommand,
			WM_USER+20: self.OnTaskbarNotify,
		}
		
		wc.style = CS_VREDRAW | CS_HREDRAW
		wc.hbrBackground = COLOR_WINDOW
		classAtom = RegisterClass(wc)
		
		wndStyle = WS_OVERLAPPED | WS_SYSMENU
		self.hWnd = CreateWindow(classAtom, "Demo", wndStyle,
			0, 0, CW_USEDEFAULT, CW_USEDEFAULT,
			0, 0, self.hInst, None)
		UpdateWindow(self.hWnd)
	
	def destroy(self):
		debug("destroy")
		for id in self.icons:
			Shell_NotifyIcon(NIM_DELETE, (self.hWnd, id))
		DestroyWindow(self.hWnd)
		PostQuitMessage(0)
	
	def add_icon(self, title, text):
		id = 0
		while id in self.icons: id += 1
		debug("add_icon", title, text, id=id)
		
		try:
			hIcon = LoadImage(self.hInst, self.icon_path, IMAGE_ICON, 0, 0, LR_LOADFROMFILE | LR_DEFAULTSIZE)
		except:
			hIcon = LoadIcon(0, IDI_APPLICATION)
		
		tooltip = title
		flags = NIF_ICON | NIF_MESSAGE | NIF_INFO
		bflags = NIIF_NONE #NIIF_USER
		nid = (self.hWnd, id, flags, WM_USER+20, hIcon, tooltip, text, 0, title, bflags)
		Shell_NotifyIcon(NIM_ADD, nid)
		self.icons.append(id)
	
	def remove_icon(self, id):
		debug("remove_icon", id)
		nid = (self.hWnd, id)
		Shell_NotifyIcon(NIM_DELETE, nid)
		self.icons.remove(id)
		
	def OnGeneric(self, hWnd, msg, wparam, lparam):
		debug("OnGeneric(%d)" % msg, hwnd=hWnd, wparam=wparam, lparam=lparam)
	
	def OnDestroy(self, hWnd, msg, wparam, lparam):
		debug("OnDestroy", hwnd=hWnd, wparam=wparam, lparam=lparam)
		PostQuitMessage(0)
	
	"""
	def OnCommand(self, hWnd, msg, wparam, lparam):
		id = LOWORD(wparam)
		debug("OnCommand", hwnd=hWnd, wparam=wparam, lparam=lparam, id=id)
	"""
	
	def OnTaskbarNotify(self, hWnd, msg, wparam, lparam):
		iconid = wparam
		event = lparam
		
		if event == WM_LBUTTONUP:
			debug("OnTaskbarNotify", iconid, "WM_LBUTTONUP")
			self.destroy()
		
		elif event == WM_RBUTTONUP:
			debug("OnTaskbarNotify", iconid, "WM_RBUTTONUP")
			"""
			menu = CreatePopupMenu()
			AppendMenu(menu, MF_STRING, 1024, "Generate balloon")
			AppendMenu(menu, MF_STRING, 1025, "Exit")
			pos = GetCursorPos()
			SetForegroundWindow(self.hWnd)
			TrackPopupMenu(menu, TPM_LEFTALIGN, pos[0], pos[1], 0, self.hWnd, None)
			PostMessage(self.hWnd, WM_NULL, 0, 0)
			"""
			pass
			
		elif event == NIN_BALLOONSHOW:
			debug("balloon_shown")
			
		elif event in (NIN_BALLOONHIDE,
				NIN_BALLOONTIMEOUT,
				NIN_BALLOONUSERCLICK):
			debug("balloon_destroyed")
			self.remove_icon(iconid)
			
			if len(self.queue):
				self.queue_next()
		
	def queue_next(self):
		debug("queue_next")
		data = self.queue.pop(0)
		self.add_icon(*data)

def sockwait():
	import socket
	s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.getprotobyname("udp"))
	s.bind(("0.0.0.0", 4457))
	while True:
		(data, addr) = s.recvfrom(1024)
		debug("recv", data, addr)
		
		title, text = [i.decode("base64") for i in data.strip().split(":")]
		
		global wnd
		wnd.queue.append((title, text))
		if len(wnd.icons) == 0:
			wnd.queue_next()

wnd = MainWindow()
wnd.icon_path = "c:\\Program Files\\Mozilla Thunderbird\\chrome\\icons\\default\\msgcomposeWindow.ico"
tid = thread.start_new_thread(sockwait, ())
PumpMessages()
wnd.destroy()