## Installing

    make

## Command-line options

  * `-C`: also list config principals (used by Kerberos internally)
  * `-N`: print only the ccache name
  * `-P`: print only the default client principal
  * `-p`: print only tickets' principal names
  * `-R`: print only the configured default realm
  * `-r` *fqdn*: print only the realm for given FQDN

## Output format

Basic format consists of tab-separated fields, the zeroth of which is type:

  * `cache`:

      1. Kerberos 5 credentials cache name

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
