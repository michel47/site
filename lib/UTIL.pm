#!/usr/bin/perl

# Note:
#   This work has been done during my time at AHE
# 
# -- Copyright GCM, 2016,2017,2018,2019 --
# 


package UTIL;
require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
#@EXPORT_OK = qw(nickname);
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};

use strict;

if (exists $ENV{M4GC_PATH}) {
  use lib $ENV{M4GC_PATH}.'/lib';
} else {
  use lib $ENV{HOME}.'/.iphs/lib'; # require HOME Env. variable
}

if (! exists $ENV{TZ}) {
my %time_zones = (
   EST => '-0500',
   PST => '-0800',
   PDT => '-0700',
);
   $ENV{'TZ'} = 'B'; # Bravo time zone UTC+2
   $ENV{'TZ'} = 'America/New_York';
   $ENV{'TZ'} = 'PST2PDT';
   $ENV{'TZ'} = 'EST'; 
   $ENV{'TZ'} = 'CET'; # Central Europe
   if (-e '/dev/null') {
     eval "use POSIX qw(tzset);";
     tzset(); # no tzset in windows
   }
}

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
our $fdow = &fdow($^T);
# -----------------------------------------------------------------------
our $wordlists = {};
our $DICT = '';
    $DICT = (exists $ENV{DICT}) ? $ENV{DICT} : '../etc'; # '/usr/share/dict';


# -----------------------------------------------------------------------
sub flush { my $h = select($_[0]); my $af=$|; $|=1; $|=$af; select($h); }
# -----------------------------------------------------------------------

# =======================================================================
if (__FILE__ eq $0) {

}
# =======================================================================

# -----------------------------------------------------------------------
sub nonl {
  my $buf = $_[0];
  $buf =~ s/\\n/\\\\n/g;
  $buf =~ s/\n/\\n/g;
  return $buf;
}
sub nl {
  my $buf = $_[0];
  $buf =~ s/\\\\n/{55799-ds}/g;
  $buf =~ s/\\n/\n/g;
  $buf =~ s/{55799-ds}/\\n/g;
  return $buf;
}
# -----------------------------------------------------------------------
sub enc { # replace special char with \{hex} code
 my $buf = shift;
 #$buf =~ tr/\000-\034\134\177-\377//d;
 #$buf =~ s/\</\&lt;/g; # XML safe !
 $buf =~ s/([\000-\032\`\<\>\177-\377])/sprintf('\\%02x',ord($1))/eg; # \xFF-ize
 return $buf;
}
sub urlenc {
 my $buf = shift;
 #$buf =~ tr/\000-\034\134\177-\377//d;
 #$buf =~ s/\</\&lt;/g; # XML safe !
 $buf =~ s/([\000-\032\`%?&\<\( \)\>\177-\377])/sprintf('%%%02X',ord($1))/eg; # html-ize (urlencoded)
 return $buf;
}
sub urldec {
 my $buf = shift;
 $buf =~ s/\+/ /g;
 $buf =~ s/%(..)/chr($1)/eg; # unhtml-ize (urldecoded)
 return $buf;
}
# -----------------------------------------------------------------------
sub get_url {
   my $url = shift;
   use LWP::Simple qw(get);
   my $content = get $url;
   warn "Couldn't get $url" unless defined $content;
   return $content;
}
# -----------------------------------------------------------------------
sub encode_base10 {
  use Math::BigInt;
  use Encode::Base58::BigInt qw();
  my $bin = join'',@_;
  my $bint = Math::BigInt->from_bytes($bin);
  return $bint;
}
sub decode_base10 {
  use Math::BigInt;
  my $i = $_[0];
  my $bin = Math::BigInt->new($i)->as_bytes();
  return $bin;
}
# -----------------------------------------------------------------------
sub encode_base58f { # flickr
  use Math::BigInt;
  use Encode::Base58::BigInt qw();
  my $bin = join'',@_;
  my $bint = Math::BigInt->from_bytes($bin);
  my $h58 = Encode::Base58::BigInt::encode_base58($bint);
  return $h58;
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
# --------------------------------------------
sub decode_base58 {
  use Math::BigInt;
  use Encode::Base58::BigInt qw();
  my $s = $_[0];
  # $e58 =~ tr/a-km-zA-HJ-NP-Z/A-HJ-NP-Za-km-z/;
  $s =~ tr/A-HJ-NP-Za-km-z/a-km-zA-HJ-NP-Z/;
  my $bint = Encode::Base58::BigInt::decode_base58($s);
  my $bin = Math::BigInt->new($bint)->as_bytes();
  return $bin;
}
# --------------------------------------------
sub encode_baser {
  use Math::BigInt;
  my ($d,$radix) = @_;
  my $n = Math::BigInt->from_bytes($d);
  my @e = ();
  while ($n->bcmp(0) == +1)  {
    my $c = Math::BigInt->new();
    my ($n,$c) = $n->bdiv($radix);
    push @e, $c->numify;
  }
  return reverse @e;
}
# ---------------------------------------------------------
sub decode_baser (\@$) {
  use Math::BigInt;
  my ($s,$radix) = @_;
  my $n = Math::BigInt->new(0);
  my $j = Math::BigInt->new(1);
  foreach my $i (reverse @$s) { # for all digits
    return '' if ($i < 0);
    my $w = $j->copy();
    $w->bmul($i);
    $n->badd($w);
    $j->bmul($radix);
  }
  my $d = $n->as_bytes();
  return $d;

  # my $h = $n->as_hex();
  ## byte alignment ...
  #my $d = int( (length($h)+1-2)/2 ) * 2;
  #$h = substr('0' x $d . substr($h,2),-$d);
  #return pack('H*',$h);
}
# -----------------------------------------------------------------------
sub encode_basex ($\@) {
  use Math::BigInt;
  my ($d,@radix) = @_;
  my $n = Math::BigInt->from_bytes($d);
  my @e = ();
  while (@radix) {
    my $radix = shift @radix;
    my $c = Math::BigInt->new();
    my ($n,$c) = $n->bdiv($radix);
    push @e, $c->numify;
  }
  return @e; # /!\ not reverse
}
# -----------------------------------------------------------------------
sub decode_basex (\@\@) {
  use Math::BigInt;
  my ($s,@radix) = @_;
  # TBD
  return undef;
}
# -----------------------------------------------------------------------
sub hashr {
   my $alg = shift;
   my $rnd = shift; # number of round to run ...
   my $tmp = join('',@_);
   use Crypt::Digest qw();
   my $msg = Crypt::Digest->new($alg) or die $!;
   for (1 .. $rnd) {
      $msg->add($tmp);
      $tmp = $msg->digest();
      $msg->reset;
      #printf "#%d tmp: %s\n",$_,unpack'H*',$tmp;
   }
   return $tmp
}
# ---------------------------------------------------------------------------
# 0.........1.........2.........3.........4.........5.........6.........7
# .1...5...9.1...5...9.1...5...9.1...5...9.1...5...9.1...5...9.1...5...9.1...
# 0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz
# 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+/= b64
# 0123456789abcdefghijklmnopqrstuvwxyz-_.!
sub base12 {
  use integer;
  my ($n) = @_;
  my $e = '';
  return(' ') if $n == 0;
  while ( $n ) {
    my $c = $n % 12;
    $e .=  chr(0x30 + $c); # 0x30: 0 included
    $n = int $n / 12;
  }
  $e =~ y/0-9:;/0-9XE/;
  return scalar reverse $e;
}
sub ubase12 { # number + [ATX] & [BE]
  my ($s) = @_;
  $s =~ y/ATXBE/AAABB/;
  $s =~ y/0-9AB/0-9:;/;
  my $n = 0;
  while ($s ne '') {
    my $c = substr($s,0,1,'');
    my $v = ord($c) - 0x30;
    #print "{c:$c}{v:$v}{n:$n}\n";
    $n *= 12; $n += $v;
  }
  return $n;
}
# -----------------------------------------------------------------------
# ABCDEFGHIJKLMNOPQRSTUVWXYZ
# 23456789CFGHJMPQRVWX 
sub base20 { # 23456789CFGHJMPQRVWX 
  use integer;
  my $n = shift;
  my $e = '';
  #return('a') if $n == 0;
  while ( $n ) { 
    my $c = $n % 20;
    $e .=  chr(0x41 + $c); # 0x41: upercase, 0x61: lowercase
    $n = int $n / 20;
  }
  $e =~ y/A-T/2-9CFGHJMPQRVWX/;
  return $e; # scalar reverse $e;
}
sub ubase20 {
  my ($s) = @_;
  $s =~ y/2-9CFGHJMPQRVWX/A-T/;
  my $n = 0;
  while ($s ne '') {
    my $c = substr($s,0,1,'');
    my $v = ord($c) - 0x41;
    #print "{c:$c}{v:$v}{n:$n}\n";
    $n *= 20; $n += $v;
  }
  return $n;
}
# -----------------------------------------------------------------------
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
# -----------------------------------------------------
sub base28 { # letters + ', '
  use integer;
  my ($n) = @_;
  my $e = '';
  return(' ') if $n == 0;
  while ( $n ) {
    my $c = $n % 28;
    $e .=  chr(0x30 + $c); # 0x30: 0 included
    $n = int $n / 28;
  }
  $e =~ y/0-K/ a-z,/;
  return scalar reverse $e;
}
sub ubase28 {
  my ($s) = @_;
  $s =~ y/ a-z,/0-K/;
  my $n = 0;
  while ($s ne '') {
    my $c = substr($s,0,1,'');
    my $v = ord($c) - 0x30;
    #print "{c:$c}{v:$v}{n:$n}\n";
    $n *= 28; $n += $v;
  }
  return $n;
}
# -----------------------------------------------------
sub base36 { # letters and numbers
  use integer;
  my ($n) = @_;
  my $e = '';
  return('0') if $n == 0;
  while ( $n ) {
    my $c = $n % 36;
    $e .=  ($c<=9)? $c : chr(0x37 + $c); # 0x37: upercase, 0x57: lowercase
    $n = int $n / 36;
  }
  return scalar reverse $e;
}
# -----------------------------------------------------
sub base37 { # letters + numbers + .
  use integer;
  my $n = shift;
  my $e = '';
  #return('a') if $n == 0;
  while ( $n ) {
    my $c = $n % 37;
    $e .=  ($c<=9)? $c : chr(0x37 + $c); # 0x37: upercase, 0x57: lowercase
    $n = int $n / 37;
  }
  return $e; # scalar reverse $e;
}
# -----------------------------------------------------
sub base40 { # 36 letter & digit + 4 char
  use integer;
  my ($n) = @_;
  my $e = '';
  return('0') if $n == 0;
  while ( $n ) {
    my $c = $n % 40;
    $e .=  chr(0x30 + $c); # 0x30: 0 included
    $n = int $n / 40;
  }
  $e =~ y/0-W/0-9a-z\-_.!/;
  return $e; # scalar reverse $e;
}
# -----------------------------------------------------
sub basen { # int -> str, radix <= 43; 
  use integer;
  my ($n,$radix) = @_;
  my $e = '';
  return('0') if $n == 0;
  while ( $n ) {
    my $c = $n % $radix;
    $e .=  chr(0x30 + $c); # 0x30: 0 included
    $n = int $n / $radix;
  }
  if ($radix <= 35) {
     $e =~ y/0-R/A-Z1-9/
  } elsif ($radix <= 40) {
     $e =~ y/0-W/0-9a-z\-_.!/
  } elsif ($radix <= 43) {
     $e =~ y/0-Z/0-9A-Z+\-$.% */;
  } elsif ($radix <= 58) {
    $e =~ y/0-i/1-9A-HJ-NP-Za-km-z/;
  } elsif ($radix <= 64) {
    $e =~ y,0-o,0-9A-Za-z+/,;
  }
  return scalar reverse $e;
}
# -----------------------------------------------------------------------
sub encode_base32 {
  use MIME::Base32 qw();
  my $mh32 = uc MIME::Base32::encode($_[0]);
  return $mh32;
}
sub decode_base32 {
  use MIME::Base32 qw();
  my $bin = MIME::Base32::decode($_[0]);
  return $bin;
}
# ---
sub encode_base32z {
  use MIME::Base32 qw();
  my $z32 = uc MIME::Base32::encode($_[0]);
  $z32 =~ y/A-Z2-7/ybndrfg8ejkmcpqxotluwisza345h769/;
  return $z32;
}
sub decode_base32z {
  use MIME::Base32 qw();
  my $b32 = $_[0];
  $b32 =~ y/ybndrfg8ejkmcpqxotluwisza345h769/A-Z2-7/;
  my $bin = MIME::Base32::decode($b32);
  return $bin;
}
sub encode_base64m {
  use MIME::Base64 qw();
  my $m64 = MIME::Base64::encode_base64($_[0],'');
  return $m64;
}
sub decode_base64m {
  use MIME::Base64 qw();
  my $bin = MIME::Base64::decode_base64($_[0]);
  return $bin;
}


sub encode_base64u {
  use MIME::Base64 qw();
  my $u64 = MIME::Base64::encode_base64($_[0],'');
  $u64 =~ y,+/,-_,;
  return $u64;
}
# ----------------------------------
sub encode_base42 { # for barcode
  use Math::BigInt;
  my ($data,$alphab) = @_;
  $alphab = '123456789ABCDEFGHJKLMNPQRSTUVWXYZ -+.$%' unless $alphab; # barcode 3 to 9
  my $radix = Math::BigInt->new(length($alphab));
  my $n = Math::BigInt->from_bytes($data);
  my $e = '';
  while ($n->bcmp(0) == +1)  {
    my $c = Math::BigInt->new();
    ($n,$c) = $n->bdiv($radix);
    $e .= substr($alphab,$c->numify,1);
  }
  return scalar reverse $e;
}
# ----------------------------------
sub decode_basea { # passing an alphabet ...
  use Math::BigInt;
  my ($s,$alphab) = @_;
  $alphab = '123456789ABCDEFGHJKLMNPQRSTUVWXYZ -+.$%' unless $alphab; # barcode 3 to 9
  my $radix = Math::BigInt->new(length($alphab));
  my $n = Math::BigInt->new(0);
  my $j = Math::BigInt->new(1);
  while($s ne '') {
    my $c = substr($s,-1,1,''); # consume chr from the end !
    my $i = index($alphab,$c);
    return '' if ($i < 0);
    my $w = $j->copy();
    $w->bmul($i);
    $n->badd($w);
    $j->bmul($radix);
  }
  my $h = $n->as_hex();
  # byte alignment ...
  my $d = int( (length($h)+1-2)/2 ) * 2;
  $h = substr('0' x $d . substr($h,2),-$d);
  return pack('H*',$h);
}
# ----------------------------------
sub encode_base63 {
  return &encode_basen($_[0],63);
}
sub decode_base63 {
  return &decode_basen($_[0],63);
}
# -----------------------------------------------------------------------
sub encode_basen { # n < 94;
  use Math::BigInt;
  my ($data,$radix) = @_;
  my $alphab = &alphab($radix);;
  my $mod = Math::BigInt->new($radix);
  #printf "mod: %s, lastc: %s\n",$mod,substr($alphab,$mod,1);
  my $h = '0x'.unpack('H*',$data);
  my $n = Math::BigInt->from_hex($h);
  my $e = '';
  while ($n->bcmp(0) == +1)  {
    my $c = Math::BigInt->new();
    ($n,$c) = $n->bdiv($mod);
    $e .= substr($alphab,$c->numify,1);
  }
  return scalar reverse $e;
}
# ---------------------------
sub decode_basen { # n < 94
  use Math::BigInt;
  my ($s,$radix) = @_;
  my $alphab = &alphab($radix);;
  die "alphab: %uc < %d\n",length($alphab) if (length($alphab) < $radix);
  my $n = Math::BigInt->new(0);
  my $j = Math::BigInt->new(1);
  while($s ne '') {
    my $c = substr($s,-1,1,''); # consume chr from the end !
    my $i = index($alphab,$c);
    return '' if ($i < 0);
    my $w = $j->copy();
    $w->bmul($i);
    $n->badd($w);
    $j->bmul($radix);
  }
  my $h = $n->as_hex();
  # byte alignment ...
  my $d = int( (length($h)+1-2)/2 ) * 2;
  $h = substr('0' x $d . substr($h,2),-$d);
  return pack('H*',$h);
}
# ---------------------------------------------------------
sub alphab {
  my $radix = shift;
  my $alphab;
  if ($radix < 12) {
    $alphab = '0123456789-';
  } elsif ($radix <= 16) {
    $alphab = '0123456789ABCDEF';
  } elsif ($radix <= 26) {
    $alphab = 'ABCDEFGHiJKLMNoPQRSTUVWXYZ';
  } elsif ($radix == 32) {
    $alphab = '0123456789ABCDEFGHiJKLMNoPQRSTUV'; # Triacontakaidecimal
    $alphab = join('',('A' .. 'Z', '2' .. '7')); # RFC 4648
    $alphab = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; # Crockfordś ![ILOU] (U:accidental obscenity)
    $alphab = 'ybndrfg8ejkmcpqxotluwisza345h769';  # z-base32 ![0lv2]

  } elsif ($radix == 36) {
    $alphab = 'ABCDEFGHiJKLMNoPQRSTUVWXYZ0123456789'; 
  } elsif ($radix <= 38) {
    $alphab = '0123456789ABCDEFGHiJKLMNoPQRSTUVWXYZ.-'; 
  } elsif ($radix <= 40) {
    $alphab = 'ABCDEFGHiJKLMNoPQRSTUVWXYZ0123456789-_.+';
  } elsif ($radix <= 43) {
    $alphab = 'ABCDEFGHiJKLMNoPQRSTUVWXYZ0123456789 -+.$%*';
  } elsif ($radix == 58) {
    $alphab = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  } elsif ($radix == 62) {
    $alphab = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  } else { # n < 94
    $alphab = '-0123456789'. 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
                             'abcdefghijklmnopqrstuwvxyz'.
             q/+.@$%_,~`'=;!^[]{}()#&/.      '<>:"/\\|?*'; #
  } 
  # printf "// alphabet: %s (%uc)\n",$alphab,length($alphab);
  return $alphab;
}
# -----------------------------------------------------------------------
sub copy ($$) {
 my ($src,$trg) = @_;
 local *F1, *F2;
 return undef unless -r $src;
 return undef if (-e $trg && ! -w $trg);
 open F2,'>',$trg or die "-w $trg $!"; binmode(F2);
 open F1,'<',$src or warn "-r $src $!"; binmode(F1);
 local $/ = undef;
 my $tmp = <F1>; print F2 $tmp;
 close F1;

 my ($atime,$mtime,$ctime) = (lstat(F1))[8,9,10];
 #my $etime = ($mtime < $ctime) ? $mtime : $ctime;
 utime($atime,$mtime,$trg);
 close F2;
 return $?;
}
# -----------------------------------------------------------------------
sub dhash {
   my $alg = shift;
   use Digest qw();
   my $msg = Digest->new($alg) or die $!;
   $msg->add(join'',@_);
   my $hash = $msg->digest();
   $msg->reset;
   $msg->add($hash);
   $hash = $msg->digest();
   return $hash;
}
# -----------------------------------------------------
sub hashr {
   my $alg = shift;
   my $rnd = shift; # number of round to run ...
   my $tmp = join('',@_);
   use Crypt::Digest qw();
   my $msg = Crypt::Digest->new($alg) or die $!;
   for (1 .. $rnd) {
      $msg->add($tmp);
      $tmp = $msg->digest();
      $msg->reset;
      #printf "#%d tmp: %s\n",$_,unpack'H*',$tmp;
   }
   return $tmp
}
# -----------------------------------------------------
sub shake { # use shake 128
  use Crypt::Digest::SHAKE;
  my $len = shift;
  my $x = ($len >= 160) ? 256 : 128;
  my $msg = Crypt::Digest::SHAKE->new($x);
  $msg->add(join'',@_);
  my $digest = $msg->done(($len+7)/8);
  return $digest;
}
# -----------------------------------------------------
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
# -----------------------------------------------------
sub digest ($@) {
 my $alg = shift;
 use Digest qw();
 my $msg = Digest->new($alg) or die $!;
    $msg->add(join'',@_);
 my $digest = $msg->digest();
 return $digest; #bin form !
}
# -----------------------------------------------------
sub get_digest ($@) {
 my $alg = shift;
 my $ns = (scalar @_ == 2) ? shift : undef;
 use Digest qw();
 local *F; open F,$_[0] or do { warn qq{"$_[0]": $!}; return undef };
 binmode F unless $_[0] =~ m/\.txt/;
 my $msg = Digest->new($alg) or die $!;
    $msg->add($ns) if defined $ns;
    $msg->addfile(*F);
 my $digest = uc( $msg->hexdigest() );
 return $digest; #hex form !
}
# -----------------------------------------------------
sub githash {
 use Digest::SHA1 qw();
 local *F = shift; seek(F,0,0);
 my $msg = Digest::SHA1->new() or die $!;
    $msg->add(sprintf "blob %u\0",(lstat(F))[7]);
    $msg->addfile(*F);
 my $digest = lc( $msg->hexdigest() );
 return $digest; #hex form !
}
# -----------------------------------------------------
sub get_digestf ($@) {
 my $alg = shift;
 my $ns = (scalar @_ == 2) ? shift : undef;
 use Crypt::Digest qw();
 my $F = shift; seek($F,0,0);
 my $msg = Crypt::Digest->new($alg) or die $!;
    $msg->add($ns) if defined $ns;
    $msg->addfile($F);
 my $digest = $msg->digest();
 return $digest; #bin form !
}
# -----------------------------------------------------
sub get_qmhash { # IPFS' cidv0 : 
   my $algo = shift;
   my $mhfncode = { 'SHA256' => 0x12, 'SHA1' => 0x11, 'MD5' => 0xd5, 'ID' => 0x00, 'GIT' => 0x11};
   my $mhfnsize = { 'SHA256' => 256, 'GIT' => 160, 'MD5' => 128};
   local *F; open F,$_[0] or do { warn qq{"$_[0]": $!}; return undef };
   binmode F unless $_[0] =~ m/\.txt/;
   local $/ = undef; my $msg = <F>; close F;
   my $data = &qmcontainer($msg);
   my $hash = undef;
   if ($algo eq 'GIT') {
     my $hdr = sprintf 'blob %u\0',length($data);
     $hash = &hashr($algo,1,$hdr,$data);
   } else {
     $hash = &hashr($algo,1,$data);
   }
   my $mh = pack'C',$mhfncode->{$algo}; # 0x12; 
   my $hsize = $mhfnsize->{$algo}/8; # 256/8
   my $mhash = join'',$mh,&varint($hsize),substr($hash,0,$hsize);
   return $mhash;

}
sub qmcontainer {
   my $msg = shift;
   my $msize = length($msg);
   my $payload = sprintf '%s%s',pack('C',(1<<3|0)),&varint(2); #f1.t0 : 2
       $payload .= sprintf '%s%s%s',pack('C',(2<<3|2)),&varint($msize),$msg; # f2.t2: msg
       $payload .= sprintf '%s%s',pack('C',(3<<3|0)),&varint($msize); # f1.t0: msize

   my $data = sprintf "%s%s%s",pack('C',(1<<3|2)),&varint(length($payload)),$payload; # f1.t2
   return $data;
}

sub get_qmhashf { # IPFS' cidv0 : 
#   f1=id: t0=varint
#   f2=data: t2=string  { Data1: { f1 Data2 Tsize3 }}

   my $algo = shift;
   my $mhfncode = { 'SHA256' => 0x12, 'SHA1' => 0x11, 'MD5' => 0xd5, 'ID' => 0x00, 'GIT' => 0x11};
   my $mhfnsize = { 'SHA256' => 256, 'GIT' => 160, 'MD5' => 128};
   local *F = shift; seek(F,0,0); local $/ = undef;
   my $msg = <F>;
   my $data = &qmcontainer($msg);
   my $mh = pack'C',$mhfncode->{$algo}; # 0x12; 
   my $hsize = $mhfnsize->{$algo}/8; # 256/8
   my $hash = undef;
   if ($algo eq 'GIT') {
     my $hdr = sprintf 'blob %u\0',length($data);
     $hash = &hashr($algo,1,$hdr,$data);
   } else {
     $hash = &hashr($algo,1,$data);
   }
   my $mhash = join'',$mh,&varint($hsize),substr($hash,0,$hsize);
   return $mhash;
}
# -----------------------------------------------------
# protobuf container :
#   f1=id: t0=varint
#   f2=data: t2=string
sub qmhash {
   my $algo = shift;
   my $msg = shift;
   my $msize = length($msg);
   my $mhfncode = { 'SHA256' => 0x12, 'SHA1' => 0x11, 'MD5' => 0xd5, 'ID' => 0x00};
   my $mhfnsize = { 'SHA256' => 256, 'GIT' => 160, 'MD5' => 128};
   
   
   #printf "msize: %u (%s)\n",$msize,unpack'H*',&varint($msize);
   printf "msg: %s%s\n",substr(&enc($msg),0,76),(length($msg)>76)?'...':'' if $dbug;
   # QmPa5thw8vNXH7eZqcFX8j4cCkGokfQgnvbvJw88iMJDVJ
   # 00000000: 0a0e 0802 1208 6865 6c6c 6f20 210a 1808  ......hello !...
   # {"Links":[],"Data":"\u0008\u0002\u0012\u0008hello !\n\u0018\u0008"}
   # 0000_1010 : f1.t2 size=14 (0a0e)
   # payload: 0802_1208 ... 1808
   #          0000_1000 : f1.t0 varint=2 (0802)
   #          0001_0010 : f2.t2 size=8 ... (1208 ...)
   #          0001_1000 : f3.t0 varint=8 (1808)
   my $payload = sprintf '%s%s',pack('C',(1<<3|0)),&varint(2);
   $payload .= sprintf '%s%s%s',pack('C',(2<<3|2)),&varint($msize),$msg;

   $payload .= sprintf '%s%s',pack('C',(3<<3|0)),&varint($msize);
   # { Data1: { f1 Data2 Tsize3 }}


   printf "payload: %s%s\n",unpack('H*',substr($payload,0,76/2)),((length($payload)>76/2)?'...':'') if $dbug;
   my $data = sprintf "%s%s%s",pack('C',(1<<3|2)),&varint(length($payload)),$payload;

   my $mh = pack'C',$mhfncode->{$algo}; # 0x12; 
   my $hsize = $mhfnsize->{$algo}/8; # 256/8
   my $hash = undef;
   if ($algo eq 'GIT') {
     my $hdr = sprintf 'blob %u\0',length($data);
     $hash = &hashr($algo,1,$hdr,$data);
   } else {
     $hash = &hashr($algo,1,$data);
   }
   my $mhash = join'',$mh,&varint($hsize),substr($hash,0,$hsize);
   printf "mh16: %s\n",unpack'H*',$mhash if $dbug;
   my $add = 0;
   if ($add) { # adding file to the repository
      my $mh32 = uc&encode_base32($mhash);
      # printf "MH32: %s\n",$mh32;
      if (exists $ENV{IPFS_PATH}) {
         my $split = substr($mh32,-3,2);
         my $objfile = sprintf '%s/blocks/%s/%s.data',$ENV{IPFS_PATH},$split,$mh32;
         if (! -e $objfile) { # create the record ... i.e. it is like adding it to IPFS !
            printf "%s created !\n",$objfile if $dbug;
            local *F; open F,'>',$objfile; binmode(F);
            print F $data; close F;
         } else {
            printf "-e %s\n",$objfile if $dbug;
         }
      }
   }
   my $cidv0 = &encode_base58($mhash);
   return $cidv0;
}
# -----------------------------------------------------
sub varint {
  my $i = shift;
  my $bin = pack'w',$i; # Perl BER compressed integer
  # reverse the order to make is compatible with IPFS varint !
  my @C = reverse unpack("C*",$bin);
  # clear msb on last nibble
  my $vint = pack'C*', map { ($_ == $#C) ? (0x7F & $C[$_]) : (0x80 | $C[$_]) } (0 .. $#C);
  return $vint;
}
# -----------------------------------------------------
sub uvarint {
  my $vint = shift;
  # reverse the order to make is compatible with perl's BER int !
  my @C = reverse unpack'C*',$vint;
  # msb = 1 except last
  my $wint = pack'C*', map { ($_ == $#C) ? (0x7F & $C[$_]) : (0x80 | $C[$_]) } (0 .. $#C);
  my $i = unpack'w',$wint;
  return $i;
}
# -----------------------------------------------------
sub fname { # extract filename etc...
  my $f = shift;
  $f =~ s,\\,/,g; # *nix style !
  my $s = rindex($f,'/');
  my $fpath = '.';
  if ($s > 0) {
    $fpath = substr($f,0,$s);
  } else {
    use Cwd;
    $fpath = Cwd::getcwd();
  }
  my $file = substr($f,$s+1);

  if (-d $f) {
    return ($fpath,$file);
  } else {
  my $p = rindex($file,'.');
  my ($bname,$ext);
  if ($p > 0) {
    $bname = substr($file,0,$p);
    $ext = lc substr($file,$p+1);
    $ext =~ s/\~$//;
  } else {
    $bname = $file;
    $ext = &get_ext($f);
  }

  $bname =~ s/\s+\(\d+\)$//; # remove (1) in names ...

  return ($fpath,$file,$bname,$ext);

  }
}
# -----------------------------------------------------------------------
sub bname { # extract basename etc...
  my $f = shift;
  $f =~ s,\\,/,g; # *nix style !
  my $s = rindex($f,'/');
  my $fpath = ($s > 0) ? substr($f,0,$s) : '.';
  my $file = substr($f,$s+1);

  if (-d $f) {
    return ($fpath,$file);
  } else {
  my $p = rindex($file,'.');
  my $bname = ($p>0) ? substr($file,0,$p) : $file;
  my $ext = lc substr($file,$p+1);
     $ext =~ s/\~$//;
  
  $bname =~ s/\s+\(\d+\)$//;

  return ($fpath,$bname,$ext);

  }

}
# -----------------------------------------------------------------------
sub get_ext {
  my $file = shift;
  my $ext = $1 if ($file =~ m/\.([^\.]+)/);
  if (! $ext) {
    my %ext = (
    text => 'txt',
    'application/octet-stream' => 'blob',
    'application/x-perl' => 'pl'
    );
    my $type = &get_type($file);
    if (exists $ext{$type}) {
       $ext = $ext{$type};
    } else {
      $ext = ($type =~ m'/(?:x-)?(\w+)') ? $1 : 'ukn';
    }
  }
  return $ext;
}
sub get_type { # to be expended with some AI and magic ...
  my $file = shift;
  use File::Type;
  my $ft = File::Type->new();
  my $type = $ft->checktype_filename($file);
  if ($type eq 'application/octet-stream') {
    my $p = rindex $file,'.';
    if ($p>0) {
     $type = 'files/'.substr($file,$p+1); # use the extension
    }
  }
  return $type;
}
# -----------------------------------------------------------------------
sub hdate { # return HTTP date (RFC-1123, RFC-2822) 
  my ($time,$delta) = @_;
  my $stamp = $time+$delta;
  my $tic = int($stamp);
  #my $ms = ($stamp - $tic)*1000;
  my $DoW = [qw( Sun Mon Tue Wed Thu Fri Sat )];
  my $MoY = [qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec )];
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday) = (gmtime($tic))[0..6];
  my ($yr4,$yr2) =($yy+1900,$yy%100);

  # Mon, 01 Jan 2010 00:00:00 GMT
  my $date = sprintf '%3s, %02d %3s %04u %02u:%02u:%02u GMT',
             $DoW->[$wday],$mday,$MoY->[$mon],$yr4, $hour,$min,$sec;
  return $date;
}
# ---------------------------------------------------------
sub edate { # return date for email (^From line)
  my ($time,$delta) = @_;
  my $stamp = $time+$delta;
  my $tic = int($stamp);
  my $DoW = [qw( Sun Mon Tue Wed Thu Fri Sat )];
  my $MoY = [qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec )];
  my ($sec,$min,$hour,$mday,$mon,$year,$wday) = (localtime($tic))[0..6];

  my $TZ = $ENV{'TZ'} || 'Z';
  my $edate = sprintf "%3s %3s %2d %02d:%02d %3s %4d",
         $DoW->[$wday],$MoY->[$mon],$mday,$hour,$min,$TZ,
         ($year < 70) ? $year + 2000 : $year + 1900;
  return $edate;
}
# -----------------------------------------------------------------------
sub sdate { # return a human readable date ... but still sortable ...
  my $tic = int ($_[0]);
  my $ms = ($_[0] - $tic) * 1000;
     $ms = ($ms) ? sprintf('%04u',$ms) : '____';
  my ($sec,$min,$hour,$mday,$mon,$yy) = (localtime($tic))[0..5];
  my ($yr4,$yr2) =($yy+1900,$yy%100);
  my $date = sprintf '%04u-%02u-%02u %02u.%02u.%02u',
             $yr4,$mon+1,$mday, $hour,$min,$sec;
  return $date;
}
# -----------------------------------------------------------------------
sub fdow {
   my $tic = shift;
   use Time::Local qw(timelocal);
   ##     0    1     2    3    4     5     6     7
   #y ($sec,$min,$hour,$day,$mon,$year,$wday,$yday)
   my $year = (localtime($tic))[5]; my $yr4 = 1900 + $year ;
   my $first = timelocal(0,0,0,1,0,$yr4);
   $fdow = (localtime($first))[6];
   #printf "1st: %s -> fdow: %s\n",&hdate($first),$fdow;
   return $fdow;
}
# -----------------------------------------------------------------------
sub version_old {
  #y ($atime,$mtime,$ctime) = (lstat($_[0]))[8,9,10];
  #y $etime = ($ctime > $mtime) ? ($mtime > $atime) ? $atime : $mtime : $ctime;
  my @times = sort { $a <=> $b } (lstat($_[0]))[9,10]; # ctime,mtime
  my $vtime = $times[-1];

  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime($vtime))[0..7]; # most recent
  printf "%s/%s/%s \@ %d:%02d:%02d\n",$mday,$mon+1,$yy+1900,$hour,$min,$sec if $dbug;
  my $rweek=($yday+&fdow($vtime))/7;
  my $rev_id = int($rweek) * 4;
  my $low_id = int(($wday+($hour/24)+$min/(24*60))*4/7);
  my $version = ($rev_id + $low_id) / 100;
  #   my ($atime,$mtime,$ctime) = (lstat($_[0]))[8,9,10];
  #   print "y:$yday f:$fdow m:$mtime c:$ctime, $mday.$mon.$yy -> rw=$rweek $rev_id $low_id $version\n";

  if (wantarray) {
     my $md6 = &get_digest('MD6',$_[0]);
     print "$_[0] : md6:$md6\n" if $dbug;
     my $pn = hex(substr($md6,-4)); # 16-bit
     my $build = &word($pn);
     return ($version, $build);
  } else {
     return sprintf '%g',$version;
  }
}
# -----------------------------------------------------------------------
sub rname { # extract rootname
  my $rname = shift;
  $rname =~ s,\\,/,g; # *nix style !
  my $s = rindex($rname,'/');
  my $rname = substr($rname,$s+1);
  $rname =~ s/\.[^\.]+//;
  return $rname; 
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
# -----------------------------------------------------------------------
sub rev {
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime($_[0]))[0..7];
  my $rweek=($yday+&fdow($_[0]))/7;
  my $rev_id = int($rweek) * 4;
  my $low_id = int(($wday+($hour/24)+$min/(24*60))*4/7);
  my $revision = ($rev_id + $low_id) / 100;
  return (wantarray) ? ($rev_id,$low_id) : $revision;
}
# -----------------------------------------------------------------------
sub stamp36 {
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime(int $_[0]))[0..7];
  my $_1yr = 365.25 * 24;
  my $yhour = $yday * 24 + $hour + ($min / 60 + $sec / 3600);
  my $stamp = &base36(int($yhour/$_1yr * 36**4)); # 18 sec accuracy
  #print "$yy/$mon/$mday $hour:$min:$sec : $yday HH$yhour\n";
  return $stamp;
}
# -----------------------------------------------------------------------
sub etime {
  my ($atime,$mtime,$ctime) = (lstat($_[0]))[8,9,10];
  my $etime = ($ctime > $mtime) ? ($mtime > $atime) ? $atime : $mtime : $ctime; # pick the earliest
  my $ltime = ($ctime > $mtime) ? $ctime : $mtime; # latest of the two
  return (wantarray) ? ($etime,$ltime) : $etime;
}
# -----------------------------------------------------------------------
sub hex2quint {
  return join '-', map { u16toq ( hex('0x'.$_) ) } $_[0] =~ m/(.{4})/g;
}
sub u32quint {
  my $u = shift;
  #printf "%04x.%04x\n",$u>>16,$u&0xFFFF;
  return u16toq(($u>>16) & 0xFFFF) . '-' . u16toq($u & 0xFFFF);
}
sub u16toq {
   my $n = shift;
  #printf "u2q(%04x) =\n",$n;
   my $cons = [qw/ b d f g h j k l m n p r s t v z /]; # 16 consonants only -c -q -w -x
   my $vow = [qw/ a i o u  /]; # 4 wovels only -e -y
   my $s = '';
      for my $i ( 1 .. 5 ) { # 5 letter words
         if ($i & 1) { # consonant
            $s .= $cons->[$n & 0xF];
            $n >>= 4;
            #printf " %d : %s\n",$i,$s;
         } else { # vowel
            $s .= $vow->[$n & 0x3];
            $n >>= 2;
            #printf " %d : %s\n",$i,$s;
         }
      }
   #printf "%s.\n",$s;
   return scalar reverse $s;
}
# -----------------------------------------------------
# 7c => 31b worth of data ... (similar density than hex)
sub word5 { # 20^4 * 26^3 words (4.5bit per letters)
 use integer;
 my $n = $_[0];
 my $vo = [qw ( a e i o u y )]; # 6
 my $cs = [qw ( b c d f g h j k l m n p q r s t v w x z )]; # 20
 my $a = ord($vo->[0]);
 my $odd = 0;
 my $str = '';
 while ($n > 0) {
   if ($odd) {
   my $c = $n % 20;
   #print "c: $c, n: $n\n";
      $n /= 20;
      $str .= $cs->[$c];
      $odd=0;
   } elsif(1) {
   my $c = $n % 26;
      $n /= 26;
      $str .= chr($a+$c);
      $odd=1;
   #} else {
   #my $c = $n % 6;
   #   $n /= 6;
   #   $str .= $vo->[$c];
   #   odd=undef;
   }
 }
 return $str;
}
# -----------------------------------------------------
sub word { # 20^4 * 6^3 words (25bit worth of data ...)
 use integer;
 my $n = $_[0];
 my $vo = [qw ( a e i o u y )]; # 6
 my $cs = [qw ( b c d f g h j k l m n p q r s t v w x z )]; # 20
 my $str = '';
 if (1 && $n < 26) {
 $str = chr(ord('a') +$n%26);
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
# -----------------------------------------------------------------------
sub loadlist {
   my $wlist = shift;
   my $file;
   my $wordlist = [];
   if (-e $wlist) {
      $file = $wlist;
   } else {
      $DICT = (exists $ENV{DICT} && -d $ENV{DICT}) ? $ENV{DICT} : `secdir`.'/dict'; # '/usr/share/dict';
      $file = sprintf '%s/%s.txt',$DICT,$wlist;
      #printf "DBUG> file: %s\n",$file;
      return undef if (! -e $file);
   }
   local *F; open F,'<',$file or die $!;
   local $/ = "\n"; @$wordlist = map { chomp($_); $_ } grep !/^#/, <F>;
   close F;
   return $wordlist;
}
# -----------------------------------------------------------------------
sub read_file {
  local *F; open F,'<',$_[0];
  local $/ = undef; my $buf = <F>; close F;
  return $buf;
}
# ---------------
sub write_file {
  my $file = shift;
  local *F; open F,'>',$file;
  foreach (@_) {
    print F $_;
  }
  close F;
}
# -----------------------------------------------------------------------
sub get_nickname {
   my $key = shift; 
   $key = &hashr('SHA256',1,$key) if (length($key) > 32);

   use Digest::MurmurHash;
   my $hash = Digest::MurmurHash::murmur_hash($key);
   my $list;
   if (defined $wordlists->{'nicknames'}) {
     $list = $wordlists->{'nicknames'};
   } else {
     $list = &loadlist('nicknames');
     $wordlists->{'nicknames'} = $list;
     #printf "%s.\n",YAML::Syck::Dump($list);
   }
   my $n = scalar(@$list);
   my $nicknames = $list->[$hash%$n];
   return $nicknames;
}
# -----------------------------------------------------------------------
sub get_wordn {
  my ($i,$wlist) = @_;
  if (! exists $wordlists->{$wlist}) {
     $wordlists->{$wlist} = &loadlist($wlist);
  }
  # ------------------------------
  my $wordlist = $wordlists->{$wlist};
  my $wl = scalar @$wordlist;
  return $wordlist->[$i%$wl];
}
# ---------------------------------------------------------
sub color { # 10 colors
  my $colors = [qw{red orange yellow green aquamarine blue violet indigo pink}];
  my $n = scalar(@$colors);
  my $key = int ($_[0]) % $n; # modulo !
  my $color = $colors->[$key];
  return $color;
}
sub flower { # 26 flowers
  my $flowers = [qw{acacia begonia coriander dahlia echinacea foxglove geranium
               hyacinth iris jonquil kurume lavander mimosa narciss ochidea
	       pensea qween_lily rose saffron tulip urn violet wahlenbergia xerophyta yarrow zephyranthes}];
  my $n = scalar(@$flowers);
  my $key = int ($_[0]) % $n; # modulo !
  my $flower = $flowers->[$key];
  return $flower;
}
# -----------------------------------------------------------------------
sub get_firstline { # not really the first line, but line that after the 13th character !
  my $file = shift; local *F; open F,'<',$file;
  seek(F,13,0);
  my $buf; read(F,$buf,80);
  close F;
  $buf =~ m/^.*?\n(.*)\n?/;
  my $firstline = $1;
  #print $firstline; exit -3;
  return $firstline;
}
sub get_lastline { # assumed last line is not over 80chars
  my $file = shift; local *F; open F,'<',$file;
  seek(F,-82,2);
  my $buf; read(F,$buf,82);
  close F;
  $buf =~ m/\s+(.*\n?)\s*$/;
  my $lastline = $1;
  return $lastline;
}
sub get_magic {
  my $file = shift; local *F; open F,'<',$file;
  my $magic; read(F,$magic,4); close F;
  return $magic;
}
# -----------------------------------------------------------------------
sub get_publicip {
 use LWP::UserAgent qw();
  my $ua = LWP::UserAgent->new();
  my $url = 'http://iph.heliohost.org/cgi-bin/remote_addr.pl';
     $ua->timeout(7);
  my $resp = $ua->get($url);
  my $ip;
  if ($resp->is_success) {
    my $content = $resp->decoded_content;
    chomp($content);
    $ip = $content;
  } else {
    print "X-Error: ",$resp->status_line;
    my $content = $resp->decoded_content;
    $ip = '127.0.0.1';
  }
  return $ip;
}

sub get_loggedip {
 use LWP::UserAgent qw();
  my $ua = LWP::UserAgent->new();
  my $url = 'http://iph.heliohost.org/cgi-bin/ip.pl?fmt=yaml';
     $ua->timeout(7);
  my $resp = $ua->get($url);
  my $ip;
  if ($resp->is_success) {
    my $content = $resp->decoded_content;
    eval "use YAML::Syck qw();";
    my $yml = &YAML::Syck::Load($content);
    $ip = $yml->{ipaddr};
  } else {
    print $resp->status_line;
    my $content = $resp->decoded_content;
    $ip = '0.0.0.0';
  }
  return $ip; 
}
# -----------------------------------------------------------------------
sub get_localip {
    use IO::Socket::INET qw();
    # making a connectionto a.root-servers.net

    # A side-effect of making a socket connection is that our IP address
    # is available from the 'sockhost' method
    my $socket = IO::Socket::INET->new(
        Proto       => 'udp',
        PeerAddr    => '198.41.0.4', # a.root-servers.net
        PeerPort    => '53', # DNS
    );
    return '0.0.0.0' unless $socket;
    my $local_ip = $socket->sockhost;

    return $local_ip;
}
# -----------------------------------------------------------------------
sub get_auth {
   my ($host,$realm,$user) = @_;
   my $clearf = $ENV{CLEARTEXT} || $ENV{HOME}.'/.secret/clear.sec';
   return 'YW5vOm55bW91cw' unless -f $clearf;
   local *F; open F,'<',$clearf;
   while (<F>) { 
     chomp($_);
     print "$_\n" if $dbug;
     if (m/^l/) {
        my ($auth,$h) = split'@',&decode_base63(substr($_,1)),2;
        next if $h ne $host;
        my ($u,$p,$r) = split':',$auth,3;
        next if $r ne $realm;
        next if $u ne $user;
        return &encode_base64m("$u:$p");
     }
     
   }
   close F;
   return 'YWRtaW46cGFzc3dvcmQ';

}
# -----------------------------------------------------------------------
1; # $Source: /my/perl/modules/UTIL.pm,v $
