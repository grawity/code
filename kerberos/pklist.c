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
#endif

#ifdef KRB5_HEIMDAL
#	include <krb5_ccapi.h>
#	define krb5_free_default_realm(ctx, realm)	krb5_xfree(realm)
#	define krb5_free_host_realm(ctx, realm)		krb5_xfree(realm)
#	define krb5_free_unparsed_name(ctx, name)	krb5_xfree(name)
#endif

char *progname = "pklist";
krb5_context ctx;
int show_cfg_tkts = 0;
int show_collection_only = 0;
int show_ccname_only = 0;
int show_defname_only = 0;
int show_names_only = 0;
int show_realm_only = 0;

void do_ccache(char *name);

void do_cccol();

void do_realm(char *host);

void show_cred(register krb5_creds *cred);

char * strflags(register krb5_creds *cred);

int main(int argc, char *argv[]) {
	int opt;
	extern char *optarg;

	char *ccname = NULL;
	char *hostname = NULL;
	krb5_error_code retval;

	while ((opt = getopt(argc, argv, "Cc:lNPpRr:")) != -1) {
		switch (opt) {
		case 'C':
			show_cfg_tkts = 1;
			break;
		case 'c':
			ccname = optarg;
			break;
		case 'l':
			show_collection_only = 1;
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
		case 'R':
			show_realm_only = 1;
			break;
		case 'r':
			show_realm_only = 1;
			hostname = optarg;
			break;
		case '?':
		default:
			fprintf(stderr, "Usage: %s [-C] [-N | -P | -p | -R | -r hostname] [-c ccname]\n", argv[0]);
			fprintf(stderr,
				"\n"
				"\t-C       also list config principals\n"
				"\t-N       show ccache name\n"
				"\t-P       show default client principal\n"
				"\t-p       show principal names\n"
				"\t-R       show default realm\n"
				"\t-r host  show realm for given FQDN\n");
			exit(EXIT_FAILURE);
		}
	}

	retval = krb5_init_context(&ctx);
	if (retval) {
		com_err(progname, retval, "while initializing krb5");
		exit(1);
	}

	if (show_collection_only) {
		do_cccol();
	} else if (show_realm_only) {
		do_realm(hostname);
	} else {
		do_ccache(ccname);
	}
	return 0;
}

void do_cccol() {
	krb5_error_code retval;
	krb5_cccol_cursor cursor;
	krb5_ccache cache;

	krb5_principal princ = NULL;
	char *princname = NULL;

	printf("default\t%s\n",
		krb5_cc_default_name(ctx));

	printf("COLLECTION\tccname\tprincipal\n");
	if ((retval = krb5_cccol_cursor_new(ctx, &cursor))) {
		com_err(progname, retval, "while listing ccache collection");
		exit(1);
	}
	while (!(retval = krb5_cccol_cursor_next(ctx, cursor, &cache))) {
		if (cache == NULL)
			break;
		if ((retval = krb5_cc_get_principal(ctx, cache, &princ)))
			goto cleanup;
		if ((retval = krb5_unparse_name(ctx, princ, &princname)))
			goto cleanup;
		printf("ccache\t%s:%s\t%s\n",
			krb5_cc_get_type(ctx, cache),
			krb5_cc_get_name(ctx, cache),
			princname);

cleanup:
		krb5_cc_close(ctx, cache);
		krb5_free_principal(ctx, princ);
		free(princname);
		free(cache);
	}
	krb5_cccol_cursor_free(ctx, &cursor);
}

void do_realm(char *hostname) {
	char **realm;
	int retval;

	if (hostname) {
		if ((retval = krb5_get_host_realm(ctx, hostname, &realm))) {
			com_err(progname, retval, "while obtaining realm for %s", hostname);
			exit(1);
		}
		printf("%s\n", *realm);
		krb5_free_host_realm(ctx, realm);
	} else {
		/* TODO: is this correct? */
		realm = malloc(sizeof(char*));
		if ((retval = krb5_get_default_realm(ctx, realm))) {
			com_err(progname, retval, "while obtaining default realm");
			exit(1);
		}
		printf("%s\n", *realm);
		krb5_free_default_realm(ctx, *realm);
	}
}

/*
 * output the ccache contents
 */
void do_ccache(char *name) {
	krb5_ccache cache = NULL;
	krb5_cc_cursor cur;
	krb5_creds creds;
	krb5_principal princ;
	krb5_flags flags;
	krb5_error_code retval;
	char *defname;

	// display cache and principal names

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

	// list all tickets

	if (!show_names_only) {
		printf("CREDS\tclient_name\tserver_name\tstart_time\texpiry_time\trenew_time\tflags\n");
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
		exit(0);
	} else {
		com_err(progname, retval, "while retrieving a ticket");
		exit(1);
	}
}

/*
 * output a single credential (ticket)
 */
void show_cred(register krb5_creds *cred) {
	krb5_error_code retval;
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

	printf("\t%s", name);

	printf("\t%s", sname);
	printf("\t%d", (uint) cred->times.starttime);
	printf("\t%d", (uint) cred->times.endtime);
	printf("\t%d", (uint) cred->times.renew_till);

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

/*
 * return Kerberos credential flags in ASCII
 */
char * strflags(register krb5_creds *cred) {
	static char buf[16];
	int i = 0;

#ifdef KRB5_HEIMDAL
	struct TicketFlags flags = cred->flags.b;

	if (flags.forwardable)			buf[i++] = 'F';
	if (flags.forwarded)			buf[i++] = 'f';
	if (flags.proxiable)			buf[i++] = 'P';
	if (flags.proxy)			buf[i++] = 'p';
	if (flags.may_postdate)			buf[i++] = 'D';
	if (flags.postdated)			buf[i++] = 'd';
	if (flags.invalid)			buf[i++] = 'i';
	if (flags.renewable)			buf[i++] = 'R';
	if (flags.initial)			buf[i++] = 'I';
	if (flags.hw_authent)			buf[i++] = 'H';
	if (flags.pre_authent)			buf[i++] = 'A';
	if (flags.transited_policy_checked)	buf[i++] = 'T';
	if (flags.ok_as_delegate)		buf[i++] = 'O';
	if (flags.anonymous)			buf[i++] = 'a';
#else
	krb5_flags flags = cred->ticket_flags;

	if (flags & TKT_FLG_FORWARDABLE)		buf[i++] = 'F';
	if (flags & TKT_FLG_FORWARDED)			buf[i++] = 'f';
	if (flags & TKT_FLG_PROXIABLE)			buf[i++] = 'P';
	if (flags & TKT_FLG_PROXY)			buf[i++] = 'p';
	if (flags & TKT_FLG_MAY_POSTDATE)		buf[i++] = 'D';
	if (flags & TKT_FLG_POSTDATED)			buf[i++] = 'd';
	if (flags & TKT_FLG_INVALID)			buf[i++] = 'i';
	if (flags & TKT_FLG_RENEWABLE)			buf[i++] = 'R';
	if (flags & TKT_FLG_INITIAL)			buf[i++] = 'I';
	if (flags & TKT_FLG_HW_AUTH)			buf[i++] = 'H';
	if (flags & TKT_FLG_PRE_AUTH)			buf[i++] = 'A';
	if (flags & TKT_FLG_TRANSIT_POLICY_CHECKED)	buf[i++] = 'T';
	if (flags & TKT_FLG_OK_AS_DELEGATE)		buf[i++] = 'O';
	if (flags & TKT_FLG_ANONYMOUS)			buf[i++] = 'a';
#endif

	buf[i] = '\0';	
	return buf;
}
