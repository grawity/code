import os
import subprocess
from time import sleep

def Suspend():
	pass

def Resume():
	bitbucket = open(os.devnull, "w")
	renew = lambda: subprocess.Popen(("ipconfig", "/renew"), stdout=bitbucket)
	renew().wait()
	sleep(5)
	renew().wait()
	sleep(5)
	renew()
