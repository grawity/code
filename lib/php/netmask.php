<?php
// ip_expand(str $addr) -> str?
// Expand a string IP address to binary representation.
// v6-mapped IPv4 addresses will be converted to IPv4.

function ip_expand($addr) {
	$addr = @inet_pton($addr);
	if ($addr === false || $addr === -1)
		return null;
	if (strlen($addr) == 16) {
		if (substr($addr, 0, 12) === "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xFF\xFF"
		||  substr($addr, 0, 12) === "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
			return substr($addr, 12);
	}
	return $addr;
}

// ip_cidr(str $host, str $cidrmask) -> bool
// Check if $host belongs to the network $mask (specified in CIDR format)
// If $cidrmask does not contain /prefixlen, an exact match will be done.

function ip_cidr($host, $mask) {
	@list ($net, $len) = explode("/", $mask, 2);

	$host = ip_expand($host);
	$net = ip_expand($net);

	// FIXME: if ip_expand strips off the v6mapped prefix from $net,
	// it also needs to adjust $len accordingly.

	if ($host === null || $net === null || strlen($host) !== strlen($net))
		return false;

	$nbits = strlen($net) * 8;

	if ($len === null || $len == $nbits)
		return $host === $net;
	elseif ($len == 0)
		return true;
	elseif ($len < 0 || $len > $nbits)
		return false;

	$host = unpack("C*", $host);
	$net = unpack("C*", $net);
	$bad = 0;

	for ($i = 1; $i <= count($net) && $len > 0; $i++) {
		$bits = $len >= 8 ? 8 : $len;
		$bmask = (0xFF << (8 - $bits)) & 0xFF;
		$bad |= ($host[$i] ^ $net[$i]) & $bmask;
		$len -= 8;
	}
	return !$bad;
}
