#!/usr/bin/env perl
use LWP::Simple;
$count = 250;
$body = get("https://aur.archlinux.org/packages/?PP=$count") || die;
$body =~ /Page 1 of (\d+)\./ || die;
$pages = $1;
for $page (1..$pages) {
	$offset = $count * ($page - 1);
	$body = get("https://aur.archlinux.org/packages/?SB=n&PP=$count&O=$offset");
	print "$1\n" while $body =~ m!<a href="/packages/(.+?)/">!g;
}
