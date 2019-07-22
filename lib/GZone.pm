#!/usr/bin/perl

# Note:
#   This work has been done during my time at GCM
# 
# -- Copyright GCM, 2017,2018 --
# 
# Running on a pseudo-private network :
#   ipfs daemon --transport-shared-key <current-key>
#   (need to participate to know the shared key...)
#
# TBD debug &nickname 
#


package GZone;
require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
#@EXPORT_OK = qw(nickname);
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};

use strict;

use UTIL qw(version encode_baser hashr);

if (exists $ENV{M4GC_PATH}) {
  use lib $ENV{M4GC_PATH}.'/lib';
} else {
  use lib $ENV{HOME}.'/.iphs/lib'; # require HOME Env. variable
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
our $DICT = '';
# dictionaries :
our $wordlists = {};
our $dicts = {
              'common' => 'common-7-letter-words.txt',
              cats => 'catnames.txt',
              first => 'fnames.txt',
              last => 'lnames.txt',
              cities => 'TZcities.txt',
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
sub ppm {
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
sub get_wordn {
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
1; # $Source: /my/perl/modules/UTIL.pm,v $
