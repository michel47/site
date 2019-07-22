#!perl
# vim: ts=2 et noai nowrap

package Brewed::HEIG;
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


# ----------------------------------------------------
# /!\ environment ... 
my $PROGRAM = $ENV{QSYNC} . '\programs';
$PROGRAM = 'c:\usr\programs' unless -d $PROGRAM;
$PROGRAM = 'X:\programs' unless -d $PROGRAM; # for GreenBadger ...
$ENV{PATH} = "$PROGRAM;".$ENV{PATH}; # 

my $kst2 = 'kst2.exe';
$kst2 = $PROGRAM.'\Kst-2.0.8\ia64\bin\kst2.exe' if (-e $PROGRAM.'\Kst-2.0.8\ia64\bin\kst2.exe');
$kst2 = $PROGRAM.'\Kst-2.0.8\bin\kst2.exe' if (-e $PROGRAM.'\Kst-2.0.8\bin\kst2.exe');
$kst2 = 'E:\programs\Kst-2.0.8\bin\kst2.exe' if (-e 'E:\programs\Kst-2.0.8\bin\kst2.exe');
$kst2 = '..\kst\bin\kst2.exe' if (-e '..\kst\bin\kst2.exe');

#$kst2 = 'C:\usr\tools\Kst-2.0.8\ia64\bin\kst2.exe' if (-e 'C:\usr\tools\Kst-2.0.8\ia64\bin\kst2.exe');
print "kst2: $kst2\n";

if (! -e $kst2) {
 print "PROGRAM: $PROGRAM\n";
 print "kst2: $kst2\n";
 my$ans=<STDIN>;
}
my $gplot = 'gnuplot.exe' ;
#my $gplot = 'c:\usr\local\gnuplot\bin\gnuplot.exe';

# ----------------------------------------------------
our $tic = $^T;
our $cnt = -1;
sub rate {
  my $time = time();
  my $elapsed = $time - $^T;
  my $rate;
  if ($time > $tic) {
    my ($i,$n) = @_;
    my $deltat = 27; # update every deltat ...
    my $duration = $time + $deltat - $tic;
    my $deltai = $i - $cnt;
       $deltai = 1 unless $deltai;
       $rate = $deltai / $duration;
    
    my $volume = 200; my $timebud = 3600*40*4.5*2/$volume;
    my $itmax = $rate * $timebud;
    printf "rate: %ff/m avg: %ff/m *** ETA: %.1fmin (itmax=%u) ~~ %.2fmin #%d <----------------- ***\n",
      $rate * 60,($n-$i)/$rate/60,$cnt/$elapsed*60,$itmax,$elapsed/60,$cnt;

    $tic = $time + $deltat;
    $cnt = $i;
  }
  return $rate;
}

# ----------------------------------------------------
sub csvload { # /!\ arrays need to be empty
  my $csv = shift;
  local *F; open F,'<',$csv or die $!;
  local $/ = "\n";
  my $header = <F>; chomp($header); $header =~ s/^#//o;
  #print "$csv: $header\n";
  my @names = split(',',$header);
  #printf "# %s\n",join',',@names;
  no strict 'refs';
  while (<F>) {
    chomp;
    my @values = split(/,/,$_);
    foreach (0 ..$#names) {
      push @{"main::".$names[$_]}, $values[$_];
    }
  }
}
# ----------------------------------------------------
sub csvdump { # csvdump($file,@List_of_ArrayNames_or_list_of_ArrayRefs);
  my $csv = shift;
  #printf "// ref0: %s ref1: %s\n",ref($_[0]),ref($_[1]);
  my @arrays = ();
  my @out = ();
  if (ref($_[0]) eq 'ARRAY') { # csvdump($file,\@data1,\@data2 ...)
     @arrays = @_;
     @out = ('x', map { "y$_"; } ( 0 .. $#arrays - 1) );
  } elsif (ref(\$_[0]) eq 'SCALAR' && ref($_[1]) eq 'ARRAY') { # csvdump($file,'y1 y2',\@data1,\@data2);
    my $label = shift;
    @out = split /[,\s+]/,$label;
    printf "label: %s\n",join',',@out if $dbug;
    @arrays = @_;

  } else { # csvdump($file,qw(y1 y2))
    no strict 'refs';
    @out = @_;
    @arrays = map { \@{"main::".$_} } (@out);
  }
  my $n = scalar @{$arrays[0]};
  local *F; open F,'>',$csv or die $!;
  local $\ = undef;
  print F '#i,',join(',',@out),"\n";
  foreach my $i (0 .. $n-1) {
    printf F '%u,',$i;
    printf F "%s\n",join',', map { sprintf '%g',${$arrays[$_]}[$i]; } ( 0 .. $#arrays );
  }
  close F;
  return $?;
}

# ----------------------------------------------------
sub pngdump {
  use Brewed::PERMA qw(basen);
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
  my $pngfile = "$fpath/${basen}_${stamp36}.png";
  system sprintf '"%s" --landscape "%s" --png "%s"',$kst2,$kstfile,$pngfile;
  $pngfile = ${stamp36} unless -e $pngfile;

  return $pngfile;
}
# ----------------------------------------------------
sub plot { # using gnuplot to display 2D curves ...
  my ($x,$y) = @_;
  my $n = $x->nelem;
  my $pid;
  our $pcnt;

  my $tmp = $ENV{TEMP} || 'c:/var/tmp';
  my $file = "$tmp\\pdata$pcnt.dat"; $pcnt;
  my $png = "$tmp\\pdata$pcnt.png"; $pcnt;
  local *F; open F,'>',$file or warn $!;
  foreach (0 .. $n-1) {
    my $xv = $x->slice($_)->sclr;
    my $yv = $y->slice($_)->sclr;
    printf F "%s\t%s\n",$xv,$yv;
  }
  close F;
  $pid = open(GP, '| "gnuplot.exe" 2>&1 '); 
  my ($xmin,$xmax) = $x->minmax;
  syswrite(GP, "set xrange [$xmin : $xmax]\n");
  syswrite(GP, "set autoscale y\n");
  syswrite(GP, "set title 'plot $pcnt'\n");
  syswrite(GP, sprintf "plot '%s' using 1:2 with lines\n",$file);  
  sleep 1;
  #my $ans = <STDIN> if $dbug;
  syswrite(GP, sprintf "set terminal png; set output '%s'; replot;\n",$png);
  syswrite(GP, "quit\n");
  system $png;
  return $pcnt++;
}
# ----------------------------------------------------
sub matrix_display { # display array
  for my $row (@{$_[0]}) {
    printf "[%s]\n",join',',map{ sprintf '%5.1f',$_ } @{$row};
  }
}

sub transpose {
  my @transposed = ();
  for my $row (@{$_[0]}) {
    foreach my $column (0 .. $#{$row}) {
       push @{$transposed[$column]}, $row->[$column];
    }
  }
  return \@transposed;
}

sub matrix_multiply {
  my ($mat1,$mat2)=@_;
  my ($r1,$c1)=($#{$mat1},$#{$mat1->[0]});
  my ($r2,$c2)=($#{$mat2},$#{$mat2->[0]});
  if (1 || $dbug) {
    printf "m1: %ux%s\n",$c1+1,$r1+1;
    printf "m2: %ux%s\n",$c2+1,$r2+1;
    printf "p: %ux%s\n",$c2+1,$r1+1;
  }
  die "matrix 1 has $c1+1 columns and matrix 2 has $r2+1 rows>" 
      . " Cannot multiply\n" unless ($c1==$r2);

  my $product = undef;
  for my $i (0 .. $r1) {
    for my $j (0 .. $c2) {
      my $sum=0;
      for my $k (0 .. $c1) {
        $sum+=$mat1->[$i][$k]*$mat2->[$k][$j];
        #printf "(%u.%u,%u): + %5.1f * %2g = %4g : sum=%g\n",
        #$i,$j,$k,$mat1->[$i][$k],$mat2->[$k][$j],
        #$mat1->[$i][$k]*$mat2->[$k][$j],
        #$sum;
      }
      $product->[$i][$j]=$sum;
    }
  }
  $product;
}
# ----------------------------------------------------
sub sumprod { 
 my $coef = shift;
 my @data = @_;
 my $acc = 0;
 my $nbt1 = scalar(@{$coef}) - 1;
 foreach my $i (0 .. $nbt1) {
   my $prod = $coef->[$i] * $data[$i];
   $acc += $prod;
   printf "i=%u c*x = %g * %g = %g a=%g\n",$i,$coef->[$i],$data[$i],$prod,$acc if $dbug;
 }
 return $acc;
}


# ----------------------------------------------------
sub timeout {
 my $f = shift;
 my $timeout = $_[0];
 eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm $timeout;
        &$f;
        alarm 0;
    };


}

# ----------------------------------------------------
sub dircut {
  my $dir = shift;
  $dir =~ s/^[a-z]://io;
  $dir =~ y,\\,/,;
  $dir =~ s,/[\.\d]+[_ ],/,g;
  $dir =~ s,/([^/])[^/]*,/\1,g;
  return $dir;
}
# ----------------------------------------------------
sub nonl {
  my $s = shift;
  $s =~ s/\s*\r?\n/\\n/g;
  return $s;
}
# ----------------------------------------------------
#use Bencode qw/bencode/;
#my $bcode = bencode($db);
#open F,'>',"$bname.b";print F $bcode; close F;
sub load_bfile {
  my $f = shift;
  local *F; open F,'<',$f or warn $!;
  local $/ = undef;  my $bcode = <F>; close F;
  use Bencode qw/bdecode/;
  #print "b: $bcode\n";
  my $db = &bdecode($bcode);
  return $db;
}
# ----------------------------------------------------

sub clip { my $x = shift; ($x<-1) ? -1 : ($x>1) ? 1 : 3/2 * ($x - $x**3/3); }
sub sgn { $_[0]>0?1:($_[0]<0)?-1:0 }
sub compare {
  my ($sig,$state,$ref,$hyst) = @_;
  my $thres = $ref + ( ($state) ? -$hyst : +$hyst );
  return ($sig > $thres) ?  1 : ($sig < $thres) ? 0 : $state;
}
# ----------------------------------------------------
# interp functions [0;1[
sub interp { (3 * $_[0]**2 - 2 * $_[0]**3); }
# sigmoidal curves
sub sigmoid { # slope a 0 at inflection : lambda/4
  my ($lambda, $x) = @_;
  return 1/(1+ exp(- $lambda * $x));
}
# ----------------------------------------------------
# logistic curves
# 4P:  f(x)= ((A-D)/(1+((x/C)^B))) + D
#
# 5P:  f(x)= A + (D/(1+(X/C)^B)^E)
#  A is minimum asymptote
#  B is the Hill slope
#  C is inflexion point
#  D is maximum asymptote
#  E is asymmetry factor
#
sub f4PL { (($_[1]-$_[4])/(1+(($_[0])/$_[3])**$_[2])) + $_[4]; }
sub f5PL { ($_[1] + ($_[4]/(1+(($_[0])/$_[3])**$_[2])**$_[5])); }
# ----------------------------------------------------




# -----------------------------------
# Interpolation Kernel ...
#
sub sample {
  my ($sample,$n) = @_; # \@data,nsample
  # input sample : n
  # output sampled : ns
  my $ns = $#$sample + 1;

  # B = 1,   C = 0   - cubic B-spline
  # B = 1/3, C = 1/3 - recommended
  # B = 0,   C = 1/2 - Catmull-Rom spline
  my ($B,$C) = (2.5,-0.8);
  my $P = 4; # range;

  my @data = ();
  for my $xo (0 .. $n-1) {
    # interpolate the values at $xo
    my $x = $ns * $xo / ($n-1);
    my $xi = int($x+0.4999);
    my $dx = $x - $xi;
    # compute Mitchell coef ...
    my $coefs = [map  { &mitchell($xi,$x-$_,$P,$B,$C) } (-2,-1,0,+1,+2) ];
    my @buffer = map { $sample->[$x-$_] } (-2,-1,0,+1,+2);
    my $y = &sumprod($coefs,@buffer);
    push @data, $y;
  }  
  return \@data;
}
sub taps { # tap coeficients :
 my ($dx,$interp,$nt) = @_; # offset,interpFunc,number of taps
 my $n2 = int( $nt / 2); # number of tap/2
 my @coefs = ();
 for (-$n2 .. $n2) {
   push @coefs, &$interp($dx-$_);
 }
 return \@coefs;
}

#
# from SIGGRAPH'88 :
# "Reconstruction Filters in Computer Graphics",
# Don P. Mitchell, Arun N. Netravali
# Computer Graphics, Volume 22, Number 4, August 1988
#
# B = 1,   C = 0   - cubic B-spline
# B = 1/3, C = 1/3 - recommended
# B = 0,   C = 1/2 - Catmull-Rom spline
sub mitchell {
 my ($xx,$x0,$P,$B,$C) = @_; # position,offset,scale,B,C 
 #print "mitchell(xx=$xx, x0=$x0, B=$B, C=$C)\n";
 my $x = abs($xx - $x0)*4/$P;
 my $k =  (($x < 1) ?
           (12 - 9*$B - 6*$C) * $x**3 +  
           (-18 + 12*$B + 6*$C) * $x**2 +
           (6 - 2*$B) :
         ($x < 2) ?
           (-$B -6*$C)  * $x**3 + (6*$B + 30*$C) * $x**2 +
           (-12*$B -48*$C) * $x + (8*$B + 24*$C) : 0) / 6;
 return ($k);
}
# -----------------------------------
sub bicubic { # cubic sync approx.
  my ($xx,$x0,$P,$a) = @_; # a from -0.5, -0.75
  my $x = abs($xx - $x0)*4/$P;
  my $k = ($x <= 1) ? ($a + 2) * $x**3 - ($a + 3) * $x**2 + 1 :
          ($x < 2) ? $a*$x**3 - 5*$a*$x**2 + 8*$a*$x - 4*$a : 0;
  return $k;
}
# -----------------------------------
sub binomial { (abs($_[0])<=1)? 1 - (3 * $_[0]**2 - 2 * abs($_[0])**3) : 0; }
# -----------------------------------
# Smoothing Kernel / Mollifier function ...
sub unif { (abs($_[0])<=1) ? 1/2 : 0; }
sub triang { (abs($_[0])<=1) ? 1-abs($_[0]): 0; }
sub epanechnikov { (abs($_[0])<=1) ? 3/4*(1-$_[0]**2) : 0; }
sub quartic { (abs($_[0])<=1) ? 15/16*(1-$_[0]**2)**2 : 0; }
sub triweight { (abs($_[0])<=1) ? 35/32*(1-$_[0]**2)**3 : 0; }
sub tricube { (abs($_[0])<=1) ? 70/91*(1-abs($_[0])**3)**3 : 0; }
sub gauss { exp(-$_[0]**2/2)/sqrt(2*atan2(0,-1)); } # mean=0 sdev=1
sub cosine { (abs($_[0])<=1) ? atan2(1,1)*cos(atan2(0,1)*$_[0]) : 0; }
sub logistic { 1/(exp($_[0]) + 2 + exp(-$_[0])); }
sub silverman { exp(-abs($_[0])/sqrt(2))/2 * sin(abs($_[0])/sqrt(2) + atan2(1,1) ); }
sub bump { abs($_[0])<1 ? exp(-1/(1 + $_[0]**2)) : 0; } # gaussian scaled into the unit disk !
sub bumpab { abs($_[0])<1 ? exp(-1/($_[0]-0.0) + 1/($_[0] - 1.0) ) : 0 }
sub bumpk {
  my $x = abs(shift);
  if ($x < 1) {
	  return exp(-1/(1-$x**$_[0]));
  } else {
    return 0;
  }
}

# ...
sub weight {
  my ($D,$r) = @_; # \&weightFunc,$kernelRadius
  my $c = int (9.1 * $r +0.5) ; # consider only sample within c from x
  my $w = [&$D(0)];
  my $n = 1;
  for my $dx (1 .. $c) {
    my $wi = &$D($dx/$r); # distance from x to data-sample
    #printf "D[%u/%g=%f] = %g\n",$dx,$r,$dx/$r,$wi;
    $w->[$dx] = $wi; # caching for later use :)
    $n += 2*$wi;
  }
  return ($w,$n);
}
sub fsmooth { # fast kernel smoothing 
  my ($x,$sample,$weight) = @_; # x,\@data,\&weightFunc
  my $y;
  my $xm = int($x + 0.5);
  my $sum = $weight->[0]*$sample->[$xm]; # central tap !
  my $n2 = int( $#$weight / 2); # number of tap/2
  for (1 .. $n2) { # assumed symetry !
    #my $prod = ($sample->[$xm-$_] + $sample->[$xm+$_]) * $weight->[$_]; $sum += $prod;
    $sum += ($sample->[$xm-$_] + $sample->[$xm+$_]) * $weight->[$_];
  }
  return $sum;
}
sub ksmooth { # kernel smoothing 
  my ($x,$sample,$D,$r,$W,@option) = @_; # x,\@data,\&weightFunc,$kernelRadius,$window, @options
  my ($sum,$n) = (0,0);
  for my $xi (0 .. $#$sample) {
    next if abs($xi - $x) > $W * $r;
    my $yi = $sample->[$xi];
    my $wi = &$D(($xi - $x)/$r,@option); # distance from x to data-sample
       $sum += $wi * $yi;
       $n += $wi;
       #printf "wi.y[%u]=%+8.6f * %+8.6f => %+8.6f \n",$xi,$yi,$wi,$sum/$n if ($wi > 0.1);
  }
  my $y = ($n) ? $sum / $n : $sum;
  return $y;
}
# -----------------------------------
# other kernel to study 
#
# abs(logistic) 
# smoothing spline
# Loess
# Hann windows ...
# Hamming
# see http://www.mikroe.com/chapters/view/72/chapter-2-fir-filters/
#


sub sgn {
  ($_[0] > 0) ? +1 : ($_[0] < 0) ? -1 : 0;
}

# ----------------------------------------------------
# trigonometry functions 
sub asin (;@) { atan2 ($_[0], sqrt(1 - $_[0] * $_[0])); }
sub acos (;@) { atan2 (sqrt(1 - $_[0] * $_[0]), $_[0]); } 
sub tan (;@) {
    my $theta = shift;
    return sin($theta)/cos($theta);
}
# ----------------------------------------------------
sub gcd { my ($a, $b) = @_; while ($a) { ($a, $b) = ($b % $a, $a) } $b }
sub lcm { my ($a, $b) = @_; ($a && $b) and $a / gcd($a, $b) * $b or 0 }
# ----------------------------------------------------
sub uniq (;@) {
  # uniquify : # @target -> @uniq'd
  my %u = ();
  my @uniq = grep {defined} map {
    if (exists $u{$_}) { undef; } else { $u{$_}=undef;$_; }
  } @_;
  undef %u;
  return @uniq;
}
# ----------------------------------------------------
# series of interpolating functions, varying coeficient 
sub kcoef { # piva (gear fonction ...)
  my $A = ord('a');
  my ($t,$T2,@data) = @_;
  my $np = scalar(@data);
  my $npo2 = int(($np-1)/2);
  my $kk = undef;
  # wrap arround before first timing ...
  push @data, ($data[0]+$T2,$data[1]);
  $t += $T2 if ($t < $data[0]);
  my $comment;
  foreach (reverse (0 .. $npo2)) {
    my $p = 2 * $_;
    my $n = $p + 2;
    my ($ta,$va) = @data[$p,$p+1];
    my ($tb,$vb) = @data[$n,$n+1];
       $vb = $va if (!defined $tb);
    if ($t > $ta) {
       my $s = ($tb>$ta) ? ($t - $ta) / ($tb - $ta) :
               ($ta>$tb) ? 0 : 1; # if ta>tb => 0, if ta=tb => 1, if ta<tb => 0~..1
       # ta -> tb
       $kk = $va + interp($s) * ($vb - $va);
       $comment = sprintf't%s=%9g < t < t%s=%9g (kk%u=%g ~ %g)',chr($A+$_),$ta,chr($A+1+$_),$tb,$_,$va,$vb;
       last;
    }
  }
  printf KK "t=%9g kk=%10g %30s #, %g,%g\n",$t,$kk,$comment,$t,$kk;
  return $kk;
}
# ----------------------------------------------------
sub ungrey { # grey to binary
   #  bi = gi ^ bi-1
   my $g = shift;
   my $b = $g; # binary results
   my $m = $g>>1; # mask
   while($m) {
      $b ^= $m;
      $m = $m>>1;
   }
   if ($dbug) {
      my $n = 5; # max size for b
      printf "%2u: 'g%s -> 'b%s %2u\n",$g,
      substr(unpack('B*',pack'n',$g),-$n),
      substr(unpack('B*',pack'n',$b),-$n),
      $b;
   }
   return $b;
}
sub grey { # binary to grey
   my $b = shift;
   my $b1 = $b>>1;
   my $xor = $b ^ $b1;

   if (0 && $dbug) {
      my $n = 5; # max size for b
      printf "%2u: %s x %s -> %s %2u\n",$b,
       substr(unpack('B*',pack'n',$b),-$n),
       substr(unpack('B*',pack'n',$b1),-$n),
       substr(unpack('B*',pack'n',$xor),-$n),
       $xor
   }
   return $xor;
}

# ----------------------------------------------------
sub b2grey { # binary to grey code (use in MEMs drive interpolation)
 my $b = shift;
 #my $n = (defined $drivez) ? $drivez : 11;
 my $n = 11;
 my $b0 = $b % (1<<$n);
 my $b1 = $b0>>1;
 my $xor = $b0 ^ $b1;
 return $xor;
}
sub nsb { # Number of set bits
# See: http://aggregate.org/MAGIC/
 my $i = shift;
 $i -= (($i >> 1) & 0x55555555);
 $i = ($i & 0x33333333) + (($i >> 2) & 0x33333333);
 return ((($i + ($i >> 4)) & 0x0F0F0F0F) * 0x01010101) >> 24;
}
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
sub polyplot {
  my $P = shift;
  my $n = scalar (@{$P}) - 1;
  my $dP = [map { ($n-$_) * $P->[$_]; } (0 .. $n-1)]; # dP/dt
  my $d2P = [map { ($n-1-$_) * ($n-$_) * $P->[$_]; } (0 .. $n-2)]; # d2P/dt2

  #my $poly = sprintf '\\[%s\\]',join',',map { sprintf '%.2f',$_ } @{$P};
  my $poly = ''; for my $i (0 .. $n) { $poly .= sprintf '%+.2f.s^%u ',$P->[$i],$n-$i; }
  local *F; open F,'>','polyplot.csv' or die $!;
  print F "s,p,v,a\n";
  for (0 .. 1000) {
    my $s = $_/1000;
    my $S = [map { $s ** ($n - $_); } (0 .. $n)]; # time vector s^n,s^n-1 ...
    my $p = 0; for my $i (0 .. $n) { $p += $P->[$i] * $S->[$i]; }
    my $v = 0; for my $i (0 .. $n-1) { $v += $dP->[$i] * $S->[$i+1]; }
    my $a = 0; for my $i (0 .. $n-2) { $a += $d2P->[$i] * $S->[$i+2]; }
    printf F "%f,%g,%g,%g\n",$s,$p,$v,$a;
  }
  close F;
  #use YAML::Syck; print YAML::Syck::Dump(\%INC);
  my $this = __FILE__;
  my $dir = substr($this,0,rindex($this,'/'));
  my $kstfile = $dir . '/polyplot.kst';
  return unless -e $kstfile;
  open F,'<',$kstfile or die $!;
  local $/ = undef; my $buf = <F>; close F;
  $buf =~ s/%POLY%/$poly/;
  open F,'>','polyplot.kst';
  print F $buf;
  close F;
  system sprintf '"%s" -F polyplot.csv polyplot.kst --png polyplot.png',$kst2;

  system "start polyplot.png" if $dbug;

  return $?;
}
# ----------------------------------------------------
sub read_lnk {
  use Win32::Shortcut;
  my $link = Win32::Shortcut->new();
  $link->Load($_[0]);
  #print "Shortcut to: $link->{'Path'} $link->{'Arguments'} \n";
  my $cmd = undef;
  if ($link->{'Arguments'}) {
    $cmd = join' ',$link->{'Path'},$link->{'Arguments'};
  } else {
    $cmd = $link->{'Path'};
  }
  $link->Close();
  return $cmd;
}
# ====================================================
sub pause {local$|=1;local$/="\n";print'...';my$a=<STDIN>}

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

# ----------------------------------------------------
sub flush { my $h = select($_[0]); my $af=$|; $|=1; $|=$af; select($h); }
# ----------------------------------------------------
sub cptime ($$) {
 my ($src,$trg) = @_;
 my ($atime,$mtime,$ctime) = (lstat($src))[8,9,10];
 #my $etime = ($mtime < $ctime) ? $mtime : $ctime;
 utime($atime,$mtime,$trg);
}
# ----------------------------------------------------
sub copy ($$) {
 my ($src,$trg) = @_;
 local *F1, *F2;
 return -1 unless -r $src;
 return -2 unless (! -e $trg || -w $trg);
 open F2,'>',$trg or warn "-w $trg $!"; binmode(F2);
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
# ----------------------------------------------------
sub update_copy {
  my $src = shift;
  my $dst = shift;
	local *F; open F,'<',$src or die $!;
	local $/ = undef; my $buf = <F>; close F;
	foreach my $k (sort keys %{$_[0]}) {
		 $buf =~ s/\%$k\%/$_[0]->{$k}/g;
	}
	open F,'>',$dst or die $!;
  print F $buf;
	close F;
  return $?;
}
# ----------------------------------------------------
sub inplace_update {
  my $f = shift;
	local *F; open F,'+<',$f or die $!;
	local $/ = undef;
	my $buf = <F>;
	foreach my $k (sort keys %{$_[0]}) {
		 $buf =~ s/%$k%/$_[0]->{$k}/g;
	}
	seek(F,0,0); # inplace substitution !
	print F $buf;
	truncate(F,tell(F));
	close F;
	return $?;
}
# ----------------------------------------------------
sub findpath {
  my $es = 'es.exe';
  $es = '../bin/es.exe' if (-e '../bin/es.exe');

  my $query = shift; # join' ', map { sprintf '"%s"',$_ } @_;
  my $cmd = sprintf '"%s" -i -n 2 %s "!\QNAP" |',$es,$query;
  open my $es,$cmd or warn $!;
  local $/ = "\n";
  my $path = <$es>; chomp $path;
  print "path: $path\n" if ($::dbug || $dbug);
  while (<$es>) { print " $_" if ($::dbug || $dbug) }
  close $es;
  return undef unless -e $path;
  return $path;
}
# ----------------------------------------------------
sub wiki2yml {
  my $url = @_[0];
  my $page = get_http($url);
  my $body = substr($page,index($page,"\r\n\r\n")+4); # skip header
  my ($start,$stop) = (index($body,'<!-- start content -->'),
                 index($body,'<!-- end content -->') );
  my $content = substr($body,$start,$stop-$start); # isolate content
     #$content =~ s,<h\d>.*</h\d>,,go; # remove headers h1,h2,...
  my ($start,$stop) = (index($content,'<textarea name="wpTextbox1" '),
                 index($content,'</textarea>') );
  my $yml = substr($content,$start,$stop-$start); # extract yml data as captured by user.
     $yml =~ s/<[^>]+>//go; # remove html tags
     $yml =~ s/&quot;/"/go; # replace specials
     $yml =~ s/&gt;/>/go;
     $yml =~ s/&lt;/</go;
     # filter headers, and other comments
     $yml = join"\n",grep !/^[#=-]|^$/, split"\n",$yml;
     return $yml;
}
# ----------------------------------------------------
sub get_http {
  my $socket;
  my $agent = $0;
  use Socket;

  my ($url) = @_;
  $url =~ s/https/http/;
  my ($host,$document) = ($url =~ m{http://([^/]+)(/.*)?}); #/#
  my $port = 80;
  $document = '/' unless $document;
  #print "$host $port\n";
  my $http_proxy = (exists $ENV{http_proxy} || $ENV{http_proxy} ne '') ? $ENV{http_proxy} : "$host:$port";
  my ($server,$port) = ($http_proxy =~ m{(?:http://)?([^/]+):(\d+)});
  printf "// contacting %s:%s\r\n",$server,$port if $dbug;

  my $iaddr = inet_aton($server);
  my $paddr = sockaddr_in($port, $iaddr);
  my $proto = (getprotobyname('tcp'))[2];
  socket($socket, PF_INET, SOCK_STREAM, $proto) or die "socket: $!";
  connect($socket, $paddr) or do { warn "connect: $!"; return 'HTTP/1.0 500 Error'."\r\n\r\nWarn: connect: $!\r\n" };
  select((select($socket),$|=1)[0]) ; binmode($socket);
  printf "GET %s HTTP/1.1\r\n",$document if $dbug;
  printf "Host: %s\r\n",$host if $dbug;

  printf $socket "GET %s HTTP/1.1\r\n",$document;
  printf $socket "Host: %s\r\n",$host;
  printf $socket "User-Agent: %s\r\n",$agent; # some site requires an agent
  print  $socket "Connection: close\r\n";
  print  $socket "\r\n";
  local $/ = undef;
  my $buf = <$socket>;
  close $socket or die "close: $!";
  return $buf;
}
# ----------------------------------------------------
sub post_http {
  my $socket;
  my $agent = $0;
  use Socket;
  my ($url,$postData) = @_;
  my ($host,$document) = ($url =~ m{http://([^/]+)(/.*)?}); #/#
  my $port = 80;
  $document = '/' unless $document;
  #print "$host $port\n";
  my $iaddr = inet_aton($host);
  my $paddr = sockaddr_in($port, $iaddr);
  my $proto = (getprotobyname('tcp'))[2];
  socket($socket, PF_INET, SOCK_STREAM, $proto) or die "socket: $!";
  connect($socket, $paddr) or do { warn "connect: $!"; return 'HTTP/1.0 500 Error'."\r\n\r\nWarn: connect: $!\r\n" };
  select((select($socket),$|=1)[0]) ; binmode($socket);
  printf "GET %s HTTP/1.1\r\n",$document if $dbug;
  printf $socket "POST %s HTTP/1.1\r\n",$document;
  printf $socket "Host: %s\r\n",$host;
  printf $socket "User-Agent: %s\r\n",$agent; # some site requires an agent
  print  $socket "ContentType: application/x-www-form-urlencoded\r\n";
  printf $socket "ContentLength: %u\r\n",length($postData);
  print  $socket "Connection: close\r\n";
  print  $socket "\r\n";
  print  $socket $postData;
  local $/ = undef;
  my $buf = <$socket>;
  close $socket or die "close: $!";
  return $buf;
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
sub zdate { # return Zulu time 
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday) = (gmtime($_[0]))[0..6];
  my ($yr4,$yr2) =($yy+1900,$yy%100);
  # 20130424T085606Z
  my $date = sprintf '%4u%02u%02uT%02u%02u%02uZ',
             $yr4,$mon+1,$mday,$hour,$min,$sec;
  return $date;
}
# ----------------------------------------------------
sub duration {
  my $n = shift;
  my ($hh,$mm,$ss);
  $ss = $n % 60;
  $n = int($n / 60);
  if ($n > 0) {
    $mm = $n % 60;
    $n = int($n / 60);
  }
  if ($n > 0) {
    $hh = $n % 24;
    $n = int($n / 24);
  }
  my $s = '';
  $s .= sprintf '%ud',$n if ($n > 0);
  $s .= sprintf ' %uh',$hh if ($hh > 0);
  $s .= sprintf ' %um',$mm if ($mm > 0);
  $s .= sprintf ' %us',$ss if ($ss > 0);
  return $s;
}
# ----------------------------------------------------
1; #$Source: /my/perl/module/from/HEIG-VD/HEIG.pm,v $

__DATA__

