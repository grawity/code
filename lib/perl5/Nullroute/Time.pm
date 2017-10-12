package Nullroute::Time;
use base "Exporter";

our @EXPORT = qw(
	time_ntfile2unix
	time_unix2ntfile
);

sub time_ntfile2unix {
    my ($file_t) = @_;

    return 0 if !defined($file_t);
    return 0 if $file_t == 0;
    return do { use bigint; ($file_t / 10_000_000) - 11644473600 };
}

sub time_unix2ntfile {
    my ($unix_t) = @_;

    return 0 if !defined($unix_t);
    return 0 if $unix_t == 0;
    return do { use bigint; ($unix_t + 11644473600) * 10_000_000 };
}

1;
