<?php
function age($t, $max_elements=null) {
	$age = array();
	
	if ($s = $t%60) {
		$age[] = "${s}s";
		$t = floor($t/60);
	}
	if ($m = $t%60) {
		$age[] = "${m}m";
		$t = floor($t/60);
	}
	if ($h = $t%24) {
		$age[] = "${h}h";
		$t = floor($t/24);
	}
	if ($d = $t%7) {
		$age[] = "${d}d";
		$t = floor($t/7);
	}
	if ($t) {
		$age[] = "${t}w";
	}

	$age = array_reverse($age);
	if ($max_elements)
		$age = array_slice($age, 0, $max_elements);
	$age = implode("", $age);

	/*
	if ($d = floor($t/86400)) {
		$age .= "${d}d";
		$t -= $d*86400;
	}
	if ($h = floor($t/3600)) {
		$age .= "${h}h";
		$t -= $h*3600;
	}
	if ($m = floor($t/60)) {
		$age .= "${m}m";
		$t -= $m*60;
	}
	if ($t) {
		$age .= "${t}s";
	}
	*/
	return $age;
}

//var_dump(age(4*7*86400 + 2*86400 + 7*3600 + 42*60 + 17));
