#!perl
# vim: ts=2 sw=3 et noai nowrap

package Brewed::Misc;
# Note:
#
#  Miscelleaneous routines
#
#  usage:
#  BEGIN { $SITE=$ENV{SITE}; push @INC,"$SITE/lib" }
#  use LSS::Misc;  
#
# -- Copyright Lemoptix, 2013,2014,2015 --
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
our $VERSION = sprintf "%d.%02d", q$Revision: 0.0 $ =~ /: (\d+)\.(\d+)/;
our ($State) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------
my $path = substr(__FILE__,0,rindex(__FILE__,'/'));
push @INC,"$path/lib";
my $SITE=$ENV{SITE}|| "$path/../..";
# ----------------------------------------------------

use constant {
PIo4 => atan2(1,1),
PIo2 => atan2(1,0),
PI => atan2(0,-1),
_2PI => 2*atan2(0,-1)
};
my $_1yr = 8765.81277; # hours in a year (~ 365.25 * 24 = 8766)


# ----------------------------------------------------
# spline: time,@knots |-> @position
#
# spline(s,[knots]) returns position verctor (p,v,a) from a normalized time (s)
sub spline {
  my ($s,$K) = @_; # s: time in [0..1] space, K: knot=(start,stop)
  my $n = 5;
  # compute time vector s^5,^s^4,s^3 ...
  my $S = [map { $s ** ($n - $_); } (0 .. $n)];
  # hermite polynom
  my $P = [&pcoef(@{$K})];
  # first derivative
  my $dP = [map { ($n-$_) * $P->[$_]; } (0 .. $n-1)]; # dP/dt
  # second derivative
  my $d2P = [map { ($n-1-$_) * ($n-$_) * $P->[$_]; } (0 .. $n-2)]; # d2P/dt2

  # compute position ...
  my $p = 0; for my $i (0 .. $n) { $p += $P->[$i] * $S->[$i]; }
  # compute velocity ...
  my $v = 0; for my $i (0 .. $n-1) { $v += $dP->[$i] * $S->[$i+1]; }
  # compute acceleration ...
  my $a = 0; for my $i (0 .. $n-2) { $a += $d2P->[$i] * $S->[$i+2]; }

  return $p,$v,$a;
}

# ----------------------------------------------------
# polynomial spline coefs ...
# pcoef: @knots |-> @coefs
sub pcoef { # hermite polynom coefs. (port of splines.gpl)
  # polynom: a.s^5 + b.s^4 + c.s^3 + d.s^2 + e.s^1 + f.s^0
  my ($p0,$v0,$a0,$p1,$v1,$a1) = @_;
  # s=0 : f = p0, e = v0, 2d = a0
  #
  # s=1 :
  # Eq1: a + b + c = k1
  # Eq2: 5a + 4b + 3c = k2
  # Eq3: 20a + 12b + 6c = k3
  #
  # Eq4: b + 2c = k4 = 5.k1 -k2
  # Eq5: 8b + 14c = 20.k1 - k3
  #
  # Eq6: 2c = k6 = 8.k4 - k5
  #
  # where k1 = p1 - f - e - d
  #       k2 = v1 - e - 2d
  #       k3 = a1 - 2d
  #

  my $k1 =  ($p1 - $p0) - $v0 - $a0/2;
  my $k2 = $v1 - $v0 - $a0;
  my $k3 = $a1 - $a0;

  my $k4 =  5.0 * $k1 - $k2;
  my $k5 = 20.0 * $k1 - $k3;
  my $k6 =  8.0 * $k4 - $k5;


  my $f = $p0;
  my $e = $v0;
  my $d = $a0 / 2.0;
  my $c = $k6 / 2.0;
  my $b = $k4 - $k6;
  my $a = $k1 - $b - $c;
  if (0 && $dbug) {
  printf "start= (%d,%.1f,%.2f) -> stop= (%d,%.2f,%g):\n",$p0,$v0,$a0,$p1,$v1,$a1;
  printf "       (k1,k2,k3) = %+.1f %+.1f %+.1f\n",$k1,$k2,$k3;
  printf "       (k4,k5,k6) = %+.1f %+.1f %+.1f\n",$k4,$k5,$k6;
  printf "polynom: [%.2f,%.2f,%.2f,%.2f,%.2f,%.2f]\n",$a,$b,$c,$d,$e,$f;
  }

  return ($a,$b,$c,$d,$e,$f);
}
# ----------------------------------------------------
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
  return ($fpath,$basen,$ext);

  }

}
# ----------------------------------------------------
sub pngdump {
  my $kst2 = 'kst2.exe'; #  die if ! -e $kst2;
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
  my $pngfile = "$fpath/${basen}_${stamp36}.png";
  system sprintf '"%s" --landscape "%s" --png "%s"',$kst2,$kstfile,$pngfile;
  $pngfile = ${stamp36} unless -e $pngfile;

  return $pngfile;
}
# ----------------------------------------------------
sub color {
  my $colors = [qw{red orange yellow green aquamarine blue violet indigo pink}];
  my $n = scalar(@$colors);
  my $key = int ($_[0]) % $n; # modulo !
  my $color = $colors->[$key];
  return $color;
}
# ----------------------------------------------------
our @diceware = ();
sub word13 { # a word from Diceware list
  my $i = shift;
  my $dw = scalar @diceware;
  if ($dw < 1) {
    my $dico = $SITE.'\etc\Diceware7776.txt';
    $dico = $path.'/Diceware7776.txt' unless -e $dico;
    local *DIC; open DIC,'<',$dico or die "$dico $!";
    local $/ = "\n"; our @diceware = map { chomp($_); $_ } <DIC>;
    close DIC;
    $dw = scalar @diceware;
  }
  return $diceware[$i%$dw];
}
# ----------------------------------------------------
sub get_md5 ($) {
 use Digest::MD5 qw();
 my $msg = Digest::MD5->new or die $!;
 local *F;
 open F, "<$_[0]" or do { warn qq{"$_[0]": $!}; return undef };
 binmode(F) unless $_[0] =~ m/\.txt$/;
 $msg->addfile(*F);
 close F;
 my $digest = uc( $msg->hexdigest() );
 return $digest; #hex form !
}
# ----------------------------------------------------
sub githash {
 my $txt = join'',@_;
 use Digest::SHA1 qw();
 my $msg = Digest::SHA1->new() or die $!;
    $msg->add(sprintf "blob %u\0",length($txt));
    $msg->add($txt);
 my $digest = lc( $msg->hexdigest() );
 return $digest; #hex form !
}
# ----------------------------------------------------
sub mid {
  my @d = sort { $a <=> $b } @_;
  return ($d[0] + $d[-1] ) / 2;
}
sub min { (sort { $a <=> $b } @_ )[0] }
sub max { (sort { $b <=> $a } @_ )[0] }
sub med { (sort { $b <=> $a } @_ )[$#_/2] }
sub sum { my $sum = 0; foreach (@_) { $sum += $_; } return $sum; }

sub avg { my ($sum,$n) = (0,0);  foreach (@_) { if(defined $_) { $sum += $_;$n++ } } return ($n)?$sum/$n:$sum; }
# ----------------------------------------------------
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
sub stamp36 {
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime(int $_[0]))[0..7];
  my $yhour = $yday * 24 + $hour + ($min / 60 + $sec / 3600);
  my $stamp = &base36(int($yhour/$_1yr * 36**4)); # 18 sec accuracy
  return $stamp;
}
sub swat { # swatch time !
  my $tod = ($_[0]+3600-1)%(24*3600); # time of the day (16.4-bit)
  return $tod * 1000 / (24*3600);
}
sub hdate { # return HTTP date (RFC-1123, RFC-2822) 
  my $DoW = [qw( Sun Mon Tue Wed Thu Fri Sat )];
  my $MoY = [qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec )];
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday) = (gmtime($_[0]))[0..6];
  my ($yr4,$yr2) =($yy+1900,$yy%100);
  my $date = sprintf '%3s, %02d %3s %04u %02u:%02u:%02u GMT',
             $DoW->[$wday],$mday,$MoY->[$mon],$yr4, $hour,$min,$sec;
  return $date;
}
# ----------------------------------------------------

1;
