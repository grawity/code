<?php
function parse_args($args, $types) {
	$types = explode(" ", $types);
	$args = explode(" ", $args, count($types));
	$parsed = array();
	foreach ($types as $i => $type) {
		if ($type == "skip") continue;

		$in = $args[$i];
		$out = null;
		
		$flag = "";
		# if type is prefixed with "*", strip one char from value before parsing
		while ($type[0] == "*") {
			$type = substr($type, 1);
			$flag .= $in[0];
			$in = substr($in, 1);
		}
		
		switch ($type) {
			case "i:h@b": # idx:handle@bot
				$out = new address();
				list ($in, $out->bot) = explode("@", $in, 2);
				list ($out->idx, $out->handle) = explode(":", $in, 2);
				break;
			case "h@b": # handle@bot
				$out = new address();
				list ($out->handle, $out->bot) = explode("@", $in, 2);
				if ($pos = strpos($out->handle, ":"))
					$out->handle = substr($out->handle, $pos+1);
				break;
			case "str": # string
				$out = $in;
				break;
			case "int":
				$out = btoi($in);
				break;
			case "int10": # integer (decimal)
				$out = intval($in, 10);
				break;
		}
		
		if (strlen($flag))
			$parsed[] = array($flag, $out);
		else
			$parsed[] = $out;
	}
	return $parsed;
}

function parse_route($str) {
	$str = explode(":", $str);
	return array($str[1], array_slice($str, 2));
}
