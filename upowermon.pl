#!/usr/bin/env perl
# © 2014 Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>
use Net::DBus;
use Net::DBus::Reactor;
use constant {
	UP_DEVICE_IFACE		=> "org.freedesktop.UPower.Device",
	DBUS_PROPERTY_IFACE	=> "org.freedesktop.DBus.Properties",
};

my @STATE = qw(unknown charging discharging fully_charged
               pending_charge pending_discharge);

my %STATE = map {$STATE[$_] => $_} @STATE;

my $bus = Net::DBus->system;

sub UPower {
	$bus
	->get_service("org.freedesktop.UPower")
	->get_object(shift // "/org/freedesktop/UPower")
}

for my $dev_p (@{UPower->EnumerateDevices()}) {
	my $dev = UPower($dev_p);
	if ($dev->Get(UP_DEVICE_IFACE, "IsRechargeable")) {
		$dev
		->as_interface(DBUS_PROPERTY_IFACE) #sigh
		->connect_to_signal("PropertiesChanged", sub {
			my ($iface, $changed, $invalidated) = @_;
			return unless $iface eq UP_DEVICE_IFACE;
			return unless (exists $changed->{Percentage}
			               || exists $changed->{State});

			my $charge = $changed->{Percentage}
			             // $dev->Get(UP_DEVICE_IFACE, "Percentage");
			my $state = $changed->{State}
			             // $dev->Get(UP_DEVICE_IFACE, "State");

			print "Battery at $charge%, $STATE[$state]\n";

			if ($state == $STATE{discharging} && $charge <= 5) {
				print "Suspending\n";
				system("systemctl", "suspend");
			}
		});
	}
}

Net::DBus::Reactor->main->run;
