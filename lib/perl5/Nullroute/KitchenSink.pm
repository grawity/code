package Nullroute::KitchenSink;
use common::sense;
use base "Exporter";
use constant {
	DATE_FMT_MBOX	=> '%a %b %_d %H:%M:%S %Y',
	DATE_FMT_MIME	=> '%a, %d %b %Y %H:%M:%S %z',
	DATE_FMT_ISO	=> '%Y-%m-%dT%H:%M:%S%z',
};

our @EXPORT = qw(
	DATE_FMT_MBOX
	DATE_FMT_MIME
	);

1;
