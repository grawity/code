#!/usr/bin/expect -f
# vim: ft=tcl

spawn telnet 192.168.1.1
expect "Login:"
send "admin\n"
expect "Password:"
send "mxfpq\n"
expect "DSL-2740U#"
send "sh\n"
expect "~ #"
send "cat /proc/self/net/nf_conntrack\n"
expect "~ #"
