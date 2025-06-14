# kc – Kerberos ccache manager

## Usage

    $ . kc.bash
    $ kc
    » 1 @               grawity@NULLROUTE.EU.ORG                        Jun 12 21:19
      2 8zRpuA          grawity@CLUENET.ORG                             Jun 13 01:32
    x 3 iaJIxT          grawity@CLUENET.ORG                             (expired)
      4 cn              grawity@CLUENET.ORG                             Jun 12 21:00
    $ kc =cna
    Password for grawity/admin@CLUENET.ORG:
    $ kc @
    Switched to grawity@NULLROUTE.EU.ORG (FILE:/tmp/krb5cc_1000)
    $

In the example above, the "default" ccache (`/tmp/krb5cc_$UID`) is selected as `$KRB5CCNAME`. The 3rd ccache is expired.

There even is ANSI color.

## Commands

  * `kc` – list ccaches
  * `kc <name>` – select ccache by name or number
  * `kc <principal>` – select ccache by principal
  * `kc new` – select a new ccache with generated name
  * `kc purge` – destroy ccaches with expired TGTs
  * `kc destroy [<name>...]` – destroy selected ccaches

## ccache abbrevs

  * one or two digits – *kc*'s internal numbering
  * `@` – system default ccache, usually `FILE:/tmp/krb5cc_${uid}`
  * `:` – `DIR:${XDG_RUNTIME_DIR}/krb5cc`, a multi-TGT cache
  * `:name` – `DIR::${XDG_RUNTIME_DIR}/krb5cc/tkt${name}`, a single ccache in the directory
  * `+` – current ccache if it is a DIR, same as `:` otherwise
  * `+name` – if current ccache is a DIR, the specified ccache in that directory; otherwise, same as `:name`
  * `^name` – `KEYRING:krb5cc.${name}`, Linux kernel keyring (MIT Krb5)
  * `^^name` – `KEYRING:${name}` (same as above)
  * `kcm` – `KCM:${uid}`, "Kerberos Credential Manager" daemon (Heimdal)
  * `new` – `FILE:/tmp/krb5cc_${uid}_XXXXXX`, randomly-generated name matching the session-specific cache pattern
  * any string with `/` – `FILE:${str}`, a file ccache in arbitrary locations
  * any other string – `FILE:/tmp/krb5cc_${uid}_${str}`, session-specific caches used by sshd, pam_krb5 and other tools

If a name is prefixed with `=`, *kc* will look for a matching line in `${XDG_CONFIG_HOME}/k5aliases` and `~/lib/dotfiles/k5aliases`. If a line with matching 1st field is found, `kinit` will be run with the 2nd and further fields as arguments.
