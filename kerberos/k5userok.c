/*
 * k5userok.c - verify user access according to krb5_userok()
 *
 * (c) 2012 Mantas Mikulėnas <grawity@gmail.com>
 * Released under the MIT license (see dist/LICENSE.mit)
 */

#define _XOPEN_SOURCE 500

#include "krb5.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>
#include <pwd.h>

char *progname = "k5userok";

#ifdef KRB5_HEIMDAL
#  define krb5_free_unparsed_name(ctx, name) krb5_xfree(name)
#endif

#if defined(HAVE_OPENBSD) || defined(HAVE_SOLARIS)
#  define NEED_KRB5_PARSE_NAME_FLAGS
#endif

#ifdef NEED_KRB5_PARSE_NAME_FLAGS
static inline krb5_error_code
krb5_parse_name_flags(krb5_context ctx, const char *name,
		      int flags, krb5_principal *princ)
{
	if (flags)
		return KRB5KRB_ERR_GENERIC;

	return krb5_parse_name(ctx, name, princ);
}
#endif

char *get_username(void) {
	struct passwd *pw;

	pw = getpwuid(geteuid());
	if (pw && pw->pw_name) {
		return strdup(pw->pw_name);
	} else {
		return strdup("?");
	}
}

void usage(void) {
	fprintf(stderr, "Usage: %s [-eqt] [-u user] principal...\n", progname);
	fprintf(stderr,
		"\n"
		"\t-e         parse principals as enterprise names\n"
		"\t-q         do not output anything, only set exit code\n"
		"\t-t         check against translated usernames (aname2lname)\n"
		"\t-u user    check against given username (default is current user)\n"
		"\n"
		"Note: Root permissions may be required for -t/-u, in order to read other\n"
		"      users' ~/.k5login files.\n"
		"\n");
	exit(2);
}

int main(int argc, char *argv[]) {
	int		opt;
	int		translate = 0;
	int		quiet = 0;
	int		parseflags = 0;
	char		*user = NULL;

	krb5_error_code	r;
	krb5_context	ctx;
	krb5_boolean	all_ok;

	int		i;
	krb5_principal	princ;
	char		lname[256];
	char		*princname;
	krb5_boolean	ok;

	while ((opt = getopt(argc, argv, "eqtu:")) != -1) {
		switch (opt) {
		case 'e':
#ifdef KRB5_PRINCIPAL_PARSE_ENTERPRISE
			parseflags |= KRB5_PRINCIPAL_PARSE_ENTERPRISE;
#else
			fprintf(stderr, "%s: system does not support enterprise names\n", progname);
			exit(2);
#endif
			break;
		case 'q':
			++quiet;
			break;
		case 't':
			translate = 1;
			break;
		case 'u':
			user = optarg;
			break;
		case '?':
		default:
			usage();
		}
	}

	if (optind == argc)
		usage();

	if (translate) {
		if (user) {
			fprintf(stderr, "%s: -t and -u conflict\n", progname);
			exit(2);
		}
	} else {
		if (!user)
			user = get_username();
		strncpy(lname, user, sizeof(lname));
	}

	r = krb5_init_context(&ctx);
	if (r) {
		com_err(progname, r, "while initializing Kerberos");
		return 3;
	}

	all_ok = 1;
	for (i = optind; i < argc; i++) {
		princ = NULL;
		princname = NULL;
		ok = 0;

		r = krb5_parse_name_flags(ctx, argv[i], parseflags, &princ);
		if (r) {
			if (!quiet)
				printf("%s %s %s\n",
					argv[i],
					"*",
					"malformed");
			goto next;
		}

		if (translate) {
			r = krb5_aname_to_localname(ctx, princ,
						sizeof(lname), lname);
			if (r) {
				lname[0] = '*';
				lname[1] = 0;
				ok = 0;
			} else
				ok = krb5_kuserok(ctx, princ, lname);
		} else
			ok = krb5_kuserok(ctx, princ, lname);

		r = krb5_unparse_name(ctx, princ, &princname);

		if (!quiet)
			printf("%s %s %s\n",
				r ? argv[i] : princname,
				lname,
				ok ? "allowed" : "denied");

	next:
		all_ok = all_ok && ok;

		if (princ)
			krb5_free_principal(ctx, princ);
		if (princname)
			krb5_free_unparsed_name(ctx, princname);
	}

	krb5_free_context(ctx);

	return all_ok ? 0 : 1;
}
