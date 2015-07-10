#!/usr/bin/env perl
use feature qw(say switch);
use Net::DBus qw(:typing);
use Data::Dumper;
use constant {
	SECRETS_PATH		=> "/org/freedesktop/secrets",
	PROPERTY_IFACE		=> "org.freedesktop.DBus.Properties",
	SERVICE_IFACE		=> "org.freedesktop.Secret.Service",
	COLLECTION_IFACE	=> "org.freedesktop.Secret.Collection",
	ITEM_IFACE		=> "org.freedesktop.Secret.Item",
	SESSION_IFACE		=> "org.freedesktop.Secret.Session",
	PROMPT_IFACE		=> "org.freedesktop.Secret.Prompt",
};

my $Bus;
my $SecretService;

sub SECRETS_OBJECT { $SecretService->get_object(SECRETS_PATH) }

sub COLLECTION_OBJECT { $SecretService->get_object(SECRETS_PATH."/collections/".shift); }

sub session_Open {
	my $service = SECRETS_OBJECT;
	my (undef, $session_p) = $service->OpenSession("plain", "");
	return $SecretService->get_object($session_p);
};

our %Commands = (
	"help" =>
	sub {
		say for sort grep {ref $Commands{$_}} keys %Commands;
	},
	"list-collections" =>
	sub {
		my $service = SECRETS_OBJECT;
		my $session = session_Open();

		my $collections = $service->Get(SERVICE_IFACE, "Collections");
		for my $coll_p (@$collections) {
			my $coll = $SecretService->get_object($coll_p);
			my $label = $coll->Get(COLLECTION_IFACE, "Label");
			say $coll_p."\t".$label;
		}

		$session->Close();
		return 0;
	},
	"ls" => "list-collections",
	"list-items" =>
	sub {
		my ($cmd, $coll_name) = @_;

		my $service = SECRETS_OBJECT;
		my $session = session_Open();

		my $coll = COLLECTION_OBJ($coll_name);
	},
);

$Bus = Net::DBus->session;

$SecretService = $Bus->get_service("org.freedesktop.secrets");

my $cmd = shift(@ARGV) // "help";
my $handler = $Commands{$cmd};
if (ref $handler eq '') {
	$handler = $Commands{$handler};
}
my $ret = $handler->($cmd, @ARGV);
exit($ret // 0);
