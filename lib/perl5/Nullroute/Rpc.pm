#!perl
package Nullroute::Rpc;
use common::sense;
use Carp;
use MIME::Base64;
use Nullroute::Rpc::Peer;

our $DEBUG = $ENV{DEBUG};

# shortcut methods for encoding Base64

sub b64_encode	{ MIME::Base64::encode_base64(shift // "", "") }
sub b64_decode	{ MIME::Base64::decode_base64(shift // "") }

# macros for use in RPC return codes

sub failure	{ success => 0 }
sub success	{ success => 1 }

1;
