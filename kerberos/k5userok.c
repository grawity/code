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
#include <krb5.h>

char *progname = "k5userok";

void usage(void) {
	fprintf(stderr, "Usage: %s [-qt] [-u user] principal...\n", progname);
	fprintf(stderr,
		"\n"
		"\t-q         do not output anything, only use exit code\n"
		"\t-t         translate principals to usernames\n"
		"\t-u user    check all principals against given user\n"
		"\n");
	exit(EXIT_FAILURE);
}

int main(int argc, char *argv[]) {
	int		opt;
	int		translate = 0;
	int		quiet = 0;
	char		*user = NULL;

	krb5_error_code	r;
	krb5_context	ctx;
	krb5_boolean	all_ok;

	int		i;
	krb5_principal	princ;
	char		lname[256];
	char		*princname;
	krb5_boolean	ok;
	char		*ok_str;

	while ((opt = getopt(argc, argv, "qtu:")) != -1) {
		switch (opt) {
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

	if (!translate) {
		if (!user)
			user = cuserid(NULL);
		if (!quiet)
			printf("# for user: %s\n", user);
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

		r = krb5_parse_name_flags(ctx, argv[i], 0, &princ);
		if (r) {
			com_err(progname, r, "while parsing '%s'", argv[i]);
			if (!quiet)
				printf("%s %s %s\n", argv[i], "*", "invalid");
			goto next;
		}

		if (translate) {
			r = krb5_aname_to_localname(ctx, princ, sizeof(lname), lname);
			if (r) {
				strcpy(lname, "*");
				ok = 0;
			} else {
				ok = krb5_kuserok(ctx, princ, lname);
			}
		} else {
			ok = krb5_kuserok(ctx, princ, lname);
		}
		ok_str = ok ? "allowed" : "denied";
		all_ok = all_ok && ok;

		r = krb5_unparse_name(ctx, princ, &princname);
		if (r == 0) {
			if (!quiet)
				printf("%s %s %s\n", princname, lname, ok_str);
		} else {
			com_err(progname, r, "while unparsing name");
			if (!quiet)
				printf("%s %s %s\n", argv[i], lname, ok_str);
		}

	next:
		if (princ)
			krb5_free_principal(ctx, princ);
		if (princname)
			krb5_free_unparsed_name(ctx, princname);
	}

	krb5_free_context(ctx);

	return all_ok ? 0 : 1;
}
