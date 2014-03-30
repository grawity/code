use List::Util qw(max);
sub xdump {
	print ">".$_."\n" for map { join("", @$_) } @_;
}

@test = (
	['a', 'b', 'c'],
	['d', 'e', 'f'],
	['g', 'h', 'i'],
	['j', 'k', 'l'],
);

xdump(@test);

sub transpose {
	my @in = @_;
	my $xm = max map {$#{$_}} @in;
	my $ym = $#in;
	map { my $x = $_; [ map { my $y = $_; $in[$y][$x] } 0..$ym ] } 0..$xm;
}

@test = transpose(@test);

xdump(@test);
