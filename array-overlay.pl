use List::Util qw(max);
use warnings;

@a = (
	["a", "b", "c", "d", "e"],
	["f", "g", "h", "i", "j"],
	["k", "l", "m", "n", "o"],
	["p", "q", "r", "s", "t"],
	["u", "v", "w". "x", "y"],
);

@b = (
	["1", "2", "3"],
	["4", "5", "6"],
);

$xs = max map {$#{$_}} @a;
$ys = $#a;

@c = map { $y = $_; [map { $x = $_; $b[$y][$x] // $a[$y][$x]; } 0..$xs]; } 0..$ys;

sub xdump {
	print "+++\n";
	print ">".$_."<\n" for map { join("", @$_) } @_;
	print "---\n";
	print "\n";
}

xdump(@a);
xdump(@b);
xdump(@c);
