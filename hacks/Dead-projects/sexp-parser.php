<?php

namespace Sexp;

const DUMP_CANONICAL = 0x00000001;
const DUMP_HEX       = 0x00000002;
const DUMP_BASE64    = 0x00000004;
const DUMP_TRANSPORT = 0x00000008;
const DUMP_FORCE     = 0x00000010;

const T_ALPHA		= "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
const T_DIGITS		= "0123456789";
const T_WHITESPACE	= " \t\v\f\r\n";
const T_PSEUDO_ALPHA	= "-./_:*+=";
const T_PUNCTUATION	= '()[]{}|#"&\\';
const T_VERBATIM	= "!%^~;',<>?";

#const T_TOKEN_CHARS	= T_DIGITS . T_ALPHA . T_PSEUDO_ALPHA;
const T_TOKEN_CHARS	= "0123456790ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-./_:*+=";

const T_HEX_DIGITS	= "0123456789ABCDEFabcdef";
const T_B64_DIGITS	= "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

const T_ESCAPE_CHARS	= "\x08\t\v\n\f\r\\";

function dump($obj, $mode=0) {
	$submode = $mode;
	if ($submode & DUMP_TRANSPORT) {
		$submode &= ~DUMP_TRANSPORT;
		$submode |= DUMP_CANONICAL;
	}

	if (is_array($obj))
		$out = dump_list($obj, $submode);
	elseif (is_string($obj))
		$out = dump_string($obj, $submode);

	if ($mode & DUMP_TRANSPORT)
		$out = "{" . base64_encode($out) . "}";
	
	return $out;
}

function dump_string($str, $mode, $hint=null) {
	if ($mode & DUMP_CANONICAL)
		$out = strlen($str) . ":" . $str;
	elseif ($mode & DUMP_TRANSPORT) {
		$str = strlen($str) . ":" . $str;
		$out = "{" . base64_encode($str) . "}";
	} elseif (is_token($str))
		$out = (string) $str;
	elseif (is_quoteable($str))
		$out = "\"" . addcslashes($str, "\x00..\x1F\\") . "\"";
	elseif ($mode & DUMP_HEX)
		$out = "#" . bin2hex($str) . "#";
	else
		$out = "|" . base64_encode($str) . "|";

	if ($hint === null)
		return $out;
	else
		return dump_hint($hint, $mode) + $out;
}

function dump_hint($str, $mode) {
	if ($str === null)
		return "";
	else
		return "[" + dump_string($str, $mode, null) + "]";
}

function dump_list($obj, $mode) {
	$out = "(";
	if ($mode & DUMP_CANONICAL)
		foreach ($obj as $item)
			$out .= dump($item, DUMP_CANONICAL);
	else {
		$s = 0;
		foreach ($obj as $item)
			$out .= ($s++ ? " " : "") . dump($item, $mode);
	}
	$out .= ")";
	return $out;
}

function is_token($str) {
	if (strpos(T_DIGITS, $str[0]) !== false)
		return false;
	$len = strlen($str);
	for ($i=0; $i < $len; $i++) {
		$c = $str[$i];
		if (strpos(T_TOKEN_CHARS, $c) === false)
			return false;
	}
	return true;
}

function is_quoteable($str) {
	$len = strlen($str);
	for ($i=0; $i < $len; $i++) {
		$c = $str[$i];
		if (strpos(T_VERBATIM, $c) !== false)
			return false;
		elseif (ord($c) >= 0x20 && ord($c) < 0x80)
			continue;
		elseif (strpos(T_ESCAPE_CHARS, $c) !== false)
			continue;
		else
			return false;
	}
	return true;
}

$a = array("foo", "bar", "baz", "asdf qux lol?", array("one", "two"));
echo dump($a, DUMP_TRANSPORT);
