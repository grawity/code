#!/usr/bin/php
<?php
define("VERSION", 'simplehttpd v1.0');
# simple HTTP server

# (c) 2009 Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>

# Requires:
# - sockets extension
# - for userdir support: posix extension

# expand path starting with ~/ given value of ~
function expand_path($path, $homedir) {
	if ($path == "~") $path .= "/";

	if (substr($path, 0, 2) == "~/" and $homedir)
		$path = $homedir . substr($path, 1);

	return $path;
}

# expand path starting with ~/ according to environment
function expand_own_path($path) {
	$home = getenv("HOME");
	if (!$home)
		$home = get_user_homedir();
	if (!$home)
		return $path;
	return expand_path($path, $home);
}

# get docroot for given user (homedir + suffix)
function get_user_docroot($user) {
	global $userdir_suffix;

	if (function_exists("posix_getpwnam")) {
		$pw = posix_getpwnam($user);
		if (!$pw)
			return false;
		else
			return "{$pw["dir"]}/{$userdir_suffix}";
	}
	else {
		return false;
	}
}

# get docroot given request (userdir or global)
function get_docroot($fs_path) {
	global $docroot, $enable_userdirs;
	$global_docroot = $docroot.$fs_path;

	# if $enable_userdirs is off, /~foo/ will be taken literally
	if ($enable_userdirs and substr($fs_path, 1, 1) == "~") {
		$fs_path = substr($fs_path, 2);
		$spos = strpos($fs_path, "/");
		if ($spos === false) $spos = strlen($fs_path);
		$req_user = substr($fs_path, 0, $spos);
		$fs_path = substr($fs_path, $spos);
		unset($spos);

		$user_dir = get_user_docroot($req_user);
		if (!$user_dir or !is_dir($user_dir)) {
			return $global_docroot;
		}

		return $user_dir . $fs_path;

	}
	else {
		# no userdir in request
		return $global_docroot;
	}
}

# read line (ending with CR+LF) from socket
function socket_gets($socket, $maxlength = 1024) {
	# This time I'm really sure it works.
	$buf = "";
	$i = 0;
	$char = null;
	while ($i <= $maxlength) {
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
function socket_die($message, $socket = false) {
	if (!empty($message))
		fwrite(STDERR, "$message: ");

	$errno = (is_resource($socket)? socket_last_error($socket) : socket_last_error());
	$errstr = socket_strerror($errno);
	fwrite(STDERR, "$errstr [$errno]\n");

	exit(1);
}

# follow symlinks to reach the actual target; basically a recursive readlink()
function follow_symlink($file) {
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
	$fh = fopen($path, "r");
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

function read_config($path) {
	if (!file_exists($path) or !is_file($path)) {
		return true;
	}

	$fh = fopen($path, "r");
	if (!$fh) {
		fwrite(STDERR, "could not open $path\n");
		return false;
	}

	$lineno = 0; while (($line = fgets($fh)) !== false) {
		$lineno++;
		$line = rtrim($line);
		if ($line == "" or $line[0] == "#" or $line[0] == ";")
			continue;

		$line = explode("=", $line, 2);
		if (count($line) < 2) {
			fwrite(STDERR, "parse error at line {$lineno}\n");
			return false;
		}

		list ($key, $value) = $line;

		$key = trim($key);
		$value = trim($value);

		if (preg_match('|^"(.*)"$|', $value, $m))
			$value = stripcslashes($m[1]);
		elseif (preg_match('|^\'(.*)\'$|', $value, $m))
			$value = stripslashes($m[1]);
		elseif (preg_match('/^(yes|true)$/i', $value))
			$value = true;
		elseif (preg_match('/^(no|false)$/i', $value))
			$value = false;

		switch ($key) {
		case "listen":
			global $listen;
			$listen = (string) $value;
			break;
		case "port":
			global $listen_port;
			$listen_port = (int) $value;
			break;
		case "hide_dotfiles":
			global $hide_dotfiles;
			$hide_dotfiles = (bool) $value;
			break;
		case "docroot":
			global $docroot;
			$docroot = expand_own_path($value);
			break;
		case "userdir.enable":
			global $enable_userdirs;
			$enable_userdirs = (bool) $value;
			break;
		case "userdir.suffix":
			global $userdir_suffix;
			$userdir_suffix = (string) $value;
			break;
		default:
			fwrite(STDERR, "warning: unknown config option $key\n");
		}
	}
	fclose($fh);
	return true;
}

$responses = array(
	200 => "Okie dokie",

	301 => "Moved Permanently",

	400 => "Bad Request",
	401 => "Unauthorized", # as if this will ever have auth.
	403 => "Forbidden",
	404 => "Not Found",
	405 => "Method Not Allowed",
	418 => "I'm a teapot",

	500 => "Internal error (something fucked up)",
	501 => "Not Implemented",
);

## Default configuration

define("LOG_REQUESTS", true);

$docroot = expand_own_path("~/public_html");
if (!is_dir($docroot))
	$docroot = ".";

$index_files = array( "index.html", "index.htm" );

$enable_userdirs = false;
$userdir_suffix = "public_html";

$hide_dotfiles = true;

$listen = "::";
$listen_port = 8001;

$log_date_format = "%a %b %_d %H:%M:%S %Y";

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

$config_files = array( "/etc/simplehttpd.conf", "./simplehttpd.conf" );

$options = getopt("c:Chl:p:v");

if (isset($options["h"]) or $options == false)
	die("Usage: simplehttpd [-Cv] [-c config] [-d docroot] [-l addr] [-p port]\n");

if (isset($options["v"]))
	die(VERSION."\n");

if (isset($options["c"]))
	$config_files = $options["c"];

# Configuration
if (!is_array($config_files)) $config_files = array($config_files);
foreach ($config_files as $file) read_config($file) or exit(1);

if (isset($options["d"]))
	$docroot = $options["d"];

if (isset($options["l"]))
	$listen = $options["l"];

if (isset($options["p"]))
	$listen_port = (int) $options["p"];

$use_ipv6 = (strpos($listen, ":") !== false);

if (!chdir($docroot)) {
	fwrite(STDERR, "failed to chdir to $docroot\n");
	exit(1);
}

$docroot = getcwd();
$local_hostname = php_uname("n");

load_mimetypes();
load_mimetypes(expand_own_path("~/.mime.types"));
ksort($content_types);

$listener = @socket_create($use_ipv6? AF_INET6 : AF_INET, SOCK_STREAM, SOL_TCP);
if (!$listener)
	socket_die("socket_create");

socket_set_option($listener, SOL_SOCKET, SO_REUSEADDR, 1);

if (!@socket_bind($listener, $listen, $listen_port))
	socket_die("socket_bind", $listener);

if (!@socket_listen($listener, 2))
	socket_die("socket_listen", $listener);

echo "* * docroot = {$docroot}\n";
echo strftime($log_date_format) . " * listening on " . ($use_ipv6? "[{$listen}]" : $listen) . ":{$listen_port}\n";

while ($s = socket_accept($listener)) {
	# get remote host
	socket_getpeername($s, $remoteHost, $remotePort);
	if (LOG_REQUESTS) echo strftime($log_date_format) . " {$remoteHost}:{$remotePort} ";

	# default headers to send
	$resp_code = 200;
	$resp_headers = array(
		"Content-Type" => "text/plain",
		# this httpd doesn't support keep-alive
		"Connection" => "close",
		"X-ZeroWing" => "All your headers are belong to us",
	);

	# read the request...
	$request = socket_gets($s);
	if ($request == "") {
		if (LOG_REQUESTS) echo "ignored\n";
		socket_close($s);
		continue;
	}
	if (LOG_REQUESTS) echo "{$request}";
	$splitReq = explode(" ", $request);
	# The request must always have 3 components;
	# spaces in path must be percent-encoded. (Sez RFC.)
	if (count($splitReq) != 3) {
		$resp_code = 400;
		$req_http_version = "HTTP/1.0";
		send_headers();
		send_error($resp_code, null, "Are you on drugs?");
		socket_close($s);
		continue;
	}
	list ($request_method, $request_path, $req_http_version) = $splitReq;
	unset($splitReq);

	# ...and slurp in the request headers.
	$inHeaders = array(); $h = false;
	while ($h !== "")
		$inHeaders[] = $h = socket_gets($s);

	# special /echo request will reply with received headers
	if ($request_path == "/echo" or $request_method == "TRACE") {
		send_headers();
		send_text($request . "\n" . implode("\n", $inHeaders) . "\n");
		socket_close($s);
		continue;
	}

	# we only support HTTP GET, ignore the rest.
	if ($request_method != "GET") {
		$resp_code = 501;
		send_headers();
		send_text(
			"{$resp_code} Not Implemented\n".
			"\n".
			"Only GET is supported.\n"
		);
		socket_close($s);
		continue;
	}

	# TODO: recognize URIs with hostnames, per RFC 2616 5.1.2
	if (strpos($request_path, "://") > 0) {
		$resp_code = 400;
		send_headers();
		send_error($resp_code, $request_path, "I guess I should implement this someday. (RFC 2616 5.1.2)");
		socket_close($s);
		continue;
	}

	# split off the query|search part
	if (($query_pos = strpos($request_path, "?")) !== false) {
		$request_query = substr($request_path, $query_pos + 1);
		$request_path = substr($request_path, 0, $query_pos);
	}

	# get the filesystem path
	$fs_path = urldecode($request_path);

	# missing first slash - fix
	# TODO: replace with a 400 Bad Request
	if ($fs_path[0] != "/")
		$fs_path = "/" . $fs_path;

	# get rid of dot segments ("." and "..")
	while (strpos($fs_path, "/../") !== false)
		$fs_path = str_replace("/../", "/", $fs_path);
	while (strpos($fs_path, "/./") !== false)
		$fs_path = str_replace("/./", "/", $fs_path);

	while (substr($fs_path, -3) == "/..")
		$fs_path = substr($fs_path, 0, -2);
	while (substr($fs_path, -2) == "/.")
		$fs_path = substr($fs_path, 0, -1);

	if ($enable_userdirs)
		$fs_path = get_docroot($fs_path);
	else
		$fs_path = $docroot.$fs_path;

	# If given path is a directory, append a slash if required
	if (is_dir($fs_path) and substr($request_path, -1) != "/") {
		$fs_path .= "/";
		$resp_headers["Location"] = $request_path . "/";
		$resp_code = 301;
		send_headers();
		socket_close($s);
		continue;
	}

	if (is_dir($fs_path))
		foreach ($index_files as $file)
			if (is_file($fs_path . $file)) {
				$fs_path .= $file;
				$auto_index_file = true;
				break;
			}

	# follow symlinks
	$original_fs_path = $fs_path;
	$fs_path = follow_symlink($fs_path);

	# dest exists, but is not readable => 403
	if (file_exists($fs_path) and !is_readable($fs_path)) {
		$resp_code = 403;
		send_headers();
		send_error($resp_code, $request_path);
		socket_close($s);
		continue;
	}

	# dest exists, and is a directory => display file list
	if (is_dir($fs_path)) {
		$resp_code = 200;
		$resp_headers["Content-Type"] = "text/html";
		# Mosaic crashes.
		#$resp_headers["Content-Type"] = "text/html; charset=utf-8";
		send_headers();

		# retrieve a list of all files
		$dirH = opendir($fs_path);
		$dirs = $files = array();
		while (($entry = readdir($dirH)) !== false) {
			if ($entry == ".") continue;
			if ($hide_dotfiles and $entry[0] == ".")
				continue;

			$entry_path = $fs_path.$entry;
			if (is_dir($entry_path) or is_dir(follow_symlink($entry_path)))
				$dirs[] = $entry;
			else
				$files[] = $entry;
		}
		closedir($dirH);
		sort($dirs); sort($files);

		$page_title = htmlspecialchars($request_path);
		send_text(
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
			"<h1>{$page_title}</h1>\n"
		);

		send_text("<ul>\n");
		foreach ($dirs as $entry) {
			$entry_path = $fs_path.$entry;
			$anchor = urlencode($entry);

			if ($entry == '..')
				$entry = "(parent directory)";
			$text = "<a href=\"{$anchor}/\">{$entry}/</a>";
			if (is_link($entry_path) and $entry_dest = @readlink($entry_path))
				$text .= " <span class=\"symlink\">→ ".htmlspecialchars($entry_dest)."</span>";
			send_text("\t<li>{$text}</li>\n");
		}
		foreach ($files as $entry) {
			$entry_path = $fs_path.$entry;
			$anchor = urlencode($entry);

			$text = "<a href=\"{$anchor}\">{$entry}</a>";
			if (is_link($entry_path) and $entry_dest = @readlink($entry_path))
				$text .= " <span class=\"sym\">→ ".htmlspecialchars($entry_dest)."</span>";
			if ($size = @filesize($entry_path))
				$text .= " <span class=\"size\">({$size})</span>";
			send_text("\t<li>{$text}</li>\n");
		}
		send_text("</ul>\n");

		# footer
		send_text(
			"<hr/>\n".
			"<footer><p>simplehttpd</p></footer>\n".
			"</body>\n".
			"</html>\n"
		);

		socket_close($s);
		continue;
	} // end of directory listing

	# dest is regular file => display
	elseif (is_file($fs_path)) {
		$path_info = pathinfo($fs_path);

		if (isset($path_info['extension'])) {
			$file_ext = $path_info['extension'];

			if ($file_ext == "gz") {
				$resp_headers["Content-Encoding"] = "gzip";
				$file_ext = pathinfo($path_info['filename'], PATHINFO_EXTENSION);
			}

			if (isset($content_types[$file_ext]))
				$resp_headers["Content-Type"] = $content_types[$file_ext];
			else
				$resp_headers["Content-Type"] = "text/plain";
		}

		$resp_code = 200;
		send_headers();
		send_file($fs_path);
		socket_close($s);
		continue;
	}

	# dest exists, but not a regular or directory => 403 (like Apache does)
	elseif (file_exists($fs_path)) {
		$resp_code = 403;
		send_headers();
		send_error($resp_code, $request_path);
		socket_close($s);
		continue;
	}

	# dest doesn't exist => 404
	else {
		$resp_code = 404;
		send_headers();
		send_error($resp_code, $request_path, "\"Quoth the Server, Four oh Four\"");
		socket_close($s);
		continue;
	}

}

# helper function to output an entire file
function send_file($file) {
	global $s;
	$file_h = fopen($file, "r");
	while (!feof($file_h)) {
		$buffer = fread($file_h, 1024);
		if ($buffer == "" or $buffer == false) {
			fclose($file_h);
			return false;
		}
		$outn = socket_write($s, $buffer);
		if ($outn == false) return;
	}
	fclose($file_h);
}

function send_text($text) {
	global $s;
	socket_write($s, $text);
}

function send_headers() {
	global $s, $req_http_version, $resp_code, $responses, $resp_headers;

	if (isset($responses[$resp_code]))
		$resp_title = $responses[$resp_code];
	else
		$resp_title = "Something's fucked up";

	$outn = socket_write($s, "{$req_http_version} {$resp_code} {$resp_title}\r\n");
	if ($outn == false) return;

	if (LOG_REQUESTS) echo " {$resp_code}\n";

	foreach ($resp_headers as $key => $values) {
		if (is_array($values)) {
			foreach ($values as $value) {
				$outn = socket_write($s, "{$key}: {$value}\r\n");
				if ($outn == false) return;
			}
		}
		else socket_write($s, "{$key}: {$values}\r\n");
	}
	socket_write($s, "\r\n");
}

function send_error($resp_code, $req_path = null, $comment = "") {
	global $s, $responses;

	if (isset($responses[$resp_code]))
		$resp_title = $responses[$resp_code];
	else
		$resp_title = "Something's fucked up";

	send_text("Oh noes, Error: {$resp_code} {$resp_title}\n\n");

	if ($comment != "")
		send_text($comment."\n\n");

	if ($req_path != null)
		send_text("Request: {$req_path}\n");
}

#EOF
