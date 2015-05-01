#!/usr/bin/php
<?php
# simplehttpd v1.7 - simple HTTP server
#  * status: working
#  * dependencies:
#       "socket" extension

define("VERSION", "simplehttpd v1.7");

$WARNING = "[;37;41;1;5m NOT TO BE USED IN PRODUCTION ENVIRONMENTS [m";

# help message must be not wider than 80 characters                            #
$HELP = <<<EOTFM
Usage: simplehttpd [-46Lahv] -d docroot [-l address] -p port

Options:
  -4, -6                       Use IPv4 or IPv6 (cannot be used with -l)
  -a                           Display hidden files in directory indexes
  -d path                      Directory to serve
  -h                           Display this help message
  -L                           Bind to localhost (::1 or 127.0.0.1)
  -l address                   Bind to specified local address
  -p port                      Listen on specified port
  -v                           Display version

$WARNING

EOTFM;

# pass through PHP-enabled webservers
if (isset($_SERVER["REMOTE_ADDR"])) {
	header("Content-Type: text/plain; charset=utf-8");
	header("Last-Modified: ".date("r", filemtime(__FILE__)));
	readfile(__FILE__);
	die;
}

$content_types = array(
	"css"	=> "text/css",

	"htm"	=> "text/html",
	"html"	=> "text/html",

	"txt"	=> "text/plain",

	# default type
	null	=> "application/octet-stream",
);

$status_messages = array(
	200 => "Okie dokie",
	
	301 => "Moved Permanently",
	
	400 => "Bad Request",
	401 => "Unauthorized",
	403 => "Forbidden",
	404 => "Not Found",
	405 => "Method Not Allowed",
	414 => "Request-URI Too Long",
	418 => "I'm a teapot",
	
	500 => "Internal Error",
	501 => "Not Implemented",
);

# read line (ending with CR+LF) from socket
function socket_gets($socket, $maxlength = 1024) {
	$data = ""; $length = 0; $char = null;
	while ($length < $maxlength) {
		$char = socket_read($socket, 1, PHP_BINARY_READ);
		# remote closed connection
		if ($char === false) return $data;
		# no more data
		if ($char == "") return $data;

		$data .= $char;

		# ignore all stray linefeeds
		#if ($length > 0 and $data[$length-1] == "\x0D" and $data[$length] == "\x0A")
		#	return substr($data, 0, $length-1);

		if ($data[$length] == "\x0A") {
			/*
			if ($length > 0 and $data[$length-1] == "\x0D")
				return substr($data, 0, $length-1);
			else
				return substr($data, 0, $length);
			*/
			return $data;
		}

		$length++;
	}
	return $data;
}

function send($fd, $data) {
	for ($total = 0; $total < strlen($data); $total += $length) {
		$length = socket_write($fd, substr($data, $total));
		if ($length == 0) return false;
	}
	return $total;
}

## Default configuration {{{
$config = new stdClass();

$config->docroot = null;
$config->index_files = array("index.html", "index.htm");
$config->hide_dotfiles = true;

$config->listen_addr = "any";
$config->listen_port = null;

$config->force_af = null;
$config->use_af = AF_INET;
# }}}

## Command-line options {{{
$options = getopt("64ad:hLl:p:v");

if (isset($options["h"]) or $options === false) {
	fwrite(STDERR, $HELP);
	exit(2);
}

foreach ($options as $opt => $value) switch ($opt) {
	case "6":
		$config->force_af = AF_INET6; break;
	case "4":
		$config->force_af = AF_INET; break;
	case "a":
		$config->hide_dotfiles = false; break;
	case "d":
		$config->docroot = $value; break;
	case "L":
		$config->listen_addr = "localhost"; break;
	case "l":
		$config->listen_addr = $value; break;
	case "p":
		$config->listen_port = intval($value); break;
	case "v":
		echo VERSION."\n";
		exit();
}

# determine real docroot
$config->docroot = realpath($config->docroot);

if (substr($config->docroot, -1) != DIRECTORY_SEPARATOR)
	$config->docroot .= DIRECTORY_SEPARATOR;

if ($config->docroot === false) {
	fwrite(STDERR, "Error: docroot does not exist\n");
	exit(1);
}
if (!@chdir($config->docroot)) {
	fwrite(STDERR, "Error: chdir to docroot failed\n");
	exit(1);
}
print "[info] docroot: {$config->docroot}\n";
# }}}

function listen() {
	global $config;
	
	if ($config->listen_addr === "any") {
		if ($config->force_af) $config->use_af = $config->force_af;
		$config->listen_addr = ($config->use_af == AF_INET6)? "::" : "0.0.0.0";
	}
	elseif ($config->listen_addr === "localhost") {
		if ($config->force_af) $config->use_af = $config->force_af;
		$config->listen_addr = ($config->use_af == AF_INET6)? "::1" : "127.0.0.1";
	}
	else {
		$addr_is_v6 = (strpos($config->listen_addr, ":") !== false);
		if ($config->force_af == AF_INET6 and !$addr_is_v6) {
			$config->listen_addr = "::ffff:".$config->listen_addr;
			$addr_is_v6 = true;
		}
		elseif ($config->force_af == AF_INET and $addr_is_v6) {
			fwrite(STDERR, "Error: cannot use IPv6 listen address for IPv4\n");
			exit(1);
		}

		if ($config->force_af)
			$config->use_af = $config->force_af;
		else
			$config->use_af = $addr_is_v6? AF_INET6 : AF_INET;
	}

	$listener = socket_create($config->use_af, SOCK_STREAM, SOL_TCP);
	#TODO# retval?

	#socket_set_option($listener, SOL_SOCKET, SO_REUSEADDR, 1);
	socket_bind($listener, $config->listen_addr, $config->listen_port);
	socket_listen($listener, 2);
	#TODO# retval?

	print "[info] listen: {$config->listen_addr} port {$config->listen_port}\n";

	while ($conn = socket_accept($listener)) {
		handle($conn);
		socket_shutdown($conn);
		socket_close($conn);
	}

	socket_close($listener);
}

function handle($sockfd) {
	global $config;

	$req = new StdClass();
	$resp = new StdClass();

	socket_getpeername($sockfd, $req->peer_host, $req->peer_port);

	## read the HTTP request {{{
	$req->raw = socket_gets($sockfd);
	if (substr($req->raw, -1) !== "\n") {
		send_error($sockfd, $resp, 413); // request entity too large
		return;
	}
	else {
		$req->length = strlen($req->raw);
		$req->raw = rtrim($req->raw, "\r\n");
	}

	$req->method = strtok($req->raw, " ");
	$req->path = strtok(" ");
	$req->version = strtok(null);

	if ($req->method != "GET") {
		send_error($sockfd, $resp, 501); // not implemented
		return;
	}

	if ($req->version === false)
		$req->version = "HTTP/0.9";

	$req->path = strtok($req->path, "?");
	$req->query = strtok(null);

	# slurp headers
	while ($req->length < 4096) {
		$line = socket_gets($sockfd, 4096 - $req->length);
		$len = strlen($line);
		if (!$len)
			return;
		elseif ($line == "\r\n" or $line == "\n")
			break;
		else
			$req->length += $len;
	}
	#}}}

	$resp->version = "HTTP/1.0";
	$resp->status = 200;
	$resp->headers = array(
		"Content-Type" => "text/plain; charset=utf-8",
		"Connection" => "close",
	);

	$req->realpath = realpath($config->docroot . $req->path);

	## Check if path is inside docroot
	if ($req->realpath === false or substr($req->realpath, 0, strlen($config->docroot)) !== $config->docroot) {
		send_error($sockfd, $resp, 404);
		return;
	}

	if (!is_readable($req->realpath)) {
		send_error($sockfd, $resp, 403);
	}
	elseif (is_dir($req->realpath)) {
		send_resp_dirindex($sockfd, $req, $resp);
	}
	else {
		send_resp_file($sockfd, $req, $resp);
	}
}

function send_headers($fd, $resp) {
	$msg = http_status_to_string($resp->status);
	
	send($fd, "{$resp->version} {$resp->status} {$msg}\r\n");
	foreach ($resp->headers as $key => $value)
		send($fd, "$key: $value\r\n");
	send($fd, "\r\n");
}

## send a full response, including headers
function send_error($fd, $resp, $status) {
	$resp->status = $status;
	$resp->headers = array(
		"Content-Type" => "text/plain; charset=utf-8",
		"Connection" => "close",
	);
	send_headers($fd, $resp);

	$msg = http_status_to_string($status);
	send($fd, "ERROR $status: $msg\n");
}

function send_resp_file($sockfd, $req, $resp) {
	$fd = fopen($req->realpath, "rb");
	if (!$fd) {
		send_error($sockfd, $resp, 403);
		return;
	}

	$resp->headers["Content-Length"] = filesize($req->realpath);
	$resp->headers["Content-Type"] = get_content_type($req->realpath);
	send_headers($sockfd, $resp);

	do {
		$buffer = fread($fd, 1024);
		send($sockfd, $buffer);
	} while (!feof($fd));

	fclose($fd);
}

function send_resp_dirindex($sockfd, $req, $resp) {
	# Auto-append a / like Apache does
	if (substr($req->path, -1) !== "/") {
		$resp->status = 301;
		$resp->headers["Location"] = $req->path."/";
		unset($resp->headers["Content-Type"]);
		send_headers($sockfd, $resp);
		return;
	}

	$dh = opendir($req->realpath);
	if (!$dh) {
		send_error($sockfd, $resp, 403);
		return;
	}

	$resp->headers["Content-Type"] = "text/html; charset=utf-8";
	send_headers($sockfd, $resp);

	$dir = suffix($req->realpath, DIRECTORY_SEPARATOR);

	send($sockfd, "<!DOCTYPE html>\n".
		"<meta charset=\"utf-8\">\n".
		"<title>Index of ".htmlspecialchars($req->path)."</title>\n".
		"<h1>Index of ".htmlspecialchars($req->path)."</h1>\n");

	send($sockfd, "<ul>\n");
	if ($req->path !== "/")
		send($sockfd, dirindex_format_entry(realpath($dir.".."), $dir, "(parent directory)"));
	while (($entry = readdir($dh)) !== false)
		send($sockfd, dirindex_format_entry($entry, $dir));
	send($sockfd, "</ul>\n");

	closedir($dh);	
}

function dirindex_format_entry($name, $dir, $display=null) {
	if ($display == null)
		$display = $name;
	$display = htmlspecialchars($display);

	$path = htmlspecialchars($name);
	$suffix = "";

	if (is_dir($dir.$name)) {
		$suffix = "/";
		$path .= "/";
	}
	
	return "\t<li> <a href=\"{$path}\">{$display}</a>{$suffix}\n";
}	

function http_status_to_string($status) {
	global $status_messages;
	if (array_key_exists($status, $status_messages))
		return $status_messages[$status];
	else
		return "D'oh.";
}

function suffix($str, $suffix) {
	if (substr($str, -strlen($suffix)) != $suffix)
		$str .= $suffix;
	return $str;
}

function get_content_type($path) {
	global $content_types;

	$name = basename($path);
	$extpos = strrpos($name, ".");
	$ext = ($extpos === false)? null : substr($name, $extpos+1);

	return @$content_types[$ext] ?: "text/plain";
}

listen();
