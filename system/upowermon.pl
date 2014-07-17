#!/usr/bin/env perl
# © 2014 Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>
use Net::DBus qw(:typing);
use Net::DBus::Reactor;
use feature qw(state);
use constant {
	UP_DEVICE_IFACE		=> "org.freedesktop.UPower.Device",
	DBUS_PROPERTY_IFACE	=> "org.freedesktop.DBus.Properties",
	NOTIFY_URGENCY_LOW	=> 0,
	NOTIFY_URGENCY_NORMAL	=> 1,
	NOTIFY_URGENCY_HIGH	=> 2,
};

my @STATE = qw(unknown charging discharging fully_charged
               pending_charge pending_discharge);

my %STATE = map {$STATE[$_] => $_} 0..$#STATE;

sub UPower {
	Net::DBus->system
	->get_service("org.freedesktop.UPower")
	->get_object(shift // "/org/freedesktop/UPower")
}

sub Notifications {
	Net::DBus->session
	->get_service("org.freedesktop.Notifications")
	->get_object("/org/freedesktop/Notifications")
}

sub notify {
	state $id = 0;
	my ($summary, %opts) = @_;

	$id = Notifications->Notify(
		$opts{app} // "upowermon",
		$id,
		$opts{icon} // undef,
		$summary,
		$opts{body},
		$opts{actions} // [],
		$opts{hints} // {},
		$opts{timeout} // 1_000);
}

for my $dev_p (@{UPower->EnumerateDevices()}) {
	my $dev = UPower($dev_p);
	if ($dev->Get(UP_DEVICE_IFACE, "IsRechargeable")) {
		print "Watching $dev_p\n";
		$dev
		->as_interface(DBUS_PROPERTY_IFACE) #sigh
		->connect_to_signal("PropertiesChanged", sub {
			my ($interface, $changed, $invalidated) = @_;
			return unless $interface eq UP_DEVICE_IFACE;
			return unless (exists $changed->{Percentage}
			               || exists $changed->{State});

			my $charge = $changed->{Percentage}
			             // $dev->Get(UP_DEVICE_IFACE, "Percentage");
			my $state = $changed->{State}
			             // $dev->Get(UP_DEVICE_IFACE, "State");

			print "Battery at $charge%, $STATE[$state]\n";

			if ($state == $STATE{discharging} && $charge <= 15) {
				my $icon = $dev->Get(UP_DEVICE_IFACE, "IconName");
				notify("Battery low",
					body => "The battery is at $charge%.",
					icon => $icon,
					hints => {
						transient => dbus_boolean(1),
						urgency => dbus_byte(NOTIFY_URGENCY_HIGH),
					},
					timeout => 10_000);
			}

			if ($state == $STATE{discharging} && $charge <= 5) {
				print "Suspending\n";
				system("systemctl", "suspend");
			}
		});
	}
}

Net::DBus::Reactor->main->run;
