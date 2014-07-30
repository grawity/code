#!/usr/bin/perl
# Attempt to reimplement the main process finding logic of procps `w`.
# Status: implementation mostly working, but decided not to merge into rwho
use common::sense;
use Data::Dumper;
use Proc::ProcessTable;
use Sys::Utmp;

my $ignoreuser = 0;

my ($proc, $table, $utmp);

sub getproc {
	my ($user, $tty, $tpid) = @_;
	# Stolen from procps/w.c:140

	$tty = "/dev/$tty";
	my $uid = scalar getpwnam($user);

	my ($best, $secondbest);

	for my $proc (@$table) {
		next if !defined $proc->{ttynum};
		# ->pid is used as the POSIX equiv to Linux ->tgid
		if ($proc->pid == $tpid) {
			$best = $proc;
		}
		if ($proc->ttydev ne $tty) {
			next;
		}
		$secondbest = $proc;
		unless ($secondbest and $proc->start <= $secondbest->start) {
			$secondbest = $proc;
		}
		if (!$ignoreuser and $uid != $proc->euid and $uid != $proc->uid) {
			next;
		}
		#if ($p->pgrp != $p->tpgid) {next;}
		if ($best and $proc->start <= $best->start) {
			next;
		}
		$best = $proc;
	}
	return ([@{$best}{qw{pid cmndline}}],
		[@{$secondbest}{qw{pid cmndline}}]);
}

$proc = Proc::ProcessTable->new();
$table = $proc->table;
$utmp = Sys::Utmp->new();

while (my $ent = $utmp->getutent()) {
	if ($ent->user_process) {
		printf "--- %s %s ---\n", $ent->ut_user, $ent->ut_line;
		my ($b, $s) = getproc($ent->ut_user, $ent->ut_line, $ent->ut_pid);
		printf "Best: %s %s\n", @$b;
		printf "Secn: %s %s\n", @$s;
	}
}

if ($ignoreuser) {
	system "w -u";
} else {
	system "w";
}
