<?php
header("Content-Type: text/plain; charset=utf-8");

function parse_txt($fqdn, $str) {
	if (substr($str, 0, 7) !== "v=wol1 ")
		return;

	$host = strtok($fqdn, ".");
	
	$data = array();
	foreach (explode(" ", $str) as $t) {
		list ($k, $v) = explode("=", $t, 2);
		$data[$k] = $v;
	}

	if (@$data["w"] !== "y")
		return;
	if (!isset($data["hw"]))
		return;

	$hw = strtolower($data["hw"]);

	if (isset($data["if"]))
		$name = "{$host} ({$data["if"]})";
	else
		$name = $host;
	
	$name = base64_encode($name);

	echo ". {$hw} {$name}\n";
}

$hosts = array();

echo "* BEGIN\n";

foreach (dns_get_record("_hosts.nullroute.eu.org", DNS_PTR) as $rp)
	foreach (dns_get_record($rp["target"], DNS_TXT) as $rh)
		foreach ($rh["entries"] as $e)
			parse_txt($rh["host"], $e);

echo "* END\n";

?>
