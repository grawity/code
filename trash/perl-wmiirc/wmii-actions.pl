use strict;
our $Config;

sub action_menu {
	my $in = join "\n", keys %$Actions;
	my ($out, $args);
	run(["wimenu"], "<", \$in, ">", \$out);
	if ($out) {
		chomp $out;
		($out, $args) = split / +/, $out, 2;
		&{$Actions->{$out}}($args);
	}
}

return {
	quit => \&suicide;
};
