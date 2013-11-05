from __future__ import print_function
import ctypes

from xmlrpc.server import SimpleXMLRPCServer
from xmlrpc.server import SimpleXMLRPCRequestHandler
from xmlrpc.server import DocXMLRPCServer
from xmlrpc.server import DocXMLRPCRequestHandler

## Win32 types

GetSystemPowerStatus	= ctypes.windll.kernel32.GetSystemPowerStatus
SetSuspendState		= ctypes.windll.powrprof.SetSuspendState

BOOL	= ctypes.c_int
BYTE	= ctypes.c_byte
DWORD	= ctypes.c_long

class Structure(ctypes.Structure):
	def dict(self):
		return {attr: getattr(self, attr) for attr, type in self._fields_}

class SYSTEM_POWER_STATUS(Structure):
	_fields_ = (
		("ACLineStatus", 	BYTE),
		("BatteryFlag",		BYTE),
		("BatteryLifePercent",	BYTE),
		("Reserved1",		BYTE),
		("BatteryLifeTime",	DWORD),
		("BatteryFullLifeTime",	DWORD),
	)

## RPC

class RequestHandler(DocXMLRPCRequestHandler):
	rpc_paths = ('/mgmt')

def register_function(func):
	server.register_function(func)
	return func

server = DocXMLRPCServer(("localhost", 8000),  requestHandler=RequestHandler)
server.register_introspection_functions()

@register_function
def Suspend(hibernate=False, force=False):
	return SetSuspendState(hibernate, force, False)

@register_function
def GetPowerStatus():
	status = SYSTEM_POWER_STATUS()
	GetSystemPowerStatus(ctypes.byref(status))
	re = dict()
	re["ACPower"]			= status.ACLineStatus == 1
	if status.BatteryFlag != 255:
		re["BatteryPresent"]		= not bool(status.BatteryFlag & 128)
		re["Charging"]			= bool(status.BatteryFlag & 8)
		re["BatteryLifeTime"]		= status.BatteryLifeTime
		re["BatteryLifePercent"]	= status.BatteryLifePercent
	return re

server.serve_forever()