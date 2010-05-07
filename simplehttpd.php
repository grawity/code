#!/usr/bin/php
<?php
$VERSION = "simplehttpd v1.6";
$WARNING = "[;37;41;1;5m NOT TO BE USED IN PRODUCTION ENVIRONMENTS [m";
# simple HTTP server

# (c) 2010 Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>

# help message must be not wider than 80 characters                            #
$HELP = <<<EOTFM
Usage: simplehttpd [-46Lahiuv] [-d docroot] [-f num] [-l address] [-p port]

Options:
  -4, -6                       Use IPv4 or IPv6 (cannot be used with -l)
  -a                           List all files, including hidden, in directories
  -f number                    Number of subprocesses (0 disables)
  -d path                      Specify docroot (default is ~/public_html or cwd)
  -h                           Display this help message
  -i                           inetd mode (read single request from stdin)
  -L                           Bind to localhost (::1 or 127.0.0.1)
  -l address                   Bind to specified local address
  -p port                      Listen on specified port
  -v                           Display version

$WARNING

EOTFM;

if (isset($_SERVER["REMOTE_ADDR"])) {
	header("Content-Type: text/plain; charset=utf-8");
	header("Last-Modified: " . date("r", filemtime(__FILE__)));
	readfile(__FILE__);
	die;
}

date_default_timezone_set("UTC");

# expand path starting with ~/ using given value of ~
function tilde_expand($path, $homedir) {
	if ($path == "~") $path .= "/";

	if ($homedir and substr($path, 0, 2) == "~/")
		$path = $homedir.substr($path, 1);

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

	if (!$home) $home = getenv("HOME");
	if (!$home and function_exists("posix_getpwnam")) {
		$uid = posix_getuid();
		$pw = posix_getpwuid($uid);
		if ($pw) $home = $pw["dir"];
	}
	if (!$home) $home = getenv("HOMEDRIVE").getenv("HOMEPATH");
	if (!$home) $home = getenv("USERPROFILE");

	return $home? $home : false;
}

function split_host_port($str) {
	$pos = strrpos($str, ":");
	if ($pos === false)
		return $str;
	else
		return array(substr($str, 0, $pos), substr($str, $pos+1));
}

function load_mimetypes($path="/etc/mime.types") {
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
	if ($fd == STDIN) $fd = STDOUT;
	
	for ($total = 0; $total < strlen($data); $total += $num) {
		# data length must be specified to avoid magic_quotes_runtime crap
		$num = fwrite($fd, $data, strlen($data));
		$data = substr($data, $total);
		if ($num == 0) return false;
	}
	return $total;
}

function logwrite($str) {
	global $logfd;
	if ($logfd !== null)
		return fwrite($logfd, $str);
}

function handle_request($sockfd) {
	global $config;

	$req = new stdClass();
	$resp = new stdClass();
	
	$peer = stream_socket_get_name($sockfd, true);
	list ($req->rhost, $req->rport) = split_host_port($peer);

	logwrite("(".strftime($config->log_date_format).") {$req->rhost}:{$req->rport} ");

	$resp->headers = array(
		"Content-Type" => "text/plain",
		//"Connection" => "close",
	);

	# TODO: reply with 414 to overly long URIs
	$req->rawreq = fgets($sockfd, 4096);
	if (substr($req->rawreq, -1) !== "\n") {
		return re_error($sockfd, $req, 414);
	}
	$req->rawreq = rtrim($req->rawreq);

	if ($req->rawreq == "") {
		logwrite("(null)\n");
		return;
	}

	logwrite($req->rawreq."\n");

	# method = up to the first space
	# path = up to the second space
	# version = the rest, including any further components
	$req->method = strtok($req->rawreq, " ");
	$req->path = strtok(" ");
	$req->version = strtok("");

	if ($req->version === false) {
		$req->version = "HTTP/0.9";
	}
	elseif (substr($req->version, 0, 5) !== "HTTP/") {
		return re_bad_request($sockfd);
	}

	# ...and slurp in the request headers.
	$req->headers = array();
	while (true) {
		$hdr = rtrim(fgets($sockfd));
		if (!strlen($hdr)) break;
		$req->headers[] = $hdr;
	}
	unset ($hdr);
	
	if ($req->method == "TRACE" or $req->path == "/echo") {
		send_headers($sockfd, $req->version, null, 200);
		send($sockfd, $req->rawreq."\r\n");
		send($sockfd, implode("\r\n", $req->headers)."\r\n");
		fclose($sockfd);
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

	$req->fspath = $config->docroot . urldecode($req->path);

	while (strpos($req->fspath, "/../") !== false)
		$req->fspath = str_replace("/../", "/", $req->fspath);

	while (substr($req->fspath, -3) == "/..")
		$req->fspath = substr($req->fspath, 0, -2);

	# If given path is a directory, append a slash if required
	if (is_dir($req->fspath) and substr($req->path, -1) != "/") {
		send_headers($sockfd, $req->version, array(
			"Location" => $req->path."/",
		), 301);
		fclose($sockfd);
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

	$req->fspath = realpath($req->fspath);

	# realpath() failed - dest is probably a broken symlink
	if ($req->fspath === false)
		return re_error($sockfd, $req, 404);

	# dest exists, but is not readable => 403
	elseif (file_exists($req->fspath) and !is_readable($req->fspath))
		return re_error($sockfd, $req, 403);

	# dest exists, and is a directory => display file list
	elseif (is_dir($req->fspath)) {
		$resp->headers["Content-Type"] = "text/html";
		#$resp->headers["Content-Type"] = "text/html; charset=utf-8";
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
		fclose($sockfd);
		return;
	}

	# dest exists, but not a regular or directory => 403
	elseif (file_exists($req->fspath))
		return re_error($sockfd, $req, 403);

	# dest doesn't exist => 404
	else
		return re_error($sockfd, $req, 404);

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

		if (is_dir(realpath($entry_path)))
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
		"<head>\n".
		"\t<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />\n".
		"\t<title>index: {$page_title}</title>\n".
		"\t<style>\n".
		"\ta { font-family: monospace; text-decoration: none; }\n".
		"\t.symlink, .size { color: gray; }\n".
		"\tfooter { font-size: smaller; color: gray; }\n".
		"\t</style>\n".
		"</head>\n".
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
		#send($sockfd, "Content-Type: text/plain\r\n");
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
	414 => "Request-URI Too Long",
	418 => "I'm a teapot",
	500 => "Internal Error (something fucked up)",
	501 => "Not Implemented",
);

## Default configuration

$config = new stdClass();

$config->docroot = tilde_expand_own("~/public_html");
if (!is_dir(realpath($config->docroot)))
	$config->docroot = ".";

$config->index_files = array( "index.html", "index.htm" );
$config->hide_dotfiles = true;

$config->listen_addr = "any";
$config->listen_port = 8001;
$config->addr_family = null;
$config->inetd = false;
$config->forks = 3;

$logfd = STDOUT;

$config->log_date_format = "%a %b %d %H:%M:%S %Y";

$content_types = array(
	# text
	"txt" => "text/plain",
	"css" => "text/css",
	"htm" => "text/html",
	"html" => "text/html",
	"js" => "text/javascript",

	# archives/binaries
	"exe" => "application/x-msdos-program",
	"tar" => "application/x-tar",
	"tgz" => "application/x-tar",
	"zip" => "application/zip",

	# images
	"gif" => "image/gif",
	"jpeg" => "image/jpeg",
	"jpg" => "image/jpeg",
	"png" => "image/png",

	# audio/video
	"m4a" => "audio/mp4",
	"m4v" => "video/mp4",
	"mp4" => "application/mp4",
	"oga" => "audio/ogg",
	"ogg" => "audio/ogg",
	"ogv" => "video/ogg",
	"ogm" => "application/ogg",

	# misc
	"pem" => "application/x-x509-ca-cert",
	"crt" => "application/x-x509-ca-cert",
);

## Command-line options

$opts = getopt("64ad:f:ihLl:p:v");

if (isset($opts["h"]) or $opts === false) {
	fwrite(STDERR, $HELP);
	exit(2);
}

foreach ($opts as $opt => $value) switch ($opt) {
	case "6":
		$config->addr_family = "inet6"; break;
	case "4":
		$config->addr_family = "inet"; break;
	case "a":
		$config->hide_dotfiles = false; break;
	case "d":
		$config->docroot = $value; break;
	case "f":
		$config->forks = intval($value); break;
	case "i":
		$config->inetd = true; break;
	case "L":
		# -4 will be handled later
		$config->listen_addr = "localhost"; break;
	case "l":
		$config->listen_addr = $value; break;
	case "p":
		$config->listen_port = intval($value); break;
	case "v":
		die(VERSION."\n");
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

function listen_tcp() {
	global $config;
	
	if ($config->listen_addr === "any") {
		# any -> :: | 0.0.0.0
		$config->listen_addr = ($config->addr_family == "inet6")? "::" : "0.0.0.0";
	}
	elseif ($config->listen_addr === "localhost") {
		# localhost -> ::1 | 127.0.0.1
		$config->listen_addr = ($config->addr_family == "inet6")? "::1" : "127.0.0.1";
	}

	$config->listen_uri = "tcp://".
		($config->addr_family == "inet6"? "[" : "").$config->listen_addr.
		($config->addr_family == "inet6"? "]" : "").":". $config->listen_port;
	
	$listener = stream_socket_server($config->listen_uri, $errno, $errstr);
	
	logwrite("* docroot {$config->docroot}\n");
	logwrite("* listening on {$config->listen_uri}\n");

	if ($config->forks and function_exists("pcntl_fork")) {
		function sigchld_handler($sig) {
			wait(-1);
		}
		pcntl_signal(SIGCHLD, "sigchld_handler");

		for ($i = 0; $i < $config->forks; $i++)
			if (pcntl_fork()) {
				while ($insock = stream_socket_accept($listener, -1)) {
					handle_request($insock);
					@fclose($insock);
				}
			}
	}
	else {
		while ($insock = stream_socket_accept($listener, -1)) {
			handle_request($insock);
			@fclose($insock);
		}
	}

	fclose($listener);
}

if ($config->inetd) {
	$logfd = null;
	handle_request(STDIN);
}
else {
	listen_tcp();
}
