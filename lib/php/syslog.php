<?php
/* Sends RFC 5424 (not BSD) syslog messages */

class Syslogger {
	private $host;
	private $sock;

	public $facility;
	public $hostname;
	public $processname;
	public $processid;

	function __construct($host, $sock=null) {
		$this->host = $host;
		$this->sock = $sock ? $sock : stream_socket_client($host);

		$this->facility = LOG_AUTHPRIV;
		$this->hostname = $_SERVER["SERVER_NAME"];
	}

	public function send($priority, $msg, $id=null) {
		if (!$this->sock)
			return;

		$priority |= $this->facility;
		$version = "1";
		$structured = null;

		$buf = "<" . $priority . ">" . $version;
		$buf .= " " . date(DATE_RFC3339);
		$buf .= " " . self::strnul($this->hostname);
		$buf .= " " . self::strnul($this->processname);
		$buf .= " " . self::strnul($this->processid);
		$buf .= " " . self::strnul($id);
		$buf .= " " . self::strnul($structured);
		$buf .= " " . "\xEF\xBB\xBF".$msg;

		fwrite($this->sock, $buf);
		fflush($this->sock);
	}

	static function strnul($str) {
		return strlen($str) ? $str : "-";
	}
}
