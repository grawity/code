Some of the tools here are useful, although mostly specific to my networks and
configurations. But expect some crazy shit, too. One might discover three
different implementations of an obscure protocol from 1980's or something just
as useless.

(Everything is licensed under WTFPL v2 <http://sam.zoy.org/wtfpl/> unless
declared otherwise in specific files. I might switch the default license to
MIT, but still not sure about it.)

Log:

  * 2014-07-29: cleaned up old branches; moved to refs/attic/* to avoid clutter

The useful stuff:

  music/
    gnome-mpris-inhibit – disable idle-suspend in GNOME while music is playing
    mpris               – control MPRISv2-capable players
  net/
    getpaste            – dump raw text of pastebin posts
    tapchown            – change owner of tun/tap network interfaces (Linux)
  x11/
    dbus-name           – list, activate, wait for DBus names
    gnome-inhibit       – set and list idle inhibitors in GNOME

The not really useful stuff:

  misc/
    envcp               – borrow the environment of another process
    motd                – show a diff for /etc/motd upon login
  net/
    rdt                 – recursive rDNS trace
  kerberos/
    kc                  – manage Kerberos ticket caches
    kl                  – a better 'klist'
    pklist              – a machine-readable 'klist'
  lib/python/nullroute/
    authorized_keys.py  – parse ~/.ssh/authorized_keys
    sexp.py             – parse Ron Rivest's S-expressions

The IRC protocol parser collection:

  lib/irc.vala
  lib/perl5/Nullroute/IRC.pm
  lib/php/irc.php
  lib/python/nullroute/irc.py
  lib/ruby/irc.rb
  lib/tests/*.txt

The rest:

  bin/
    – contains symlinks to all scripts, for my $PATH
  dist/
    – scripts dealing with this repository itself
  obj/
    – compiled binaries for C tools, to allow sharing `~/code` over NFS
  tools/
    – stuff that will, some day, be cleaned up and put in the right place
