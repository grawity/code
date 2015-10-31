use warnings;
use strict;
use Glib;
use Irssi;
use Net::DBus::GLib;
use Net::DBus;
use POSIX;

our %IRSSI = (
    name        => "sleep_disconnect",
    description => "Disconnects when system goes to sleep",
    contact     => "Mantas Mikulėnas <grawity\@gmail.com>",
    license     => "MIT (Expat) <http://grawity.mit-license.org/2015>",
);
our $VERSION = '0.1';

my $bus = Net::DBus::GLib->system();
my $logind_svc = $bus->get_service("org.freedesktop.login1");
my $logind_mgr = $logind_svc->get_object("/org/freedesktop/login1");

my $inhibit_fd = undef;
my @restart_servers = ();

sub disconnect_all {
    @restart_servers = ();
    for my $server (Irssi::servers()) {
        if ($server->{connected}) {
            Irssi::print(" - disconnecting from $server->{tag}");
            #push @restart_servers, $server;
            push @restart_servers, $server->{tag};
            $server->disconnect();
        }
    }
}

sub reconnect_all {
    use Data::Dumper;
    #for my $server (@restart_servers) {
    #    Irssi::print(Dumper($server));
    #    Irssi::print(" - reconnecting to $server->{tag}");
    #    # the above two actually work fine, it's just the ->connect() that crashes
    #    $server->connect();
    #}
    for my $tag (@restart_servers) {
        Irssi::print(" - reconnecting to $tag");
        Irssi::command("connect $tag");
    }
    @restart_servers = ();
}

sub take_inhibit {
    if (defined $inhibit_fd) { die "take_inhibit: already has \$inhibit_fd!"; }

    my $fd = $logind_mgr->Inhibit("sleep",
                                  "Irssi",
                                  "Irssi needs to disconnect from IRC",
                                  "delay");

    if (!$fd) { die "take_inhibit: could not take an inhibitor"; }

    $inhibit_fd = $fd;
}

sub drop_inhibit {
    if (defined $inhibit_fd) {
        POSIX::close($inhibit_fd);
        $inhibit_fd = undef;
    }
}

sub connect_signals {
    drop_inhibit();

    $logind_mgr->connect_to_signal("PrepareForSleep", sub {
        my ($suspending) = @_;
        if ($suspending) {
            Irssi::print("suspending...");
            Irssi::print(" - disconnecting");
            disconnect_all();
            Irssi::print(" - dropping inhibit lock");
            drop_inhibit();
            Irssi::print("okay.");
        } else {
            Irssi::print("waking up...");
            Irssi::print(" - taking inhibit lock");
            take_inhibit();
            Irssi::print(" - reconnecting");
            reconnect_all();
            Irssi::print("okay.");
        }
    });

    take_inhibit();
}

connect_signals();

# vim: ts=4:sw=4:et:
