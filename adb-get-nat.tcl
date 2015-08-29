#!/usr/bin/expect -f
# vim: ft=tcl

spawn telnet gateway
expect "Login:"
send "admin\n"
expect "Password:"
send "admin\n"
expect "ADB#"
send "show ip_conntrack\n"
expect "ADB#"
