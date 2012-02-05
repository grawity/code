use strict;
our $Config;
return {
	Start => [1, \&suicide],

	CreateTag => [1, sub {
		my ($tag) = @_;
		ctl_create("/lbar/$tag",
			colors => $Config->{colors}{normal},
			label => $tag,
		);
	}],

	DestroyTag => [1, sub {
		my ($tag) = @_;
		ixp_remove("/lbar/$tag");
	}],

	FocusTag => [1, sub {
		my ($tag) = @_;
		ctl_write("/lbar/$tag",
			colors => $Config->{colors}{focus},
		);
	}],

	UnfocusTag => [1, sub {
		my ($tag) = @_;
		ctl_write("/lbar/$tag",
			colors => $Config->{colors}{normal},
		);
	}],

	UrgentTag => [2, sub {
		my ($setter, $tag) = @_;
		ctl_write("/lbar/$tag",
			colors => $Config->{colors}{urgent},
		);
	}],

	NotUrgentTag => [2, sub {
		my ($ssetter, $tag) = @_;
		if ($tag eq this_tag) {
			on_event "FocusTag", $tag;
		} else {
			on_event "UnfocusTag", $tag;
		}
	}],

	LeftBarClick => [2, sub {
		my ($button, $tag) = @_;
		if ($button == MOUSE_LEFT) {
			ctl_write("/ctl", view => $tag);
		} elsif ($button == MOUSE_SCROLL_UP) {
			ctl_write("/ctl", view => prev_tag);
		} elsif ($button == MOUSE_SCROLL_DOWN) {
			ctl_write("/ctl", view => next_tag);
		}
	}],

	Key => [1, sub {
		my ($key) = @_;
		on_key $key;
	}],
};
