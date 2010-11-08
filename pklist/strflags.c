#include <krb5.h>
#include <krb5_ccapi.h>

char * strflags(register krb5_creds *cred) {
	static char buf[16];
	int i = 0;

#ifdef HEIMDAL_TKTFLAGS
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

	if (flags & TGT_FLG_FORWARDABLE)
		buf[i++] = 'F';
	if (flags & TGT_FLG_FORWARDED)
		buf[i++] = 'f';
	if (flags & TGT_FLG_PROXIABLE)
		buf[i++] = 'P';
	if (flags & TGT_FLG_PROXY)
		buf[i++] = 'p';
	if (flags & TGT_FLG_MAY_POSTDATE)
		buf[i++] = 'D';
	if (flags & TGT_FLG_POSTDATED)
		buf[i++] = 'd';
	if (flags & TGT_FLG_INVALID)
		buf[i++] = 'i';
	if (flags & TGT_FLG_RENEWABLE)
		buf[i++] = 'R';
	if (flags & TGT_FLG_INITIAL)
		buf[i++] = 'I';
	if (flags & TGT_FLG_HW_AUTH)
		buf[i++] = 'H';
	if (flags & TGT_FLG_PRE_AUTH)
		buf[i++] = 'A';
	if (flags & TGT_FLG_TRANSIT_POLICY_CHECKED)
		buf[i++] = 'T';
	if (flags & TGT_FLG_OK_AS_DELEGATE)
		buf[i++] = 'O';
	if (flags & TGT_FLG_ANONYMOUS)
		buf[i++] = 'a';
#endif

	buf[i] = '\0';	
	return buf;
}
