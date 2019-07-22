#!perl
# $RCSfile: $
BEGIN { push @INC, '/strawberry/perl/site/lib','/strawberry/perl/site/lib/Brewed' }

package Camera;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};
local $VERSION = sprintf "%d.%02d", q$Revision: 1.00 $ =~ /: (\d+)\.(\d+)/;
my ($STATE) = q$State: Exp $ =~ /: (\w+)/; our $dbug = $STATE eq 'dbug';

use strict;
# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$dbug $VERSION @EXPORT_OK @EXPORT/;

use Digest::Pearson qw(pearson);

# ------------------------
my $fdc = 400 + rand(20);
my $Qdc = 40 + rand(30);
my $amax = 3.0; # in V;

# ----------------------------------------------------
our $pgm = '';
if (defined $::pgm) {
  $pgm = $::pgm;
} else {
$0 =~ s,\\,/,g; # unix style fs
$0 =~ s,(.*)/([^/]+)$,$2,;
our ($bin,$pgm)=($1||'.',$2||$0);
$pgm =~ s,\.[^.]+$,,; # suppress any extension
}
# ----------------------------------------------------
if ($0 eq __FILE__) {
  # check connected cameras
  system 'CommandCam.exe /devlistdetail';
  exit 1;
}

our $_i=0;
local *YLOG;
sub init {
if (! -e "${pgm}_faY.csv") {
open YLOG,'>',"${pgm}_faY.csv" or die $!;
print YLOG "#i,f,a,Y,cn,,tic=$^T\n";
} else {
open YLOG,'>>',"${pgm}_faY.csv" or die $!;
}
return 1;
}

# -------------------------------------------------------------------------
# text to be added on the image ...
sub set_label {
  my ($f,$a) = @_;
	local *F; open F,'>label.txt';
	printf F "f=%gHz ampl=%.2fV\n",$f,$a;
	close F;
}
# -------------------------------------------------------------------------
# Documentation :
#  get_height() take a screenshot and compute the height of the screen
# routines for evaluating image ...
# ----------------------------------------------------
sub get_height {
 my ($camera,$f,$ampl) = @_; # 'DMx 41BU02' or 'USB 2.0 Camera'
 if ($camera eq 'model') { # use a simple model ...
   my $cn = 0;
   # ------------------------
   my $_2pi = 4 * atan2(1,0);
   my $w0 = $_2pi * $fdc;
   my $coj = $w0/$Qdc;
   my $w = $_2pi * $f; 
   my $aaw =  $w0**2 / sqrt( $coj**2*$w**2 + ( $w0**2 - $w**2)**2 ); # amplification: a(w)
   #printf "model: fdc=%f f=%f a(w)=%g ampl=%f\n",$fdc,$f,$aaw,$amax/$aaw;
   my $height = 800 * ($ampl / $amax) * $aaw;

   my $xtic = time()/86400 + 25569 + 2/24; 
   printf YLOG "%g,%g,%g,%g,%u,%.6f\n",$_i++,$f,$ampl,$height,$cn,$xtic;
   return int ($height -2 +  rand(3) );  # int rand(500) + 300 if $dbug;
 } 

 # ------------------------------------------
 # acquire image ...
 my $cn = &pearson($camera) % 11; # pick the right modulo to making it a perfect hash
 my $snapbmp = sprintf "snap%u.bmp",$cn;
 my $acquire = 'CommandCam.exe /filename %s /devname "%s" /delay 500 /quiet > NUL';
 #print "$camera cn=$cn\n" if $dbug;; # return $cn; exit;
 # ------------------------------------------
 if ($cn == 1  && -e '/usr/bin/WebCamImageSave.exe') {
   &set_label($f,$ampl);
   unlink 'WebCamImageSave.cfg'; link 'c:\usr\bin\WebCamImageSave.cfg','WebcamImageSave.cfg';
   $snapbmp = sprintf "snapWebCamImage%u.png",$cn;
   $acquire = 'WebCamImageSave.exe /capture /LabelColor 004080 /FontBold 1 /FontSize 16 /FontName "Arial" /Filename "%s"';
 }
 unlink $snapbmp;
 my $status = system sprintf $acquire,$snapbmp,$camera;
 printf "camera: %u (%s) status=%s\n",$cn,$camera,$status if $dbug;
 printf "error %s: %s\n",$?,$! if $?;
 return undef if ($status == 7168 || $status == 3584);
 # ------------------------------------------
 
my $crop = ($cn == 7) ? '(1,1,638,478)' : '(1,1,1278,958)'; # <--- adjust !
my $iview = '/usr/bin/i_view432.exe';
  if (-e $snapbmp) {
    unlink "snap.png";
    $crop = ($cn == 4) ? sprintf ('"%s" "%%s" /crop=%s /transpcolor=(1,2,3) /grey /bpp=8 /convert="%%s" > NUL',$iview,$crop) :
                         sprintf ('"%s" "%%s" /crop=%s /transpcolor=(1,2,3) /convert="%%s" > NUL',$iview,$crop) ;
    system sprintf $crop, $snapbmp, 'snap.png';
  }
  
  my $convert = sprintf ('"%s" "%%s" /convert="%%s" > NUL',$iview);
  system sprintf $convert, "snap.png", "snap.ppm";
  {
  # removing IrfanView's comment
  local $/ = "\n";
  open IrfV, "<snap.ppm";binmode IrfV; my @buf = <IrfV>; close IrfV; unlink "snap.ppm";
  open PPM, ">snap.ppm"; binmode PPM;
  foreach (@buf) {
    next if (m/^# Created/);
    print PPM;
  }
  close PPM;
  }

my $image = 'snap.ppm';
# load ppm image ...
# and write the raw file for the simulation if necessary
my $pic = &loadpnm(sprintf('%s',$image));
my $basen = $1 if ($image =~ m/([^\\\/]+)\.p.m/);
my $X = $pic->{x};
my $Y = $pic->{y};
#printf "// %s: %dx%d (detected)\n",$basen,$X,$Y;
my $pix = $pic->{raster};

my $maxv = 0;
my @slice = ();
foreach my $j (0 .. $Y-1) {
my $xsum = 0.0000;
foreach my $i (0 .. $X-1) {
  my $p = $j * $X + $i;
  my $px = $pix->[$p];
  my ($r,$g,$b) = unpack('CCC',$px); # only 8b greyscale image ...
  $xsum += $r;
  $maxv = $xsum if ($xsum > $maxv);
}
$slice[$j] = $xsum;
}
die "/!\\ @slice" unless scalar @slice;
#printf "slice: %u lines\n",scalar @slice;
# ------------------------------------
my $xsum2 = $slice[$#slice/2];
my $th = ($xsum2) ? 1.05 * $maxv/($xsum2) : 1.05/0.80 ; # middle point is assumed  to be the deemer (sinus drive)
my $d2ymax = 1.10*$th; # take 10 % margin
#printf "// thres=%g (1/th=%f)\n",$th,1/$th;
local *CSV;
open CSV,'>',"${pgm}_snap.csv";
printf CSV "#j,xsum,1/v,d2y,,f=,%g,ampl=,%f",$f,$ampl;
print CSV "\n";
my $pd2y = $d2ymax;
my @yr = ();
my @yf = ();;
foreach my $j (0 .. $#slice) {
  my $xsum = $slice[$j];
  #           A  B   C   D
  #           1  2   3   4
  #           j xsumxavg 1/y
  my $d2y = ($maxv > $xsum * $d2ymax) ? $d2ymax : ($xsum) ? $maxv/$xsum : $d2ymax;
  printf CSV "%u,%g, %g, %g",$j,$xsum,($maxv)?$xsum/$maxv:0,$d2y;
  # ----------------------------------------------------
  if ($d2y < $th && $pd2y > $th) { # \_
    push @yf,$j;
  } elsif ($d2y > $th && $pd2y < $th) { # _/
    push @yr,$j;
  }
  # ----------------------------------------------------
  print CSV "\n";
  $pd2y = $d2y;
}
close CSV;
# ------------------------------------
if ($slice[-1] && $maxv/$slice[-1] < $th) {
push @yr,$#slice;
printf " /!\\ bottom cropped : d2y(tr): %g\n",$maxv/$slice[-1];
}
if ($slice[0] && $maxv/$slice[0] < $th) {
unshift @yf,0;
printf " /!\\ top cropped : d2y(tf): %g\n",$maxv/$slice[0];
}
my $height = $yr[-1] - $yf[0];

my $xtic = time()/86400 + 25569 + 2/24; 
printf YLOG "%g,%g,%g,%g,%u,%.6f\n",$_i++,$f,$ampl,$height,$cn,$xtic;
return $height;

}
# -------------------------------------------------------------------------
# portable pixmap:
#   P1:  1b ascii (B&W)
#   P2:  8b ascii (grey)
#   P3: 24b ascii (color)
#
#   P4:  1b binary (B&W)
#   P5:  8b binary (grey)
#   P6: 24b binary (color)
sub loadpnm {
  my $pnm = $_[0];
  my ($x,$y) = (1,1);
  my @raster = ();
  my $raster = \@raster;
  #print "file: $pnm\n";
  open PNM, "<$pnm";
  local $/ = "\n";
  local $_; # make $_ local as there is a loop above
  my $magic = <PNM>; chomp($magic);
  #PBM P1 P4 --  1b/px (portable bit map)
  my $max = undef;
  if ($magic eq 'P1') {
    my $hdr = 1;
    while (<PNM>) {
      next if /^#/;
      chomp;
      s/\s+/ /g;
      s/\s#.*//;
      if ($hdr) {
        ($x,$y) = ($1,$2), $hdr=0 if (m/^(\d+)\s+(\d+)\s*$/);
        #print "$.: $_\n";
      } else {
        push @raster, map { $_ ? 0x000000 : 0x7F7F7F; } split(' ',$_);
        #printf "%s %dpx\n",$_,scalar @$raster;
      }
    }
#use YAML;
#YAML::DumpFile( "dbug.yml", $raster );

    
  #PPM P3    -- 24b/px (portable pix map)
  } elsif ($magic eq 'P3') {
    my $hdr = 1;
    my @pix = ();
    while (<PNM>) {
      next if /^#/;
      chomp;
      s/\s+/ /g;
      s/\s#.*//;
      if ($hdr) {
        ($x,$y) = ($1,$2) if (m/^(\d+)\s+(\d+)\s*$/);
        $max = $1, $hdr = 0 if (m/^(\d+)$/);
        #print "$.: '$_'\n";
      } else {
        push @pix, split(' ',$_);
        #printf "%s %dpx\n",$_,$#pix+1;
      }
    }
    my $np = (scalar @pix)/3;
    #printf "np=%d\n",$np;
    for (0 .. $np-1) {
      push @raster, pack('CCC',$pix[$_*3],$pix[$_*3+1],$pix[$_*3+2]);
    }
    undef @pix;
  } else {
    binmode(PNM);
    my $px = ($magic eq 'P5') ? 8 : 24; # pixel size;
    ($x,$y) = ($1,$2) if (<PNM> =~ m/(\d+)\s+(\d+)/i);
    $max = <PNM>; chomp($max);
    #print "magic: $magic ${x}x${y} $max\n";
    $/ = undef;
    my $buf = <PNM>;
    my $np = int(8*length($buf)/$px);
    my @pix = unpack('C*',$buf);
    if ($magic ne 'P5') {
    for (0 .. $np-1) {
      push @raster, pack('CCC',$pix[$_*3],$pix[$_*3+1],$pix[$_*3+2]);
    }
    } else {
      @raster = map { pack('CCC',$_,$_,$_); } @pix;
    }
    undef @pix;
  }
  close PNM;

  #printf "// magic : '%s' (%dx%d)\n",$magic,$x,$y;
  my $pic = { 'x' => $x, 'y' => $y, 'raster' => $raster };
  undef $raster; # dereference @raster for future garbage collection
  return ($pic);  

}
# -------------------------------------------------------------------------
1; # vim: nowrap ts=2
