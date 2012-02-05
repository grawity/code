use strict;
our $Config;

sub program_menu {
	my ($out);
	run(["wimenu"], "<", $Config->{program_cache}, ">", \$out);
	$out and spawns $out;
}

my $Keys = {
	"Modkey-h" => sub { ixp_xwrite "/tag/sel/ctl", "select left" },
	"Modkey-j" => sub { ixp_xwrite "/tag/sel/ctl", "select down" },
	"Modkey-k" => sub { ixp_xwrite "/tag/sel/ctl", "select up" },
	"Modkey-l" => sub { ixp_xwrite "/tag/sel/ctl", "select right" },
	"Modkey-space" => sub { ixp_xwrite "/tag/sel/ctl", "select toggle" },
	# Modkey-(1..9) below

	"Modkey-d" => sub { ixp_xwrite "/tag/sel/ctl", "colmode sel default-max" },
	"Modkey-s" => sub { ixp_xwrite "/tag/sel/ctl", "colmode sel stack-max" },
	"Modkey-m" => sub { ixp_xwrite "/tag/sel/ctl", "colmode sel stack+max" },

	"Modkey-f" => sub { ixp_xwrite "/client/sel/ctl", "fullscreen toggle" },
	"Modkey-q" => sub { ixp_xwrite "/client/sel/ctl", "kill" },

	"Modkey-p" => \&program_menu,

	"Modkey-Return" => sub { spawns $Config->{term} },
	"Modkey-KP_Enter" => sub { spawns $Config->{term} },

	"Modkey-Shift-h" => sub { ixp_xwrite "/tag/sel/ctl", "send sel left" },
	"Modkey-Shift-j" => sub { ixp_xwrite "/tag/sel/ctl", "send sel down" },
	"Modkey-Shift-k" => sub { ixp_xwrite "/tag/sel/ctl", "send sel up" },
	"Modkey-Shift-l" => sub { ixp_xwrite "/tag/sel/ctl", "send sel right" },
	"Modkey-space" => sub { ixp_xwrite "/tag/sel/ctl", "send sel toggle" },
	# Modkey-Shift-(1..9) below

	"Modkey-grave" => sub {
		my $tag = this_tag+1;
		ixp_xwrite "/ctl", "view $tag"
	},

	"Menu" => \&program_menu,
};

foreach my $tag (1..9) {
	$Keys->{"Modkey-$tag"} = sub {
		ixp_xwrite "/ctl", "view $tag"
	};
	$Keys->{"Modkey-Shift-$tag"} = sub {
		ixp_xwrite "/client/sel/tags", $tag
	};
}

return $Keys;
