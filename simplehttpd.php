#!/usr/bin/php
<?php
# simplehttpd r20091203
#
# (c) 2009 <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>
#
# Requires:
# - sockets extension
# - for userdir support: posix extension
#
# Todo:
# - Add simple CGI support
#   - make sure it can be disabled easily, as most users don't give a fuck about /media/* being +x
# - Maybe: Change LOG_REQUESTS and ENABLE_USERDIRS to globals

define("LOG_REQUESTS", true);

define("ENABLE_USERDIRS", true);

#$docroot = "/var/www/";
$docroot = "/srv/http/";
#$docroot = getenv("HOME") . "/public_html/";

$index_files = array( "index.html", "index.htm" );

$hide_dotfiles = true;

# On Linux, if use_ipv6 is on and Listen is ::, both IPv4 and IPv6 will work
# (assuming sysctl net.ipv6.bindv6only == 0)
$use_ipv6 = true;
$listen = $use_ipv6? "::" : "0.0.0.0";
$listen_port = 8001;

$log_date_format = "%a %b %_d %H:%M:%S %Y";

// // // // // / // // // // // // // // // // // // // // // // // // // // //

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

$content_types = array(
	"cer" => "application/x-x509-ca-cert",
	"crt" => "application/x-x509-ca-cert",
	"css" => "text/css",
	"der" => "application/x-x509-ca-cert",
	"gif" => "image/gif",
	"gz" => "application/x-gzip",
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
	"pem" => "application/x-x509-ca-cert",
	"png" => "image/png",
	"tgz" => "application/x-tar",
	"wtls-ca-certificate" => "application/vnd.wap.wtls-ca-certificate",
);

$local_hostname = php_uname("n");

$listener = socket_create($use_ipv6? AF_INET6 : AF_INET, SOCK_STREAM, SOL_TCP);
socket_set_option($listener, SOL_SOCKET, SO_REUSEADDR, 1);
socket_bind($listener, $listen, $listen_port);
echo "* * docroot = {$docroot}\n";
echo strftime($log_date_format) . " * listening on " . ($use_ipv6? "[{$listen}]" : $listen) . ":{$listen_port}\n";
socket_listen($listener, 2);

function get_user_docroot($user) {
	$suffix = "/public_html/";
	
	if (function_exists("posix_getpwnam")):
		$user_info = posix_getpwnam($user);
		if ($user_info == false) {
			# user not found, fall back to real path
			return false;
		}
		return $user_info["dir"].$suffix;
	
	# HACK
	elseif (PHP_OS == "WINNT"):
		return getenv("USERPROFILE") . "/../{$user}/Documents/Website/";
	
	else:
		return false;

	endif;
}

function socket_gets($s, $maxlength = 1024) {
	# This time I'm really sure it works.
	$buf = "";
	$i = 0;
	$char = null;
	while ($i <= $maxlength) {
		$char = socket_read($s, 1, PHP_BINARY_READ);
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

function follow_symlink($file) {
	# Get the actual target of a symlink. Basically a recursive readlink()
	# Hardcoded limit of 32 symlink levels.
	$i = 0; while (is_link($file)) {
		if (++$i < 32)
			$n = readlink($file);
		else
			$n = false;
		if ($n === false) return $file;

		# relative link
		if ($n[0] != '/')
			$n = dirname($file) . "/" . $n;
		$file = $n;
	}
	return $file;
}

function get_docroot($fs_path) {
	global $docroot;
	$global_docroot = $docroot.$fs_path;
	
	if (substr($fs_path, 1, 1) == "~") {
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

function readMimeTypes($path = "/etc/mime.types") {
	global $content_types;
	$fh = fopen($path, "r");
	if (!$fh) return false;
	while ($line = fgets($fh)) {
		$line = rtrim($line);
		if ($line == "" or $line[0] == " " or $line[0] == "#") continue;
		$line = preg_split("/ +/", $line);
		array_shift($line);
		$type = array_shift($line);
		foreach ($line as $ext) $content_types[$ext] = $type;
	}
	fclose($fh);
}

#readMimeTypes();
#readMimeTypes(getenv('HOME') . '/.mime.types');

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

	if (ENABLE_USERDIRS)
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
