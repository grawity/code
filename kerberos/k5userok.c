/*
 * k5userok.c - verify user access according to krb5_userok()
 *
 * © 2012 Mantas M. <grawity@gmail.com>
 * Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>
 */

#define _XOPEN_SOURCE

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <krb5/krb5.h>
#include <et/com_err.h>

#ifdef KRB5_KRB5_H_INCLUDED
#	define KRB5_MIT
#elif defined(__KRB5_H__)
#	define KRB5_HEIMDAL
#endif

#ifdef KRB5_HEIMDAL
#	define krb5_free_unparsed_name(ctx, name)	krb5_xfree(name)
#endif

char *progname = "k5userok";

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
			parseflags |= KRB5_PRINCIPAL_PARSE_ENTERPRISE;
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
			user = cuserid(NULL);
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
