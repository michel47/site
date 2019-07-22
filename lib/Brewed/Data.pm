#!perl

# Note:
#   This work has been done during my time at GCM
# 
# -- Copyright GCM, 2016,2017 --

#
# Private : ipfs daemon --transport-shared-key <current-key>
#
package Brewed::Data;
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

# -------------------------------------------------------------------
my $fdow = 0;
{  my $tic = time;
   use Time::Local qw(timelocal);
##     0    1     2    3    4     5     6     7
#y ($sec,$min,$hour,$day,$mon,$year,$wday,$yday)
   my $year = (localtime($tic))[5]; my $yr4 = 1900 + $year ;
   my $first = timelocal(0,0,0,1,0,$yr4);
   $fdow = (localtime($first))[6];
   #printf "1st: %s -> fdow: %s\n",&hdate($first),$fdow;
}
# -----------------------------------------------------------------------
sub flush { my $h = select($_[0]); my $af=$|; $|=1; $|=$af; select($h); }
# -----------------------------------------------------------------------
#
# STatistics 
# dump csv
sub dumpcsv {
   my $csvf= shift;
   my $db = $_[0];
   local *CSV;
   open CSV,'>', $csvf;
   my $date = (exists $db->{date}) ? $db->{date} : &hdate($^T);
   my $subject = (exists $db->{info}{subject}) ? $db->{info}{subject} : $csvf
   my $title = (exists $db->{info}{title}) ? $db->{info}{title} : '--';


   printf CSV "#,%s,%s,%s\n",$calib,$par,&hdate($db->{start}); # parameters
   print CSV "#i,$par.v,order,idx,percent,$par.a,$par.d,\n";
   foreach my $i (0 .. $ni-1) {
      printf CSV '%s,%s,%s,%s,%s,%s,%s',  $i,$hpar{$kpar}{values}[$i],$hpar{$kpar}{order}[$i],$hpar{$kpar}{index}[$i],
      $hpar{$kpar}{perc}[$i],$hpar{$kpar}{avg}[$i],$hpar{$kpar}{deriv}[$i];
      print CSV "\n";
   }
   my $values = $hpar{$kpar}{values};
   my $order = $hpar{$kpar}{order};
   # ---------------------------------------
   our $spar = $par; $spar =~ s/_/\\_/g;
   our ($mean,$med,$sigma,$sem) = &stats( @{$values}[@{$order}] );
   our ($spec,$tol) = ($mean, 0.02); # <----
   if ($mean eq '') {
      printf "%s values: [%s...]\n",$par,join',',@{$values}[0 .. 3];
   } else {
      printf "stats : spec=%s, mean=%s, median=%s, sigma=%s, stderr=%s\n",$spec,$mean,$med,$sigma,$sem;
   }
   our ($Pp,$LSL,$USL) = &capab($spec,$tol,$sigma);
   my $tol4 = ($mean) ? 4 * $sigma / $mean : ($med) ? 4 * $sigma / $med : 'N/A';
   my $tol6 = ($mean) ? 6 * $sigma / $mean : ($med) ? 6 * $sigma / $med : 'N/A';
   our ($tol100,$tol400,$tol600) = map { $_ * 100 } ($tol,$tol4,$tol6);
   # ---------------------------------------
   close CSV;
   use LSS::Misc qw(pngdump);
   unlink 'data.csv'; link $csvf, 'data.csv';
   my $stamp = &pngdump('data.kst');
   my $pngfile = sprintf 'calib\%s\%s_%s_raw.png',$calib,$par,$serial; unlink $pngfile;
   rename sprintf('data_%s_raw.png',$stamp),$pngfile;
   my $pngfile = sprintf 'calib\%s\%s_%s_index.png','png',$par,$serial; unlink $pngfile;
   rename sprintf('data_%s_index.png',$stamp),$pngfile;
   #unlink 'data.csv';
   #
   #
}

# collect statistics
# -----------------------------------------------------------------------
sub stats {
   my @data = @_; # assumed data is ordered
   my $np = scalar @data;

   return (undef,undef,undef,undef) if ($np <= 0);
   #printf "%u: %s\n",$np,join', ',@data[0 .. 3];
   my ($acc,$n) = (0,0);
   foreach my $dat (@data) {
      $acc += $dat;
      $n++;
   }
   # mean & median
   our $mean = $acc / $n;
   my $med0 = $data[($np-1)/2];
   my $med1 = $data[($np+0)/2];
   our $med = ($med0 + $med1) / 2;

   # stdev & sterr
   my $sum2 = 0;
   foreach my $dat (@data) {
      my $error = $dat - $mean;
      $sum2 += $error ** 2;
   }
   my $var = $sum2 / $np;
   our $sigma = sqrt( $sum2/($np-1) );
   our $sem= $sigma / sqrt($np); # standard error of mean


   return ($mean,$med,$sigma,$sem);
}
# -----------------------------------------------------------------------
# Statistical Process Control :
sub capab { # -> return Pp ( = 1 for 6 sigma design; <1 if 
   my ($spec,$tol,$sigma) = @_;
   return undef if $sigma == 0;
   our $USL = $spec * (1 + $tol);
   our $LSL = $spec * (1 - $tol);
   our $pp = ($USL - $LSL) / (6 * $sigma);
   print "$LSL < $spec < $USL : pp = $pp (6sig)\n";
   return ($pp,$LSL,$USL);
}
# -----------------------------------------------------------------------
sub runa { # running average ...
   my $wz = shift;
   my $wz1 = $wz - 1;
   my @array = @_;
   my $ni = scalar(@array);
   my $sum = $wz * $array[0]; # initialize running average
   my @wind = map { $array[0] } (0 .. $wz1);
   push @array, map { $array[-1] } (0 .. $wz1);
   my @avg; for my $i (0 .. $ni-1 + $wz) { # runing average
      my $value = $array[$i];
      my $delta = $value - $wind[$i%$wz];
      #$deriv[$i] = ($delta != 0) ? $wz / $delta : $deriv[$i-1];
      $sum += $delta;
      $wind[$i%$wz] = $value;
      $avg[$i-$wz/2] = $sum / $wz if ($i > $wz/2);
   };
   #y @delta; for (0 .. $ni-1) { $delta[$_] = ($values[$order[$_]] - $values[$order[$_-1]]) * $ni }; # derivative
   return @avg[0 .. $ni-1];
}
# -----------------------------------------------------------------------
sub filter {
   my $r = shift; # radius
   my @gauss; # TBD

}
# -----------------------------------------------------------------------
sub deriv {
   my @value = @_;
   my $ni = scalar(@value);
   push @value, $value[-1],$value[0];
   my @delta = map { $value[$_] - $value[$_-1]; } (0 .. $ni-1);
   return @delta;
}




# -----------------------------------------------------------------------
sub version {
  my @times = sort { $a <=> $b } (lstat($_[0]))[9,10];
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime($times[-1]))[0..7]; # most recent
  my $rweek=($yday+$fdow)/7;
  my $rev_id = int($rweek) * 4;
  my $low_id = int(($wday+($hour/24)+$min/(24*60))*4/7);
  my $version = ($rev_id + $low_id) / 100;
  #my ($atime,$mtime,$ctime) = (lstat($_[0]))[8,9,10];
  #print "y:$yday f:$fdow m:$mtime e:$etime, $mday.$mon.$yy -> rw=$rweek $rev_id $low_id $version\n";

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
sub rev {
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime($_[0]))[0..7];
  my $rweek=($yday+$fdow)/7;
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
# -----------------------------------------------------
sub base58 { # 62 char except 0IOl
  use integer;
  my ($n) = @_;
  my $e = '';
  return('1') if $n == 0;
  while ( $n ) {
    my $c = $n % 58;
    $e .=  chr(0x31 + $c); # 0x31: 0 excluded
    $n = int $n / 58;
  }
  $e =~ y/1-j/1-9A-HJ-NP-Za-km-z/;
  return scalar reverse $e;
}
# -----------------------------------------------------
sub encode_base58 {
  use Math::BigInt;
  use Encode::Base58::GMP qw();
  my $hex = unpack'H*',join'',@_;
  my $bint = Math::BigInt->from_hex($hex);
  my $h58 = Encode::Base58::GMP::encode_base58($bint);
  return $h58;
}
sub encode_base58_from_hex {
  use Math::BigInt;
  use Encode::Base58::GMP qw();
  my $bint = Math::BigInt->from_hex($_[0]);
  my $h58 = Encode::Base58::GMP::encode_base58($bint);
  return $h58;
}
sub decode_base58_to_hex {
  use Math::BigInt;
  use Encode::Base58::GMP qw();
  my $bint = Math::BigInt->new(Encode::Base58::GMP::decode_base58($_[0]));
  #print "bi: $bint\n";
  my $h16 = $bint->as_hex();
  return $h16;
}
# -----------------------------------------------------------------------
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
# -----------------------------------------------------------------------
sub encode_basen {
  my ($n,$alphabet) = @_;
  my @alphabet = split //, $alphabet;
  my $base= scalar @alphabet;
  return $alphabet[0] if $n == 0;
  my $str = ""; # this will be the end value.
  while( $n > 0 ) {
    #printf "// c=%s\n", $alphabet[$n % $base];
    $str = $alphabet[$n % $base] . $str; # LSB
    $n = int( $n / $base ); # MSB reminder
  }
  #printf "// n=%d base=%d => %s\n",$n,$base,$str;
  return $str;
}

sub decode_basen {
  my ($str,$alphabet) = @_;
  my $i = 0;
  my %value = map { $_ => $i++; } split //, $alphabet;
  my $base= length $alphabet; # or scalar keys %value
  my $n = 0;
  for( split //, $$str ) {
      $n *= $base;
      $n += $value{$_};
   }
   return $n;
}
# -----------------------------------------------------------------------
1; # $Source: /my/perl/modules/developped/at/AHE/Data.pm,v $
