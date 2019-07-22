#!perl
# vim: ts=2 et noai nowrap
#
package Brewed::STATS;
# --------------------------------------------
# Note:
#
# @(#) This package provides function useful
# for collecting statistics ...
#
# 
# -- Copyright Provence Tech., 2012,2013,2014,2015 --
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

our $universe = {};

# statistics functions
sub mid {
  my @d = sort { $a <=> $b } @_;
  return ($d[0] + $d[-1] ) / 2;
}
sub min { (sort { $a <=> $b } @_ )[0] }
sub max { (sort { $b <=> $a } @_ )[0] }
sub med { (sort { $b <=> $a } @_ )[$#_/2] }
sub sum { my $sum = 0; foreach (@_) { $sum += $_; } return $sum; }

sub avg { my ($sum,$n) = (0,0);  foreach (@_) { if(defined $_) { $sum += $_;$n++ } } return ($n)?$sum/$n:$sum; }

sub compare {
  my ($sig,$state,$ref,$hyst) = @_;
  my $thres = $ref + ( ($state) ? -$hyst : +$hyst );
  return ($sig > $thres) ?  1 : ($sig < $thres) ? 0 : $state;
}
# special stat and filters ...
sub filters { # {{{
  my ($data,$wsize,$period) = @_;
  # ---------------------------------------------
  # Outputs arrays ...
  my @avg;
  my @wmax;
  my @wmin;
  my @wmed;

  my @maxavg;
  my @minavg;
  my @max;
  my @min;
  my @ampl;

  my @uenv;
  my @lenv;
  my @esig;
  my @env;

  my @navg;
  my @nmu;
  my @nerr;
  my @ndev;

  my @pavg;
  my @pmu;
  my @perr;
  my @pdev;
  # ---------------------------------------------
  my ($maxavg,$minavg) = (undef,undef);
  my ($ndev,$pdev);
  my ($uenv,$lenv);
  my ($nmu,$pmu);
  # ---------------------------------------------
  my @ravg = ();
  my @nsig = ();
  my @psig = ();

  my $n = scalar(@$data);
  # initialize variables
  my ($iue,$ile) = (0,0); # index of previous data for envelop detection
  my ($nsum,$psum) = (0,0); # sign sum accumulator
  my ($npts,$ppts) = (0,0); # negative / positive points

  for my $i (0 .. $n-1) {
  my $sig = $data->[$i];
  # measure amplitude
  # 1) rolling avg on $np window
  $ravg[$i%$wsize] = $sig;
  my $avg = &sum(@ravg)/$wsize;
  # compute window min and max
  my $wmax = &max(@ravg);
  my $wmin = &min(@ravg);
  my $wmed = &med(@ravg);

  # 2) monitor max ...
  if ($avg >= $maxavg) { # envelop detect is > 0, 0 otherwise
    $maxavg = $avg;
  } elsif ($avg < 0) {
    $maxavg = 0;
  }
  my $max = $maxavg if $maxavg; # keep non-zero max values ...
  # 3) monitor min ...
  if ($avg <= $minavg) {
    our $minavg = $avg;
  } elsif ($avg > 0) {
    $minavg = 0;
  }
  my $min = $minavg if $minavg; # keep non zero min values ...
  # 4) compute amplitude
  my $ampl = $max - $min;
  #
  # 5) raw envelop detection (assume there is no DC component ..
  if ($sig > $uenv || ($i - $iue) > $period) { # reset upper-envelop after period points
    $uenv = $sig;
    $iue = $i; # track time !
  }
  if ($sig < $lenv || ($i - $ile) > $period) {
    $lenv = $sig;
    $ile = $i; # track time !
  }
  my $esig = &max(-$lenv,$uenv);
  my $env = $uenv - $lenv;

  my ($navg,$nerr);
  # 6) negative average & deviation ...
  if ($avg < 0) {
     push @nsig, $sig;
     $nsum += $sig;
     $npts++;
     $navg = $nsum/$npts;
  } else {
    if ($npts != 0) { # once just when sig == 0
      $nmu = $navg;
      $nerr = $nsig[-1] - $navg; # use last stored sig < 0
      my $nssum = 0; # accu to computer variance...
      foreach (@nsig) {
        $nssum += ($_ - $navg)**2;
      }
      my $pz = ($npts>75) ? $npts : ($npts>1) ? $npts-1 : 1;
      $ndev = sqrt($nssum / $pz); # unbiased standard dev.
    }
    @nsig = ();
    $nsum = 0;
    $npts = 0;
  }

  my ($pavg,$perr);
  # 7) positive average & deviation ...
  if ($avg > 0) {
     push @psig, $sig;
     $psum += $sig;
     $ppts++;
     $pavg = $psum/$ppts;
  } else {
    if ($ppts != 0) { # once just when sig == 0
      $pmu = $pavg;
      $perr = $psig[-1] - $pavg; # use last stored sig > 0
      my $pssum = 0; # accu to computer variance...
      foreach (@psig) {
        $pssum += ($_ - $pavg)**2;
      }
      my $pz = ($ppts>75) ? $ppts : ($ppts>1) ? $ppts-1 : 1;
      $pdev = sqrt($pssum / $pz); # unbiased standard dev.
    }
    @psig = ();
    $psum = 0;
    $ppts = 0;
  }

  push @avg,$avg;
  push @wmax,$wmax;
  push @wmin,$wmin;
  push @wmed,$wmed;

  push @maxavg,$maxavg;
  push @minavg,$minavg;
  push @max,$max;
  push @min,$min;
  push @ampl,$ampl;

  push @uenv,$uenv;
  push @lenv,$lenv;
  push @esig,$esig;
  push @env,$env;

  push @navg,$navg;
  push @nmu,$nmu;
  push @nerr,$nerr;
  push @ndev,$ndev;

  push @pavg,$pavg;
  push @pmu,$pmu;
  push @perr,$perr;
  push @pdev,$pdev;

  }

  return (\@avg,\@wmax,\@wmin,\@wmed,
          \@maxavg,\@minavg,\@max,\@min,\@ampl,
          \@uenv,\@lenv,\@esig,\@env,
          \@navg,\@nmu,\@nerr,\@ndev,
          \@pavg,\@pmu,\@perr,\@pdev
  );

# }}}  
}

# standard statistical values :
# min,max,mean
# sdev,variance,sigma
# mid,median,MAD
sub stats { # assume array is sorted ...
  my @sdata  = @_;
  my $n = scalar(@sdata);
  #printf "n: %u \n",$n;
  my $min = $sdata[0];
  my $max = $sdata[-1];
  #printf " min: %g\n",$min;
  my $med0 = $sdata[($n-1)/2];
  my $med1 = $sdata[($n+0)/2];
  my $med = ($med0 + $med1)/2;
  #printf " med: %g (#%g,#%g)\n",($med0+$med1)/2,($n-1)/2,($n+0)/2;
  my $mid = ( $min + $max ) / 2;
  #printf " mid: %g\n",$mid;
  #printf " max: %g\n",$max;
  
  my ($sum,$ns) = (0,0);
  # mean (PASS 1)
  foreach (@sdata) {
    my $value = $_ + 0.0;
    $sum += $value;
    $ns++;
  }
  my $mean = ($ns)?$sum/$ns:$sum;
  # variance (PASS 2)
  my $sum2 = 0;
  foreach (@sdata) {
     my $error = $_ - $mean;
     $sum2 += $error**2;
  }
  my $var = $sum2/$n;
  # standard deviation
  my $sigma = sqrt($var); # biased
  my $pz = ($n>75) ? $n : ($n>1) ? $n-1 : 1 ; # population unbiased size
  my $sdev = sqrt($sum2/$pz); # unbiased std deviation

  # median absolute deviation (PASS 3)
  my @adev = sort { $a <=> $b} map { abs($_ - $med); } @sdata;
  my $mad0 = $adev[($n-1)/2];
  my $mad1 = $adev[($n+0)/2];
  my $mad = ($mad0 + $mad1)/2;
  
  return ($min,$mean,$max, $sdev,$var,$sigma, $mid,$med,$mad);

}

sub cdf { # cummulative distribution function (pdf's integral)
  my $sdata = shift;
  my @x = (); # samples
  my @rug = (); # pdf rug plot
  my @cdf = ();
  my %frq = ();
  my $x = 0;
  my $cdf = 0;
  foreach (@$sdata) {
    my $value = $_ + 0.0;
    unless ($frq{$value}++) {
      # note: as population is sorted the hashing is not mandatory!
      # TBD:
      # (previous value would be the same if there is a multiple occurence)
      push @x, $value;
      $x++;
    }
    $cdf += 1; # quantile function ...
    $cdf[$x-1] = $cdf; #= $frq{$value};
    $rug[$x-1] = $frq{$value};
  }
  return (\@x,\@rug,\@cdf);
}

sub pdf {
 my ($x,$cdf) = @_;
 # differenciate cdf to compute pdf 
  my @pdf = ();
  my @x2 = (); # for re-phasing dcdf/dx
  foreach (1 .. $#$x) {
    my $dcdf =  ($cdf->[$_] - $cdf->[$_-1]) / ($x->[$_] - $x->[$_-1]);

    my $x2 = ($x->[$_] + $x->[$_-1]) / 2;
    push @pdf, $dcdf;
    push @x2, $x2;
  }
  return (\@x2,\@pdf);
}

# kernel : non negative function that integrate to one and have a mean zero
sub kde { # Kernel density estimator
  my ($x,$d,$K,$h) = @_; # x,\@data,\&kernel,$smoothing
  my $n = scalar @$d;
  my $fh = &sum( map { &$K( ($x - $d->[$_]) / $h ) } (0 .. $n-1) ) / ($n*$h);
  return $fh; 
}	
# ----------------------------------------------------
sub deviation { # compute deviation to a model reject point that are off by sigma
  my ($estim,$model,$sigma) = @_;
  my $n = scalar(@$model);
  $sigma = 6 unless defined $sigma;
  my ($sum2,$ns) = (0,0);
  foreach my $i (0 .. $n-1) {
    my $er2 = ($estim->[$i] - $model->[$i])**2;
    if ( $i < 36 || $sum2 == 0 || ($er2 * $i) <= ($sigma * $sum2) ) { # skip spikes 
      $sum2 += $er2;
      $ns++;
    } else { # reject ...
      my $var = ($ns) ? $sum2/$ns : $sum2; 
      printf "%u data=%f er2 =%f, sum2=%f thres = %g * %f = %f\n",$i,$estim->[$i],$er2,$sum2,$sigma,$var,$sigma*$var if $dbug;
    }
  }
  #my $var = $sum2/$n;
  my $pz = ($ns>75) ? $ns : ($ns>1) ? $ns-1 : 1 ; # population unbiased size
  my $sdev = sqrt($sum2/$pz); # unbiased std deviation
  print "sdev = $sdev\n" if $dbug;
  return $sdev;
}
# ----------------------------------------------------


1; # $Souce: /my/perl/modules/STATS.pm $
