#!/usr/bin/perl
use strict;
use constant LDAP_HOST => "ldap.cluenet.org";

use Getopt::Long;
use Socket;
use Authen::SASL;
use Net::addrinfo;
use Net::LDAP;
use Net::LDAP::Extension::WhoAmI;
use Net::LDAP::Util qw(ldap_explode_dn);
use Data::Dumper;

my $ldap;
my $cmd;
my $exit;
my $my_name;
my %commands;

use constant SHELL_SERVICES => qw(atd cron login passwd sshd su sudo);

### String and hostname manipulation

# Canonicalize a hostname
sub canon_host($) {
	my ($host) = @_;
	my $hint = Net::addrinfo->new(flags => AI_CANONNAME);
	my $ai = getaddrinfo($host, undef, $hint);
	return (ref $ai eq "Net::addrinfo") ? $ai->canonname : $host;
}

# FQDNize a given host
sub fqdn($) {
	my ($host) = @_;
	return ($host =~ /\./) ? $host : "$host.cluenet.org";
}

# Split "host/service" arg
sub to_hostservice($) {
	my ($host, $service, $rest) = split /\//, shift, 3;
	return (fqdn($host), $service, $rest);
}
sub to_hostservice_safe($) {
	my ($host, $service, $rest) = split /\//, shift, 3;
	unless ($host and $service) {
		die "syntax error: empty host or service: '$host/$service'\n";
	}
	return (fqdn($host), $service, $rest);
}

# 
sub user_dn {"uid=".shift().",ou=people,dc=cluenet,dc=org"}
sub server_dn {"cn=".fqdn(shift).",ou=servers,dc=cluenet,dc=org"}

# Find the next rightmost RDN after given base
sub from_dn($$@) {
	my ($entrydn, $branchdn, $nonames) = @_;
	my %opts = (reverse => 1, casefold => "lower");
	my @entry = @{ldap_explode_dn($entrydn, %opts)};
	my @base = @{ldap_explode_dn($branchdn, %opts)};
	for my $rdn (@base) {
		my @brdn = %$rdn;
		my @erdn = %{shift @entry};
		return if ($erdn[0] ne $brdn[0]) or ($erdn[1] ne $brdn[1]);
	}
	my @final = %{shift @entry};
	return $nonames ? $final[1] : @final;
}

### LDAP connection

# Establish LDAP connection, authenticated or anonymous
sub connect_auth() {
	my $sasl = Authen::SASL->new("GSSAPI");
	my $ldap = Net::LDAP->new(LDAP_HOST) or die "$@";
	#$ldap->start_tls(verify => "require",
	#	cafile => "$ENV{HOME}/lib/ca/cluenet.pem") or die "$@";
	my $authen = $sasl->client_new("ldap", canon_host LDAP_HOST);
	my $msg = $ldap->bind(sasl => $authen);
	$msg->code and die "error: ".$sasl->error;
	return $ldap;
}
sub connect_anon() {
	my $ldap = Net::LDAP->new(LDAP_HOST) or die "$@";
	$ldap->bind;
	return $ldap;
}

# Get and cache LDAP authzid
sub whoami() {
	if (!defined $my_name) {
		$my_name = $ldap->who_am_i->response;
		$my_name =~ s/^dn:uid=(.+?),.*$/\1/;
		$my_name =~ s/^u://;
	}
	return $my_name;
}

sub ldap_errmsg {
	my ($msg, $dn) = @_;
	my $text = "LDAP error: ".$msg->error."\n";
	if ($dn) {
		$text .= "\tfailed: $dn\n";
	}
	if ($msg->dn) {
		$text .= "\tmatched: ".$msg->dn."\n";
	}
	$text;
}

### Miscellaneous

sub usage($@) {
	my ($cmd, @args) = @_;
	my $text = $cmd." ".join(" ", map {$_ eq '...' ? $_ : "<$_>"} @args);

	print STDERR "Usage: $text\n";
	exit 2;
}

### User interface commands

$commands{"access"} = sub {
	my (@services, @add_users, @del_users);
	for (@_) {
		if (/\//) {
			my ($h, $s) = to_hostservice_safe($_);
			if ($s eq 'shell') {
				push @services, [$h, $_] for SHELL_SERVICES;
			} else {
				push @services, [$h, $s];
			}
		}
		elsif (/^\+(.+)$/) {push @add_users, $1}
		elsif (/^-(.+)$/) {push @del_users, $1}
		else {die "syntax error: '$_'\n"}
	}
	
	usage("access", qw(host/service ... [+-]user ...))
		unless @services;
	
	if (@add_users or @del_users) {
		$ldap = connect_auth;
	} else {
		$ldap = connect_anon;
	}
	
	for (@services) {
		my ($host, $service) = @$_;
		my $group = "cn=$service,cn=svcAccess,".server_dn($host);
		
		if (@add_users or @del_users) {
			# found +user/-user in args -- update members
			my %changes;
			if (@add_users) {
				$changes{add} = {member => [map {user_dn $_} @add_users]};
				print "Adding access: {".join(", ", @add_users)."} to $host/$service\n";
			}
			if (@del_users) {
				$changes{delete} = {member => [map {user_dn $_} @del_users]};
				print "Removing access: {".join(", ", @del_users)."} to $host/$service\n";
			}
			my $res = $ldap->modify($group, %changes);
			$res->is_error and warn ldap_errmsg($res, $group);
		}
		else {
			# list members
			my $res = $ldap->search(base => $group, scope => "base",
				filter => q(objectClass=*), attrs => ["member"]);
			$res->is_error and warn ldap_errmsg($res, $group);
			for my $entry ($res->entries) {
				my @members = $entry->get_value("member");
				print "$host/$service\t$_\n"
					for sort map {from_dn($_, "ou=people,dc=cluenet,dc=org", 1)} @members;
			}
		}
	}
};

$commands{"acl"} = sub {
	my $err;
	$ldap = connect_anon;
	for my $host (@_) {
		my ($dn, $res);
		# authz = authorizedService attributes
		# acl = cn=svcAccess subentry
		my (%services, @svcs_authz, @svcs_acl);

		$dn = server_dn($host);
		$res = $ldap->search(base => $dn, scope => "bas",
			filter => q(objectClass=*), attrs => ["authorizedService"]);
		if ($res->is_error) { warn ldap_errmsg($res, $dn); $err++; }
		for my $entry ($res->entries) {
			@svcs_authz = $entry->get_value("authorizedService");
			last;
		}

		$dn = "cn=svcAccess,".server_dn($host);
		$res = $ldap->search(base => $dn, scope => "one",
			filter => q(objectClass=groupOfNames), attrs => ["cn"]);
		if ($res->is_error) { warn ldap_errmsg($res, $dn); $err++; }
		for my $entry ($res->entries) {
			push @svcs_acl, $entry->get_value("cn");
		}

		# create a hash of $service => [has_authz, has_acl]
		%services = map {$_ => [1, undef]} @svcs_authz;
		$services{$_}->[1] = 1 for @svcs_acl;

		for my $svc (sort keys %services) {
			my ($authz, $acl) = @{$services{$svc}};
			if (!$authz) {
				print STDERR "warning: service '$svc' does not have an authorizedService\n";
			} elsif (!$acl) {
				print STDERR "warning: service '$svc' does not have an ACL\n";
			}
			print "$host/$svc\n";
		}
	}
};

$commands{"acl:create"} = sub {
	my $err;
	$ldap = connect_auth;
	for (@_) {
		my ($host, $service) = to_hostservice_safe($_);
		my ($dn, $res, %entry);
		
		print "Creating ACL: $host/$service\n";
		$dn = "cn=$service,cn=svcAccess,".server_dn($host);
		%entry = (
			objectClass => "groupOfNames",
			cn => $service,
			member => user_dn(whoami),
		);
		$res = $ldap->add($dn, attr => [%entry]);
		if ($res->is_error) { warn ldap_errmsg($res, $dn); $err++; }
		
		$dn = server_dn($host);
		%entry = (authorizedService => $service);
		$res = $ldap->modify($dn, add => \%entry);
		if ($res->is_error) { warn ldap_errmsg($res, $dn); $err++; }
	}
	return $err;
};

$commands{"acl:delete"} = sub {
	my $err;
	$ldap = connect_auth;
	for (@_) {
		my ($host, $service) = to_hostservice_safe($_);
		my ($dn, $res, %entry);
		
		print "Deleting ACL: $host/$service\n";
		$dn = "cn=$service,cn=svcAccess,".server_dn($host);
		$res = $ldap->delete($dn);
		if ($res->is_error) { warn ldap_errmsg($res, $dn); $err++; }
		
		$dn = server_dn($host);
		%entry = (authorizedService => $service);
		$res = $ldap->modify($dn, delete => \%entry);
		if ($res->is_error) { warn ldap_errmsg($res, $dn); $err++; }
	}
	return $err;
};

$commands{"server:create"} = sub {
	my $err;
	$ldap = connect_auth;

	my ($host, $dn, $subdn, $owner, $res, %entry);
	$host = shift;
	$dn = server_dn($host);

	Getopt::Long::GetOptionsFromArray(\@_, "o|owner=s" => \$owner);
	if (!defined $owner) {
		die "error: owner must be specified\n";
	}

	%entry = (
		objectClass => ["server", "ipHost",
			"authorizedServiceObject", "serviceRequirementObject"],
		cn => fqdn($host),
		owner => user_dn($owner),
		isOfficial => "FALSE",
		userAccessible => "TRUE",
		isActive => "TRUE",

		authorizedService => [SHELL_SERVICES],

		# dummy address for oC=ipHost
		ipHostNumber => "0.0.0.0",
	);
	print Dumper \%entry;
	#$res = $ldap->add($dn, attr => [%entry]);
	#if ($res->is_error) { warn ldap_errmsg($res, $dn); $err++; }

	my $subdn = "cn=svcAccess,$dn";
	%entry = (
		objectClass => "groupOfGroups",
		cn => "svcAccess",
		description => "Tree for groups of users that can access certain services.",
	);
	print Dumper \%entry;

	for (SHELL_SERVICES) {
		$subdn = "cn=$_,cn=svcAccess,$dn";
		%entry = (
			objectClass => "groupOfNames",
			cn => $_,
			member => user_dn($owner),
		);
		print Dumper \%entry;
	}

	return $err;
};

$commands{"help"} = sub {
	print qq{Usage: cluenet <command>

ACCESS LISTS
	read	access <host/service>...
	modify	access <host/service>... [+-]<user>...
	list	acl <host>...
	create	acl:create <host/service>...
	delete	acl:delete <host/service>...

NOT YET IMPLEMENTED
	server:create <host> --owner <owner>
};

	return 0;
};

$commands{"whoami"} = sub {
	$ldap = connect_auth();
	print $ldap->who_am_i->response."\n";
};

### Main code

$cmd = shift(@ARGV) // "help";

if (defined $commands{$cmd}) {
	$exit = $commands{$cmd}->(@ARGV);
	$ldap and $ldap->unbind;
	exit $exit ? 1 : 0;
} else {
	die "Unknown command '$cmd'\n";
}
