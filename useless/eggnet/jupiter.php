<?php
## If +r doesn't work...

$juped = array();

function jupe($bot) {
	global $juped;
	if (array_key_exists($bot, $juped)) {
		return false;
	}
	else {
		puts("n", $bot, Config::$handle, "-".itob(0));
		$juped[$bot] = 1;
	}
}

function unjupe($bot) {
	global $juped;
	if (array_key_exists($bot, $juped)) {
		puts("n", $bot, Config::$handle, "-".itob(0));
		unset($juped[$bot]);
	}
	else {
		return false;
	}
}
