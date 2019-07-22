#!perl
# vim: ts=2 et noai nowrap

package Brewed::STAMP;
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
local $VERSION = sprintf "%d.%02d", q$Revision: 0.0 $ =~ /: (\d+)\.(\d+)/;
my ($State) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------

my $yepoch = 1970; my $yoffset = 100 * int($yepoch/100);
my $year = $yoffset + (localtime($^T))[5]; # this year
my $century = int($year/100 + 0.9999);

my $_1yr = 8765.81277; # hours in a year (~ 365.25 * 24 = 8766)
my $_20yr = int(20*$_1yr*3600 + 0.4999); # 29.3-bit time in sec (i.e. 20 years)

my $_1d = 24 * 3600;
my $_spd = $_1yr/365.25*3600; # seconds per day
my $doffset = ( 0xFFFF_FFFF/$_spd ) - (100 * $century - $yepoch) * 365.25; 
# ----------------------------------------------------
my $nounce = undef;

my $opdfile = 'c:/sandbox/admin/etc/onceperday.yml';

our %past = ();
my $past = \%past;
use YAML::Syck qw(LoadFile DumpFile);
our $opd = undef;
if (-e $opdfile) {
  $opd = LoadFile($opdfile);
} else {
  $opd = {};
}

#require "timelocal.pl";
use Time::Local qw(timelocal);
# ------------------------------------------------------
my $first = timelocal(0,0,0,1,0,$year);
my $fdow = (localtime($first))[6];
my $w1st = ($fdow > 3) ? 1 : 0; # this year week offset
# ----------------------------------------------------
$main::VERSION = sprintf '%.2f',&ver(&etime((caller(0))[1])) unless defined $main::VERSION;
# ----------------------------------------------
#
sub etime {
my ($atime,$mtime,$ctime) = (lstat($_[0]))[8,9,10];
my $etime = ($ctime > $mtime) ? ($mtime > $atime) ? $atime : $mtime : $ctime; # pick the earliest
  return $etime;
} 
# ----------------------------------------------------
sub tcheck { # time check
  my ($tic) = @_;
  my $tcn = int ( ($tic-7*3600)%(24*3600) / (25*60) );

}
# ----------------------------------------------------
#
sub counter {
  my ($file,$inc) = @_;
  my $cnt = 0;
  local *F; open F,'+<',$file or return undef;
  local $/ = "\n"; <F>;
  my $line = <F>;
  my ($counter,$value) = ($1,$2) if ($line =~ m/(\w+)\s*=\s*([-+\d]+)/);
  seek(F,-length($line)-1,1); # rewind last line ...
  $value += $inc;
  printf F "%s=%d\n",$counter,$value;
  close F;
  return $value;  
}
# ----------------------------------------------------
sub weekn {
  my ($yy,$wday,$yday) = (localtime(int $_[0]))[5..7];
  my $first = timelocal(0,0,0,1,0,$yy+1900);
  my $fdow = (localtime($first))[6];
  my $w1st = ($fdow > 3) ? 1 : 0; # week offset
  my $yweek=$yday/7 + $w1st;
  return int $yweek; 
}
# ----------------------------------------------------
sub abc {
  return uc &base26(&htic(int $_[0])%17576); # 26**3 = 17576;
}
sub sn {
  # 9630 = 20yr / 65536;
  return ( ($_[0]-1)%($_20yr)/9630 ); # 16-bit time
}
# ---------------------------------------------------------
sub swat { # swatch time !
  my $tod = ($_[0]+3600-1)%(24*3600); # time of the day (16.4-bit)
  return $tod * 1000 / (24*3600);
}
# ---------------------------------------------------------
sub ver {
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime(int $_[0]))[0..7];
  my $rweek=($yday+$fdow)/7;
  my $rev_id = int($rweek) * 4;
  my $low_id = int(($wday+($hour/24)+$min/(24*60))*4/7);
  my $version = ($rev_id + $low_id) / 100;
  return ( wantarray ) ? ($rev_id,$low_id) : $version;
}

sub rev { # 4 releases per week
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime(int $_[0]))[0..7];
  my $rweek=($yday+$fdow)/7;
  my $rev_id = int($rweek) * 4;
  my $low_id = int(($wday+($hour/24)+$min/(24*60))*4/7);
  return ($rev_id,$low_id);
}

sub stamp36 {
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime(int $_[0]))[0..7];
  my $yhour = $yday * 24 + $hour + ($min / 60 + $sec / 3600);
  my $stamp = &base36(int($yhour/$_1yr * 36**4)); # 18 sec accuracy
  return $stamp;
}

# ----------------------------------------------------
sub flower { # return a flower name based on time
  my $tic = int ($_[0]);
  my $abc = uc &base26(&htic($tic)%17576); # 26**3 = 17576
  my $flowers = [qw{acacia begonia coriander dahlia echinacea foxglove geranium
               hyacinth iris jonquil kurume lavander mimosa narciss ochidea
	       pensea qween_lily rose saffron tulip urn violet wahlenbergia xerophyta yarrow zephyranthes}];
  my $flower = $flowers->[ord(substr($abc,0,1))-0x41]; # 0x41 upper
  return $flower;
}
# ----------------------------------------------------
sub sdate { # return a human readable date ... but still sortable ...
  my $tic = int ($_[0]);
  my $ms = ($_[0] - $tic) * 1000;
     $ms = ($ms) ? sprintf('%04u',$ms) : '____';
  my ($sec,$min,$hour,$mday,$mon,$yy) = (localtime($tic))[0..5];
  my ($yr4,$yr2) =($yy+1900,$yy%100);
  my $date = sprintf '%04u-%02u-%02u %02u:%02u:%02u',
             $yr4,$mon+1,$mday, $hour,$min,$sec;
  return $date;
}
# ----------------------------------------------------
sub hdate { # return HTTP date (RFC-1123, RFC-2822) 
  my $DoW = [qw( Sun Mon Tue Wed Thu Fri Sat )];
  my $MoY = [qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec )];
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday) = (gmtime($_[0]))[0..6];
  my ($yr4,$yr2) =($yy+1900,$yy%100);
  # Mon, 01 Jan 2010 00:00:00 GMT

  my $date = sprintf '%3s, %02d %3s %04u %02u:%02u:%02u GMT',
             $DoW->[$wday],$mday,$MoY->[$mon],$yr4, $hour,$min,$sec;
  return $date;
}
# ----------------------------------------------------
sub thash { # 12-bit time hash (period 1hr 8min)
  my ($tic) = @_;
  my $tod = ($tic-1)%(24*3600); # 16.4-bit time of the day
  use Digest::MurmurHash; # Austin Appleby (Murmur 32-bit)
  my $digest = Digest::MurmurHash::murmur_hash(pack'N',$tod);
  return  ($digest ^ ($digest>>10) ^ ($digest>>20)) & 0xFFF; # 12-bit
}
sub thash_base64 { # 12-bit time hash (period 1hr 8min)
  my ($tic) = @_;
  my $tod = ($tic-1)%(24*3600); # 16.4-bit time of the day
  use Digest::MurmurHash; # Austin Appleby (Murmur 32-bit)
  my $digest = Digest::MurmurHash::murmur_hash(pack'N',$tod);
  my $th = ($digest ^ ($digest>>10) ^ ($digest>>20)) & 0xFFF; # 12-bit
     $th = pack('H3',substr(unpack('H*',pack'n',$th),1));
  my $t64 = &encode_base64($th,'');
     $t64 =~ s/[=A]+$//o;
     $t64 =~ tr ,/+,.-,;
  return $t64;
}
sub htic { # 16-bit time hash
  my ($tic) = @_;
  use Digest::MurmurHash; # Austin Appleby (Murmur 32-bit)
  my $digest = Digest::MurmurHash::murmur_hash(pack'N',$tic);
  return  ($digest ^ ($digest>>16)) & 0xFFFF; # 16-bit
}
sub hday { # 16-bit unique hash
  my ($tic) = @_;
  my $day = int(($tic-1)/$_1d);
  my $nonce = 0;
  if (exists $opd->{$day}) {
    $nonce = $opd->{$day};
  } else {
    $nonce = int (rand(0x10000))<<8 | int(rand(0x10000));
    $opd->{$day} = $nonce;
    DumpFile($opdfile,$opd);
  }
  use Digest::MurmurHash; # Austin Appleby (Murmur 32-bit)
  my $digest = Digest::MurmurHash::murmur_hash(pack'N2',$day,$nonce);
  $digest = ($digest>>16 ^ $digest) & 0xFFFF; # period ; 179yr
  $digest++ while $past->{$digest};
  $past->{$digest}++;
  return $digest;
}
sub hday2 { # hash of the day
  my ($tic,$salt) = @_;
  my $day = int ( $doffset + ($tic-1)/$_spd ); # 16-bit date
  #my $day = int ( ($tic-1)/(24*3600) ); # 16-bit date
  use Digest::MurmurHash; # Austin Appleby (Murmur 32-bit)
  my $digest = Digest::MurmurHash::murmur_hash(pack'nN',$day,$salt);
  $digest = ($digest>>16 ^ $digest) & 0xFFFF; # period ; 179yr
  $digest++ while $past->{$digest}; # need a bloom-filter for efficiency
  $past->{$digest}++;
  return $digest;
  #return  ($digest ^ ($digest>>10) ^ ($digest>>20)) & 0xFFF; # period 11yr
  
}
sub nonce { # recover from  timespace database ...
  my $timefile = '/home/RnD/09_Miscellaneous/06_journal/timespace.n';
  my ($time) = @_;
  my $day = int ( $doffset + ($time-1)/$_spd ); # 16-bit date (0 .. 49710)
  my $size = (lstat($timefile))[7];
  my $seek = int($day) * 4;
  

  my $nonce = undef;
  if ($seek+4 < $size) {
  open *N,'<',$timefile; binmode(N);
  seek(N,$seek,0);read(N,$nonce,4);
  close N;
  }
  #print "size: $size, seek: $seek -> nonce: $nonce\n";
  return 0x12345678 unless $nounce;
  return undef if ($nonce eq pack'N',0x4F88BC48);
  return $day if ($nonce eq "\0\0\0\0");
  return $time if ($nonce eq pack'N',0xFFFF_FFFF);
  #printf "// recover from seek=%d: %08x (D%d)\n",$seek,unpack('N',$nonce),$day;
  return unpack'N',$nonce;
}

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
sub base36 {
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
1; # $Source: /my/perl/modules/developped/at/HEIG-VD/STAMP.pm,v $
