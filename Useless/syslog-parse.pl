#!/usr/bin/env perl
# vim: ts=4:sw=4:noet
use common::sense;
use Data::Dumper;

my %entry;

sub event_new_wait {
	%entry = (@_);
}
sub event_new_push {
	%entry = (@_);
	push_event(\%entry);
	%entry = ();
}
sub event_push {
	%entry = (%entry, @_);
	push_event(\%entry);
	%entry = ();
}
sub event_has {
	exists $entry{shift()};
}

sub push_event {
	my $entry = shift;
	print Dumper($entry);
}

while (<>) {
	chomp;
	my $ident = "ksu";
	my $msg = $_;
	given ($ident) {
		when ("ksu") {
			say "$ident: $msg";
			given ($msg) {
				when (/^'ksu (.+?)' authenticated (\S+) for (\S+) on (\S+)$/) {
					event_new_wait(
						action	=> "elevate",
						event	=> "elevate",
						user	=> $3,
						princ	=> $2,
						tty		=> $4,
						to_user	=> $1,
					);
				}
				when (/^'ksu (.+?)' authentication failed for (\S+) on (\S+)$/) {
					event_new_push(
						action	=> "elevate",
						event	=> "authentication failed",
						user	=> $2,
						tty		=> $3,
						to_user	=> $1,
					);
				}
				when (/^Account (.+?): authorization for (\S+) successful$/) {
					event_push(
						princ	=> $2,
						to_user	=> $1,
					) if event_has("user");
				}
				when (/^Account (.+?): authorization for (\S+) for execution of (.+?) successful$/) {
					event_push(
						princ	=> $2,
						to_user	=> $1,
						command	=> $3,
					) if event_has("user");
				}
				when (/^Account (.+?): authorization of (\S+) failed$/) {
					event_push(
						action	=> "elevate",
						event	=> "authorization failed",
						princ	=> $2,
						to_user	=> $1,
					) if event_has("user");
				}
				default {
					say "$ident: $msg";
				}
			}
		}
	}
}
