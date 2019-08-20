#!/usr/bin/perl

# This perl module implements the NIST SP800-185*
# bytepad, left_encode, right_encode function.
# for the message authentication code KMAC (MAC-SHA3)
# using cSHAKE hash function (Secure  Hash  Algorithm  [KECCAK])

# note:
#  * for L < 160 I use KMAC128 and KMAC256 otherwise
#  * cSHAKE is slightly different than NIST because of the 2 bits: 00
#    in message for the sponge function.


# for spec: see [*](https://doi.org/10.6028/NIST.SP.800-185)

package KMAC;

require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
#@EXPORT_OK = qw(nickname);
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};

use strict;
# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$dbug $VERSION/;
# ----------------------------------------------------
our $VERSION = sprintf "%d.%02d", q$Revision: 0.0 $ =~ /: (\d+)\.(\d+)/;
my ($State) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------
$VERSION = &version(__FILE__) unless ($VERSION ne '0.00');

# KMAC128(K, X, L, S): Validity Conditions: len(K) < 2^2040 and 0 ≤ L < 2^2040 and len(S) < 2^2040
# newX = bytepad(encode_string(K), 168) || X || right_encode(L).
# return cSHAKE128(newX, L, “KMAC”, S).

# KMAC256(K, X, L, S): Validity Conditions: len(K) < 2^2040 and 0 ≤ L < 2^2040 and len(S) < 2^2040
# newX = bytepad(encode_string(K), 136) || X || right_encode(L).
# return cSHAKE256(newX, L, “KMAC”, S).


# example for using S (Customization String)
# *  cSHAKE128(public_key, 256, "", "key fingerprint")
# *  cSHAKE128(email_contents, 256, "", "email signature")

if ($0 eq __FILE__) {
printf "ver: %s\n",$VERSION if $dbug;
my $km = &KMAC('123',"",128);
printf qq(km:%s\n),enc($km);
printf qq(KMAC('123',"",128): %s\n),&encode_base58($km);
# newX:01a83132338001
# M:\01\a8KMAC\01\a8123\80\01\00
# km:o\03\e9tp\84\eb\a2\3c\e4\98z\d2\fcK/
# KMAC('123',"",128): Ei6sCmCakHWbz5qmqG8NPx

exit $?;
}

sub KMAC {
  my ($K,$X,$L,$S) = @_;
  my $rate = ($L >= 160) ? 136 : 168;
  my $newX = &bytepad($K,$rate) . $X . &right_encode($L);
  printf qq(newX:%s\n),unpack'H*',$newX if $dbug;
  return &cSHAKE($newX,$L,"KMAC",$S);
}


sub cSHAKE {
  my ($X,$L,$N,$S) = @_;
  if ($N eq '' && $S eq '') {
    return &shake($L,$X); # L before X
  } else {
    # KECCAK[256/512](bytepad(encode_string(N) || encode_string(S), 168/136) || X ||  00, L).
    my $rate = ($L >= 160) ? 136 : 168;
    my $M = &bytepad($N.$S,$rate) . $X . "\x00"; # /!\ bug alert here != NIST document : "00" as 2 bits !!!
    printf qq(M:%s\n),enc($M) if $dbug;
    my $kh = &shake($L,$M); # L before M
    return $kh;
  }
}


sub shake { # use shake 128 for L < 160
  # see also [*][sponge]
  use Crypt::Digest::SHAKE;
  my $len = shift;
  my $x = ($len >= 160) ? 256 : 128; # selection of the sponge !
  my $msg = Crypt::Digest::SHAKE->new($x);
  $msg->add(join'',@_);
  my $digest = $msg->done(($len+7)/8);
  return $digest;
}

sub bytepad {
  my ($X,$w) = @_;
  my $z = &left_encode($w) . $X;
  while (length($z)/8 % $w != 0) {
    $z = $z . "\x00"
  }
  return $z;
}

sub left_encode { # for now limited to 32bit... (int32)
   my $i = shift;
   my $x = &encode_base256($i);
   my $n = length($x);
   my $s = pack('C',$n) . $x;
   return $s;

}
sub right_encode { # for now limited to 32bit... (int32)
   my $i = shift;
   my $x = &encode_base256($i);
   my $n = length($x);
   my $s = $x.pack('C',$n);
   return $s;
}

sub encode_base256 { # limited to integer for now, will need to extend to bigint later
 use integer;
  my ($n) = @_;
  my $e = '';
  return("\x00") if $n == 0;
  while ( $n ) {
    my $c = $n % 256;
    $e .=  pack'C',$c;
    $n = int $n / 256;
  }
  return scalar reverse $e;
}

sub encode_base58 { # btc
  use Math::BigInt;
  use Encode::Base58::BigInt qw();
  my $bin = join'',@_;
  my $bint = Math::BigInt->from_bytes($bin);
  my $h58 = Encode::Base58::BigInt::encode_base58($bint);
  $h58 =~ tr/a-km-zA-HJ-NP-Z/A-HJ-NP-Za-km-z/;
  return $h58;
}

sub enc { # replace special char with \{hex} code
 my $buf = shift;
 #$buf =~ tr/\000-\034\134\177-\377//d;
 #$buf =~ s/\</\&lt;/g; # XML safe !
 $buf =~ s/([\000-\032\`\<\>\177-\377])/sprintf('\\%02x',ord($1))/eg; # \xFF-ize
 return $buf;
}
# -----------------------------------------------------------------------
sub version {
  #y ($atime,$mtime,$ctime) = (lstat($_[0]))[8,9,10];
  my @times = sort { $a <=> $b } (lstat($_[0]))[9,10]; # ctime,mtime
  my $vtime = $times[-1]; # biggest time...
  my $version = &rev($vtime);

  if (wantarray) {
     my $shk = &get_shake(160,$_[0]);
     print "$_[0] : shk:$shk\n" if $dbug;
     my $pn = unpack('n',substr($shk,-4)); # 16-bit
     my $build = &word($pn);
     return ($version, $build);
  } else {
     return sprintf '%g',$version;
  }
}
sub rev {
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime($_[0]))[0..7];
  my $rweek=($yday+&fdow($_[0]))/7;
  my $rev_id = int($rweek) * 4;
  my $low_id = int(($wday+($hour/24)+$min/(24*60))*4/7);
  my $revision = ($rev_id + $low_id) / 100;
  return (wantarray) ? ($rev_id,$low_id) : $revision;
}
sub fdow {
   my $tic = shift;
   use Time::Local qw(timelocal);
   ##     0    1     2    3    4     5     6     7
   #y ($sec,$min,$hour,$day,$mon,$year,$wday,$yday)
   my $year = (localtime($tic))[5]; my $yr4 = 1900 + $year ;
   my $first = timelocal(0,0,0,1,0,$yr4);
   our $fdow = (localtime($first))[6];
   #printf "1st: %s -> fdow: %s\n",&hdate($first),$fdow;
   return $fdow;
}

sub get_shake { # use shake 256 because of ipfs' minimal length of 20Bytes
  use Crypt::Digest::SHAKE;
  my $len = shift;
  local *F; open F,$_[0] or do { warn qq{"$_[0]": $!}; return undef };
  #binmode F unless $_[0] =~ m/\.txt/;
  my $msg = Crypt::Digest::SHAKE->new(256);
  $msg->addfile(*F);
  my $digest = $msg->done(($len+7)/8);
  return $digest;
}
sub word { # 20^4 * 6^3 words (25bit worth of data ...)
 use integer;
 my $n = $_[0];
 my $vo = [qw ( a e i o u y )]; # 6
 my $cs = [qw ( b c d f g h j k l m n p q r s t v w x z )]; # 20
 my $str = '';
 if (1 && $n < 26) {
 $str = chr(ord('A') +$n%26);
 } else {
 $n -= 6;
 while ($n >= 20) {
   my $c = $n % 20;
      $n /= 20;
      $str .= $cs->[$c];
   #print "cs: $n -> $c -> $str\n";
   my $c = $n % 6;
      $n /= 6;
      $str .= $vo->[$c];
   #print "vo: $n -> $c -> $str\n";

 }
 if ($n > 0) {
   $str .= $cs->[$n];
 }
 return $str;
 }
}





# [KECCAK]: http://keccak.noekeon.org/Keccak-reference-3.0.pdf
# [sponge]: http://sponge.noekeon.org/CSF-0.1.pdf

1;
