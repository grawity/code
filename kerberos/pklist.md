# pklist - machine-readable Kerberos ticket list

## Installation

    make pklist

## Command-line options

  * `-C`: also list config principals (used by Kerberos internally)
  * `-c type:rest`: list contents of a specific ccache
  * `-l`: list ccaches in a collection
  * `-ll`: list contents of all ccaches
  * `-N`: print only the ccache name
  * `-P`: print only the default client principal
  * `-p`: print only tickets' principal names
  * `-R`: print only the configured default realm
  * `-r fqdn`: print only the realm for given FQDN

## Output format

Basic format consists of tab-separated fields, the zeroth of which is type:

  * `cache`:

     1. Kerberos 5 credential cache name

  * `principal`:

     1. default client principal name

  * `ticket`:

     1. client principal name
     2. server principal name
     3. "valid starting" time
     4. expiry time
     5. renewable until time (0 if ticket not renewable)
     6. ticket flags

  * `cfgticket`: same as `ticket`

In collection mode (`-l`), there are two additional line types:

  * `default`:

    1. name of the default credential cache

  * `cache`:

    1. credential cache name (as `cache` above)
    2. default client principal name (as `principal` above)

    These two lines are merged in order to display one cache per line.

Some modes output a header line, which has type in all uppercase (such as `CREDENTIALS`) and following fields acting as column headers for following output lines.

When any of `-N`, `-P`, `-p`, `-R`, or `-r` is given, _only_ the requested data is displayed, without any type prefix.

Flags mostly match those documented in `klist(1)`:

  * `F` - Forwardable
  * `f` - forwarded
  * `P` - Proxiable
  * `p` - proxy
  * `D` - postDateable
  * `d` - postdated
  * `R` - Renewable
  * `I` - Initial (`AP_REQ`)
  * `i` - invalid
  * `H` - hardware authenticated
  * `A` - preAuthenticated
  * `T` - transit policy checked
  * `O` - Okay as delegate
  * `a` - anonymous`

## Collections

MIT Kerberos 1.10, as well as Heimdal for quite a while, have support for collections of several credential caches. When implemented by the Krb5 libraries, it is possible to obtain credentials for several unrelated realms at once and have the correct principal chosen automatically.

With MIT Krb5 1.10, one such type is `DIR` caches, where the residual points to an existing directory, and Krb5 automatically creates new file-based caches for each principal given to `kinit`. The correct cache to use can be chosen based on the user's `k5identity(5)` file.

    mkdir "/run/user/grawity/krb5cc"
    export KRB5CCNAME="DIR:/run/user/grawity/krb5cc"
    kinit grawity@NULLROUTE.EU.ORG
    kinit grawity@CLUENET.ORG
    ...

