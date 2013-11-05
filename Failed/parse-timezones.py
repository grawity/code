#!/usr/bin/env python
import datetime

fmt = '%Y-%m-%d %H:%M:%S';
ofmt = fmt+' %z'

ZERO = datetime.timedelta(0)
HOUR = datetime.timedelta(hours=1)

class UTC(datetime.tzinfo):
	def utcoffset(self, dt):
		return ZERO
	def tzname(self, dt):
		return "UTC"
	def dst(self, dt):
		return ZERO

utc = UTC()

class FixedOffset(datetime.tzinfo):
	def __init__(self, offset, name):
		print("init: minutes=%d" % offset)
		self._offset = datetime.timedelta(minutes=offset)
		self._name = name
	def utcoffset(self, dt):
		return self._offset
	def tzname(self, dt):
		return self._name
	def dst(self, dt):
		return ZERO

dates = [
	("2012-03-01 18:36:00",	":Europe/Vilnius",	"2012-03-01 16:36:00"),
	("2012-04-01 18:20:00",	":Europe/Paris",	"2012-04-01 16:20:00"),
	("2012-04-01 19:19:12",	"+0300",		"2012-04-01 16:19:12"),
];

def parse_timezone(tzspec):
	if tzspec[0] in "+-":
		offset = int(tzspec[1:3], 10) * 60 + int(tzspec[3:5], 10)
		offset *= (-1 if tzspec[0] == "-" else 1)
		return FixedOffset(offset, tzspec)
	elif tzspec[0] == ":":
		print("ignoring unimp", tzspec)
		return UTC()
	else:
		return UTC()

def fixup(indate, tzspec):
	dt = datetime.datetime.strptime(indate, fmt)
	print(dt, "parsed")
	tz = parse_timezone(tzspec)
	dt = dt.replace(tzinfo=tz)
	print(dt, "with tz")
	dt = dt.astimezone(utc)
	print(dt, "as utc")
	return dt.strftime(fmt)

for i in dates:
	indate, inzone, outdate = i
	out = fixup(indate, inzone)
	print("%s\t%s\t%s" % ("ok" if out == outdate else "ERR", outdate, out))
