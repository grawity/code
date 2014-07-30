/*
 *   stunnel       Universal SSL tunnel
 *   Copyright (C) 1998-2012 Michal Trojnara <Michal.Trojnara@mirt.net>
 *
 *   This program is free software; you can redistribute it and/or modify it
 *   under the terms of the GNU General Public License as published by the
 *   Free Software Foundation; either version 2 of the License, or (at your
 *   option) any later version.
 * 
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *   See the GNU General Public License for more details.
 * 
 *   You should have received a copy of the GNU General Public License along
 *   with this program; if not, see <http://www.gnu.org/licenses>.
 * 
 *   Linking stunnel statically or dynamically with other modules is making
 *   a combined work based on stunnel. Thus, the terms and conditions of
 *   the GNU General Public License cover the whole combination.
 * 
 *   In addition, as a special exception, the copyright holder of stunnel
 *   gives you permission to combine stunnel with free software programs or
 *   libraries that are released under the GNU LGPL and with code included
 *   in the standard release of OpenSSL under the OpenSSL License (or
 *   modified versions of such code, with unchanged license). You may copy
 *   and distribute such a system following the terms of the GNU GPL for
 *   stunnel and the licenses of the other code concerned.
 * 
 *   Note that people who make modified versions of stunnel are not obligated
 *   to grant this special exception for their modified versions; it is their
 *   choice whether to do so. The GNU General Public License gives permission
 *   to release a modified version without this exception; this exception
 *   also makes it possible to release a modified version which carries
 *   forward this exception.
 */

/* getpeername() can't be declared in the following includes */
#define getpeername no_getpeername
#include <sys/types.h>
#include <sys/socket.h> /* for AF_INET */
#include <netinet/in.h>
#include <arpa/inet.h>  /* for inet_addr() */
#include <stdlib.h>     /* for getenv() */
#ifdef __BEOS__
#include <be/bone/arpa/inet.h> /* for AF_INET */
#include <be/bone/sys/socket.h> /* for AF_INET */
#else
#include <sys/socket.h> /* for AF_INET */
#endif
#undef getpeername

#include <string.h>

union sockunion {
    struct sockaddr     sa;
    struct sockaddr_in  in;
    struct sockaddr_in6 in6;
} sockunion_t;

int getpeername(int s, struct sockaddr *name_sa, socklen_t *len) {
    char *value;
    int r;

    (void)s; /* skip warning about unused parameter */
    (void)len; /* skip warning about unused parameter */

    union sockunion *name = (union sockunion *) name_sa;

    bzero(name_sa, *len);

    value = getenv("REMOTE_HOST");
	if (!value)
        value = getenv("SOCAT_PEERADDR");
    if (!value) {
        /* no env */
        name->sa.sa_family = AF_INET;
        name->in.sin_addr.s_addr = htonl(INADDR_ANY);
    }
    else if (strncmp(value, "::ffff:", 7) == 0) {
        /* v6mapped */
        name->sa.sa_family = AF_INET;
        name->in.sin_addr.s_addr = inet_addr(value+7);
    }
    else if (strchr(value, ':') == NULL) {
        /* ipv4 */
        name->sa.sa_family = AF_INET;
        name->in.sin_addr.s_addr = inet_addr(value);
    }
    else {
        /* ipv6 */
        name->sa.sa_family = AF_INET6;
        inet_pton(AF_INET6, value, &name->in6.sin6_addr);
    }

    value = getenv("REMOTE_PORT");
    if (!value)
        value = getenv("SOCAT_PEERPORT");

    unsigned int port = value ? atoi(value) : 0;

    switch (name->sa.sa_family) {
    case AF_INET:
        name->in.sin_port = htons(port);
        break;
    case AF_INET6:
        name->in6.sin6_port = htons(port);
        break;
    }

    return 0;
}

/* end of env.c */

/* vim: set ts=4:sw=4:et: */
