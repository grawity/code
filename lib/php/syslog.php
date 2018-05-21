<?php
/* Sends RFC 5424 (not BSD) syslog messages */

class Syslogger {
	private $host;
	private $sock;

	public $facility = LOG_AUTHPRIV;
	public $hostname = $_SERVER["SERVER_NAME"];
	public $processname;
	public $processid;

	function __construct($host, $sock=null) {
		self::$host = $host;
		self::$sock = $sock ? $sock : stream_socket_client($host);
	}

	public function send($priority, $msg, $id=null) {
		if (!self::$sock)
			return;

		$priority |= self::$facility;
		$version = "1";
		$structured = null;

		$buf = "<" . $priority . ">" . $version;
		$buf .= " " . date(DATE_RFC3339);
		$buf .= " " . self::strnul(self::$hostname);
		$buf .= " " . self::strnul(self::$processname);
		$buf .= " " . self::strnul(self::$processid);
		$buf .= " " . self::strnul($id);
		$buf .= " " . self::strnul($structured);
		$buf .= " " . "\xEF\xBB\xBF".$msg;

		fwrite(self::$sock, $buf);
		fflush(self::$sock);
	}

	static function strnul($str) {
		return strlen($str) ? $str : "-";
	}
}
