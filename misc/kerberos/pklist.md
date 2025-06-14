# pklist - machine-readable Kerberos ticket list

## Installation

    cc -o pklist pklist.c -lkrb5 -lcom_err

Or run `make pklist` from repository root.

## Command-line options

  * `-C`: list config principals
  * `-CC`: list raw config principal names
  * `-c type:rest`: list contents of a specific ccache
  * `-l`: list ccaches in a collection
  * `-ll`: list contents of all ccaches
  * `-N`: print only the ccache name
  * `-P`: print only the default client principal
  * `-p`: print only tickets' principal names
  * `-R`: print only the configured default realm
  * `-r fqdn`: print only the realm for given FQDN
  * `-T`: print ticket data

## Output format

Basic format consists of tab-separated fields, the zeroth of which is type:

### "cache"

Always the first line when describing a new credential cache.

In default mode:

 1. Kerberos 5 credential cache name

In "list collection caches" mode:

 1. credential cache name
 2. default client principal name (as `principal` above)

These two lines are merged in order to display one cache per line.

### "principal"

In default mode:

 1. default client principal name

In "list collection caches" mode, merged with `cache` as above.

### "ticket", "cfgticket"

`ticket` is a normal Kerberos credential. `cfgticket` is a configuration item, used internally by krb5 and not shown unless `-CC` is specified.

If the ticket is a configuration ticket, or if `-T` is specified, the raw ticket data will be output as the last field.

 1. client principal name
 2. server principal name
 3. "valid starting" time
 4. expiry time
 5. renewable until time (0 if ticket not renewable)
 6. ticket flags
 7. ticket data (only if `-T` is given if a normal ticket)

### "config"

`config` is a configuration item, shown as a name/value pair with the name separated into multiple components. Only shown if `-C` is specified.

 1. number of name components
 2. *multiple* name components
 3. value (octal-encoded)

Common values for the first component are `fast_avail` (server supports FAST) and `pa_type` (preauth type used when obtaining this TGT). The second component in both cases is the TGT's server principal.

### "default"

In "list collection caches" mode:

 1. name of the default credential cache

## Headers

Some modes output a header line, which has type in all uppercase (such as `CREDENTIALS`) and following fields acting as column headers for following output lines. This is only for informational purposes and should not be relied upon.

When any of `-N`, `-P`, `-p`, `-R`, or `-r` is given, _only_ the requested data is displayed, without any type prefix.

## Flags

Flags mostly match those documented in `klist(1)`:

  * `F`, `f` – Forwardable and forwarded
  * `P`, `p` – Proxiable and proxy
  * `D`, `d` – postDateable and postdated
  * `R` – Renewable
  * `I` – Initial (`AP_REQ`)
  * `i` – invalid
  * `A` – preAuthenticated
  * `H` – hardware authenticated
  * `T` – transit policy checked
  * `O` – Okay as delegate
  * `a` – anonymous`

## Collections

MIT Kerberos 1.10, as well as Heimdal for quite a while, have support for collections of several credential caches. When implemented by the Krb5 libraries, it is possible to obtain credentials for several unrelated realms at once and have the correct principal chosen automatically.

With MIT Krb5 1.10, one such type is `DIR` caches, where the residual points to an existing directory, and Krb5 automatically creates new file-based caches for each principal given to `kinit`. The correct cache to use can be chosen based on the user's `k5identity(5)` file.

    mkdir "/run/user/grawity/krb5cc"
    export KRB5CCNAME="DIR:/run/user/grawity/krb5cc"
    kinit grawity@NULLROUTE.EU.ORG
    kinit grawity@CLUENET.ORG
    ...

