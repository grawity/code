<?php
namespace Ident;
/* identd checking library
 *
 * (c) 2010 Mantas Mikulėnas <grawity@gmail.com>
 * Released under the MIT License (dist/LICENSE.mit)
 *
 * IdentReply Ident\query($rhost, $rport, $lhost, $lport)
 *     $rhost, $rport
 *         remote (client) host/port
 *     $lhost, $lport
 *         local (server) host/port
 *
 * IdentReply Ident\query_cgiremote()
 *
 * IdentReply Ident\query_stream($stream)
 *     $stream
 *         handle to connected stream resource
 *
 * IdentReply Ident\query_socket($socket)
 *     $socket
 *         handle to connected socket resource
 *
 * class IdentReply {
 *      bool $success;
 *      // for "success" replies:
 *      string $userid;
 *      string $ostype;
 *      string $charset;
 *      // for "failure" replies:
 *      string $response_type;
 *      string $add_info;
 *      // addresses
 *      int $lhost;
 *      int $lport;
 *      int $rhost;
 *      int $rport;
 * }
 */

class Ident {
	static $debug = false;
	static $timeout = 2;

	static function debug($str) {
		if (self::$debug) print $str;
	}

	static function query($rhost, $rport, $lhost, $lport) {
		$authport = getservbyname("auth", "tcp");

		$lhost_w = escape_host($lhost);
		$rhost_w = escape_host($rhost);

		self::debug("query($rhost_w:$rport -> $lhost_w:$lport)\n");

		$ctx = array();
		$ctx["socket"]["bindto"] = "$lhost_w:0";
		$ctx = stream_context_create($ctx);

		$st = @stream_socket_client("tcp://$rhost_w:$authport", $errno, $errstr,
			self::$timeout, \STREAM_CLIENT_CONNECT, $ctx);

		if (!$st)
			return IdentReply::_failure("[$errno] $errstr");

		$req_str = "$rport,$lport";
		fwrite($st, "$req_str\r\n");
		$reply_str = fgets($st, 1024);
		fclose($st);

		$r = new IdentReply($reply_str);
		$r->lhost = $lhost;
		$r->rhost = $rhost;
		$r->raw_request = $req_str;
		return $r;
	}

	static function query_cgiremote() {
		return self::query(
			$_SERVER["REMOTE_ADDR"],
			$_SERVER["REMOTE_PORT"],
			$_SERVER["SERVER_ADDR"],
			$_SERVER["SERVER_PORT"]);
	}

	static function query_socket($sh) {
		if (!socket_getsockname($sh, $lhost, $lport)) {
			$errno = socket_last_error($sh);
			$err = socket_strerror($errno);
			return _failure("unable to determine socket name: [$errno] $err");
		}
		if (!socket_getpeername($sh, $rhost, $rport)) {
			$errno = socket_last_error($sh);
			$err = socket_strerror($errno);
			return _failure("unable to determine peer name: [$errno] $err");
		}
		return self::query($rhost, $rport, $lhost, $lport);
	}

	static function query_stream($sh) {
		$local = stream_socket_get_name($sh, false);
		if (!$local) {
			return _failure("unable to determine socket name");
		}
		$remote = stream_socket_get_name($sh, true);
		if (!$remote) {
			return _failure("unable to determine peer name");
		}
		$local = split_host_port($local);
		$remote = split_host_port($remote);
		return self::query($remote[0], $remote[1], $local[0], $local[1]);
	}
}

class IdentReply {
	public $raw_request;
	public $raw_reply;
	public $response_type;
	public $add_info;

	public $success;
	public $userid;
	public $ostype;
	public $charset;

	public $lhost;
	public $rhost;
	public $lport;
	public $rport;

	public $rcode; // compat
	public $ecode; // compat

	function __construct($str=null) {
		if (!strlen($str))
			return;

		$this->parse($str);
	}

	function parse($str) {
		$str = rtrim($str, "\r\n");
		Ident::debug("parsing: $str\n");
		$this->raw_reply = $str;

		$ports = strtok($str, ":");
		$ports = explode(",", $ports, 2);
		$this->rport = intval($ports[0]);
		$this->lport = intval($ports[1]);

		$this->response_type = strtoupper(trim(strtok(":")));
		switch ($this->response_type) {
		case "USERID":
			$this->success = true;
			$ostype = strtok(":");
			if (strpos($ostype, ",") !== false)
				list ($ostype, $charset) = explode(",", $ostype, 2);
			else
				$charset = "US-ASCII";
			$this->ostype = trim($ostype);
			$this->charset = trim($charset);
			$this->userid = ltrim(strtok(null));
			break;
		case "ERROR":
			$this->success = false;
			$this->add_info = strtoupper(trim(strtok(null)));
			break;
		default:
			$this->success = false;
		}

		$this->rcode = $this->response_type;
		$this->ecode = $this->add_info;
	}

	function __toString() {
		$str = "";

		if ($this->success)
			$str = "ident: ";
		else
			$str = "error: ";

		switch ($this->response_type) {
		case "ERROR":
			$str .= "server error: [".$this->add_info."] ".strerror($this->add_info);
			break;
		case "USERID":
			$str .= "{$this->userid} (OS: {$this->ostype})";
			break;
		default:
			$str .= "{$this->response_type}: {$this->add_info}";
		}
		return $str;
	}

	function _failure($add_info) {
		$r = new self();
		$r->success = false;
		$r->response_type = "X-CLIENT-ERROR";
		$r->add_info = $add_info;
		return $r;
	}
}

function debug($x=true) {
	Ident::$debug = $x;
}

function strerror($ecode) {
	switch ($ecode) {
	case "INVALID-PORT":
		return "invalid port specification";
	case "NO-USER":
		return "connection not identifiable";
	case "HIDDEN-USER":
		return "server refused to identify connection";
	case "UNKNOWN-ERROR":
		return "unknown server failure";
	default:
		if ($ecode[0] == "X")
			return "unknown server error code: $ecode";
		else
			return "invalid server error code: $ecode";
	}
}

function escape_host($h) {
	if (strpos($h, ":") !== false)
		return "[$h]";
	else
		return $h;
}

function split_host_port($h) {
	$pos = strrpos($h, ":");
	return array(
		substr($h, 0, $pos),
		intval(substr($h, ++$pos)),
	);
}

function query($rhost, $rport, $lhost, $lport) {
	return Ident::query($rhost, $rport, $lhost, $lport);
}

function query_cgiremote() {
	return Ident::query_cgiremote();
}

function query_stream($sh) {
	return Ident::query_stream($sh);
}

function query_socket($sh) {
	return Ident::query_socket($sh);
}

/// TEST FUNCTIONS

function test_sshenv() {
	$s = getenv("SSH_CONNECTION");
	list ($rhost, $rport, $lhost, $lport) = explode(" ", $s);
	var_dump(query($rhost, $rport, $lhost, $lport));
}

function test_stream() {
	$se = stream_socket_server("tcp://[::]:1234");
	if ($co = stream_socket_accept($se, -1)) {
		print "accept\n";
		var_dump($re = query_stream($co));
		fwrite($co, "You are {$re->userid}\n");
		fclose($co);
	}
	fclose($se);
}

function test_socket() {
	$se = socket_create(AF_INET6, SOCK_STREAM, SOL_TCP);
	socket_bind($se, "::", 1234);
	socket_listen($se, 1);
	if ($co = socket_accept($se)) {
		print "accept\n";
		var_dump($re = query_socket($co));
		socket_write($co, "You are {$re->userid}\n");
		socket_close($co);
	}
	socket_close($se);
}

function test_stream_client($host="localhost", $port=22) {
	$host = escape_host($host);
	$co = stream_socket_client("tcp://$host:$port");
	var_dump(query_stream($co));
	fclose($co);
}

function test_socket_client($af=AF_INET, $host="localhost", $port=22) {
	$co = socket_create($af, SOCK_STREAM, SOL_TCP);
	socket_connect($co, $host, $port);
	var_dump(query_socket($co));
	socket_close($co);
}
