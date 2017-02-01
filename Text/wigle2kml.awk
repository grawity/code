#!/usr/bin/awk -f

BEGIN {
	FS = ",";
	print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>";
	print "<kml xmlns=\"http://www.opengis.net/kml/2.2\">";
	print "<Folder>";
}

NR > 2 {}

#$2 ~ /^utena/ {
$1 ~ /^..:..:..:..:..:..$/ {
	print "  <Placemark>";
	print "    <name>&quot;" $2 "&quot; (" $6 ", " $1 ")</name>";
	print "    <Point>";
	print "      <coordinates>" $8 "," $7 "," $9 "</coordinates>";
	print "    </Point>";
	print "  </Placemark>";
}

END {
	print "</Folder>";
	print "</kml>";
}
