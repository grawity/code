#!/bin/sh -ex
tail -f "$@" '/n/ukweb/C/Program Files (x86)/Apache Software Foundation/Apache2.2/htdocs/system/_errors.php' | ./smartweb-decode-errors.pl
