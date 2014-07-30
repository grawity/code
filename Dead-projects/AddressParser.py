import re

types = dict()

def addr_type(klass):
	types[klass._type] = klass
	return klass

class Address(object):
	_fields = None

	def __init__(self, addr=None, **kwargs):
		for field, ftype in self._fields:
			if field in kwargs:
				value = ftype(field)
			else:
				value = None
			setattr(self, field, value)

		if addr is not None:
			if not self.parse_into(addr):
				raise ValueError("Invalid address %r" % addr)

	def __str__(self):
		return self.to_s()

	def __repr__(self):
		fs = ["%s=%r" % (field, getattr(self, field, None)) \
			for (field, ftype) in self._fields]
		return "<%s(%s)>" % (self.__class__.__name__, ", ".join(fs))

	def parse_into(self, string):
		raise NotImplementedError

@addr_type
class CompuServeAddress(Address):
	_type = "compuserve"
	_name = "CompuServe"
	_fields = [
		("userid", str),]
	
	_syntax = "proj,prog"
	# <project>,<programmer> from TOPS-10
	# used by CompuServe as single unit
	
	_rx = re.compile(r"""
			(\d+),(\d+)
			$""", re.X)

	def parse_into(self, string):
		m = self._rx.match(string)
		if m:
			self.userid = m.group(0)
			return True
	
	def to_s(self):
		return self.userid
	
	def to_arpa(self):
		return "%s@compuserve.com" % self.userid.replace(",", ".")

@addr_type
class FidoNetAddress(Address):
	_type = "fidonet"
	_name = "Fidonet/FTN" # FidoNet Technology Network
	_fields = [
		("user", str),
		("zone", int),
		("region", int),
		("node", int),
		("point", int),
		("domain", str),
		("inetdomain", str),]

	# http://www.ftsc.org/docs/fsp-1028.002

	# http://www.ftsc.org/docs/frl-1002.001 "Standard Fidonet Addressing"

	_syntax = "[user @ ][zone:]region/node[.point][@domain]"

	_rx = re.compile(r"""
			(?: (.+) (?:\s+on\s+|\s+at\s+|\s*@\s*) )?
			(?: ([a-z0-9_~-]+)\# )?
			(?: (\d+): )?
			(\d+)/(-?\d+)
			(?: \.(-?\d+) )?
			(?: @([a-z0-9_~-]+) )?
			$""", re.X | re.I)

	_rx_domain = re.compile(r"""
			(?: p(\d+)\. )?
			[fn](\d+)\.[nr](\d+)\.z(\d+)\.(.+)
			$""", re.X | re.I)

	default_domain = "fidonet"

	default_inetdomain = "binkp.net"

	def is_valid_fsp1004(self):
		return ((1 <= self.zone <= 32767)
			and (1 <= self.region <= 32767)
			and (-1 <= self.node <= 32767)
			and (0 <= self.point <= 32767)
			and (1 <= len(self.domain) <= 8))
	
	def is_zonegate(self):
		return (self.zone == self.region) and (self.node > 0)
	
	def is_point(self):
		return (self.point > 0)
	
	def parse_into(self, string):
		m = self._rx.match(string)
		if m:
			user, ftn, zone, region, node, point, domain = m.groups()
			self.user	= user.strip() if user else None
			self.zone	= int(zone) if zone else 1
			self.region	= int(region)
			self.node	= int(node)
			self.point	= int(point) if point else 0
			self.domain	= (ftn or domain or self.default_domain).lower()
			return self.is_valid_fsp1004()
		elif "." in string:
			if "@" in string:
				lhs, rhs = string.rsplit("@", 1)
			else:
				lhs, rhs = None, string
			m = self._rx_domain.match(rhs)
			if m:
				point, node, region, zone, inetdomain = m.groups()
				self.user	= lhs
				self.zone	= int(zone)
				self.region	= int(region)
				self.node	= int(node)
				self.point	= int(point) if point else 0
				self.domain	= self.default_domain
				self.inetdomain	= inetdomain
				valid		= self.is_valid_fsp1004()
				self.domain	= inetdomain
				return valid

	def to_s(self, fqfa=False):
		sz = ""
		if self.user:
			sz += "%s @ " % self.user
		if self.domain and fqfa:
			sz += "%s#" % self.domain
		if self.zone:
			sz += "%d:" % self.zone
		sz += "%d/%d" % (self.region, self.node)
		if self.point or fqfa:
			sz += ".%d" % self.point
		if self.domain and not fqfa:
			sz += "@%s" % self.domain
		return sz

	def to_fqfa(self):
		return self.to_s(fqfa=True)

	def to_brake(self):
		sz = ""
		if self.user:
			sz += "%s @ " % self.user
		sz += "%s.%d.%d.%d.%d" % (self.domain, self.zone,
					self.region, self.node, self.point)

	def to_arpa(self):
		# http://www.ftsc.org/docs/fsp-1004.001
		sz = ""
		if self.user:
			sz += "%s@" % self.user.replace(".", "").replace(" ", ".")
		if self.point:
			sz += "p%d." % self.point
		sz += "f%d.n%d.z%d.%s." % (self.node, self.region, self.zone,
					self.inetdomain or self.default_inetdomain)
		return sz

@addr_type
class UucpAddress(Address):
	_type = "uucp"
	_name = "UUCP"

	_fields = [
		("relative", bool),
		("hosts", list),
		("user", str),]

	_syntax = "*<host!>[user]"

	def parse_into(self, string):
		hops = string.split("!")
		self.user = hops.pop() or None
		self.hosts = hops

		if self.hosts[0] == "...":
			self.relative = True
			self.hosts.pop(0)
		elif self.hosts[0].startswith("..."):
			self.relative = True
			self.hosts[0] = self.hosts[0][3:]
		else:
			self.relative = False

		return True
	
	def to_s(self):
		items = []
		if self.relative:
			items.append("...")
		items.extend(self.hosts)
		items.append(self.user or "")
		return "!".join(items)

if __name__ == "__main__":
	for line in open("AddressParser.samp"):
		t, s = line.strip().split(None, 1)
		a = types[t](s) if t in types else None
		print(t, s)
		print("-->", a)
		print("  *", repr(a))
