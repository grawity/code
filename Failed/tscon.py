import sys
import win32cred as Cred
import win32ts as Ts
import win32wts as Wts

def GetUsername(id):
	server = Ts.WTS_CURRENT_SERVER_HANDLE
	for session in Ts.WTSEnumerateSessions(server):
		if session["SessionId"] == id:
			user = Ts.WTSQuerySessionInformation(server, id, Ts.WTSUserName)
			domain = Ts.WTSQuerySessionInformation(server, id, Ts.WTSDomainName)
			return domain, user
	raise IndexError("No such session")

def GetPassword(target):
	flags = 0
	flags |= Cred.CREDUI_FLAGS_USERNAME_TARGET_CREDENTIALS
	flags |= Cred.CREDUI_FLAGS_SHOW_SAVE_CHECK_BOX
	flags |= Cred.CREDUI_FLAGS_EXPECT_CONFIRMATION
	flags |= Cred.CREDUI_FLAGS_EXCLUDE_CERTIFICATES
	user, passwd, persist = Cred.CredUIPromptForCredentials(target, 0, target, None, True, flags)
	return user, passwd, persist

def Connect(id):
	current = Ts.WTSGetActiveConsoleSessionId()
	if current == id:
		print "Already connected to session %d." % id
		return True # because we *are* connected to the requested session
	domain, user = GetUsername(id)
	target = "%s\\%s" % (domain, user)
	target, passwd, persist = GetPassword(target)
	domain, user = Cred.CredUIParseUserName(target)
	
	print `domain`, `user`, `passwd`
	try:
		Wts.winstation.Connect(None, id, None, passwd, True)
	except Wts.Win32Error as e:
		print "[%s] %s" % (e.err, e.message)
		if e.args[0] == 1326:
			Cred.CredUIConfirmCredentials(target, False)
		return False
	else:
		Cred.CredUIConfirmCredentials(target, True)
		return True

id = int(sys.argv[1])
if not Connect(id):
	sys.exit(1)