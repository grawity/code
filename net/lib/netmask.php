<?php
// Check IPv4/6 address against netmask
function netmask($addr, $subnet) {
	$addr = inet_pton($addr);
	if (strpos($subnet, "/") === false) {
		$subnet = inet_pton($subnet);
		return $addr === $subnet;
	} else {
		list ($subnet, $mask) = explode("/", $subnet, 2);
		$subnet = inet_pton($subnet);
		if (strpos($mask, ".") === false) {
			$bits = intval($mask);
			$mask = str_repeat("\x00", strlen($subnet));
			for ($i = 0; $i < $bits; $i++) {
				$j = floor($i / 8);
				$mask[$j] |= chr(1 << ($i % 8));
			}
		} else {
			$mask = inet_pton($mask);
		}
		return ($addr & $mask) === $subnet;
	}
}
