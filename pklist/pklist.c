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
#include <unistd.h>
#include <string.h>
#include <krb5.h>

#ifdef KRB5_KRB5_H_INCLUDED
#	define KRB5_MIT
#elif defined(__KRB5_H__)
#	define KRB5_HEIMDAL
#	include <krb5_ccapi.h>
#	define krb5_free_unparsed_name(ctx, name) krb5_xfree(name)
#endif

char *progname;
krb5_context ctx;
int show_cfg_tkts = 0;
int show_ccname_only = 0;
int show_defname_only = 0;
int show_names_only = 0;
char *defname;

void do_ccache(char *name);

void show_cred(register krb5_creds *cred);

char * strflags(register krb5_creds *cred);

int main(int argc, char *argv[]) {
	int opt;
	char *ccname;
	extern char *optarg;
	krb5_error_code retval;

	progname = "pklist";

	ccname = NULL;
	while ((opt = getopt(argc, argv, "Cc:NPp")) != -1) {
		switch (opt) {
		case 'C':
			show_cfg_tkts = 1;
			break;
		case 'c':
			ccname = optarg;
			break;
		case 'N':
			show_ccname_only = 1;
			break;
		case 'P':
			show_defname_only = 1;
			break;
		case 'p':
			show_names_only = 1;
			break;
		case '?':
		default:
			fprintf(stderr, "Usage: %s [-C | -N | -P | -p] [-c ccname]\n", argv[0]);
			exit(EXIT_FAILURE);
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

	if (show_ccname_only) {
		printf("%s:%s\n",
			krb5_cc_get_type(ctx, cache),
			krb5_cc_get_name(ctx, cache));
		return;
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

	if (show_defname_only) {
		printf("%s\n", defname);
		return;
	}

	if (!show_names_only) {
		printf("cache\t%s:%s\n",
			krb5_cc_get_type(ctx, cache),
			krb5_cc_get_name(ctx, cache));
		printf("principal\t%s\n", defname);
	}

	if ((retval = krb5_cc_start_seq_get(ctx, cache, &cur))) {
		com_err(progname, retval, "while starting to retrieve tickets");
		exit(1);
	}
	while (!(retval = krb5_cc_next_cred(ctx, cache, &cur, &creds))) {
		if (krb5_is_config_principal(ctx, creds.server) && !show_cfg_tkts)
			continue;
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

	if (show_names_only) {
		printf("%s\n", sname);
		return;
	}

	if (!cred->times.starttime)
		cred->times.starttime = cred->times.authtime;
	
	// "ticket" server client start renew flags
	if (krb5_is_config_principal(ctx, cred->server))
		printf("cfgticket");
	else
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

char * strflags(register krb5_creds *cred) {
	static char buf[16];
	int i = 0;

#ifdef KRB5_HEIMDAL
	struct TicketFlags flags = cred->flags.b;

	if (flags.forwardable)
		buf[i++] = 'F';
	if (flags.forwarded)
		buf[i++] = 'f';
	if (flags.proxiable)
		buf[i++] = 'P';
	if (flags.proxy)
		buf[i++] = 'p';
	if (flags.may_postdate)
		buf[i++] = 'D';
	if (flags.postdated)
		buf[i++] = 'd';
	if (flags.invalid)
		buf[i++] = 'i';
	if (flags.renewable)
		buf[i++] = 'R';
	if (flags.initial)
		buf[i++] = 'I';
	if (flags.hw_authent)
		buf[i++] = 'H';
	if (flags.pre_authent)
		buf[i++] = 'A';
	if (flags.transited_policy_checked)
		buf[i++] = 'T';
	if (flags.ok_as_delegate)
		buf[i++] = 'O';
	if (flags.anonymous)
		buf[i++] = 'a';
#else
	krb5_flags flags = cred->ticket_flags;

	if (flags & TKT_FLG_FORWARDABLE)
		buf[i++] = 'F';
	if (flags & TKT_FLG_FORWARDED)
		buf[i++] = 'f';
	if (flags & TKT_FLG_PROXIABLE)
		buf[i++] = 'P';
	if (flags & TKT_FLG_PROXY)
		buf[i++] = 'p';
	if (flags & TKT_FLG_MAY_POSTDATE)
		buf[i++] = 'D';
	if (flags & TKT_FLG_POSTDATED)
		buf[i++] = 'd';
	if (flags & TKT_FLG_INVALID)
		buf[i++] = 'i';
	if (flags & TKT_FLG_RENEWABLE)
		buf[i++] = 'R';
	if (flags & TKT_FLG_INITIAL)
		buf[i++] = 'I';
	if (flags & TKT_FLG_HW_AUTH)
		buf[i++] = 'H';
	if (flags & TKT_FLG_PRE_AUTH)
		buf[i++] = 'A';
	if (flags & TKT_FLG_TRANSIT_POLICY_CHECKED)
		buf[i++] = 'T';
	if (flags & TKT_FLG_OK_AS_DELEGATE)
		buf[i++] = 'O';
	if (flags & TKT_FLG_ANONYMOUS)
		buf[i++] = 'a';
#endif

	buf[i] = '\0';	
	return buf;
}
