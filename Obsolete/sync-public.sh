#!/bin/sh

srchost='imap.myopera.com'
dsthost='mail.nullroute.eu.org'

_user() { getnetrc -df %u "imap@$1"; }
_pass() { getnetrc -df %p "imap@$1"; }

imapsync \
	--host1 "$srchost"			\
	--ssl1					\
	--user1 "$(_user "$srchost")"		\
	--password1 "$(_pass "$srchost")"	\
	--host2 "$dsthost"			\
	--ssl2					\
	--user2 "$(_user "$dsthost")"		\
	--password2 "$(_pass "$dsthost")"	\
	--include '^(Interesting|OldUsenet)'	\
	--prefix2 'Public/'			\
	--delete2				\
	;
