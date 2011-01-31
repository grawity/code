import os
import sys
from subprocess import Popen, PIPE
import console as cons

old_attrs = cons.get_text_attr()
def cleanup():
	cons.set_text_attr(old_attrs)

colors = {
	None:		cons.FOREGROUND_GREY,
	"ok":		cons.FOREGROUND_GREEN | cons.FOREGROUND_INTENSITY,
	"timeout":	cons.FOREGROUND_YELLOW | cons.FOREGROUND_INTENSITY,
}

args = ["ping"] + sys.argv[1:]
proc = Popen(args, stdout=PIPE)
while True:
	try:
		line = proc.stdout.readline()
	except KeyboardInterrupt:
		cleanup()
		sys.exit()

	if not line:
		break
	line = line.strip()
	
	if line.startswith("Reply from "):
		status = "ok"
		_, data = line.split(": ", 1)
		data = data.split()
		data = {k[0]: k[1] for k in [j.split("=") for j in data]}
	elif line == "Request timed out.":
		status = "timeout"
	else:
		status = None
	
	cons.set_text_attr(colors.get(status, None))
	print line