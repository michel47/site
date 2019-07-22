#!perl
# vim: sw=3 ts=2 et noai nowrap

package Brewed::IPModlib;
# $Parent: /ipfs/QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn/ $
#
# The ideas is to have a globally available libraries of perl modules
# callable w/ 
# IPMod::MichelC::helloworld::v1.1
#
#
# Note:
#   This work has been done during my time HEIG-VD
#   65% employment (CTI 13916)
#
# -- Copyright HEIG-VD, 2013,2014,2015 --
# ----------------------------------------------------
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

#require "timelocal.pl";
use Time::Local qw(timelocal);
# ------------------------------------------------------
my $yepoch = 1970; my $yoffset = 100 * int($yepoch/100);
my $year = $yoffset + (localtime($^T))[5]; # this year
my $first = timelocal(0,0,0,1,0,$year);
my $fdow = (localtime($first))[6];
my $w1st = ($fdow > 3) ? 1 : 0; # this year week of
# ------------------------------------------------------


$main::VERSION = sprintf '%.2f',&version((caller(0))[1]) unless defined $main::VERSION;
# ----------------------------------------------------
sub swat { # swatch time !
  my $tod = ($_[0]+3600-1)%(24*3600); # time of the day (16.4-bit)
  return $tod * 1000 / (24*3600);
}
# ----------------------------------------------------
sub flush { my $h = select($_[0]); my $af=$|; $|=1; $|=$af; select($h); }
# -----------------------------------------------------------------------
sub word { # 20^4 * 6^3 words (25bit worth of data ...)
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
# -----------------------------------------------------------------------
sub version {
  my ($atime,$mtime,$ctime) = (lstat($_[0]))[8,9,10];
  my $etime = ($ctime > $mtime) ? ($mtime > $atime) ? $atime : $mtime : $ctime;
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime($etime))[0..7];
  my $rweek=($yday+$fdow)/7;
  my $rev_id = int($rweek) * 4;
  my $low_id = int(($wday+($hour/24)+$min/(24*60))*4/7);
  my $version = ($rev_id + $low_id) / 100;

  if (wantarray) {
     my $md6 = &digest('MD6',$_[0]);
     print "$0 : $md6\n";
     my $pn = hex(substr($md6,-4)); # 16-bit
     my $build = &word($pn);
     return ($version, $build);
  } else {
     return sprintf '%g',$version;
  }
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
# ----------------------------------------------------
sub pngdump {
  use Brewed::STAMP qw(stamp36 swat hdate);
#  die if ! -e $kst2;
  my $csv = shift;
  my ($fpath,$basen,$ext) = &basen($csv);
  
  my $kstfile = "$fpath/$basen.kst";
  my $tmplfile = "${basen}-tmpl.kst";

  my $filename = $basen; $filename =~ y/_/ /; # to display on kst plots
  my $tic = time();
  my $swat = &swat($tic);
  my $date = &hdate($tic);
  my $stamp36 = &stamp36($tic);
  
  if (-e $tmplfile) {
    local *F; open F,'<',$tmplfile or return $?;
    local $/ = undef; my $buf = <F>; close F;
    $buf =~ s/%filename%/$filename/g if ($buf =~ m/%filename%/o);
    $buf =~ s/%swat%/$swat/g if ($buf =~ m/%swat%/o);
    $buf =~ s/%date%/$date/g if ($buf =~ m/%date%/o);
    $buf =~ s/%stamp36%/$stamp36/g if ($buf =~ m/%stamp36%/o);
    $buf =~ s/%out_dir%/$fpath/g if ($buf =~ m/%out_dir%/o);
    no strict 'refs';
    $buf =~ s/%([a-z]\w+)%/${'::'.$1}/eig if ($buf =~ m/%[a-z]\w+%/io);

    open F,'>',$kstfile;
    print F $buf;
    close F;
  }
  my $kst2 = 'kst2.exe';
  my $pngfile = "$fpath/${basen}_${stamp36}.png";
  system sprintf '"%s" --landscape "%s" --png "%s"',$kst2,$kstfile,$pngfile;
  $pngfile = ${stamp36} unless -e $pngfile;

  return $pngfile;
}
# ----------------------------------------------------
sub basen { # extrac basename etc...
  my $f = shift;
  $f =~ s,\\,/,g; # *nix style !
  my $s = rindex($f,'/');
  my $fpath = ($s > 0) ? substr($f,0,$s) : '.';
  my $file = substr($f,$s+1);

  if (-d $f) {
    return ($fpath,$file);
  } else {
  my $p = rindex($file,'.');
  my $basen = ($p>0) ? substr($file,0,$p) : $file;
  my $ext = lc substr($file,$p+1);
     $ext =~ s/\~$//;
  
  $basen =~ s/(F[0-9]{5}|[a-f0-9]{7})[0-9]{4,8}\s+[0-9]{4}_[0-9]{5}$/\1/;
  $basen =~ s/\s+([a-z]{5}-)?v[0-9.]{4}$//; # remove version ...
  
  $basen =~ s/\s+[0-9]{4}_[0-9]{5}$//;
  $basen =~ s/\s-\s[A-Z0-9]{4}$//;
  $basen =~ s/\s[a-f0-9]{7}$//;
  $basen =~ s/\s+\(\d+\)$//;
  $basen =~ s/\s*\(.*[Cc]onflict(?:ed)?[^)]*\)$//;
  $basen =~ s/_conflict-\d+-\d+$//;
  $basen =~ s/\s+[b-z][aeiouy][a-z][aeiouy][b-z]$//;   

  return ($fpath,$basen,$ext);

  }

}
# ----------------------------------------------------

# ----------------------------------------------------
1; # $Source: /my/perl/modules/at/HEIG-VD/PERMA.pm,v $
