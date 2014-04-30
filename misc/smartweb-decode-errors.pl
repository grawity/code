#!/usr/bin/env perl

%map = (
	SP => " ",
	CR => "\r",
	LF => "\n",
	AMP => "&",
);

while (<>) {
	s!\[([A-Z]+)\]!$map{$1} // $&!ge;
	tr/[]/<>/;
	s/^DB:-=-:.+?:-=-:/\e[30;45m$&\e[m\n/;
	print;
}
