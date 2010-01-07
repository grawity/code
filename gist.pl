#!/usr/bin/perl
# gist v1.0
# gist.github.com submission script
#
# (c) 2009 <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>

use warnings;
use strict;
use utf8;

use Getopt::Long;
use File::Basename;
use LWP::UserAgent;

sub usage {
	print "Usage:\n";
	print "\tgist [-p|--private] [-n|--name foo] < file\n";
	print "\tgist [-p|--private] [-a|--add-remote] file [file2 file3 ...]\n";
	return 2;
}

sub get_github_auth {
	chomp(my $user = `git config --global github.user`);
	chomp(my $token = `git config --global github.token`);

	return $user eq ""? () : (login => $user, token => $token);
}

sub build_post_data {
	my ($private, $filename, @files) = @_;

	my %data = get_github_auth;
	$data{"action_button"} = "private" if $private;

	my $i = 1;
	if ($#files == -1) {
		# get from stdin
		$data{"file_name[gistfile$i]"} = $filename;
		$data{"file_ext[gistfile$i]"} = "";
		$data{"file_contents[gistfile$i]"} = "";

		while (my $line = <STDIN>) {
			$data{"file_contents[gistfile$i]"} .= $line;
		}
	}
	else {
		if ($filename ne "") {
			print STDERR "warning: file names given; option --name will be ignored\n";
		}

		for my $filename (@files) {
			$data{"file_name[gistfile$i]"} = basename($filename);
			$data{"file_ext[gistfile$i]"} = "";
			$data{"file_contents[gistfile$i]"} = "";

			open IN, "< $filename" or die "Cannot open file $filename\n";
			while (my $line = <IN>) {
				$data{"file_contents[gistfile$i]"} .= $line;
			}
			close IN;
			$i++;
		}
	}

	return \%data;
}

my $private = 0;
my $filename = "";
my $add_git_remote = 0;
GetOptions(
	"private|p" => \$private,
	"name=s" => \$filename,
	"add-remote|a" => \$add_git_remote,
) or exit usage;

my $data = build_post_data $private, $filename, @ARGV;

my $ua = new LWP::UserAgent();
my $response = $ua->post(
	"http://gist.github.com/gists",
	"Content-Type" => "application/x-www-form-urlencoded; charset=utf-8",
	Content => $data);

if ($response->code == 302) {
	# successful post, redirecting to the gist's page
	my $url = $response->header("Location");

	$url =~ /https?:\/\/(gist\.github\.com)\/(.+)$/;
	my $git_public_url = "git://$1/$2.git";
	my $git_private_url = "git\@$1:$2.git";

	print "gist page: $url\n";
	print "private: $git_private_url\n";
	print "public: $git_public_url\n" unless $private;

	if ($add_git_remote) {
		system "git remote add gist $git_private_url";
		system "git push gist master --force";
	}
}
else {
	print $response->decoded_content;
	exit 1;
}
