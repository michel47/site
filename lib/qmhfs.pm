#!/usr/bin/perl

# Note:
# ㋡ This work has been done during my time at Gratual Quanta Unc.
# 
# -- Copyright GQunc, 2017,2018 --
# 
# Running on a pseudo-private network :
#   ipfs daemon --transport-shared-key <current-key>
#   (need to participate to know the shared key...)
#
# TBD debug &nickname ㋛
#
# shrug : ¯\_(ツ)_/¯



package qmhfs;
require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
#@EXPORT_OK = qw(nickname);
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};

use strict;

use lib $ENV{SITE}.'/lib'; # require SITE Env. variable
use UTIL qw(version encode_basex encode_baser hashr );
# use lib $ENV{QMHF_PATH}.'/lib';

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
our $DICT = '';
# dictionaries :
my $geonames = undef;
my $cats = undef;
my $colors = [qw{red orange yellow green aquamarine blue violet indigo pink}];
my $flowers = [qw{acacia begonia coriander dahlia echinacea foxglove geranium
               hyacinth iris jonquil kurume lavander mimosa narciss ochidea
    pensea qween_lily rose saffron tulip urn violet wahlenbergia xerophyta yarrow zephyranthes}];
our $wordlists = {};
our $dicts = {
              'common' => 'common-7-letter-words.txt',
              cats => 'catnames.txt',
              first => 'fnames.txt',
              last => 'lnames.txt',
              cities => 'cities.txt',
              streets => 'streets.txt',

              Diceware => 'Diceware7776.txt',
              SKEY => 'SKEY2048.txt',
              PGP => 'PGP256.txt',
              dict350K => 'dict349900.txt',
              word235K => 'words235886.txt',
              BIP39 => 'BIP39-English.txt'
            
};

# =======================================================================
if (__FILE__ eq $0) {

}
# =======================================================================
sub get_peerid { # dependency on ipfs
  my $buf = `ipfs id`;
  use JSON qw(decode_json);
  my $json = &decode_json($buf);
  return $json->{ID};
}
sub canonical_path {
  my ($peerid,$bin) = @_;
  my %rdx = ( first => 5494, middle => 5494, last => 88799, ini => 26, age => 109-16,
             color => 10, kitty => 300, flower => 26, cvv => 9999, msgid => 26**4,
   num => 128, street => 240, cities => 1301, places => 928139 );

  # using peerid to select a place
  my $ns = &decode_base58($peerid);
  my $plid = unpack'N',substr($ns,2,4);
  printf "plid: %s\n",$plid;
  $geonames = &load_geoname() unless (defined $geonames);
  my $place = $geonames->[$plid%928139];

  # using bin to select a box 
  my $hz = 41; # nb bits (zoneb)
  my $hl = int(($hz+7)/8); # in bytes 
  my $box = substr($bin,$hl+16,5); # 5 (mailbox w/ 4 letter msgid)
  printf "box: %s\n",unpack'H*',$box;
  $cats = &load_wlist('cats') unless (defined $cats);

  my @box = &encode_basex($box,@rdx{qw(color flower kitty cvv msgid)}, 9999);
  my $reminder = $box[-1];
  my $color = $colors->[$box[0]];
  my $flower = $flowers->[$box[1]];
  my $kitty = $cats->[$box[2]];
  my $cvv = $box[3];
  my $msgid = uc &word($box[4]);

  my $BOX = "$color $flower/box $cvv/$kitty for $msgid";
  printf "// BOX: %s\n",$BOX;
  
  
  #printf "%s.\n",YAML::Syck::Dump($place); use YAML::Syck;
  my $cpath = sprintf '/%s/%s/%s/',(@$place)[1,2,3];
  return $cpath;

}

sub canonical {
  my ($bin,$type,$size) = @_; # size is used to compute necessary bits: nb
  $size = 1 unless $size; # minimal size (quanta)
  # Repository space allocation 
  my $z1G = 1<<(3 * 10);
  my $capacity = {
    text => 20*$z1G,
    'application/pdf' => 100*$z1G,
    'image/jpeg' => 100*$z1G,
    'image/x-png' => 10*$z1G,
    'image/gif' => 2*$z1G,
    video => 100*$z1G,
    'application/octet-stream' => 50*$z1G,
    'application/x-perl' => 1*$z1G,
    'text/html' => 5*$z1G,
    blob0170 => 1*$z1G, # protobuf
    blob0155 => 20*$z1G, # raw
    blob => 30*$z1G
  };
  
  my $n = 8 * $capacity->{$type} / $size;
  printf "unknown type: %s for %s\n",$type,unpack('H*',$bin) unless $n;
  my $nr = (log(3*$n)/log(2));
  my $nb = int(($nr +7)/8);
  printf "nr: %.2fb (required bits for n=%u %s of %uB) using nb=%uB\n",$nr,$n,$type,$size,$nb;
  my $key = substr($bin,-$nb-2,$nb);
  my $cname = undef;
  # ----------------------------------------------
  if ($type =~  m/^blob/) {
    printf "key: 0x%s\n",unpack'H*',$key;
    $cname = &encode_base63($key) . '.blob';
  # ----------------------------------------------
  } elsif ($type =~ m'stream') {
    $cname = &encode_basen($key,36) . '.dat';
  # ----------------------------------------------
  } elsif ($type =~ m'image/(\w+)') {
    my $ext = $1;
    my $n = hex(unpack'H*',$key);
    $cname = sprintf('img_%u.%s',$n,$ext);
  # ----------------------------------------------
  } elsif ($type =~ m'video/(\w+)') {
    my $ext = $1;
    my $n = hex(unpack'H*',$key);
    $cname = sprintf('vid_%u.%s',$n,$ext);
  # ----------------------------------------------
  } elsif ($type =~ m'htm') {
    $cname = &encode_basen($key,36) . '.htm';
  # ----------------------------------------------
  } elsif ($type eq 'text/plain') {
    $cname = &encode_basen($key,36) . '.txt';
  # ----------------------------------------------
  } else {
    my $ext = ($type =~ m'/(?:x-)?(\w+)') ? $1 : 'ukn';
    $ext = 'pl' if $ext eq 'perl';
    $cname = &word5(hex(unpack'H*',$key)) . '.'.$ext;
  }
  # ----------------------------------------------
  return $cname;
  
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
   } else {
   #my $c = $n % 6;
   #   $n /= 6;
   #   $str .= $vo->[$c];
   #   odd=undef;
   }
 }
 return $str;
}
# -----------------------------------------------------
# -----------------------------------------------------------------------
sub shake { # use shake 128
  use Crypt::Digest::SHAKE;
  my $len = shift;
  my $msg = Crypt::Digest::SHAKE->new(128);
  $msg->add(join'',@_);
  my $digest = $msg->done(($len+7)/8);
  return $digest;
}
# -----------------------------------------------------------------------
sub get_shake {
  use Crypt::Digest::SHAKE;
  my $len = shift;
  my $ns = shift;
  local *F; open F,$_[0] or do { warn qq{"$_[0]": $!}; return undef };
  #binmode F unless $_[0] =~ m/\.txt/;
  my $msg = Crypt::Digest::SHAKE->new(256);
  $msg->add($ns);
  $msg->addfile(*F);
  my $digest = $msg->done(($len+7)/8);
  return $digest;
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
sub get_type {
  my $file = shift;
  use File::Type;
  my $ft = File::Type->new();
  my $type = $ft->checktype_filename($file);
  return $type;
}
# -----------------------------------------------------------------------
sub get_source {
  my $file = shift; local *F; open F,'<',$file;
 local $/ = "\n";
  my $source = undef;
  while (<F>) {
     if (m/\$Source:\s*(.*)\s*\$/) {
        $source = $1;
     }
  }
  close F;
  return $source
}
# -----------------------------------------------------------------------
sub get_what {
  my $pat = "\x{2661}\x{1F30D}\x{1F30F}\x{1F30E}\x{1F310}";
  my $file = shift; local *F; open F,'<',$file;
  #binmode(F, ':bytes');
  binmode(F, ':utf8');
  binmode(STDERR,':utf8');
  my @whats = ();
  while (<F>) {
     if (m/\@\(([#$pat])\)(.*?)[\0"\n]/) {
       push @whats, '@('.$1.')'.$2;
     }
  }
  close F;
  return \@whats;
}
# -----------------------------------------------------------------------
sub get_shrug {
  #use utf8;
  my $pat = "\x{30C4}\x{30F3}";
  my $pat2 = "\x{32E1}\x{32DB}\x{1F937}";
  my $file = shift; local *F; open F,'<',$file;
  binmode(F, ':utf8');
  binmode(STDERR,':utf8');
  my @shrug = ();
  while (<F>) {
     printf STDERR "//info: %s",$_ if m/\x{2661}/;
     if (m/\@\(([#$pat])\)(.*?)[\0"\n]/) {
       push @shrug, '@('.$1.')'.$2;
     } elsif (m/([$pat2])(.*?)[\-"\n]/) {
       push @shrug, "@(\x{30C4})".$2;
     }
  }
  close F;
  return \@shrug;
}
# -----------------------------------------------------------------------
sub get_firstline { # note really the first line, but line that after the 13th character !
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

# TBD ... continue the work 😃


sub load_geoname {
# locId,country,region,city,postalCode,latitude,longitude,metroCode,areaCode
# 928139,"ES","51","Almería","04630",37.1814,-1.8225,,
 my @geolist = ();
 my $geolist = \@geolist;
 $DICT = (exists $ENV{DICT} && -d $ENV{DICT}) ? $ENV{DICT} : `secdir`.'/dict'; # '/usr/share/dict';
 my $file = sprintf '%s/%s',$DICT,'GeoLiteCity.csv';
 #print "//geofile: $file\n";
 
 open *F; open F,'<',$file; local $/ = "\n";
 while (<F>) {
   chomp;
   my ($locid,$cntry,$region,$city,$zip,$lat,$long,$mcode,$acode) = map { s/"(.*)"/\1/;  $_; } split(',',$_);
   $geolist->[$locid] = [$locid,$cntry,$region,$city,$zip,$lat,$long,$mcode,$acode];
 } 
 return $geolist;
}
# -----------------------------------------------------------------------
sub load_wlist {
   my $wlist = shift;
   my $wordlist;
   my $file;
   $DICT = (exists $ENV{DICT} && -d $ENV{DICT}) ? $ENV{DICT} : `secdir`.'/dict'; # '/usr/share/dict';
   if (exists $dicts->{$wlist}) {
      $file = sprintf '%s/%s',$DICT,$dicts->{$wlist};
   } else {
      if (-e $wlist) {
         $file = $wlist; 
      } else {
         $file = sprintf '%s/%s.txt',$DICT,$wlist;
      }
   }
   if (! -e $file) {
      print "X-ERROR: ! -e $file\n";
      return undef;
   }
   local *F; open F,'<',$file or die $!;
   #local $/ = "\n"; @$wordlist = map { chomp($_); (split("\t",$_))[0] } grep !/^#/, <F>;
   local $/ = "\n"; @$wordlist = map { chomp($_); $_ } grep !/^#/, <F>;
   close F;
   my $wl = scalar @$wordlist;
   printf "X-Info: %8s file://%s : %uw\n",$wlist,$file,$wl;
  return $wordlist;
}
# -----------------------------------------------------------------------
sub encode_words {
  my ($data,$wordlist) = @_;
  my $wl = scalar @$wordlist;
  return map { $wordlist->[$_] } &encode_baser($data,$wl);
}
# -----------------------------------------------------------------------
sub fullname { # /!\ there is a modulo bias
  my $bin = shift; # only consider 80-bit
     $bin = &hashr('SHA256',1,$bin) if (length($bin) > 32);
  my $funiq = substr($bin,1,6); # 6 char (except 1st)
  my $luniq = substr($bin,7,4);  # 4 char 
  $wordlists->{'fnames'} = &load_wlist('fnames') unless (defined $wordlists->{'fnames'});
  $wordlists->{'lnames'} = &load_wlist('lnames') unless (defined $wordlists->{'lnames'});
  my $flist = $wordlists->{'fnames'};
  my $llist = $wordlists->{'lnames'};
  my @first = map { $flist->[$_] } &encode_baser($funiq,5494);
  my @last = map { $llist->[$_] } &encode_baser($luniq,88799);
 
  return (@first,join'-',@last);
}
# -----------------------------------------------------------------------
sub ppm { # part per million ...
  my $bin = shift; # only consider 32-bit
  $bin = &hashr('SHA256',1,$bin) if (length($bin) > 32);
  my $uniq = length($bin) < 19 ? substr($bin,-8) : substr($bin,11,8);
  my $ppm = unpack'Q',$uniq;
  return $ppm % 1000_000;
}
# -----------------------------------------------------------------------
sub nickname {
   my $key = shift; 
   $key = &hashr('SHA256',1,$key) if (length($key) > 32);

   use Digest::MurmurHash;
   my $hash = Digest::MurmurHash::murmur_hash($key);
   my $list;
   if (defined $wordlists->{'fnames'}) {
     $list = $wordlists->{'fnames'};
   } else {
     $list = &load_wlist('fnames');
     $wordlists->{'fnames'} = $list;
     #printf "%s.\n",YAML::Syck::Dump($list);
   }
   my $n = scalar(@$list);
   my $firstname = $list->[$hash%$n];
   return $firstname;
}
# -----------------------------------------------------------------------
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
# -----------------------------------------------------------------------
sub get_wordn { # return ith words from a wordlist
  my ($i,$wlist) = @_;
  if (! exists $wordlists->{$wlist}) {
     printf "X-DBUG: no wordlists for %s\n",$wlist;
     $wordlists->{$wlist} = &load_wlist($wlist);
  }
  # ------------------------------
  my $wordlist = $wordlists->{$wlist};
  my $wl = scalar @$wordlist;
  printf "X-DBUG: %s's wordlist has %u words\n",$wlist,$wl;
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
# -----------------------------------------------------
sub encode_base58 {
  use Math::BigInt;
  use Encode::Base58::BigInt qw();
  my $bin = join'',@_;
  my $bint = Math::BigInt->from_bytes($bin);
  my $h58 = Encode::Base58::BigInt::encode_base58($bint);
  $h58 =~ tr/a-km-zA-HJ-NP-Z/A-HJ-NP-Za-km-z/;
  return $h58;
}
# -----------------------------------------------------
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
  } elsif ($radix <= 37) {
    $alphab = '0123456789ABCDEFGHiJKLMNoPQRSTUVWXYZ.';
  } elsif ($radix == 43) {
    $alphab = 'ABCDEFGHiJKLMNoPQRSTUVWXYZ0123456789 -+.$%*';
  } elsif ($radix == 58) {
    $alphab = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  } else { # n < 94
    $alphab = '-0123456789'. 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
                             'abcdefghijklmnopqrstuwvxyz'.
             q/+.@$%_,~`'=;!^[]{}()#&/.      '<>:"/\\|?*'; #
  }
  # printf "// alphabet: %s (%uc)\n",$alphab,length($alphab);
  return $alphab;
}
# -----------------------------------------------------------------------
1; # $Source: /my/perl/modules/UTIL.pm,v $
