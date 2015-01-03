My giant repo o' random hacks.

Started off as your regular ~/bin dump – with two Finger implementations and a
web server written in PHP. Later got pushed over to ~/code, to make place for
the horde of overgrown aliases that have since taken over ~/bin (which I didn't
consider commit-worthy at first, but then I suddenly had 250 scripts in ~/code
and almost 200 in ~/bin and *five* different Finger implementations...)

tl;dr I write a lot of useless scripts

---

Everything licensed under WTFPL v2 <http://sam.zoy.org/wtfpl/> unless declared
otherwise in specific files. (Thinking about changing to MIT, not sure yet.)

The generally useful stuff:

  music/
    gnome-mpris-inhibit – disable power management in GNOME while music is playing
    mpris               – control MPRISv2-capable players
  net/
    getpaste            – download pastebin posts as plain text (even ZeroBin)
    tapchown            – change owner of Linux tun/tap network interfaces
  term/
    xterm-color-chooser – a color picker for ANSI & Xterm sequences
  x11/
    dbus-name           – list, activate, wait for D-Bus names
    gnome-inhibit       – set & list power management inhibitors in GNOME

The not really useful stuff:

  devel/
    git-find-blob       – find all Git commits that contain a given file
  misc/
    envcp               – borrow the environment of another process
    motd                – show a diff for /etc/motd upon login
    treeify             – translate a list of files to a fancy tree
  net/
    rdt                 – run a recursive rDNS trace
    sprunge             – post to the sprunge.us pastebin
  kerberos/
    kc                  – manage Kerberos ticket caches
    kl                  – like 'klist' except better
    pklist              – like 'klist' except machine-readable
  system/
    upower-monitor      – suspend when UPower claims it's low on battery

The "that's nice... but what's it good for?" stuff:

  lib/python/nullroute/
    authorized_keys.py  – parse ~/.ssh/authorized_keys
    sexp.py             – parse Ron Rivest's S-expressions
  misc/
    uniboxify           – convert ASCII box drawings to Unicode box drawings
  security/
    accdb/              – plain-text account & password database
    denettalk           – decrypt Nettalk "NCTCTC001"-encrypted messages
    dh                  – do a D-H key exchange over IRC or whatever
    ssh-duphosts        – clean up ~/.ssh/known_hosts
  system/
    locale-check        – half-assed attempt to verify your locale settings

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
  misc/
    – stuff that will, some day, be cleaned up and put in the right place

Things that used to be here:

  ssh-publickeyd        – backend for SecureCRT's "public key assistant"
                          <https://github.com/grawity/ssh-publickeyd>

Log:

  * 2009-11-28: initial commit of "simplehttpd"
  * 2010-01-01: initial commit of the "main" repository
  * 2014-07-29: cleaned up old branches; moved to refs/attic/* to avoid clutter

vim: ts=4:sw=4:et
