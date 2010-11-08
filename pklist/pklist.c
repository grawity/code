/*
 * pklist.c
 *
 * Parseable `klist`.
 *
 * © 2010 <grawity@gmail.com>
 * Relesed under WTFPL v2 <http://sam.zoy.org/wtfpl/>
 * Portions of code lifted from MIT Kerberos (clients/klist/klist.c)
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <krb5.h>
#include <krb5_ccapi.h>

#include "strflags.h"

char *progname;
krb5_context ctx;
char *defname;

void do_ccache(char *name);

void show_cred(register krb5_creds *cred);

int main(int argc, char *argv[]) {
	int opt;
	char *ccname;
	krb5_error_code retval;

	progname = "pklist";

	ccname = NULL;
	while ((opt = getopt(argc, argv, "c")) != -1) {
		switch (opt) {
		case 'c':
			ccname = argv[optind++];
			break;
		}
	}

	retval = krb5_init_context(&ctx);
	if (retval) {
		com_err(progname, retval, "while initializing krb5");
		exit(1);
	}

	do_ccache(ccname);
	return 0;
}

void do_ccache(char *name) {
	krb5_ccache cache = NULL;
	krb5_cc_cursor cur;
	krb5_creds creds;
	krb5_principal princ;
	krb5_flags flags;
	krb5_error_code retval;

	if (name == NULL) {
		if ((retval = krb5_cc_default(ctx, &cache))) {
			com_err(progname, retval, "while getting default ccache");
			exit(1);
		}
	} else {
		if ((retval = krb5_cc_resolve(ctx, name, &cache))) {
			com_err(progname, retval, "while resolving ccache %s", name);
			exit(1);
		}
	}

	flags = 0;
	if ((retval = krb5_cc_set_flags(ctx, cache, flags))) {
		if (retval == KRB5_FCC_NOFILE) {
			com_err(progname, retval, "(ticket cache %s:%s)",
				krb5_cc_get_type(ctx, cache),
				krb5_cc_get_name(ctx, cache));
		} else {
			com_err(progname, retval, "while setting cache flags (ticket cache %s:%s)",
				krb5_cc_get_type(ctx, cache),
				krb5_cc_get_name(ctx, cache));
		}
		exit(1);
	}
	if ((retval = krb5_cc_get_principal(ctx, cache, &princ))) {
		com_err(progname, retval, "while retrieving principal name");
		exit(1);
	}
	if ((retval = krb5_unparse_name(ctx, princ, &defname))) {
		com_err(progname, retval, "while unparsing principal name");
		exit(1);
	}

	printf("cache\t%s:%s\n", krb5_cc_get_type(ctx, cache), krb5_cc_get_name(ctx, cache));
	printf("principal\t%s\n", defname);

	if ((retval = krb5_cc_start_seq_get(ctx, cache, &cur))) {
		com_err(progname, retval, "while starting to retrieve tickets");
		exit(1);
	}
	while (!(retval = krb5_cc_next_cred(ctx, cache, &cur, &creds))) {
		if (krb5_is_config_principal(ctx, creds.server)) {
			printf("=== is_config_principal\n");
			//continue;
		}
		show_cred(&creds);
		krb5_free_cred_contents(ctx, &creds);
	}
	if (retval == KRB5_CC_END) {
		if ((retval = krb5_cc_end_seq_get(ctx, cache, &cur))) {
			com_err(progname, retval, "while finishing ticket retrieval");
			exit(1);
		}
#if 0
		flags = KRB5_TC_OPENCLOSE;
		if ((retval = krb5_cc_set_flags(ctx, cache, flags))) {
			com_err(progname, retval, "while closing ccache");
			exit(1);
		}
#endif
		exit(0);
	} else {
		com_err(progname, retval, "while retrieving a ticket");
		exit(1);
	}
}

void show_cred(register krb5_creds *cred) {
	krb5_error_code retval;
	krb5_ticket *tkt;
	char *name, *sname, *flags;

	if ((retval = krb5_unparse_name(ctx, cred->client, &name))) {
		com_err(progname, retval, "while unparsing client name");
		return;
	}
	if ((retval = krb5_unparse_name(ctx, cred->server, &sname))) {
		com_err(progname, retval, "while unparsing server name");
		krb5_free_unparsed_name(ctx, name);
		return;
	}

	if (!cred->times.starttime)
		cred->times.starttime = cred->times.authtime;
	
	// "ticket" server client start renew flags
	printf("ticket");
	if (strcmp(name, defname))
		printf("\t%s", name);
	else
		printf("\t*");
	printf("\t%s", sname);
	printf("\t%d", cred->times.starttime);
	printf("\t%d", cred->times.endtime);
	printf("\t%d", cred->times.renew_till);

	flags = strflags(cred);
	if (flags && *flags)
		printf("\t%s", flags);
	else if (flags)
		printf("\t-");
	else
		printf("\t?");
	
	printf("\n");

	krb5_free_unparsed_name(ctx, name);
	krb5_free_unparsed_name(ctx, sname);
}
