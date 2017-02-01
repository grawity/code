function Convert-CidrToNetmask {
	param([string]$cidrmask)
	
	$addr, $plen = $cidrmask.Split("/")
	$plen = $plen -as [int]

	if ($addr.Contains(":")) {
		$nbits = 128; $bits = 16; $fmt = "{0:x4}"; $sep = ":"
	} else {
		$nbits = 32; $bits = 8; $fmt = "{0}"; $sep = "."
	}

	$parts = @()
	$all = (1 -shl $bits) - 1
	for ($i = $plen; $i -ge $bits; $i -= $bits) {
		$parts += $fmt -f $all
	}
	$parts += $fmt -f ($all -shl $bits -shr $i -band $all)
	for ($i = $nbits - $plen; $i -gt $bits; $i -= $bits) {
		$parts += $fmt -f 0
	}
	$mask = $parts -join $sep

	return "$addr/$mask"
}

Convert-CidrToNetmask "193.219.181.192/26"
Convert-CidrToNetmask "193.219.181.192/10"
Convert-CidrToNetmask "193.219.181.192/24"
Convert-CidrToNetmask "fe80::c5:8eff:fe60:35e5/62"
