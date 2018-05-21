<?php
header("Content-Type: text/plain; charset=utf-8");

$i = array(
	"server" => array(
		"host" => $_SERVER["SERVER_ADDR"],
		"port" => intval($_SERVER["SERVER_PORT"]),
	),
	"client" => array(
		"host" => $_SERVER["REMOTE_ADDR"],
		"port" => intval($_SERVER["REMOTE_PORT"]),
	),
);

if (@include "libident.php") {
	Ident\Ident::$timeout = 3;
	$ident = Ident\query_cgiremote();

	if ($ident) {
		$i["raw"] = array(
			"request" => $ident->raw_request,
			"reply" => $ident->raw_reply,
		);
	}

	if (!$ident) {
		$i["ident"] = array(
			"status" => "failure",
			"response" => "unknown",
		);
	}
	elseif ($ident->success) {
		$i["ident"] = array(
			"status" => "success",
			"response" => $ident->response_type,
			"user-id" => $ident->userid,
			"os-type" => $ident->ostype,
			"charset" => $ident->charset,
		);
	}
	else {
		$i["ident"] = array(
			"status" => "failure",
			"response" => $ident->response_type,
			"additional" => $ident->add_info,
		);
	}
}
else {
	$i["ident"] = array(
		"status" => "internal error",
		"error" => "libident.php missing",
	);
}

print "Your Ident lookup results:\n";
print "\n";

if (function_exists("yaml_emit"))
	print yaml_emit($i, YAML_UTF8_ENCODING);
else {
	print "(Notice: missing 'yaml' module)\n";
	print_r($i);
}

print "\n";
print "(This information is not stored in any logs.)\n";
