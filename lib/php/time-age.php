<?php
function fmt_duration($t, $space="", $max_elements=null) {
	$str = array();
	
	$s = $t%60; $t = floor($t/60);
	$m = $t%60; $t = floor($t/60);
	$h = $t%24; $t = floor($t/24);
	$d = $t%7; $t = floor($t/7);
	$w = $t;

	if ($s) {
		$str[] = "${s}s";
	}
	if ($m || ($h && $s) || ($d && $s)) {
		$str[] = "${m}m";
	}
	if ($d || $h || $m || $s) {
		$str[] = "${h}h";
	}
	if ($d || $w) {
		$str[] = "${d}d";
	}
	if ($w) {
		$str[] = "${w}w";
	}

	$str = array_reverse($str);
	if ($max_elements)
		$str = array_slice($str, 0, $max_elements);
	$str = implode($space, $str);
	return $str;
}
