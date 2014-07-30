import ctypes
from ctypes import byref
from ctypes.wintypes import (
	BOOL,
	DWORD,
	HANDLE,
	LPWSTR,
	ULONG,
	WORD)
import win32api
import win32con
import win32gui
import win32service
import win32ts

user32 = ctypes.windll.user32
wtsapi = ctypes.windll.wtsapi32
winsta = ctypes.windll.winsta

CAD_HOTKEY		= 0

LN_START_TASK_MANAGER	= 0x4
LN_LOCK_WORKSTATION	= 0x5
LN_UNLOCK_WORKSTATION	= 0x6
LN_MESSAGE_BEEP		= 0x9

WM_LOGONNOTIFY		= 0x004c
WM_HOTKEY		= 0x0311

class Win32Error(win32api.error):
	def __init__(self, func=None, err=0):
		if err:
			self.err = err
		else:
			self.err = win32api.GetLastError()
		self.message = win32api.FormatMessageW(self.err)
		self.args = (self.err, func, self.message)

def WinStationConnect(hServer, SessionID, TargetSessionID, Password="", Wait=False):
	if hServer is None:
		hServer = win32ts.WTS_CURRENT_SERVER_HANDLE

	if SessionID is None:
		SessionID = win32ts.WTS_CURRENT_SESSION

	if TargetSessionID is None:
		TargetSessionID = win32ts.WTS_CURRENT_SESSION

	res = winsta.WinStationConnectW(HANDLE(hServer), ULONG(SessionID),
		ULONG(TargetSessionID), LPWSTR(Password or ""), BOOL(Wait))

	if res != 1:
		raise Win32Error(func="WinStationConnect")

def WinStationRename(hServer, oldName, newName):
	if hServer is None:
		hServer = win32ts.WTS_CURRENT_SERVER_HANDLE

	res = winsta.WinStationRenameW(HANDLE(hServer), LPWSTR(oldName), LPWSTR(newName))

	if res != 1:
		raise Win32Error(func="WinStationRename")

"""
def GetRemoteIPAddress(hServer, SessionID):
	if hServer is None:
		hServer = win32ts.WTS_CURRENT_SERVER_HANDLE

	if SessionID is None:
		SessionID = win32ts.WTS_CURRENT_SESSION

	remoteIPAddress = ctypes.create_unicode_buffer(256)

	port = WORD()

	res = winsta.WinStationGetRemoteIPAddress(HANDLE(hServer), ULONG(SessionID),
		byref(remoteIPAddress), byref(port))

	return ctypes.wstring_at(remoteIPAddress), port
"""

def FindSasWindow():
	hDesktop = win32service.OpenDesktop("Winlogon", 0, False,
		win32con.DESKTOP_READOBJECTS  | win32con.DESKTOP_ENUMERATE)
	for hWindow in hDesktop.EnumDesktopWindows():
		if win32gui.GetClassName(hWindow) == "SAS window class":
			return hDesktop, hWindow

def WinXPUnlockWorkstation():
	hDesktop, hSasWindow = FindSasWindow()
	win32gui.PostMessage(hSasWindow, WM_LOGONNOTIFY, LN_UNLOCK_WORKSTATION, 0)

def LockWorkstation():
	res = user32.LockWorkStation()
	return BOOL(res)

_api = {
	"WinStationConnect": (WinStationConnect, int, int, int, str, bool),
	"WinStationRename": (WinStationRename, int, str, str),
}