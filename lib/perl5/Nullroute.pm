#!perl
package Nullroute;
use base "Exporter";
use common::sense;
use POSIX;

our @EXPORT = qw(
	daemonize
	forked
	readfile
);

sub daemonize {
	chdir("/")
		or die "can't chdir to /: $!";
	open(STDIN, "<", "/dev/null")
		or die "can't read /dev/null: $!";
	open(STDOUT, ">", "/dev/null")
		or die "can't write /dev/null: $!";
	my $pid = fork()
		// die("can't fork: $!");

	if ($pid) {
		exit;
	} else {
		if (POSIX::setsid() < 0) {
			warn "setsid failed: $!";
		}
	}
}

sub forked(&) {
	my $sub = shift;
	my $pid = fork();
	if ($pid) {return $pid} else {exit &$sub}
}

sub readfile {
	my ($file) = @_;
	open(my $fh, "<", $file)
		or die "$!";
	grep {chomp} my @lines = <$fh>;
	close($fh);
	wantarray ? @lines : shift @lines;
}
