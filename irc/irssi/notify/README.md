# notify - irssi notification script'

## Requirements for `notify_send`

*libnotify* over DBus:

  * Net::DBus (*perl-net-dbus*, *libnet-dbus-perl* or straight from CPAN)

Growl:

  * Mac::Growl (from CPAN)
  * as a fallback, the `growlnotify` tool will be used

TCP or UDP over IPv6:

  * IO::Socket::INET6

TCP with SSL:

  * IO::Socket::SSL

## Usage

Install the `notify_send.pl` script, load it to Irssi, and change the `notify_targets` setting to one or more of, space separated:

  * <code>file!*path*</code> - append to a file
  * <code>growl</code> - use Growl
  * <code>libnotify</code> - use libnotify over DBus (default)
  * <code>ssl!*host*!*port*</code> - SSL-encrypted TCP connection
  * <code>tcp!*host*!*port*</code> - TCP connection
  * <code>udp!*host*!*port*</code> - UDP datagram
  * <code>unix!*path*</code> - Unix local socket
  * <code>unix!stream!*path*</code>, <code>unix!dgram!*path*</code>

<code>dbus</code> is accepted as an alias for <code>libnotify</code> for compatibility.

## Bugs

  * `tcp` and `udp` use non-blocking sockets, only use the first IP address returned for the hostname, and ignore pretty much all errors.

  * The script is unaware of Irssi /hilights, due to limitations of Irssi scripting. This means you will need to edit the script yourself to add message regexps to `@hilights`, or custom rules to `sub on_message`.

    (The only signal available which carries message levels such as "hilighted" is *"print text"*, which only provides the final output line, with sender, channel, and text merged into one.)

## Usage of `notify_receive`

For cases where Irssi is running on a faraway server, notifications can be sent over UDP or TCP to the *notify_receive* script.

The script accepts two arguments — the notification source and destination. The source can be *tcp* or *udp* with the same options as above, or *stdin*. The destination can be *libnotify* or *growl*.
