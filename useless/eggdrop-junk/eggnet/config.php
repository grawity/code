<?php
Config::$handle = "foobie";
Config::$link_host = "[::1]";
Config::$link_port = 12894;
Config::$link_pass = "z93kyb7s3qs";
Config::$link_ssl = true;

Config::$note_forward = (object) array(
	"recipient" => "grawity@neph",
	"storage" => "notes.db",
	"add_via" => true,
);

const MY_VERSION = "foodrop v0.2";
const DEBUG = 1;
const USE_CHALLENGE = true;
