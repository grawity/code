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

my $logind_mgr = undef;
my $inhibit_fd = undef;
my %restart_servers = ();

sub _trace {
    Irssi::print("$IRSSI{name}: @_") if $ENV{DEBUG};
}

sub disconnect_all {
    %restart_servers = ();
    for my $server (Irssi::servers()) {
        if ($server->{connected}) {
            _trace(" - disconnecting from $server->{tag}");
            $restart_servers{$server->{tag}} = 1;
            $server->command("reconnect");
        }
    }
}

sub reconnect_all {
    use Data::Dumper;
    for my $tag (sort keys %restart_servers) {
        _trace(" - reconnecting to $tag");
        _trace("TODO what to put here?");
        #Irssi::command("reconnect $tag");
    }
    %restart_servers = ();
}

sub take_inhibit {
    if (!$logind_mgr) {
        Irssi::print("take_inhibit: no manager object", MSGLEVEL_CLIENTERROR);
        return;
    }
    elsif (defined $inhibit_fd) {
        Irssi::print("take_inhibit: already has an inhibit fd", MSGLEVEL_CLIENTERROR);
        return;
    }

    my $fd = $logind_mgr->Inhibit("sleep",
                                  "Irssi",
                                  "Irssi needs to disconnect from IRC",
                                  "delay");
    if (!$fd) {
        Irssi::print("take_inhibit: could not take an inhibitor");
        $inhibit_fd = undef;
        return;
    }
    _trace("got inhibit fd $fd");
    $inhibit_fd = $fd;
}

sub drop_inhibit {
    if (defined $inhibit_fd) {
        _trace("closing fd $inhibit_fd");
        POSIX::close($inhibit_fd);
        $inhibit_fd = undef;
    }
}

sub connect_signals {
    drop_inhibit();

    my $logind_svc = eval {$bus->get_service("org.freedesktop.login1")};
    if ($@ || !$logind_svc) {
        Irssi::print("systemd-logind not available on D-Bus, bailing");
        return;
    }

    # eval{} can't catch errors here, but that's fine.
    # If get_object() fails here, it has to be a systemd-logind bug.
    $logind_mgr = $logind_svc->get_object("/org/freedesktop/login1");

    $logind_mgr->connect_to_signal("PrepareForSleep", sub {
        my ($suspending) = @_;

        if ($suspending) {
            _trace("suspending...");
            _trace("* disconnecting");
            disconnect_all();
            _trace("* dropping inhibit lock");
            drop_inhibit();
            # system goes to sleep at this point
        } else {
            _trace("waking up...");
            _trace("* taking inhibit lock");
            take_inhibit();
            _trace("* reconnecting");
            reconnect_all();
        }
    });

    Irssi::signal_add("server looking", sub {
        my ($server) = @_;

        if ($restart_servers{$server->{tag}}) {
            _trace("stopping 'server looking' signal for $server->{tag}");
            Irssi::signal_stop();
            $restart_servers{$server->{tag}} = 0;
        }
    });

    take_inhibit();
}

sub UNLOAD {
    drop_inhibit();
}

connect_signals();

# vim: ts=4:sw=4:et:
