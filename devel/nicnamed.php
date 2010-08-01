#!/usr/bin/env php
<?php

const MAX_REQUEST = 512;

$rules = array(
	"*.cluenet.org" => "| ~/cluenet/whois-server",
);

@include "nicnamed.conf";

function match($mask, $input) {
	$mask = str_replace(
		array(".", "*", "%", "?"),
		array("\\.", ".+", "[^.]+", "."),
		$mask);

	if (preg_match("/^$mask\$/i", $input))
		return true;
	else
		return false;
}

function handle_request($request, $rule, $handler) {
	//var_dump($request, $rule, $handler);

	if (is_string($handler)) {
		if ($handler[0] == "<") {
			// "< file"
			$pattern = trim(substr($handler, 1));
			$file = sprintf($pattern, $request);
			if (file_exists($file)) {
				readfile($file);
			} else {
				print("Error: Not found\r\n");
			}
		} elseif ($handler[0] == "|") {
			// "| command"
			$handler = trim(substr($handler, 1));
			pipe_request($request, $handler);
		} elseif (function_exists($handler)) {
			// create_function()
			$handler($request, $rule);
		}
	} else {
		$handler($request, $rule);
	}
}

function pipe_request($request, $handler) {
	$fd_spec = array(
		0 => array("pipe", "r"),
		1 => STDOUT,
		2 => STDERR,
	);

	$peername = stream_socket_get_name(STDIN, true);

	$env = array();

	$proc = proc_open($handler, $fd_spec, $pipes, NULL, $env);
	if (!$proc) {
		print("Error: Unknown error\r\n");
		return false;
	}
	fwrite($pipes[0], "$request\n");
	fclose($pipes[0]);
	$retval = proc_close($proc);
	return ($retval == 0);
}

$request = stream_get_line(STDIN, MAX_REQUEST+1, "\n");
if ($request === false)
	exit;
if (strlen($request) > MAX_REQUEST) {
	print("Error: Request too long\r\n");
	exit;
}
if (strpos($request, "/") !== false) {
	print("Error: Invalid request\r\n");
	exit;
}

$request = rtrim($request, ".");

foreach ($rules as $rule => $handler) {
	if (match($rule, $request)) {
		handle_request($request, $rule, $handler);
		exit;
	}
}

print("Error: Not found\r\n");
