#!/usr/bin/perl
use strict;
use constant LDAP_HOST => "ldap.cluenet.org";

use Getopt::Long;
use Socket;
use Net::DNS;
use Net::IP;
use Authen::SASL;
use Socket::GetAddrInfo qw(:newapi getaddrinfo);
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
	my %hint = (flags => Socket::GetAddrInfo->AI_CANONNAME);
	my ($err, @ai) = getaddrinfo($host, "", \%hint);
	return $err ? $host : ((shift @ai)->{canonname} // $host);
}

sub lookup_host {
	my ($host) = @_;
	my @addrs = ();
	my $r = Net::DNS::Resolver->new;

	my $query = $r->query($host, "A");
	if ($query) { push @addrs, $_->address for $query->answer }

	$query = $r->query($host, "AAAA");
	if ($query) { push @addrs, $_->address for $query->answer }

	return @addrs;
}

sub format_name {
	my ($user) = @_;
	my $name = $user->{uid};
	if ($user->{cn} ne $user->{uid}) {
		$name .= " (".$user->{cn}.")";
	}
	return $name;
}

sub format_address {
	my ($host, $port) = @_;
	if ($host =~ /:/) {
		$host = Net::IP::ip_compress_address($host, 6);
		return "[$host]:$port";
	} else {
		return "$host:$port";
	}
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
sub user_from_dn {
	from_dn(shift, "ou=people,dc=cluenet,dc=org", 1);
}
sub server_from_dn {
	from_dn(shift, "ou=servers,dc=cluenet,dc=org", 1);
}

### LDAP connection

# Establish LDAP connection, authenticated or anonymous
sub connect_auth() {
	my $sasl = Authen::SASL->new("GSSAPI");
	my $ldap = Net::LDAP->new(LDAP_HOST) or die "$!";
	#$ldap->start_tls(verify => "require",
	#	cafile => "$ENV{HOME}/lib/ca/cluenet.pem") or die "$@";
	my $authen = $sasl->client_new("ldap", canon_host LDAP_HOST);
	my $msg = $ldap->bind(sasl => $authen);
	$msg->code and die "error: ".$sasl->error;
	return $ldap;
}
sub connect_anon() {
	my $ldap = Net::LDAP->new(LDAP_HOST) or die "$!";
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

$commands{"server"} = sub {
	$ldap = connect_anon;
	my $server = get_server_info(shift);
	my $owner = get_user_info($server->{owner}, 1);
	my @admins = map {get_user_info($_, 1)}
		@{$server->{authorizedAdministrator}};
	print_server_info($server, $owner, @admins);
	print_user_info($owner);
	print_user_info($_) for @admins;
	return 0;
};

sub get_server_info {
	my ($host, $is_dn) = @_;
	my $dn = $is_dn ? $host : server_dn($host);

	my $res = $ldap->search(base => $dn, scope => "base",
		filter => q(objectClass=server));
	$res->is_error and die ldap_errmsg($res, $dn);
	for my $entry ($res->entries) {
		my %server = map {$_ => [$entry->get_value($_)]} $entry->attributes;
		for (qw(cn owner internalAddress serverRules sshPort)) {
			$server{$_} = $server{$_}->[0];
		}
		for (qw(isActive isOfficial userAccessible)) {
			$server{$_} = $server{$_}->[0] eq "TRUE";
		}
		$server{address} = [lookup_host($server{cn})];
		return \%server;
	}
}
sub get_user_info {
	my ($user, $is_dn) = @_;
	my $dn = $is_dn ? $user : user_dn($user);

	my $res = $ldap->search(base => $dn, scope => "base",
		filter => q(objectClass=posixAccount));
	$res->is_error and die ldap_errmsg($res, $dn);
	for my $entry ($res->entries) {
		my %user;
		for (qw(uid uidNumber gidNumber gecos homeDirectory loginShell cn
				krb5PrincipalName clueIrcNick ircServicesUser)) {
			$user{$_} = $entry->get_value($_);
		}
		return \%user;
	}
}

sub print_server_info {
	my ($server, $owner, @admins) = @_;
	@admins = sort {$a->{uid} cmp $b->{uid}} @admins;
	my $port = $server->{sshPort} // 22;
	my $fmt = "%-16s%s\n";
	printf $fmt, "hostname:", uc $server->{cn};
	printf $fmt, "address:", format_address($_, $port)
		for @{$server->{address}};
	printf $fmt, "owner:", format_name($owner);
	printf $fmt, "admin:", format_name($_)
		for @admins;
	printf $fmt, "status:", join(", ", grep {defined} (
		$server->{isOfficial}? "official" : "unofficial",
		$server->{userAccessible}? "public" : "private",
		$server->{isActive}? "active" : "inactive",
		(grep {/:/} @{$server->{address}})? "IPv6" : undef,
		));

	if (defined $server->{authorizedService}) {
		my @services = sort @{$server->{authorizedService}};
		printf $fmt, "services:", join(", ", @services);
	}
	print "\n";
}

sub print_user_info {
	my ($user) = @_;
	my $fmt = "%-16s%s\n";
	printf $fmt, "person:", uc $user->{uid};
	print "\n";
}

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
