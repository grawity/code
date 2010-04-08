#!/usr/bin/python 
# Prints user reputation on StackOverflow and related sites.

import urllib2
import json

userids = {
	'stackoverflow.com': 49849,
	'serverfault.com': 5799,
	'superuser.com': 1686,
	'meta.stackoverflow.com': 49849,
}

def getflair(domain, userid):
	url = "http://%s/users/flair/%d.json" % (domain, userid)
	req = urllib2.urlopen(url)
	return json.load(req)

for domain, userid in userids.iteritems():
	flair = getflair(domain, userid)
	print "%(name)s on %(domain)s: %(reputation)s" % {
		"name": flair["displayName"],
		"domain": domain,
		"reputation": int(flair["reputation"].replace(",", "")),
	}
