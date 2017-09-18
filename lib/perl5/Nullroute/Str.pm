package Nullroute::Str;
use parent "Exporter";

@EXPORT_OK = qw(
	expand_ranges
);

# expands numeric ranges like "1,5,9-12"

sub expand_ranges {
	my ($s) = @_;

	map {
		if (/^(\d+)-(\d+)$/) {
			int($1) .. int($2)
		} elsif (/^(\d+)$/) {
			int($1)
		} else {
			warn "invalid range item '$_'";
			()
		}
	} split(/,/, $s);
}
