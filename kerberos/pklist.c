/*
 * pklist.c
 *
 * Parseable `klist`.
 *
 * © 2010 <grawity@gmail.com>
 * Relesed under WTFPL v2 <http://sam.zoy.org/wtfpl/>
 * Portions of code lifted from MIT Kerberos (clients/klist/klist.c)
 */

#define _GNU_SOURCE

#define HAVE_COLLECTIONS

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
int show_collection = 0;
int show_ccname_only = 0;
int show_defname_only = 0;
int show_names_only = 0;
int show_realm_only = 0;
int show_header_only = 0;
int quiet_errors = 0;

int do_realm(char*);
int do_ccache(krb5_ccache);
int do_ccache_by_name(char*);
int do_collection();
void show_cred(register krb5_creds*);
char* strflags(register krb5_creds*);
krb5_error_code krb5_cc_get_principal_name(krb5_context, krb5_ccache, char**);
krb5_ccache resolve_ccache(char*);

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
			show_collection++;
			quiet_errors = 1;
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
			fprintf(stderr, "Usage: %s [-C] [-l] [-N | -P | -p | -R | -r hostname] [-c ccname]\n", progname);
			fprintf(stderr,
				"\n"
				"\t-C         also list config principals\n"
				"\t-c ccname  show contents of given ccache\n"
				"\t-l         list known ccaches\n"
				"\t-ll        - also show contents\n"
				"\t-N         only show ccache name\n"
				"\t-P         show default client principal\n"
				"\t-p         only show principal names\n"
				"\t-R         show default realm\n"
				"\t-r host    show realm for given FQDN\n");
			exit(EXIT_FAILURE);
		}
	}

	retval = krb5_init_context(&ctx);
	if (retval) {
		com_err(progname, retval, "while initializing krb5");
		exit(1);
	}

	if (show_collection) {
		return do_collection();
	} else if (show_realm_only) {
		return do_realm(hostname);
	} else {
		return do_ccache_by_name(ccname);
	}
}

/*
 * Find the realm for given hostname
 */
int do_realm(char *hostname) {
	krb5_error_code	retval;
	char		**realm;

	if (hostname) {
		if ((retval = krb5_get_host_realm(ctx, hostname, &realm))) {
			com_err(progname, retval, "while obtaining realm for %s", hostname);
			exit(1);
		}
		printf("%s\n", *realm);
		krb5_free_host_realm(ctx, realm);
	} else {
		realm = malloc(sizeof(realm));
		if ((retval = krb5_get_default_realm(ctx, realm))) {
			com_err(progname, retval, "while obtaining default realm");
			exit(1);
		}
		printf("%s\n", *realm);
		krb5_free_default_realm(ctx, *realm);
		free(realm);
	}
	return 0;
}

/*
 * output the ccache contents
 */
int do_ccache(krb5_ccache cache) {
	char		*ccname = NULL;
	krb5_creds	creds;
	krb5_cc_cursor	cursor;
	krb5_principal	princ = NULL;
	char		*princname = NULL;
	krb5_flags	flags = 0;
	krb5_error_code	retval;
	int		status = 1;

	asprintf(&ccname, "%s:%s",
		krb5_cc_get_type(ctx, cache),
		krb5_cc_get_name(ctx, cache));
	if (!ccname)
		goto cleanup;

	if (show_ccname_only && !show_collection) {
		// With just -N, always show the name...
		printf("%s\n", ccname);
		status = 0;
		goto cleanup;
	}

	if ((retval = krb5_cc_set_flags(ctx, cache, flags))) {
		if (quiet_errors)
			;
		else if (retval == KRB5_FCC_NOFILE)
			com_err(progname, retval, "(ticket cache %s)", ccname);
		else
			com_err(progname, retval, "while setting cache flags (ticket cache %s)", ccname);
		goto cleanup;
	}
	if (krb5_cc_get_principal(ctx, cache, &princ)) {
		goto cleanup;
	}
	if (krb5_unparse_name(ctx, princ, &princname))
		goto cleanup;

	if (show_ccname_only && show_collection) {
		// ...with -l -N, only show names pointing to valid ccaches.
		printf("%s\n", ccname);
		status = 0;
		goto cleanup;
	}

	if (show_defname_only) {
		printf("%s\n", princname);
		status = 0;
		goto cleanup;
	}

	if (!show_names_only) {
		if (show_collection == 1) {
			// only show the header
			printf("cache\t%s\t%s\n", ccname, princname);
			status = 0;
			goto cleanup;
		} else {
			// TODO: should the format be merged into the one above?
			// separate cache/principal kept for now, for compat reasons
			printf("cache\t%s\n", ccname);
			printf("principal\t%s\n", princname);
		}
		printf("CREDENTIALS\tclient_name\tserver_name\tstart_time\texpiry_time\trenew_time\tflags\n");
	}

	if ((retval = krb5_cc_start_seq_get(ctx, cache, &cursor))) {
		com_err(progname, retval, "while starting to retrieve tickets");
		goto cleanup;
	}
	while (!(retval = krb5_cc_next_cred(ctx, cache, &cursor, &creds))) {
		if (!show_cfg_tkts && krb5_is_config_principal(ctx, creds.server))
			continue;
		show_cred(&creds);
		krb5_free_cred_contents(ctx, &creds);
	}
	if (retval == KRB5_CC_END) {
		if ((retval = krb5_cc_end_seq_get(ctx, cache, &cursor))) {
			com_err(progname, retval, "while finishing ticket retrieval");
		} else {
			status = 0;
		}
		goto cleanup;
	} else {
		com_err(progname, retval, "while retrieving a ticket");
		goto cleanup;
	}

cleanup:
	if (princ)
		krb5_free_principal(ctx, princ);
	if (princname)
		krb5_free_unparsed_name(ctx, princname);
	if (ccname)
		free(ccname);
	return status;
}

krb5_ccache resolve_ccache(char *name) {
	krb5_ccache		cache = NULL;
	krb5_error_code		retval;

	if (name == NULL) {
		if ((retval = krb5_cc_default(ctx, &cache))) {
			com_err(progname, retval, "while getting default ccache");
		}
	} else {
		if ((retval = krb5_cc_resolve(ctx, name, &cache))) {
			com_err(progname, retval, "while resolving ccache %s", name);
		}
	}
	return cache;
}

/*
 * resolve a ccache and output its contents
 */
int do_ccache_by_name(char *name) {
	krb5_ccache		cache;
	int			status = 1;

	cache = resolve_ccache(name);
	if (cache) {
		status = do_ccache(cache);
		krb5_cc_close(ctx, cache);
	}
	return status;
}

/*
 * Display all ccaches in a collection, in short form.
 */
int do_collection() {
#ifdef HAVE_COLLECTIONS
	krb5_error_code		retval;
	krb5_cccol_cursor	cursor;
	krb5_ccache		cache;
#endif

	if (!show_ccname_only && !show_names_only && !show_defname_only) {
		printf("default\t%s\n",
			krb5_cc_default_name(ctx));
		printf("COLLECTION\tccname\tprincipal\n");
	}

#ifdef HAVE_COLLECTIONS
	if ((retval = krb5_cccol_cursor_new(ctx, &cursor))) {
		com_err(progname, retval, "while listing ccache collection");
		exit(1);
	}
	while (!(retval = krb5_cccol_cursor_next(ctx, cursor, &cache))) {
		if (cache == NULL)
			break;
		do_ccache(cache);
		krb5_cc_close(ctx, cache);
	}
	krb5_cccol_cursor_free(ctx, &cursor);
	return 0;
#else
	return do_ccache_by_name(NULL);
#endif
}

/*
 * output a single credential (ticket)
 */
void show_cred(register krb5_creds *cred) {
	krb5_error_code	retval;
	char		*clientname;
	char		*servername;
	char		*flags;

	if ((retval = krb5_unparse_name(ctx, cred->client, &clientname))) {
		com_err(progname, retval, "while unparsing client name");
		goto cleanup;
	}
	if ((retval = krb5_unparse_name(ctx, cred->server, &servername))) {
		com_err(progname, retval, "while unparsing server name");
		goto cleanup;
	}

	if (show_names_only) {
		printf("%s\n", servername);
		goto cleanup;
	}

	if (!cred->times.starttime)
		cred->times.starttime = cred->times.authtime;
	
	// "ticket" server client start renew flags
	if (krb5_is_config_principal(ctx, cred->server))
		printf("cfgticket");
	else
		printf("ticket");

	printf("\t%s", clientname);
	printf("\t%s", servername);
	printf("\t%ld", (ulong) cred->times.starttime);
	printf("\t%ld", (ulong) cred->times.endtime);
	printf("\t%ld", (ulong) cred->times.renew_till);

	flags = strflags(cred);
	if (flags && *flags)
		printf("\t%s", flags);
	else if (flags)
		printf("\t-");
	else
		printf("\t?");

	printf("\n");

cleanup:
	if (clientname)
		krb5_free_unparsed_name(ctx, clientname);
	if (servername)
		krb5_free_unparsed_name(ctx, servername);
}

/*
 * return Kerberos credential flags in ASCII
 *
 * TODO: can MIT and Heimdal use the same code?
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
