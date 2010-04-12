<?php
# Addresses of type idx:handle@bot and handle@bot
class address {
	public $idx, $handle, $bot;
	
	function __construct($str=null) {
		if (!strlen($str)) return;
		$p = $p = strpos($str, ":");
		if ($p !== false) {
			$this->idx = (int) substr($str, 0, $p);
			$str = substr($str, ++$p);
		}
		$p = strpos($str, "@");
		if ($p !== false) {
			$this->handle = substr($str, 0, $p);
			$str = substr($str, ++$p);
		}
		$this->bot = $str;
	}
	
	function __toString() {
		if ($this->idx !== null)
			return "{$this->idx}:{$this->handle}@{$this->bot}";
		elseif ($this->handle !== null)
			return "{$this->handle}@{$this->bot}";
		else
			return $this->bot;
	}
	
	function __invoke($format="ihb") {
		switch ($format) {
		case "ihb":
			if ($this->idx !== null)
				return "{$this->idx}:{$this->handle}@{$this->bot}";
		case "hb":
			if ($this->handle !== null)
				return "{$this->handle}@{$this->bot}";
		case "b":
			return $this->bot;
		}
	}
}
