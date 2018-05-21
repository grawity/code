import os, sys
from time import time, sleep

import win32api		as Wapi
import win32file	as Wfile
import win32process	as Wproc
import win32service	as Wsvc
import win32ts		as Wts

def subst(device, target):
	try:
		Wfile.QueryDosDevice(device)
	except:
		Wfile.DefineDosDevice(0, device, target)

def start_service(*svcs):
	scm_h = Wsvc.OpenSCManager(None, None, Wsvc.SC_MANAGER_ENUMERATE_SERVICE)
	for svc in svcs:
		svc_h = Wsvc.OpenService(scm_h, svc, Wsvc.SERVICE_QUERY_STATUS | Wsvc.SERVICE_START)
		status = Wsvc.QueryServiceStatusEx(svc_h)
		if status["CurrentState"] == Wsvc.SERVICE_STOPPED:
			Wsvc.StartService(svc_h, None)
		Wsvc.CloseServiceHandle(svc_h)
	Wsvc.CloseServiceHandle(scm_h)

def poll_dir(dir):
	started = time()
	timeout = 15*60
	interval = 3
	print("Polling for %s every %d seconds" % (dir, interval))
	while time()-started < timeout:
		if os.path.exists(dir):
			return True
		else:
			sleep(interval)
	return False

def find_process(**kw):
	mypid = os.getpid()
	mysession = Wts.ProcessIdToSessionId(mypid)
	srv_h = Wts.WTS_CURRENT_SERVER_HANDLE
	for session, pid, image, sid in Wts.WTSEnumerateProcesses(srv_h):
		if session != mysession:
			continue
		if "image" in kw and image.lower() != kw["image"].lower():
			continue
		if "pid" in kw and pid != kw["pid"]:
			continue
		yield session, pid, image, sid

def has_process(**kw):
	for x in find_process(**kw):
		return True
	return False