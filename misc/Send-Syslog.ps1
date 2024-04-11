# Send-Syslog -- send a syslog message via UDP
#
# This currently is hardcoded to sending an ALERT-level message because I use
# such messages to trigger push notifications.

Param($Tag, $Text);

# TODO: Look up 'syslog' via DNS
$ServerIP = "10.147.1.4";

$FAC_USER = 1;
$SEV_ALERT = 1;

$nil = "-";
$pri = ($FAC_USER * 8) + $SEV_ALERT;
$time = Get-Date -AsUTC -UFormat "%Y-%m-%dT%H:%M:%SZ";
#$time = Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ssZ";
$hostname = $env:COMPUTERNAME;
$appname = $Tag;
$procid = $nil;
$msgid = $nil;
$sdata = $nil;
$buf = "<$pri>1 $time $hostname $appname $procid $msgid $sdata $Text";
$buf = [System.Text.Encoding]::UTF8.GetBytes($buf);

$af = [System.Net.Sockets.AddressFamily]::InterNetwork
$sf = [System.Net.Sockets.SocketType]::Dgram 
$pf = [System.Net.Sockets.ProtocolType]::UDP 
$sock = New-Object System.Net.Sockets.Socket $af, $sf, $pf

$addr = [System.Net.IPAddress]::Parse($ServerIP)
$port = 514
$ep = New-Object System.Net.IPEndpoint $addr, $port
$sock.Connect($ep)
$res = $sock.Send($buf)
