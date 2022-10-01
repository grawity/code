#define _GNU_SOURCE
#include <dlfcn.h>
#include <err.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <sys/socket.h>

int setsockopt(int fd, int level, int name, const void *value, socklen_t len)
{
	static int (*real_setsockopt)(int, int, int, const void *, socklen_t);
	int r;

	if (!real_setsockopt)
		real_setsockopt = dlsym(RTLD_NEXT, "setsockopt");
	
	if ((level == SOL_IP && name == IP_TOS) ||
	    (level == SOL_IPV6 && name == IPV6_TCLASS))
	{
		/* This is probably the TCP socket that will be used for SSH. */
		r = real_setsockopt(fd, SOL_TCP, TCP_CONGESTION, "lp", sizeof "lp");
		if (r != 0)
			warn("Could not set congestion control algorithm");
	}

	return real_setsockopt(fd, level, name, value, len);
}
