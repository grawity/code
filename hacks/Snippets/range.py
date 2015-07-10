import sys
from subprocess import call

def wget(url, template, i):
	args = ['wget', '-c', url % i]
	if template:
		args += ['-O', template % i]
	#call(args)
	print args

ranges = sys.argv[1]
url = sys.argv[2]
url = url.replace('%', '%%')
url = url.replace('#', '%')
try:
	template = sys.argv[3]
	template = template.replace('#', '%')
except IndexError:
	template = None

for r in ranges.split(","):
	if "-" in r:
		s, e = r.split("-")
	else:
		s = e = r
	s = int(s)
	e = int(e)
	for i in range(s, e+1):
		wget(url, template, i)
