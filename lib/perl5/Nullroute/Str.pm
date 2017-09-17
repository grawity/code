package Nullroute::Str;
use parent "Exporter";

@EXPORT_OK = qw(
	expand_ranges
);

sub expand_ranges {
	my ($s) = @_;
	my @r;
	for (split(/,/, $s)) {
		if (/^(\d+)-(\d+)$/) {
			push @r, int($1)..int($2);
		}
		elsif (/^(\d+)$/) {
			push @r, int($1);
		}
		else {
			warn "invalid range item '$_'\n";
		}
	}
	return @r;
}
