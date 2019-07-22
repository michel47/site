#!/usr/bin/perl

# Note:
#   This work has been done during my time at GC-Bank™
# 
# -- Copyfair GCB, 2017,2018,2019 --
# 
# Running on a pseudo-private network :
#   ipfs daemon --transport-shared-key <current-key>
#   (need to participate to know the shared key...)
#

package KYC;
my $private_secret = '5ECBE7'; # use a salt ...
our $priv_key = undef;

require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
#@EXPORT_OK = qw(pkiadmin);
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};

use strict;

use lib $ENV{SITE}.'/lib';
use UTIL qw(version encode_baser hashr);

# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$dbug $VERSION/;
# ----------------------------------------------------
our $VERSION = sprintf "%d.%02d", q$Revision: 0.0 $ =~ /: (\d+)\.(\d+)/;
my ($State) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------
$VERSION = &version(__FILE__) unless ($VERSION ne '0.00');



if ($dbug) {
  eval "use YAML::Syck qw(Dump);";
}
# -------------------------------------------------------------------
use Math::Prime::Util qw(srand irand64 urandomm csrand random_strong_prime entropy_bytes);
my $seed = srand();
printf "seed: %s\n",$seed if $dbug;


# =======================================================================
if (__FILE__ eq $0) {
my $owner = shift || $ENV{USER} || 'iglake';
my $payload = shift;



 exit $?;
}
# =======================================================================

# -----------------------------------------------------------------------
sub tokenize {
  return &enc(&hashr('SHA-256',3,$VERSION,@_));
}
# -----------------------------------------------------------------------
sub enc {
  use MIME::Base64 qw(encode_base64);
  my $e = encode_base64(join('',@_),'');
  $e =~ y{+/}{_-};
  return $e;
}
# -----------------------------------------------------------------------
sub get_peerid { # dependency on ipfs
  my $buf = `ipfs id`;
  use JSON qw(decode_json);
  my $json = &decode_json($buf);
  return $json->{ID};
}
# -----------------------------------------------------------------------
sub get_prime {
 use LWP::UserAgent qw();
  my $ua = LWP::UserAgent->new();
  my $url = 'http://127.0.0.1:8080/ipns/QmckFMJZ4eEbaAhLKDRgv187qA2ZJxCrx9CihLGFU5hTLE';
  my $resp = $ua->get($url);
  my ($g,$p) = (3, 107);
  if ($resp->is_success) {
    my $content = $resp->decoded_content;
    #printf "content: %s\n",$content;
    use YAML::Syck qw();
    my ($yml,$hash) = &YAML::Syck::Load($content);
    $p = $yml->{p};
  } else {
    print $resp->status_line;
    my $content = $resp->decoded_content;
  }
  return ($g,$p);
 
}
# -----------------------------------------------------------------------
sub hmac {
   my($alg, $data, $key, $blk_size) = @_;

   use Digest;
   my $hash = Digest->new($alg);
   $blk_size ||= 64; # in bytes !
   # hash(k_opad,hash(k_ipad,data))
      if (length($key) > $blk_size) {
         $hash->add($key);
         $key = $hash->digest;
         $hash->reset();
      }

   my $k_ipad = $key ^ (chr(0x36) x $blk_size);
   my $k_opad = $key ^ (chr(0x5c) x $blk_size);
   if (0) {
      printf "key:  %s\n",unpack'H*',$key;
      printf "ipad: %s\n",unpack'H*',$k_ipad;
      printf "opad: %s\n",unpack'H*',$k_opad;
   }

   $hash->add($k_ipad);
   $hash->add($data);
   my $inner_digest = $hash->digest;

   $hash->reset();
   $hash->add($k_opad);
   $hash->add($inner_digest);

   my $digest = $hash->digest;
   return $digest; # hash message authentication code (binary)
}
# -----------------------------------------------------------------------
sub DH_secret {
  my ($g,$p,$key) = @_;
  use Crypt::DH; # keys agreement :
  my $dh = Crypt::DH->new( p => "$p", g => $g );
  if (! defined $priv_key) {
     my $pub =  $dh->generate_keys;
     $priv_key = $dh->priv_key();
     my $keypair = { pubkey => $pub, seckey => $priv_key };
     printf "seckey: %s\n",&tokenize($keypair->{seckey},$private_secret);
  } else {
     $dh->priv_key($priv_key);
     my $pub_key = $dh->compute_secret( $g );
     #printf "pubkey: %s\n",$pub_key;
  }
  my $secret = $dh->compute_secret( $key );
  return $secret || 'polichinel';
}
# -----------------------------------------------------------------------
sub get_publickey { # get public key of recipient 
  my $key = shift;
  use LWP::UserAgent qw();
  my $ua = LWP::UserAgent->new();
  my $url = sprintf 'http://127.0.0.1:8080/ipns/%s/kyc-pkey.yml',$key;
  my $resp = $ua->get($url);
  if ($resp->is_success) {
    my $content = $resp->decoded_content;
    use YAML::Syck qw();
    my $yml = &YAML::Syck::Load($content);
    my $pkey = $yml->{pkey};
    return $pkey;
  } else {
    return '6P-Tv4b';
  }
}
# -----------------------------------------------------------------------
sub decode_base85 {
  my $text = shift;
  my $bin = Convert::Ascii85::decode($text);
  return $bin;
}
# -----------------------------------------------------------------------
sub hashr {
   my $alg = shift;
   my $rnd = shift;
   my $tmp = join('',@_);
   use Digest qw();
   my $msg = Digest->new($alg) or die $!;
   for (1 .. $rnd) {
      $msg->add($tmp);
      $tmp = $msg->digest();
      $msg->reset;
   }
   return $tmp
}
# -----------------------------------------------------------------------
1; # $Source: /my/perl/modules/KYC.pm,v $
