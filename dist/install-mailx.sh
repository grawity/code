#!/bin/bash -e
: ${SRCDIR:=~/src}
: ${LOCAL:=~/.local}
: ${CONFIG:=~/.config}

# download

mkdir -p "$SRCDIR" && cd "$SRCDIR"
curl 'http://nail.cvs.sourceforge.net/viewvc/nail/?view=tar' | tar xz

# build

makeflags=( PREFIX="$LOCAL" SYSCONFDIR="$CONFIG" )

cd "nail/nail"
patch -p1 -N <<'EOF'
--- nail.orig/openssl.c	2009-05-27 00:04:15.000000000 +0300
+++ nail/openssl.c	2011-07-12 11:12:02.000000000 +0300
@@ -216,9 +216,7 @@ ssl_select_method(const char *uhp)
 
 	cp = ssl_method_string(uhp);
 	if (cp != NULL) {
-		if (equal(cp, "ssl2"))
-			method = SSLv2_client_method();
-		else if (equal(cp, "ssl3"))
+		if (equal(cp, "ssl3"))
 			method = SSLv3_client_method();
 		else if (equal(cp, "tls1"))
 			method = TLSv1_client_method();
EOF
make clean
make "${makeflags[@]}" IPv6="-DHAVE_IPv6_FUNCS"

# install

make "${makeflags[@]}" UCBINSTALL="install" install
