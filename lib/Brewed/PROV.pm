#!perl
# vim: ts=2 et nowrap

package Brewed::PROV;
# Note:
#   This work has been done during my spare time at Provence Technologies
# 
# -- Copyright Provence, 2013,2014,2015 --
# ----------------------------------------------------
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
local $VERSION = sprintf "%d.%02d", q$Revision: 0.0 $ =~ /: (\d+)\.(\d+)/;
my ($State) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------
my $SITE=$ENV{SITE}; push @INC,"$SITE/lib";
#
my $seed = $^T ^ $$;

if (! -f '/dev/null') { # non-unix system
sub getpwuid ();
}

# ----------------------------------------------------
our %mhc = ( # multi-hash-code ...
 'id7' => 0x0107, 'id13' => 0x020D,
 'ipfs' => 0x1220,

 'null' => 0x0000
);

# ----------------------------------------------------
# Hilbert's Walk
sub d2xy { # this works well
  use integer;
  my ($n,$d) = @_;
  my ($x,$y) = (0,0);
  my $s = 1; # 1,2,4,8,...
  my $t = $d;
  while ($s<$n) {
    # identify which quadrant ...
    my $rx = 1 & ($t>>1); # 1st or 2nd half
    my $ry = 1 & ($t ^ $rx); # 
    #printf "(x,y)=(%g,%g) rx=%g, ry=%g\n",$x,$y,$rx,$ty;

    ($x,$y) = &rot($s,$x,$y,$rx,$ry);
    $x += $s * $rx;
    $y += $s * $ry;
    $t >>= 2 ;
    $s <<= 1;
  }
  return ($x,$y);
}
# ----------------------------------------------------
sub xy2d { # not working
  use integer;
  my ($n,$x,$y) = @_;
  my $d = 0;
  my $s = $n/2;
  while ($s>0) {
    my $rx = $x & $s > 0;
    my $ry = $y & $s > 0;
    $d += $s * $s * (3 * $rx) ^$ry;
    ($x,$y) = &rot($s,$x,$y,$rx,$ry);
    $s /=2;
  }
  return $d;
}
# an other approach :
# see http://my.safaribooksonline.com/book/information-technology-and-software-development/0201914654/hilbert-curve/ch14lev1sec4
# 14-4. Incrementing the Coordinates on the Hilbert Curve
# 
# Given the (x, y) coordinates of a point on the order n Hilbert curve,
# how can one find the coordinates of the next point? One way is to convert
# (x, y) to s, add 1 to s, and then convert the new value of s back to
# (x, y), using algorithms given above.

# A slightly (but not dramatically) better way is based on the fact that as
# one moves along the Hilbert curve, at each step either x or y, but not
# both, is either incremented or decremented (by 1). The algorithm to be
# described scans the coordinate numbers from left to right to determine
# the type of U-curve that the rightmost two bits are on. Then, based on
# the U-curve and the value of the rightmost two bits, it increments or
# decrements either x or y.
# ----------------------------------------------------
# rotate a quadrant
sub rot {
  my ($n,$x,$y,$rx,$ry) = @_;
  if ($ry == 0) {
    if ($rx == 1) {
      $x = $n - 1 - $x;
      $y = $n - 1 - $y;
    }
    ($x,$y) = ($y,$x);
  }
  return ($x,$y);
}
# ----------------------------------------------------

sub signed {
  no strict 'refs';
  printf "prog: %s\n",$0;
  open $0,'<',$0 or die $!; binmode($0);
  local$/ = undef; my $code = <$0>; close $0;
  printf "code: %s\n",substr($code,0,80);
  my $git = &githash($code);
  my $md5 = &md5hash($git,@_);
  printf "githash %s\n",$git;
  printf "md5 sig: %s\n",$md5;
  printf "signature: %s\n",@_;
  return 1;
}

sub camel {
  #use re 'debug';
  my $str = $_[0];
  $str =~ s/(?:www|http|com)/ /igo; # certain names
  $str =~ s/[^a-z0-9#]/ /igo; # remove all odd char
  $str =~ s/\s*(.)([^ ]*)/\u$1\L$2\E/go;
  return $str; 
}
# ----------------------------------------------------
sub nonl {
  my $s = shift;
  $s =~ s/\s*\r?\n/\\n/g;
  return $s;
}
# ------------------------
sub md5hash {
 my $txt = join'',@_;
 use Digest::MD5 qw();
 my $msg = Digest::MD5->new() or die $!;
    $msg->add($txt);
 my $digest = lc( $msg->hexdigest() );
 return $digest; #hex form !
}
# ------------------------
sub githash {
 my $txt = join'',@_;
 use Digest::SHA1 qw();
 my $msg = Digest::SHA1->new() or die $!;
    $msg->add(sprintf "blob %u\0",length($txt));
    $msg->add($txt);
 my $digest = lc( $msg->hexdigest() );
 return $digest; #hex form !
}
# ------------------------
sub mhash { # multihash
 use Digest;
 my $hcode = shift;
 my $state = pack('F*',@_);

 if ($hcode == $mhc{'ipfs'}) {
   my $header = sprintf'0x%04x',$mhc{'ipfs'};
   use Encode::Base58::GMP;
   my $msg = Digest->new('SHA-256');
   $msg->add($state);
   my $sha2 = $msg->hexdigest();
   my $mhash58 = encode_base58(Math::BigInt->from_hex($header.$sha2),'bitcoin');
   return $mhash58;

 } elsif ($hcode == $mhc{'id7'}) {
   my $git = &githash($state);
   my $id7 = hex(substr($git,0,7));
   return $id7;

 } elsif ($hcode == $mhc{'id13'}) {
   my $git = &githash($state);
   my $id13 = hex(substr($git,0,13));
   return $id13;

 } else {
   my $git = &githash($state);
   return $git;
 }
}
sub state {
 my $index = shift;
 my $statename = &word13($index);
 $statename =~ y/\&"':*?/n__.../; # remove special char for filename
 return $statename;
}
# ------------------------
sub base26 {
  use integer;
  my $n = shift;
  my $e = '';
  #return('a') if $n == 0;
  while ( $n ) {
    my $c = $n % 26;
    $e .=  chr(0x61 + $c); # 0x41: upercase, 0x61: lowercase
    $n = int $n / 26;
  }
  return $e; # scalar reverse $e;
}
# ------------------------
# PassPhrase and WordList
# ---------------------------------------------------------
sub word25 { # 20^4 * 6^3 words (25bit worth of data ...)
 my $n = $_[0];
 my $vo = [qw ( a e i o u y )]; # 6
 my $cs = [qw ( b c d f g h j k l m n p q r s t v w x z )]; # 20
 my $str = '';
 while ($n >= 20) {
   my $c = $n % 20;
      $n /= 20;
      $str .= $cs->[$c];
   my $c = $n % 6;
      $n /= 6;
      $str .= $vo->[$c];
 }
 $str .= $cs->[$n];
 return $str; 
}
# ---------------------------------------------------------
# "inverse speaker ameliorate floated platypuses yearns conjugate nullified"
our @wordlist = ();
sub word11 {
  my $i = shift;
  my $nw = scalar @wordlist;
  if ($nw < 1) {
    my $dico = 'c:\usr\etc\SKEY2048.txt';
    print "loading $dico\n";
    local *DIC; open DIC,'<',$dico or die $!;
    local $/ = "\n"; our @wordlist = map { chomp($_); $_ } <DIC>;
    close DIC;
    $nw = scalar @wordlist;
  }
  return $wordlist[$i%$nw];
}
our @diceware = ();
sub word13 { # a word from Diceware list
  my $i = shift;
  my $dw = scalar @diceware;
  if ($dw < 1) {
    my $dico = $SITE.'\etc\Diceware7776.txt';
    local *DIC; open DIC,'<',$dico or die "$dico $!";
    local $/ = "\n"; our @diceware = map { chomp($_); $_ } <DIC>;
    close DIC;
    $dw = scalar @diceware;
  }
  return $diceware[$i%$dw];
}
our @places = ();
sub place12 { # a place from Places in Switzerland List
  my $i = shift;
  my $np = scalar @places;
  if ($np < 1) {
    my $list = $SITE.'\etc\Places3750.txt';
    local *LST; open LST,'<',$list or die "$list $!";
    local $/ = "\n"; our @places = map { chomp($_); $_ } <LST>;
    close LST;
    $np = scalar @places;
  }
  return $places[$i%$np];
}

# -------------------------------
# pick the i'th word from a file
# (in a cache friendly way) ...
sub word {
  my $dico = shift;
  my $i = $_[0];
  close DIC if ($i < 0);
  my $nw = scalar @wordlist;
  my $cpl = 1;
  if (*DIC) {
    local *DIC; open DIC,'<',$dico or die $!;
    #collect stats ...
    $cpl = 6;
  }
  #seek(DIC,$i*$cpl);
  my $w = <DIC>;
  #TBC ...
  return $w;
}
# -------------------------------

# ----------------------------------------------------
sub rational {
  my $q = $_[0];
  $q = 1/$q if ($q > 1); # q need to be in [0..1]
  # look for (n,d) 3 ZZ  / q = n/d
  my ($n,$d) = (1,1);
  my ($nmin,$nmax) = (0,1);
  my ($dmin,$dmax) = (1,1);
  my $rmin = 1; my $preci = 1/(1<<32-1);
  my $f = 0;
  while (1) {
    $f++;
    # median fraction :
    my ($nmed,$dmed) = ($nmin+$nmax,$dmin+$dmax);
    if ($dmed > 1024) { # stop if too deep in the tree ...
     ($n,$d) = ($nmed,$dmed); last;
    }
    # reminder
   my $rem = $q - $nmed/$dmed;
   if (abs($rem) <= $rmin) { # store the best so far ...
     #printf "rem=%f (precision=%g)\n",$rem,$preci;
     $rmin = abs($rem);
     ($n,$d) = ($nmed,$dmed);
   }
   if ($rem > $preci) { # update 
     ($nmin,$dmin) = ($nmed,$dmed);
   } elsif ($rem < -$preci) {
     ($nmax,$dmax) = ($nmed,$dmed);
   } else {
     last;
   }
  }
 return ($n,$d);

}
# ----------------------------------------------------
1; #$Source: /my/perl/module/from/Provence/PROV.pm,v $

__DATA__

