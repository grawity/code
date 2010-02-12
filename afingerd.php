#!/usr/bin/php
<?php
define("VERSION", "afingerd.php v1.38 2009-12-25");
# a PHP finger daemon

# (c) 2009 Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>

define("DATE_FORMAT", "%a %b %e %R %Y (%Z)");

# Print a newline if two elements printed since last one
# (for the login/name/directory/shell columns)
function newline($force = false) {
	static $elements;
	if (++$elements % 2 == 0)
		print("\r\n");
}

# Convert config value to boolean
function bool($v) {
	if ($v === true) return true;
	$v = strtolower(trim($v));
	return $v == "1"
		or $v == "on"
		or $v == "true"
		or $v == "y"
		or $v == "yes";
}

# Read afingerd configuration from file
function read_config($file, $is_global_conf = false) {
	if (!is_file($file) or !is_readable($file)) return;

	$data = @parse_ini_file($file, true);
	if (!$data) {
		print("fingerd: parsing $file failed\r\n");
		return false;
	}

	foreach ($data as $section => $keys) switch ($section) {
	case "allow":
		if (!$is_global_conf) break;
		global $allow;
		foreach ($keys as $key => $value) switch ($key) {
		case "userlist":
			// see comments in respond_userlist()
			global $allow_userlist;
			$allow_userlist = bool($value);
			break;
		case "recursive":
			global $allow_recursive;
			$allow_recursive = bool($value);
			break;
		case "user_config":
			global $allow_user_config;
			$allow_user_config = bool($value);
			break;
		case "min_uid":
			global $min_uid;
			$min_uid = (int) $value;
			break;
		}
		break;
	
	case "display":
		global $show;
		foreach ($keys as $key => $value)
			$show[$key] = bool($value);
		break;
	
	case "mail":
		foreach ($keys as $key => $value) switch ($key) {
		case "mailspool":
			if (!$is_global_conf) break;

			global $mailspool_path;
			$mailspool_path = $value;
			break;

		case "inbox":
			global $user_inbox_path;
			$user_inbox_path = $value;
			break;
		}
		break;
	}
}

# Print the entire infoscreen
function respond_user($login) {
	global $min_uid, $allow_user_config, $show;
	
	$pw = posix_getpwnam($login);
	if ($pw === false)
		return respond_nouser();
	$pw = (object) $pw;
	
	# Disallow system users
	if ($pw->uid < $min_uid and $pw->uid != 0)
		return respond_nouser();
	
	if (file_exists("{$pw->dir}/.nofinger"))
		return respond_nouser();
	
	if ($allow_user_config) {
		read_config("{$pw->dir}/.config/afingerd.conf");
		read_config("{$pw->dir}/.afingerd");
	}
	
	$name = strtok($pw->gecos, ",");
	$room = strtok(",");
	$work_phone = strtok(",");
	$home_phone = strtok(",");

	$show["office"] &= ($room !== false);
	$show["work_phone"] &= ($work_phone !== false);
	$show["home_phone"] &= ($home_phone !== false);
	
	printf("Login: %-33s", $pw->name);
	newline();

	printf("Name: %-34s", $name === false? "(null)" : $name);
	newline();
	
	if ($show["homedir"]) {
		printf("Directory: %-29s", $pw->dir);
		newline();
	}
	
	if ($show["shell"]) {
		printf("Shell: %-33s", $pw->shell);
		newline();
	}
	
	$office = array();
	if ($show["office"])
		$office[] = $room;
	if ($show["work_phone"])
		$office[] = $work_phone;
	
	if (count($office) > 0) {
		printf("Office: %-32s", implode(", ", $office));
		newline();
	}
	
	if ($show["home_phone"]) {
		printf("Home phone: %-28s", $home_phone);
		newline();
	}
	
	if ($show["mail_forward"])
		respond_user_file("{$pw->dir}/.forward", "Mail forwarded to ");
	
	if ($show["mail_status"])
		respond_user_mailstatus($pw);
	
	# .pgpkey, .project, and .plan
	if ($show["pgpkey"])
		respond_user_file("{$pw->dir}/.pgpkey", "PGP key:\r\n");

	if ($show["project"])
		respond_user_file("{$pw->dir}/.project", "Project:\r\n");

	if ($show["plan"])
		respond_user_file("{$pw->dir}/.plan", "Plan:\r\n")
			or print("No Plan.\r\n");
}

# print contents of a user file (.plan or such)
function respond_user_file($path, $title) {
	$fh = @fopen($path, "r");
	if ($fh) {
		print($title);
		fpassthru_conv($fh);
		fclose($fh);
		return true;
	}
	else {
		return false;
	}
}

# print user's mailbox status
function respond_user_mailstatus($pwent) {
	global $mailspool_path, $user_inbox_path;
	
	if ($user_inbox_path == null)
		$path = "${mailspool_path}/{$pwent->name}";
	else
		$path = $user_inbox_path;

	if (substr($path, 0, 2) == "~/")
		$path = "{$pwent->dir}/" . substr($path, 2);
	
	$stat = @stat($path);
	if ($stat === false or $stat["size"] == 0) {
		print("No mail.\r\n");
	}
	elseif ($stat["mtime"] > $stat["atime"]) {
		printf("New mail received %s\r\n",
			strftime(DATE_FORMAT, $stat["mtime"]));
		printf("     Unread since %s\r\n",
			strftime(DATE_FORMAT, $stat["atime"]));
	}
	else {
		printf("Mail last read %s\r\n",
			strftime(DATE_FORMAT, $stat["atime"]));
	}
}

# print userlist
function respond_userlist() {
	global $allow_userlist;

	// if I use system(), it does not enable .nofinger checking.
	// pcntl_exec(), on the other hand, causes it to fail on IPv6 addresses :(
	/*
	if ($allow_userlist)
		switch (pcntl_fork()) {
		case -1:
			print("finger: fork() failed\r\n");
			break;
		case 0:
			pcntl_exec("/usr/bin/finger", array("-s"));
			exit;
		default:
			pcntl_wait($status);
		}
	else
	*/
		print("finger: userlist is disabled\r\n");
}

function respond_nouser() {
	print("finger: sorry, no such user.\r\n");
}

# convert newlines to CR/LF
function fpassthru_conv($fh) {
	while (($line = fgets($fh)) !== false)
		print(rtrim($line) . "\r\n");
}

function forward_query($query, $detailed) {
	$p = strrpos($query, "@");
	$host = substr($query, $p+1);
	$query = substr($query, 0, $p);

	if ($detailed)
		$query = "/W $query";

	$port = getservbyname("finger", "tcp");
	if (!$port) {
		print("finger: tcp/finger: unknown protocol\r\n");
		return;
	}

	$sock = @fsockopen($host, $port, $errno, $errstr, 30);
	if (!$sock) {
		printf("finger: %s (%s)\r\n", $errstr, $errno);
		return;
	}
	print("[{$host}]\r\n");
	fwrite($sock, $query."\r\n");
	fpassthru_conv($sock);
	#while (($char = fgetc($sock)) !== false)
	#	print($char);
	fclose($sock);
}

### Configuration
### Use /etc/afingerd.conf, don't edit these.

# hier(7) says /var/spool/mail is obsolete; however, /var/mail symlinks to it.
if (is_dir("/var/mail"))
	$mailspool_path = "/var/mail";
else
	$mailspool_path = "/var/spool/mail";

$user_inbox_path = null;

$allow_userlist = true;
$allow_recursive = false;
$allow_user_config = true;
$min_uid = 1000;

$show = array(
	#"login"      => true, # required by RFC 1288
	#"name"       => true, # required by RFC 1288
	"homedir"      => true,
	"shell"        => true,
	"office"       => true,
	"home_phone"   => true,
	"work_phone"   => true,
	"mail_forward" => true,
	"mail_status"  => true,
	"pgpkey"       => true,
	"project"      => true,
	"plan"         => true,
);

read_config($argc > 1? $argv[1] : "/etc/afingerd.conf", true);

$options = getopt("hv");
if (isset($options["h"]))
	die("afingerd should be run from inetd or a similar service.\n");
if (isset($options["v"]))
	die(VERSION."\n");
unset($options);

# preventing DoS
stream_set_timeout(STDIN, 30);

$query = stream_get_line(STDIN, 1024, "\r\n");

$detailed = false;

# Request for full information? (as in finger -l)
if ($query == "/W" or substr($query, 0, 3) == "/W ") {
	$detailed = true;
	$query = ltrim(substr($query, 3));
}

# recursive request
if (strpos($query, "@") !== false) {
	if ($allow_recursive) {
		syslog(LOG_INFO, "fingerd: fingered $query");
		recursive_query($query, $detailed);
	}
	else {
		syslog(LOG_NOTICE, "fingerd: rejected $query");
		print("finger: recursive queries not allowed\r\n");
	}
	exit();
}
elseif ($query == "") {
	respond_userlist($detailed);
}
else {
	respond_user($query);
}
