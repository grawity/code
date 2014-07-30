# vi: ft=perl
use strict;
use Data::Dumper;
my @entries = ();
my $cur;
my %cur;
my $group = undef;

my @m;

open my $fh, "<", "$ENV{HOME}/Documents/Address book.txt";
while (<$fh>) {
	chomp;
	if (/^#/ or !$_) {
		next;
	}
	elsif (/^\[(.+)\]$/) {
		# section headers
		$group = $1;
		next;
	}
	elsif (/^\t/) {
		s/^\t//;
		if (/^<(.+\@.+)>$/) {
			$cur->{email} = $1;
		}
		elsif (/^(.+?):\s+(.+)$/) {
			$cur->{$1} = $2;
		}
	}
	else {
		push @entries, $cur = {name => $_};
		if (@m = $cur->{name} =~ /^(.+) <(.+\@.+)>$/) {
			($cur->{name}, $cur->{email}) = @m;
		}
		if (@m = $cur->{name} =~ /^(.+?) \((.+ .+)\)$/) {
			($cur->{nick}, $cur->{name}) = @m;
		} elsif (@m = $cur->{name} =~ /^(.+ .+) \((.+?)\)$/) {
			($cur->{nick}, $cur->{name}) = @m;
		} else {
			$cur->{nick} = (split /\s+/, $cur->{name})[0];
		}
	}
}
close $fh;

#print Dumper(@entries);
return @entries;
