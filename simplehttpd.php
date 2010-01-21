#!/usr/bin/php
<?php
$VERSION = "simplehttpd v1.2";
$WARNING = "[;37;41;1;5m NOT TO BE USED IN PRODUCTION ENVIRONMENTS [m\n";
# simple HTTP server

# (c) 2009 Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>

# help message must be not wider than 80 characters                            #
$HELP = <<<EOTFM
Usage: simplehttpd [-46Lahuv] [-d docroot] [-f num] [-l address] [-p port]
	[-U suffix]

Options:
  -4                           Force IPv4
  -6                           Force IPv6, even for IPv4 addresses
  -a                           List all files, including hidden, in directories
  -f number                    Number of subprocesses (0 disables)
  -d path                      Specify docroot (default is ~/public_html)
  -h                           Display help message
  -L                           Bind to localhost (::1 or 127.0.0.1)
  -l address                   Bind to specified local address (default is ::)
  -p port                      Listen on specified port
  -U suffix                    Set userdir suffix (default is 'public_html')
  -u                           Enable userdirs
  -v                           Display version

$WARNING
EOTFM;

if (isset($_SERVER["REMOTE_ADDR"])) {
	header("Content-Type: text/plain; charset=utf-8");
	header("Last-Modified: " . date("r", filemtime(__FILE__)));
	readfile(__FILE__);
	die;
}

if (!function_exists("socket_create")) {
	fwrite(STDERR, "Error: 'sockets' extension not available\n");
	exit(3);
}

date_default_timezone_set("UTC");

# expand path starting with ~/ when given value of ~
function tilde_expand($path, $homedir) {
	if ($path == "~")
		$path .= "/";

	if ($homedir and substr($path, 0, 2) == "~/")
		$path = $homedir . substr($path, 1);

	return $path;
}

# expand path starting with ~/ using $HOME
function tilde_expand_own($path) {
	$home = get_homedir();
	return $home? tilde_expand($path, $home) : $path;
}

# get homedir for current user (for determining default docroot)
function get_homedir() {
	$home = null;

	if (!$home)
		$home = getenv("HOME");

	if (!$home and function_exists("posix_getpwnam")) {
		$uid = posix_getuid();
		$pw = posix_getpwuid($uid);
		if ($pw) $home = $pw["dir"];
	}

	if (!$home)
		$home = getenv("USERPROFILE");

	return $home? $home : false;
}

# get docroot for given user (homedir + suffix)
function get_user_docroot($user) {
	global $config;
	$user_home = null;

	if (!$user_home and function_exists("posix_getpwnam")) {
		$pw = posix_getpwnam($user);
		if ($pw) $user_home = $pw["dir"];
	}

	if (!$user_home)
		return false;

	return $user_home? $user_home."/".$config->userdir_suffix : false;
}

# parse request path (/foo.html or /~user/foo.html) and return absolute
# filesystem path
function get_docroot($fs_path) {
	global $config;

	# if $enable_userdirs is off, /~foo/ will be taken literally
	if ($config->userdirs and substr($fs_path, 0, 2) == "/~") {
		$user_path = substr($fs_path, 2);
		$req_user = strtok($user_path, "/");
		$user_path = (string) strtok("");

		$user_dir = get_user_docroot($req_user);

		if ($user_dir and is_dir(deref_symlink($user_dir))) {
			return $user_dir."/".$user_path;
		}
		else
			return $config->docroot."/".$fs_path;
	}
	else {
		# no userdir in request
		return $config->docroot."/".$fs_path;
	}
}

# read line (ending with CR+LF) from socket
function socket_gets($socket, $maxlength = 1024) {
	# This time I'm really sure it works.
	$buf = ""; $i = 0; $char = null;
	while ($i < $maxlength) {
		$char = socket_read($socket, 1, PHP_BINARY_READ);
		# remote closed connection
		if ($char === false) return $buf;
		# no more data
		if ($char == "") return $buf;

		$buf .= $char;

		# ignore all stray linefeeds
		#if ($i > 0 and $buf[$i-1] == "\x0D" and $buf[$i] == "\x0A")
		#	return substr($buf, 0, $i-1);

		# terminate on both LF and CR+LF
		if ($buf[$i] == "\x0A") {
			if ($i > 0 and $buf[$i-1] == "\x0D")
				return substr($buf, 0, $i-1);
			else
				return substr($buf, 0, $i);
		}

		$i++;
	}
	return $buf;
}

# print error message and die
function _die($message) {
	if (!empty($message))
		fwrite(STDERR, "$message\n");
	exit(1);
}

function _die_socket($message, $socket = false) {
	if (!empty($message))
		fwrite(STDERR, "$message: ");

	$errno = (is_resource($socket)? socket_last_error($socket) : socket_last_error());
	$errstr = socket_strerror($errno);
	fwrite(STDERR, "$errstr [$errno]\n");

	exit(1);
}

# dereference symlink
function deref_symlink($file) {
	$i = 0; while (is_link($file)) {
		if (++$i < 32)
			$target = readlink($file);
		else
			$target = false;

		if ($target === false) return $file;

		# relative link
		if ($target[0] != '/')
			$target = dirname($file) . "/" . $target;

		$file = $target;
	}
	return $file;
}

function load_mimetypes($path = "/etc/mime.types") {
	global $content_types;
	$fh = @fopen($path, "r");
	if (!$fh) return false;
	while ($line = fgets($fh)) {
		$line = rtrim($line);
		if ($line == "" or $line[0] == " " or $line[0] == "#") continue;
		$line = preg_split("/\s+/", $line);
		$type = array_shift($line);
		foreach ($line as $ext) $content_types[$ext] = $type;
	}
	fclose($fh);
}

function send($fd, $data) {
	for ($total = 0; $total < strlen($data); $total += $num) {
		$num = socket_write($fd, $data);
		$data = substr($data, $total);
		if ($num == 0) return false;
	}
	return $total;
}

function handle_request($sockfd, $logfd) {
	global $config;

	$req = new stdClass();
	$resp = new stdClass();

	socket_getpeername($sockfd, $req->rhost, $req->rport);
	fwrite($logfd, "(".strftime($config->log_date_format).") {$req->rhost}:{$req->rport} ");

	$resp->headers = array(
		"Content-Type" => "text/plain",
		//"Connection" => "close",
	);


	$req->rawreq = socket_gets($sockfd);

	if ($req->rawreq == "") {
		fwrite($logfd, "(null)\n");
		return;
	}

	fwrite($logfd, $req->rawreq."\n");

	# method = up to the first space
	# path = up to the second space
	# version = the rest, including any further components
	$req->method = strtok($req->rawreq, " ");
	$req->path = strtok(" ");
	$req->version = strtok("");

	if ($req->version == false) {
		$req->version = "HTTP/1.0";
	}
	elseif (strpos($req->version, " ") !== false) {
		# more than 3 components = bad
		return re_bad_request($sockfd);
	}
	elseif (strtok($req->version, "/") !== "HTTP") {
		# we're not a HTCPCP server
		return re_bad_request($sockfd);
	}

	# ...and slurp in the request headers.
	$req->headers = array();
	while (true) {
		$hdr = socket_gets($sockfd);
		if (!strlen($hdr)) break;
		$req->headers[] = $hdr;
	}
	unset ($hdr);

	if ($req->method == "TRACE" or $req->path == "/echo") {
		send_headers($sockfd, $req->version, null, 200);
		send($sockfd, $req->rawreq."\r\n");
		send($sockfd, implode("\r\n", $req->headers)."\r\n");
		socket_close($sockfd);
		return;
	}

	if ($req->method != "GET") {
		# Not implemented
		return re_error($sockfd, $req, 501);
	}

	if ($req->path[0] != "/") {
		return re_error($sockfd, $req, 400);
	}

	$req->path = strtok($req->path, "?");
	$req->query = strtok("");

	$req->fspath = urldecode($req->path);
	
	# get rid of dot segments ("." and "..")
	while (strpos($req->fspath, "/../") !== false)
		$req->fspath = str_replace("/../", "/", $req->fspath);
	while (strpos($req->fspath, "/./") !== false)
		$req->fspath = str_replace("/./", "/", $req->fspath);

	while (substr($req->fspath, -3) == "/..")
		$req->fspath = substr($req->fspath, 0, -2);
	while (substr($req->fspath, -2) == "/.")
		$req->fspath = substr($req->fspath, 0, -1);

	$req->fspath = get_docroot($req->fspath);

	# If given path is a directory, append a slash if required
	if (is_dir($req->fspath) and substr($req->path, -1) != "/") {
		send_headers($sockfd, $req->version, array(
			"Location" => $req->path."/",
		), 301);
		socket_close($sockfd);
		return;
	}

	# check for indexfiles
	if (is_dir($req->fspath)) {
		global $index_files;
		foreach ($config->index_files as $file)
			if (is_file($req->fspath . $file)) {
				$req->fspath .= $file;
				$auto_index_file = true;
				break;
			}
	}

	$req->fspath = deref_symlink($req->fspath);

	# dest exists, but is not readable => 403
	if (file_exists($req->fspath) and !is_readable($req->fspath)) {
		return re_error($sockfd, $req, 403);
	}

	# dest exists, and is a directory => display file list
	if (is_dir($req->fspath)) {
		$resp->headers["Content-Type"] = "text/html; charset=utf-8";
		send_headers($sockfd, $req->version, $resp->headers, 200);
		return re_generate_dirindex($sockfd, $req->path, $req->fspath);
	}

	# dest is regular file => display
	elseif (is_file($req->fspath)) {
		$info = pathinfo($req->fspath);

		if (isset($info['extension'])) {
			$ext = $info['extension'];

			if ($ext == "gz") {
				$resp->headers["Content-Encoding"] = "gzip";
				$ext = pathinfo($info['filename'], PATHINFO_EXTENSION);
			}

			global $content_types;
			if (isset($content_types[$ext]))
				$resp->headers["Content-Type"] = $content_types[$ext];
			else
				$resp->headers["Content-Type"] = "text/plain";
		}

		send_headers($sockfd, $req->version, $resp->headers, 200);
		send_file($sockfd, $req->fspath);
		socket_close($sockfd);
		return;
	}

	# dest exists, but not a regular or directory => 403
	elseif (file_exists($req->fspath)) {
		return re_error($sockfd, $req, 403);
	}

	# dest doesn't exist => 404
	else {
		return re_error($sockfd, $req, 404);
	}

}

# List files in a directory
function re_generate_dirindex($sockfd, $req_path, $fs_path) {
	global $config;
	$dirs = $files = array();

	$dirfd = opendir($fs_path);
	while (($entry = readdir($dirfd)) !== false) {
		if ($entry == ".")
			continue;

		if ($config->hide_dotfiles and $entry[0] == "." and $entry != "..")
			continue;

		$entry_path = $fs_path.$entry;

		if (is_dir(deref_symlink($entry_path)))
			$dirs[] = $entry;
		else
			$files[] = $entry;
	}
	closedir($dirfd);

	sort($dirs);
	sort($files);

	$page_title = htmlspecialchars($req_path);
	send($sockfd,
		"<!DOCTYPE html>\n".
		"<html>\n".
		"<head>\n".
		"\t<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />\n".
		"\t<title>index: {$page_title}</title>\n".
		"\t<style type=\"text/css\">\n".
		"\ta { font-family: monospace; text-decoration: none; }\n".
		"\t.symlink, .size { color: gray; }\n".
		"\tfooter { font-size: smaller; color: gray; }\n".
		"\t</style>\n".
		"</head>\n".
		"<body>\n".
		"<h1>{$page_title}</h1>\n".
		"<ul>\n"
	);

	foreach ($dirs as $entry) {
		$entry_path = $fs_path.$entry;
		$anchor = urlencode($entry);

		if ($entry == '..')
			$entry = "(parent directory)";

		$text = "<a href=\"{$anchor}/\">{$entry}/</a>";
		if (is_link($entry_path) and $entry_dest = @readlink($entry_path))
			$text .= " <span class=\"symlink\">→ ".htmlspecialchars($entry_dest)."</span>";
		send($sockfd, "\t<li>{$text}</li>\n");
	}

	foreach ($files as $entry) {
		$entry_path = $fs_path.$entry;
		$anchor = urlencode($entry);

		$text = "<a href=\"{$anchor}\">{$entry}</a>";
		if (is_link($entry_path) and $entry_dest = @readlink($entry_path))
			$text .= " <span class=\"sym\">→ ".htmlspecialchars($entry_dest)."</span>";
		if ($size = @filesize($entry_path))
			$text .= " <span class=\"size\">({$size})</span>";
		send($sockfd, "\t<li>{$text}</li>\n");
	}

	send($sockfd,
		"</ul>\n".
		"<hr/>\n".
		"<footer><p>simplehttpd</p></footer>\n".
		"</body>\n".
		"</html>\n"
	);

	return true;
}

function re_bad_request($sockfd) {
	send_headers($sockfd, "HTTP/1.0", null, 400);
	send($sockfd, "Are you on drugs?\r\n");
	return false;
}

function re_error($sockfd, $req, $status, $comment = null) {
	global $messages;

	send_headers($sockfd, $req->version, null, $status);

	send($sockfd, "Error $status: "
		. (isset($messages[$status]) ? $messages[$status] : "FUCKED UP")
		. "\r\n"
		);
	send($sockfd, "Request: {$req->rawreq}\r\n");

	return false;
}

# If $headers is NULL, "Content-Type: text/plain" will be sent.
# To send no headers, specify an empty array().
function send_headers($sockfd, $version, $headers, $status = 200) {
	global $messages;

	send($sockfd, "$version $status "
		. (isset($messages[$status]) ? $messages[$status] : "FUCKED UP")
		. "\r\n"
		);

	if ($headers === null)
		send($sockfd, "Content-Type: text/plain; charset=utf-8\r\n");

	else foreach ($headers as $key => $value)
		send($sockfd, "$key: $value\r\n");

	send($sockfd, "\r\n");
}

function send_file($sockfd, $file) {
	$filefd = fopen($file, "rb");
	while (!feof($filefd)) {
		$buffer = fread($filefd, 1024);
		if ($buffer == "" or $buffer == false) {
			fclose($filefd);
			return false;
		}
		send($sockfd, $buffer);
	}
	fclose($filefd);
}

$messages = array(
	200 => "Okie dokie",
	301 => "Moved Permanently",
	400 => "Bad Request",
	401 => "Unauthorized",
	403 => "Forbidden",
	404 => "Not Found",
	405 => "Method Not Allowed",
	418 => "I'm a teapot",
	500 => "Internal error (something fucked up)",
	501 => "Not Implemented",
);

## Default configuration

$config = new stdClass();

$config->docroot = tilde_expand_own("~/public_html");
if (!is_dir(deref_symlink($config->docroot)))
	$config->docroot = ".";

$config->userdirs = false;
$config->userdir_suffix = "public_html";

$config->index_files = array( "index.html", "index.htm" );
$config->hide_dotfiles = true;

$addr_family = -1;
$config->listen_addr = "::";
$config->listen_port = 8001;

$config->forks = 3;

$logfd = STDOUT;

$config->log_date_format = "%a %b %_d %H:%M:%S %Y";

$content_types = array(
	"css" => "text/css",
	"gif" => "image/gif",
	"htm" => "text/html",
	"html" => "text/html",
	"jpeg" => "image/jpeg",
	"jpg" => "image/jpeg",
	"js" => "text/javascript",
	"m4a" => "audio/mp4",
	"m4v" => "video/mp4",
	"mp4" => "application/mp4",
	"oga" => "audio/ogg",
	"ogg" => "audio/ogg",
	"ogv" => "video/ogg",
	"ogm" => "application/ogg",
	"png" => "image/png",
	"tgz" => "application/x-tar",
);

## Command-line options

$opts = getopt("64ac:d:f:IhLl:p:U:uv", array("help"));

if (isset($opts["h"]) or isset($opts["help"]) or $opts === false) {
	fwrite(STDERR, $HELP);
	exit(2);
}

foreach ($opts as $opt => $value) switch ($opt) {
	case "6":
		$addr_family = AF_INET6; break;
	case "4":
		$addr_family = AF_INET; break;
	case "a":
		$config->hide_dotfiles = false; break;
	case "d":
		$config->docroot = $value; break;
	case "f":
		$config->forks = (int) $value; break;
	case "L":
		# -4 will be handled later
		$config->listen_addr = "::1"; break;
	case "l":
		$config->listen_addr = $value; break;
	case "p":
		$config->listen_port = (int) $value; break;
	case "U":
		$config->userdir_suffix = $value;
	case "u":
		$config->userdirs = true; break;
	case "v":
		die(VERSION."\n");
}

$addr_is_v6 = (strpos($config->listen_addr, ":") !== false);

if ($addr_family == AF_INET6) {
	if (!$addr_is_v6) {
		$config->listen_addr = "::ffff:".$config->listen_addr;
		$addr_is_v6 = true;
	}
}
elseif ($addr_family == AF_INET) {
	if ($config->listen_addr == "::")
		$config->listen_addr = "0.0.0.0";

	elseif ($config->listen_addr == "::1")
		$config->listen_addr = "127.0.0.1";

	elseif ($addr_is_v6) {
		fwrite(STDERR, "Error: IPv4 forced but IPv6 listen address specified\n");
		exit(5);
	}
}
else {
	$addr_family = $addr_is_v6? AF_INET6 : AF_INET;
}

if (!@chdir($config->docroot)) {
	fwrite(STDERR, "Error: Cannot chdir to docroot {$config->docroot}\n");
	exit(1);
}

$config->docroot = getcwd();
$local_hostname = php_uname("n");

load_mimetypes();
load_mimetypes(tilde_expand_own("~/.mime.types"));
ksort($content_types);

$listener = @socket_create($addr_family, SOCK_STREAM, SOL_TCP);

$listener or _die_socket("socket_create");

socket_set_option($listener, SOL_SOCKET, SO_REUSEADDR, 1);

@socket_bind($listener, $config->listen_addr, $config->listen_port)
	or _die_socket("socket_bind", $listener);

@socket_listen($listener, 2)
	or _die_socket("socket_listen", $listener);

fwrite($logfd, "* docroot {$config->docroot}\n");
fwrite($logfd, "* listening on " . ($addr_is_v6? "[{$config->listen_addr}]" : $config->listen_addr) . ":{$config->listen_port}\n");

if ($config->forks and function_exists("pcntl_fork")) {
	function sigchld_handler($sig) {
		wait(-1);
	}
	pcntl_signal(SIGCHLD, "sigchld_handler");

	for ($i = 0; $i < $config->forks; $i++)
		if (pcntl_fork()) {
			while ($insock = socket_accept($listener)) {
				handle_request($insock, $logfd);
				@socket_close($insock);
			}
		}
}
else {
	while ($insock = socket_accept($listener)) {
		handle_request($insock, $logfd);
		@socket_close($insock);
	}
}

socket_close($listener);
