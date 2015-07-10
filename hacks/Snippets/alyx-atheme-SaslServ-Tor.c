#include "atheme.h"

DECLARE_MODULE_V1(
        "saslserv/tor", false, _modinit, _moddeinit,
        PACKAGE_STRING,
        "Alyx <alyx@malkier.net>"
        );

static void on_user_identify(user_t *u);
static void on_user_sethost(user_t *u);

void _modinit(module_t *m)
{
    hook_add_event("user_identify");
    hook_add_user_identify(on_user_identify);
    hook_add_event("user_sethost");
    hook_add_user_sethost(on_user_sethost);
}

void _moddeinit(module_unload_intent_t intent)
{
    hook_del_user_identify(on_user_identify);
    hook_del_user_sethost(on_user_sethost);
}

static void do_sethost(user_t *u, char *host)
{
    service_t *svs;

        if (!strcmp(u->vhost, host ? host : u->host))
                return;

    svs = service_find("saslserv");

    strshare_unref(u->vhost);
    u->vhost = strshare_get(host ? host : u->host);

        user_sethost(svs->me, u, u->vhost);
}

static void on_user_identify(user_t *u)
{
    myuser_t *mu = u->myuser;
    metadata_t *md;
    char buf[NICKLEN + 20], host[BUFSIZE];

    if (strcmp(u->host, "tor.") != 0)
        return;

    snprintf(buf, sizeof buf, "private:usercloak:%s", u->nick);
    md = metadata_find(mu, buf);
    if (md == NULL)
        md = metadata_find(mu, "private:usercloak");
    if (md != NULL)
        return;

    snprintf(host, sizeof host, "%s.tor.arinity.org", entity(u->myuser)->name);
    do_sethost(u, host);
}

void on_user_sethost(user_t *u)
{
    char buf[BUFSIZE];

    if(strcmp(u->host, "tor.") != 0)
        return;
    
    if (strcmp(u->vhost, u->host) == 0)
    {
        snprintf(buf, sizeof buf, "%s.tor.arinity.org", entity(u->myuser)->name);
        do_sethost(u, buf);
    }
}