<?php

function endswith($str, $suffix) {
	return substr($str, -strlen($suffix)) === $suffix;
}

class ZoneParser {
	function __construct($input) {
		$this->input = $input;
	}

	private function token() {
	}
}

$origin = ".";

while (($line = fgets(STDIN)) !== false) {
	$line = rtrim($line);

	if (preg_match('/^\$ORIGIN\s+(\S+)$/', $line, $m)) {
		$origin = $m[1];
		echo "origin is now $origin\n";
	}
	elseif (preg_match('/^\s*(;.*)$/', $line, $m)) {
		$comment = $m[1];
		echo "comment=$comment\n";
	}
	elseif (preg_match('/
			^ (\S*) \s+
			(?: (\d+) \s+ )?
			(?: (CH|HS|IN) \s+ )?
			([A-Z]+\d*) \s+
			(.+) \s* $/x', $line, $m)) {
		$owner = $m[1];
		if (!strlen($owner))
			$owner = $last_owner;
		elseif ($owner === "@")
			$owner = $origin;
		elseif (!endswith($owner, "."))
			$owner .= ".$origin";
		$ttl = @$m[2];
		$class = @$m[3];
		if (!strlen($class))
			$class = "IN";
		$type = $m[4];
		$data = $m[5];
		echo "owner=$owner ttl=$ttl class=$class type=$type data=$data\n";

		$last_owner = $owner;
	}
}
