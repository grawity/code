Function Test-IpInNetwork {
	Param([string]$Address, [string]$Network)
	$tmp = $Network.Split("/", 2)
	$haddr = [System.Net.IPAddress]::Parse($Address)
	$naddr = [System.Net.IPAddress]::Parse($tmp[0])
	$plen = [int]$tmp[1]
	if ($haddr.AddressFamily -ne $naddr.AddressFamily) {
		return $false
	}
	$hbyte = $haddr.GetAddressBytes()
	$nbyte = $naddr.GetAddressBytes()
	$bad = 0
	if ($hbyte.Length -ne $nbyte.Length -Or $plen -notin 0..($hbyte.Length*8)) {
		return $false
	}
	for ($i = 0; $i -le $hbyte.Length -And $plen -gt 0; $i++) {
		$bits = [math]::Min($plen, 8)
		$bmask = (0xFF00 -shr $bits) -band 0xFF
		$bad = $bad -bor (($hbyte[$i] -bxor $nbyte[$i]) -band $bmask)
		$plen -= 8
	}
	return ($bad -eq 0)
}

Test-IpInNetwork -Address 10.45.197.56 -Network 10.45.0.0/16
Test-IpInNetwork -Address 10.45.197.56 -Network 10.45.0.0/17
Test-IpInNetwork -Address 10.3.4.4 -Network fe80::/64
Test-IpInNetwork -Address 2001:778:e27f::1 -Network fe80::/64
Test-IpInNetwork -Address 2001:778:e27f::1 -Network 2001:778::/48
Test-IpInNetwork -Address 2001:778:e27f::1 -Network 2001:778:e27f::/48
