<?php
Config::$handle = "foobie";
Config::$link_host = "";
Config::$link_port = 6512;
Config::$link_pass = "585jtktrwi97f9";
Config::$link_ssl = false;

Config::$note_forward = (object) array(
	"recipient" => "grawity@neph",
	"storage" => "notes.db",
	"add_via" => true,
);

const MY_VERSION = "foodrop v0.2";
const DEBUG = 1;
const USE_CHALLENGE = true;
