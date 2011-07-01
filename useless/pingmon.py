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

def parse_data(data):
	for token in data.split():
		if "=" in token:
			yield token.split("=", 1)
		elif "<" in token:
			t = token.partition("<")
			yield token[0], token[1]+token[2]

args = ["ping", "-t", "-w", "1"] + sys.argv[1:]
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
		data = {k[0]: k[1] for k in parse_data(data)}
	elif line == "Request timed out.":
		status = "timeout"
	else:
		status = None
	
	cons.set_text_attr(colors.get(status, None))
	print line