<?php
// inet_pton_v6mapped(str $addr) -> str?
// Convert a string IP address to binary representation, and unmap "v6-mapped"
// addresses such as "::ffff:1.2.3.4" to their native IPv4 representation.

function inet_pton_v6mapped($addr) {
	$addr = inet_pton($addr);
	if ($addr === false || $addr === -1)
		return null;
	if (strlen($addr) == 16 &&
	    (substr($addr, 0, 12) === "\0\0\0\0\0\0\0\0\0\0\xFF\xFF" ||
	     substr($addr, 0, 12) === "\0\0\0\0\0\0\0\0\0\0\0\0"))
		return substr($addr, 12);
	return $addr;
}

// ip_cidr(str $host, str $mask) -> bool
// Check if $host belongs to the network $mask (specified in CIDR format). If
// $mask does not contain /prefixlen, a full-length prefix (/32 or /128) is
// assumed.

function ip_cidr($host, $mask) {
	@list ($net, $len) = explode("/", $mask, 2);
	$host = inet_pton_v6mapped($host);
	$net = inet_pton($net);

	if ($host === false || $net === false || !is_numeric("0$len"))
		throw new \InvalidArgumentException();
	elseif (strlen($host) !== strlen($net))
		return false; /* Mismatching address families aren't an error */

	$nbits = strlen($host) * 8;
	$len = strlen($len) ? intval($len) : $nbits;

	if ($len < 0 || $len > $nbits)
		throw new \InvalidArgumentException();
	elseif ($len == 0)
		return true;

	$host = unpack("C*", $host);
	$net = unpack("C*", $net);

	for ($i = 1; $i <= count($net) && $len > 0; $i++) {
		$bits = min($len, 8);
		$len -= $bits;
		$bmask = (0xFF00 >> $bits) & 0xFF;
		if (($host[$i] ^ $net[$i]) & $bmask)
			return false;
	}
	return true;
}

function ip_range($mask) {
	@list ($net, $len) = explode("/", $mask, 2);
	$net = inet_pton($net);

	if ($net === false || !is_numeric("0$len"))
		throw new \InvalidArgumentException();

	$nbits = strlen($net) * 8;
	$len = strlen($len) ? intval($len) : $nbits;

	if ($len < 0 || $len > $nbits)
		throw new \InvalidArgumentException();

	$net = unpack("C*", $net);
	$first = [];
	$last = [];

	for ($i = 1; $i <= count($net); $i++) {
		$bits = min($len, 8);
		$len -= $bits;
		$bmask = (0xFF00 >> $bits) & 0xFF;

		$first[$i] = $net[$i] & $bmask;
		$last[$i] = $net[$i] | ~$bmask & 0xFF;
	}

	$first = inet_ntop(pack("C*", ...$first));
	$last = inet_ntop(pack("C*", ...$last));
	return [$first, $last];
}
