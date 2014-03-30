use LWP::Simple;
use XML::Feed;

my $url = shift @ARGV;

my $data = get($url);

my $feed = XML::Feed->parse(\$data);

for my $entry ($feed->entries) {
	print "title: ".$entry->title."\n";
}
