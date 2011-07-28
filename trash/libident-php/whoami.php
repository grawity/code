<?php
header("Content-Type: text/plain; charset=utf-8");

$i = array(
	"remote host" => $_SERVER["REMOTE_ADDR"],
	"remote port" => intval($_SERVER["REMOTE_PORT"]),
);

if (@include "libident.php") {
	Ident\Ident::$timeout = 3;
	$ident = Ident\query_cgiremote();
	if (!$ident) {
		$i["ident"] = array(
			"status" => "failure",
			"response type" => "unknown",
		);
	}
	elseif ($ident->success) {
		$i["ident"] = array(
			"status" => "success",
			"response type" => $ident->response_type,
			"user id" => $ident->userid,
			"os type" => $ident->ostype,
			"charset" => $ident->charset,
		);
	}
	else {
		$i["ident"] = array(
			"status" => "failure",
			"response type" => $ident->response_type,
			"additional" => $ident->add_info,
		);
	}
	$i["ident"]["raw reply"] = $ident->raw_reply;
}
else {
	$i["ident"] = array(
		"status" => "internal error",
		"error" => "libident.php missing",
	);
}

print yaml_emit($i, YAML_UTF8_ENCODING);

?>

(The above information is not logged.)
