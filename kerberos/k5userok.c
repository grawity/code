/*
 * k5userok.c - verify user access according to krb5_userok()
 *
 * © 2012 Mantas M. <grawity@gmail.com>
 * Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>
 */

#define _XOPEN_SOURCE

#include <stdio.h>
#include <unistd.h>
#include <krb5.h>

char *progname = "k5userok";

void usage(void) {
	fprintf(stderr, "Usage: %s [-u user] principal...\n", progname);
	fprintf(stderr,
		"\n"
		"\t-u user    perform check for given user instead of current UID\n"
		"\n");
	exit(EXIT_FAILURE);
}

int main(int argc, char *argv[]) {
	int		opt;
	int		quiet = 0;
	char		*user = NULL;

	krb5_error_code	r;
	krb5_context	ctx;
	krb5_boolean	all_ok;

	int		i;
	krb5_principal	princ;
	char		*princname;
	krb5_boolean	ok;

	while ((opt = getopt(argc, argv, "qu:")) != -1) {
		switch (opt) {
		case 'q':
			++quiet;
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

	if (!user)
		user = cuserid(user);
	
	if (!quiet)
		printf("# for user: %s\n", user);

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
				printf("%s %s\n", argv[i], "invalid");
			goto next;
		}

		ok = krb5_kuserok(ctx, princ, user);
		all_ok = all_ok && ok;

		r = krb5_unparse_name(ctx, princ, &princname);
		if (r) {
			com_err(progname, r, "while unparsing name");
			if (!quiet)
				printf("%s %s\n", argv[i], ok ? "allowed" : "denied");
			goto next;
		}

		if (!quiet)
			printf("%s %s\n", princname, ok ? "allowed" : "denied");

	next:
		if (princ)
			krb5_free_principal(ctx, princ);
		if (princname)
			krb5_free_unparsed_name(ctx, princname);
	}

	krb5_free_context(ctx);

	return all_ok ? 0 : 1;
}
