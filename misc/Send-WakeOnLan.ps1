# wol -- send a Wake-on-LAN broadcast
#
# An experiment in pure-PowerShell socket usage.

Param($MacAddress);

$buf = New-Object byte[] (6*17)
$mac = $MacAddress.Split(":") | % { [Convert]::ToByte($_, 16) }
for ($i = 0; $i -le 16; $i++) {
	for ($p = 0; $p -lt 6; $p++) {
		$ofs = ($i * 6) + $p
		if ($i -eq 0) {
			$buf[$ofs] = 0xFF
		} else {
			$buf[$ofs] = $mac[$p]
		}
	}
}

$addr = [System.Net.IPAddress]::Parse("255.255.255.255")
$port = 9

$af = [System.Net.Sockets.AddressFamily]::InterNetwork
$sf = [System.Net.Sockets.SocketType]::Dgram
$pf = [System.Net.Sockets.ProtocolType]::UDP
$sock = New-Object System.Net.Sockets.Socket $af, $sf, $pf
#$sock.TTL = 26
$ep = New-Object System.Net.IPEndpoint $addr, $port
$sock.Connect($ep)
$res = $sock.Send($buf)
#Write-Host "{0} characters sent to: {1} " -f $res, $addr
