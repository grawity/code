from win32api import *
from win32security import *
from win32ts import *
from win32cred import *

protocols = {
	WTS_PROTOCOL_TYPE_CONSOLE: "console",
	WTS_PROTOCOL_TYPE_ICA: "citrix",
	WTS_PROTOCOL_TYPE_RDP: "rdp",
}

def Authenticate(user, domain, password):
	token, sid, profile, quotas = LogonUserEx(user, domain, password, LOGON32_LOGON_NEW_CREDENTIALS, LOGON32_PROVIDER_WINNT50)
	return token

def Impersonate(token=None):
	if token is None:
		RevertToSelf()
	else:
		ImpersonateLoggedOnUser(token)

def Connect(host=None):
	return WTS_CURRENT_SERVER_HANDLE if (host is None) else WTSOpenServer(host)
	
def Disconnect(server):
	WTSCloseServer(server)

def CredPrompt(host):
	user, password, persisted = CredUIPromptForCredentials(host, 0, None, None, True, 0)
	# CREDUI_FLAGS_
	"""  INCORRECT_PASSWORD = 0x1,
   DO_NOT_PERSIST = 0x2,
   REQUEST_ADMINISTRATOR = 0x4,
   EXCLUDE_CERTIFICATES = 0x8,
   REQUIRE_CERTIFICATE = 0x10,
   SHOW_SAVE_CHECK_BOX = 0x40,
   ALWAYS_SHOW_UI = 0x80,
   REQUIRE_SMARTCARD = 0x100,
   PASSWORD_ONLY_OK = 0x200,
   VALIDATE_USERNAME = 0x400,
   COMPLETE_USERNAME = 0x800,
   PERSIST = 0x1000,
   SERVER_CREDENTIAL = 0x4000,
   EXPECT_CONFIRMATION = 0x20000,
   GENERIC_CREDENTIALS = 0x40000,
   USERNAME_TARGET_CREDENTIALS = 0x80000,
   KEEP_USERNAME = 0x100000,"""
	return user, password

GetCurrentCred = lambda user: CredMarshalCredential(UsernameTargetCredential, user)

def EnumSessions(server):
	for session in WTSEnumerateSessions(server):
		sessionId = session["SessionId"]
		session["UserName"] = WTSQuerySessionInformation(server, sessionId, WTSUserName)
		session["ClientName"] = WTSQuerySessionInformation(server, sessionId, WTSClientName)
		session["ClientDisplay"] = WTSQuerySessionInformation(server, sessionId, WTSClientDisplay)
		session["WinStationName"] = session["WinStationName"] or None
		session["Protocol"] = WTSQuerySessionInformation(server, sessionId, WTSClientProtocolType)
		session["ProtocolName"] = protocols.get(session["Protocol"], "unknown")
		yield session

class Session(object):
	def __init__(self):
		self.server = None
	def disconnect(self, wait=False):
		win32ts.WTSDisconnectSession(self.server, self.id, wait)
	def logoff(self, wait=False):
		win32ts.WTSLogoffSession(self.server, self.id, wait)

host = "digit.cluenet.org"
user = "grawity"

#server = Connect(host)
#for session in EnumSessions(server):
#	print "%(UserName)-20s %(WinStationName)s (%(ProtocolName)s/%(SessionId)d)" % session
#Disconnect(server)