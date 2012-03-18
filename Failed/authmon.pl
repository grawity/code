#!/usr/bin/env perl
use common::sense;
use Data::Dumper;

sub putlog {
	my (%data) = @_;
	print Dumper(\%data);
}

while (my $line = <>) {
	chomp $line;
	#my ($date, $text) = split(/ /, $line, 2);
	my ($date, $text) = $line =~ /^(\w+ \d+ \d+:\d+:\d+) (.+)$/;
	my $host;

	if ($text =~ /^\d+ (\w+) (.+)/) {
		$host = $1;
		$text = $2;
	}
	elsif ($text =~ /^(\w+) (.+)/) {
		$host = $1;
		$text = $2;
	}

	given ($text) {
		when (/^LOGIN-(\w+): \[\d+\] User authentication success \(Username: (.+)\)$/) {
			putlog	host => $host,
				action => "login",
				service => $1,
				user => $2;
		}
		when (/^LOGIN-(\w+): \[\d+\] User authentication failure \(Unauthorized User "(.+)"\)$/) {
			putlog	host => $host,
				action => "loginfail",
				service => $1,
				user => $2;
		}
		# openssh
		when (/^sshd\[\d+\]: Accepted (\w+) for (\S+) from (\S+) port \d+ \w+$/) {
			putlog	host => $host,
				action => "login",
				service => "ssh",
				mech => $1,
				user => $2,
				rhost => $3;
		}
		when (/^sshd\[\d+\]: Failed (\w+) for (\S+) from (\S+) port \d+ \w+$/) {
			putlog	host => $host,
				action => "loginfail",
				service => "ssh",
				mech => $1,
				user => $2,
				rhost => $3;
		}
		# dovecot
		when (/^auth \[.+\]: 
	}
}
