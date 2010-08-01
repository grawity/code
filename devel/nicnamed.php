#!/usr/bin/env php
<?php

const MAX_REQUEST = 512;

$rules = array();

@include "nicnamed.conf";

if (count($rules) == 0) {
	fwrite(STDERR, "Error: No rules configured\n");
	exit(2);
}

function stream_getpeername($stream, &$host, &$port) {
	$name = stream_socket_get_name($stream, true);
	if (strlen($name)) {
		$pos = strrpos($name, ":");
		$host = substr($name, 0, $pos++);
		$port = substr($name, $pos);
		return true;
	} else {
		return false;
	}
}

function handle_request($request, $rule, $handler) {
	#var_dump($request, $rule, $handler);
	if (is_string($handler)) {
		if ($handler[0] == "/" or $handler[0] == ".") {
			reply_file($request, $handler);
		} elseif ($handler[0] == "<") {
			reply_file($request, substr($handler, 1));
		} elseif ($handler[0] == "|") {
			reply_pipe($request, substr($handler, 1));
		} elseif (function_exists($handler)) {
			$handler($request);
		} else {
			reply_file($request, $handler);
		}
	} else {
		$handler($request, $rule);
	}
}

function reply_file($request, $path) {
	$path = trim($path);
	$path = sprintf($path, $request);
	if (file_exists($path))
		readfile($path);
	else
		print("Error: Not found\r\n");
}

function reply_pipe($request, $handler) {
	$handler = trim($handler);
	$fd_spec = array(
		0 => array("pipe", "r"),
		1 => STDOUT,
		2 => STDERR,
	);

	$env = array();
	stream_getpeername(STDIN, $env["REMOTE_ADDR"], $env["REMOTE_PORT"]);

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

#$request = stream_get_line(STDIN, MAX_REQUEST+1, "\r\n");
$request = rtrim(fgets(STDIN, MAX_REQUEST+1));

if ($request === false) {
	exit;
}
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
	$regexp = str_replace(
		array(".", "*", "%", "?"),
		array("\\.", ".+", "[^.]+", "."),
		$rule);
	$regexp = "/^{$regexp}\$/i";

	if (preg_match($regexp, $request, $matches)) {
		if (count($matches) > 1)
			$request = $matches[1];
		handle_request($request, $rule, $handler);
		exit;
	}
}

print("Error: Not found\r\n");
