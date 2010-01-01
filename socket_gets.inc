<?php
# vim: ft=php
function socket_gets($sockfd, $maxlength = 1024) {
	$buf = "";
	$size = 0;
	$char = null;
	while ($size < $maxlength) {
		$char = socket_read($sockfd, 1, PHP_BINARY_READ);
		# remote closed connection
		if ($char === false) break;
		# eof
		if ($char == "") break;

		$buf .= $char;
		if ($buf[$size] == "\n") {
			if ($size > 0 and $buf[$size-1] == "\r")
				return substr($buf, 0, $size-1);
			else
				return substr($buf, 0, $size);
		}
		$size++;
	}
	return $buf;
}
