#!/usr/bin/python
import os
from os.path import expanduser
from glob import glob
from util import *
import threading
import time
import subprocess
import win32api
import win32process
from win32con import *

"""
@job
def MountTruecrypt():
	truecrypt = "C:/Program Files/TrueCrypt/TrueCrypt.exe"

	if not os.path.exists("P:"):
		Popen([
			truecrypt,
			"/volume", "F:\\Users\\Mantas\\profile.tc",
			"/letter", "P",
			"/auto",
			"/quit",
			"/keyfile", expanduser("~/Local Settings/profile.key"),
			])
"""

REALTIME_PRIORITY_CLASS		= 0x00000100
HIGH_PRIORITY_CLASS		= 0x00000080
ABOVE_NORMAL_PRIORITY_CLASS	= 0x00008000
NORMAL_PRIORITY_CLASS		= 0x00000020
BELOW_NORMAL_PRIORITY_CLASS	= 0x00004000
IDLE_PRIORITY_CLASS		= 0x00000040

tdelay = 0

def add(delay, func, *args, **kwargs):
	if delay is None:
		delay = tdelay
	def DelayedRun(delay, func, args, kwargs):
		time.sleep(delay)
		print("call:", func.__name__, args)
		func(*args, **kwargs)
	print("add:", delay, func.__name__, args)
	threading.Thread(target=DelayedRun, args=(delay, func, args, kwargs)).start()

def queue(func, *args, **kwargs):
	global tdelay
	tdelay += 5
	add(tdelay, func, *args, **kwargs)

def Popen(*args, **kwargs):
	kwargs["creationflags"] = kwargs.get("creationflags", 0)
	#kwargs["creationflags"] |= BELOW_NORMAL_PRIORITY_CLASS
	proc = subprocess.Popen(*args, **kwargs)
	hproc = win32api.OpenProcess(PROCESS_SET_INFORMATION, False, proc.pid)
	#time.sleep(10)
	#win32process.SetPriorityClass(hproc, NORMAL_PRIORITY_CLASS)

def Run(*args):
	subprocess.Popen(args)

def RunMinimized(*args):
	si = subprocess.STARTUPINFO()
	si.dwFlags = STARTF_USESHOWWINDOW
	si.wShowWindow = SW_MINIMIZE
	Popen(args, startupinfo=si)

def RunHidden(*args):
	si = subprocess.STARTUPINFO()
	si.dwFlags = STARTF_USESHOWWINDOW
	si.wShowWindow = SW_HIDE
	Popen(args, startupinfo=si)

def StartAgents():
	keys = glob(expanduser("~/Private/Keys/*.ppk"))
	if len(keys) or not has_process(image="pageant.exe"):
		Run("pageant", *keys)

	#RunHidden("plink", "-batch",
	#		"-noagent",
	#		"equal.cluenet.org",
	#		"cluenet/bin/k5sshinit")

if __name__ == "__main__":
	"""
	RunHidden("plink", "-batch",
			"-noagent",
			"-D", "9050",
			"-N",
			"equal.cluenet.org")
	"""
	#queue(Run, "F:/Users/Mantas/Application Data/Dropbox/bin/Dropbox.exe")
	#queue(Run, "C:/Program Files/MIT/Kerberos/bin/netidmgr.exe", "--minimized")
	#queue(Run, "C:/Program Files/Pidgin/pidgin.exe")
	queue(None, Run, "C:/Program Files/full phat/Snarl/snarl.exe")
	#queue(Run, "F:/Users/Mantas/Application Data/Wuala/Roaming/Wuala.exe",
	#	"-silent")
	queue(StartAgents)
	add(120, RunHidden, "F:/Users/Mantas/bin/git-up.cmd")
