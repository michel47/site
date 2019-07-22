#!perl

package Brewed::Solver;
require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw(solver);
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
my %seen = (); # hash for random walk ...

sub walk { # return a value between [0 and 1]
 my ($type,$r) = @_;
 my $pos = undef;
 if ($type eq 'swing') { # swing walk!
   if ($r > 0) {
     my $aa = int(log(2 * ($r+1) - 1) / log (2) ); # number of swing
     my $na = (1<<($aa-1)); # previously seen points
     my $ja = ($r - $na); # reminder in local pass
     $pos = ($aa%2) ? ($na - $ja - 0.5)/$na  : ($ja + 0.5)/$na; # [0,1[
   } else {
     $pos = 1;
   }
 } elsif ($type eq 'hype') {
   $pos = 1/($r+1);
 } elsif ($type eq 'grey') {
   use Brewed::HEIG qw(b2grey);
   my $g = &b2grey($r);
   my $l = int( (($g > $r) ? log(2*$g-1) : log(2*$r-1) ) / log(2));
   $pos = $g / (1<<$l);
 } elsif ($type eq 'random') {
   $pos = rand(1);
   while ($seen{$pos}++) {
     $pos = rand(1);
   }
 } elsif ($type eq 'farey') {
 } else {
     $pos = rand(1);
 }
 return $pos;

}
# ----------------------------------------------------
# 2D walk ...
# -----------------------------------
sub serpentine {
  my ($algo,$x,$y) = @_;
  my @curve = ();
  my $p =0;
  if ($algo == 0) { # normal raster order
  foreach my $j (0 .. $y-1) {
  foreach my $i (0 .. $x-1) {
    #print "$p $i $j\n";
    $curve[$p] = [$i,$j];
    $p++;
  } # for i
  } # for j
  } # if algo
  
  return @curve;
}
# -----------------------------------

# parameter accessible from outside to tune solver:
our $acc = 1.2; # acceleration
our $kstep = 100; # intial step accuracy control (step=initial_value/kstep)
our $minstep = 1E-99;  # step min bound

sub solver { # hill climber (numerical solver !)
  my $eq = shift;
  my ($p) = @_; # initial value

  my $best = $p;
  my $bestscore = $p;

  my $step = $p / $kstep;
  #my $minstep = 1E-99;
  #my $acc = 1.2; # acceleration ..
  my @c = (-$acc,-1/$acc,-1.8,-0.5001,1.0,0.5,+1/$acc,$acc);
  while (1) { # continous hill-climb
    my $s = &{$eq}($p); # current solution
    printf " eq(%s) = %g\n",$p,$s if $dbug;
    my $localbest = $p;
    my $localbestscore = abs($s);
    my $nstep = 0;

  foreach my $c (@c) {
    my $np = $p + $step * $c; # try out a neighboring points
    my $s = &{$eq}($np);
      printf " c=%+6.3g : eq(np=%g) = %g",$c,$np,$s if $dbug;
    if (abs($s) < $localbestscore) {
      $localbestscore = abs($s);
      $localbest = $np;
      $nstep = $step * $c; # adjust speed
      print "*" if $dbug;
    }
    print "\n" if $dbug;
  }
  if ($localbest == $p) { # nothing is better
    $step = - $step / 2;
  } else {
    $p = $localbest;
    $step = $nstep;
  }
  if ($localbestscore < $bestscore) {
    $best = $localbest;
    $bestscore = $localbestscore;
    printf " retain eq(%g) = %g <--\n",$best,$bestscore if $dbug;
  }
  last if ($bestscore == 0);
  last if ($best + $step == $best);
  last if (abs($step) < $minstep);
  }
  return $best;
}

# Landscape parameters 
sub initLand { # initialize landscape ...
  my ($seed,$m,$range) = @_;
  $seed = srand($seed);
  my @land = ();
  for (0 .. $m-1) {
    my @coef = (rand(1.0)); # ampl
    push @coef, map { rand($range) } (0,1); # mu
    push @coef, map { rand($range/2.0) } (0,1); # sdev
    push @coef, (rand(1.0) ); # corr
    $land[$_] = \@coef;
  }
  return \@land;
}

# bivariate Gaussian for Landscape Generation ...
sub bivGauss {
  my ($x,$y,$coef) = @_;
  my ($ampl,$mux,$muy,$sigx,$sigy,$corxy) = @{$coef};
  #my $A = $pi2*$sigx*$sigy*sqrt(1-$corxy**2);
  my $z =    ( ($x - $mux)/$sigx)**2
           - 2 * $corxy * ($x - $mux)*($y - $muy) / ($sigx*$sigy)
	   + ( ($y - $muy)/$sigy)**2;
  my $E =  $z / (2 * (1 - $corxy**2) ) ;
  my $fit = $ampl * exp(-$E); # / $A;
  return $fit;
}
sub fitness {
  my ($x,$y,$land) = @_;
  my $fitness = 0;
  my $scale = 0;
  my $m = scalar(@$land);
  for (0 .. $m-1) {
    $scale = $land->[$_][0] if ($land->[$_][0] > $scale);
    my $fit = &bivGauss($x,$y,$land->[$_]);
    $fitness = $fit if $fit > $fitness; # uses max fit
  }
  return $fitness/$scale;
}

sub ver { return $VERSION; }
1; # $Source: /my/perl/modules/developped/at/HEIG-VD/Solver.pm,v $
