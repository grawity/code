#!/usr/bin/env perl
# Get <title> for user homepages; let Apache do its CGI stuff.
# Status: working, replaced with PHP implementation

use strict;
use warnings;
use HTML::TreeBuilder;
use LWP::Simple;

sub get_title {
	my ($url) = @_;
	my $data = LWP::Simple::get($url);
	my $tree = HTML::TreeBuilder->new_from_content($data);
	if ($tree) {
		my @tags = $tree->look_down(_tag => "title");
		if (@tags) {
			return $tags[0]->{_content}[0];
		}
	}
}

sub get_userdir_title {
	my ($user) = @_;
	get_title "http://localhost/~$user/";
}

for (@ARGV) {
	print get_userdir_title($_)."\n";
}
