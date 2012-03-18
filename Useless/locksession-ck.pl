#!/usr/bin/env perl
use strict;
use Net::DBus;

my $bus = Net::DBus->system;
my $ck = $bus->get_service("org.freedesktop.ConsoleKit");
my $manager = $ck->get_object("/org/freedesktop/ConsoleKit/Manager");
my $session_p = $manager->GetCurrentSession();
print "session_p = $session_p\n";
my $session = $ck->get_object($session_p);
$session->Lock();
