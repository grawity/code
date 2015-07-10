#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <glib.h>

static GLogFunc old_handler = NULL;

static int _debug = -1;
static int _lvl = -1;

/*
 * glib/gmessages.c:1328
 */

void
Nullroute_glib_log_handler(
		const gchar *log_domain,
		GLogLevelFlags log_level,
		const gchar *message,
		gpointer unused_data)
{
	char *prefix_color = "";
	char *prefix = "<log>";
	int tty = isatty(fileno(stderr));

	if (log_level & G_LOG_FLAG_RECURSION) {
		old_handler(log_domain, log_level, message, unused_data);
		return;
	}

	if (_debug < 0) {
		_debug = !!getenv("DEBUG");
	}

	if (_lvl < 0) {
		char *lvl_str = getenv("LVL");
		if (lvl_str)
			_lvl = atoi(lvl_str);
		else
			_lvl = 0;
	}

	switch (log_level)
	{
	case G_LOG_LEVEL_ERROR:
		prefix_color = "\033[1;31m";
		prefix = "error";
		break;
	case G_LOG_LEVEL_CRITICAL:
		prefix_color = "\033[1;31m";
		prefix = "critical";
		break;
	case G_LOG_LEVEL_WARNING:
		prefix_color = "\033[1;33m";
		prefix = "warning";
		break;
	case G_LOG_LEVEL_DEBUG:
		prefix_color = "\033[36m";
		prefix = "debug";
		break;
	}

	/* program name */

	if (_debug || _lvl > 0)
	{
		char *progname = NULL;
		char *(*func)(void) = dlsym(RTLD_NEXT, "g_get_prgname");

		if (func)
			progname = func();
		else
			progname = "???";

		if (_debug)
			fprintf(stderr, "%s[%lu]: ", progname, getpid());
		else
			fprintf(stderr, "%s: ", progname);
	}

	/* level prefix */

	fprintf(stderr, "%s%s:%s ",
		tty ? prefix_color : "",
		prefix,
		tty ? "\033[m"     : "");

	/* message text */

	if (*log_domain)
		fprintf(stderr, "(%s) ", log_domain);

	fprintf(stderr, "%s\n", message);
}

void __attribute__((constructor))
Nullroute_lib_init(void)
{
	old_handler = g_log_set_default_handler(Nullroute_glib_log_handler, NULL);
}
