<?php

class ParserException extends Exception {}

class Parser {
	public $str;
	public $pos;
	public $char;
	
	function __construct($str) {
		$this->str = $str;
		$this->len = strlen($str);
		$this->pos = 0;
		$this->char = $this->str[0];
	}
	
	function next() {
		if (++$this->pos >= $this->len)
			$this->char = null;
		else
			$this->char = $this->str[$this->pos];
		return $this->char;
	}
	
	function skip($char) {
		if (strlen($char) != 1) {
			throw new ParserException("skip() only accepts single character");
		}

		if ($this->char === null) {
			throw new ParserException("eof found, '{$char}' expected at {$this->pos}");
		} elseif ($this->char !== $char) {
			throw new ParserException("char '{$this->char}' found, '{$char}' expected at {$this->pos}");
		} else {
			$this->next();
		}
	}

	function skipws() {
		while ($this->char !== null) {
			switch ($this->char) {
			case " ":
			case "\t":
			case "\n":
				$this->next();
			default:
				return;
			}
		}
	}

	function scan_char() {
		if ($this->char === "\\")
			return $this->scan_escape();
		else
			return $this->char;
	}

	function scan_escape() {
		$this->skip("\\");
		switch ($this->char) {
		case "b":	return "\b";
		case "t":	return "\t";
		case "v":	return "\v";
		case "n":	return "\n";
		case "f":	return "\f";
		case "r":	return "\r";
		case "\n":	return "";
		case "\r":	return "";
		default:	return $this->char;
		}
	}

	function scan_word() {
		$out = "";
		$this->skipws();
		while ($this->char !== null) {
			switch ($this->char) {
			case "\"":
				$out .= $this->scan_quoted($this->char);
				break 2;
			case " ":
			case "\n":
				break 2;
			default:
				$out .= $this->scan_char();
			}
			$this->next();
		}
		return $out;
	}

	function scan_quoted($qchar="\"") {
		$out = "";
		$this->skipws();
		$this->skip($qchar);
		while ($this->char !== null) {
			if ($this->char == $qchar) {
				$this->next();
				break;
			} else
				$out .= $this->scan_char();
			$this->next();
		}
		return $out;
	}

	function scan_balanced($ochar="(", $cchar=")") {
		$out = "";
		$nest = 1;
		$this->skipws();
		$this->skip($ochar);
		while ($this->char !== null) {
			if ($this->char == $cchar)
				if (--$nest)
					$out .= $this->char;
				else {
					$this->next();
					break;
				}
			elseif ($this->char == $ochar) {
				$out .= $this->char;
				++$nest;
			}
			else
				$out .= $this->scan_char();
			$this->next();
		}
		return $out;
	}

	function scan_eol() {
		$out = "";
		while ($this->char !== null) {
			if ($this->char == "\r" or $this->char == "\n")
				break;
			else
				$out .= $this->scan_char();
			$this->next();
		}
		return $out;
	}
}

class IonParser {
	private $p;

	static function parse_line($line) {
		$p = new Parser($line);
		$f = $p->scan_word();
		$p->skip(" ");
		$d = self::scan_tc_eol($p);
		return array($f, $d);
	}

	// Total Commander multi-line description
	private function scan_tc_eol($p) {
		$out = "";
		while ($p->char !== null) {
			if ($p->char == "\r" or $p->char == "\n")
				break;
			elseif ($p->char == "\x04") {
				$p->next();
				$p->next();
				break;
			}
			else
				$out .= $p->scan_char();
			$p->next();
		}
		return $out;
	}
}


class DirLister {
	public $dir;
	public $descr;

	function __construct($dir) {
		$this->dir = $dir;
		$this->descr = array();
		$this->load_descriptions();
	}

	function enumerate() {
		$dirs = array();
		$files = array();
		$fh = opendir($this->dir);
		if (!$fh)
			return;
		while (($name = readdir($fh)) !== false) {
			$path = $this->dir."/".$name;
			$is_dir = is_dir($path);
			$entry = array($name, $path, $is_dir);
			if ($name == "." || $name == "..")
				continue;
			elseif (strtolower($name) == "descript.ion")
				continue;
			elseif ($is_dir)
				$dirs[] = $entry;
			else
				$files[] = $entry;
		}
		closedir($fh);
		return array_merge($dirs, $files);
	}

	function load_descriptions() {
		$fh = fopen($this->dir."/descript.ion", "r");
		if (!$fh)
			return;
		while (($line = fgets($fh)) !== false) {
			try {
				list ($file, $descr) = IonParser::parse_line($line);
			} catch (Exception $e) {
				continue;
			}
			if (strlen($descr))
				$this->descr[strtolower($file)] = $descr;
		}
		fclose($fh);
	}

	function get_full_description($name) {
		return @$this->descr[strtolower($name)];
	}

	function get_description($name) {
		$descr = @$this->descr[strtolower($name)];
		$descr = explode("\n", $descr);
		return $descr[0];
	}
}

class DirIndexer {
	public $dir;
	private $lister;

	function __construct($dir) {
		$this->dir = $dir;
		$this->lister = new DirLister($dir);
	}

	function display() {
		foreach ($this->lister->enumerate() as $entry) {
			list ($name, $path, $is_dir) = $entry;
			$wpath = $path;
			if ($is_dir)
				$dname = "[{$name}]";
			else
				$dname = $name;
			$descr = $this->lister->get_description($name);

			print	"<td class=\"name\">".
				"<a href=\"".htmlspecialchars($wpath)."\">".
				htmlspecialchars($dname).
				"</a>".
				"</td>\n";

			print	"<td class=\"description\">".
				htmlspecialchars($descr).
				"</td>\n";
		}
	}
}


$p = "D:/Software/Internet/Web";
$d = new DirIndexer($p);
$d->display();
