#!perl

package Brewed::Capture;
require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};
local $VERSION = sprintf "%d.%02d", q$Revision: 1.00 $ =~ /: (\d+)\.(\d+)/;
my ($STATE) = q$State: Exp $ =~ /: (\w+)/; our $dbug = $STATE eq 'dbug';

# capturing video clip using ffmpeg
#
# list devices:
#  ffmpeg -list_devices true -f dshow -i dummy
# CommandCam.exe /devlistdetail
#
# list options:
#ffmpeg -f dshow -list_options true -i video
#
# video grab :
# ============
#
# #-vcodec copy
# -framerate 30
# -c:v libx264
# -y
# -rtbufsize 768M
# -pixel_format gray
# -timelimit 120
# -vframes 4800
# -vf crop=x:y:w:w
#
#
# video conversion ...
# ====================
# options: 
#  -i input
#  -ss 0.5 (start time offset)
#  -r 1
#  -t 120 # duration
#  -f image2 "frame.jpg"
#
#  -stdin
#
# -----------------------------------------
# install dir setup
use Brewed::HEIG qw(findpath);
our $es = 'es.exe'; # path to everything
my $QSYNC = $ENV{USERPROFILE}.'/Qsync';
# -----------------------------------------
# choices: fastcapture,CommandCam,webcamImageSave,ffmpeg
# get install path to ffmpeg and i_view
my $ffmpeg = &findpath('local\ffmpeg\static\bin\ffmpeg.exe') || $QSYNC.'\programs\ffmpeg\static\bin\ffmpeg.exe';
my $fastcap = &findpath('fastcapture\fastcapture.exe') || $QSYNC.'\programs\fastcapture\fastcapture.exe';
my $camcom = &findpath('CommandCam.exe') || $QSYNC.'\programs\Camera\CommandCam.exe';
my $webcam = &findpath('WebCamImageSave.exe') || $QSYNC.'\programs\Camera\WebCamImageSave.exe';
my $iccapture = &findpath('\IC Capture.exe') || $QSYNC.'\programs\The Imaging Source Europe GmbH\IC Capture 2.3\IC Capture.exe';
# -----------------------------------------
my ($fc,$cc,$wc,$fm,$ic) = (0,0,0,1,0); # snapshot programs
# -----------------------------------------
my $ffplay = &findpath('ffplay.exe') || 'c:\usr\tools\bin\ffplay.exe';
our $djpeg = &findpath('djpeg.exe') || $ENV{SHARE}.'\programs\jpeg-6b-4\bin\djpeg.exe';

#our $iview = &findpath('\bin\i_view32.exe !\qnap') || &findpath('i_view432.exe') || 'c:\usr\local\IrfanView\i_view32.exe';

our $iview = 'i_view32.exe';
    $iview = 'c:\usr\local\IrfanView\i_view32.exe' if (-e 'c:\usr\local\IrfanView\i_view32.exe');
    $iview = '..\bin\i_view32.exe' if (-e '..\bin\i_view32.exe');

our $djpeg = $ENV{SHARE}.'\programs\jpeg-6b-4\bin\djpeg.exe';

if (-e $djpeg) { # option,outfile,infile
our $convert =sprintf '"%s" %%s -outfile "%%s" "%%s"',$djpeg;
} else {
our $convert =sprintf '"%s" %%s /convert="%%s" "%%s"',$iview;
}
our $vpano =sprintf '"%s" /convert="%%s" /panorama=(2,%%s,%%s)',$iview,
push @EXPORT_OK, '$iview','$convert', '$vpano';

use strict;
# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$dbug $VERSION @EXPORT_OK @EXPORT/;
# --------------------------------------------------

if ($0 eq __FILE__) {

	#&info(); exit;

	my $crop = undef;
	if (! defined $crop) {
  # extract one frame to adjust parameters (crop for instance)
	my $frame = 'frame01.jpg';
	&getoneframe('DMK 23U445',$frame);
  # view image ...
  system sprintf '%s "%s"',$iview,$frame;
  local $/ = "\n";
	print "crop ? (wx:wy:x:y)\n";
  $crop = <STDIN>; chomp($crop);
	unlink $frame;
	}

	printf 
	#&capture('DMK 23U445',$crop,120,'v:\Tinker\TiePie\frame%04d.jpg');
	&getframes('DMK 23U445',$crop,60,'v:\Tinker\TiePie\frame%04d.ppm');
	&capture('DMK 23U445',$crop,60,'v:\Tinker\TiePie\frame.mp4');
}
# --------------------------------------------------
sub is_black { # assume picture have enough details such that the file size is allways in the same bulk part...
  my $file = shift;
  my $size = (lstat($file))[7];
  our $sum_is_black += $size; our $n_is_black++;
  printf "size: %.1f (avg=%.1f)\n",$size/1024,$sum_is_black/$n_is_black/1024;
  return ($n_is_black * $size < 0.80 * $sum_is_black) ? 1 : 0;
}
# --------------------------------------------------
sub info {
  my $info = sprintf '%s -pix_fmts',$ffmpeg;
  my $status = system sprintf $info;
	return $status;
}

sub init {
  mkdir 'v:\ppm' unless -d 'v:\ppm';
  system 'del v:\ppm\frame*.p*';
}

sub getnframes {
 my ($dev,$n,$file) = @_; # capture one frame
 $file =~ s/\.jpg/_%02d.jpg/;
 my $t = $n/30;
 my $input = sprintf 'video="%s"',$dev;
 my $xfrm = sprintf '"%s" -nostats -hide_banner -loglevel quiet -y -f dshow -i %%s %%s -t %g -r 30 -f image2 %%s',$ffmpeg,$t;
 #my $filter = '-vf drawtext="fontfile=FreeSans.ttf:text=%{localtime\\\\:%a %b %d %Y}"';
 my $filter = '';
 printf $xfrm."\n",$input,$filter,$file if $dbug;
 my $status = system sprintf $xfrm,$input,$filter,$file;
 return $status;
}

sub getoneframe {
 my ($dev,$file) = @_; # capture one frame
 print "get frame from device $dev; file:$file\n" if $::dbug;
# ------------------------------
my $xfrm;
my $status;
if ($fc) {
my $devn = 1; # for SPCAM SP503U
# fastcapture.exe 1 2 "snap.bmp"
$xfrm = sprintf '"%s" %%d 2 %%s',$fastcap;
printf "$xfrm\n",$devn,$file;
$status = system sprintf $xfrm,$devn,$file;
} elsif ($cc) {
# CommandCam.exe /filename "snap.bmp" /devname "SPACM SP503U" /delay 500 /quiet;
$xfrm = sprintf '"%s" /filename "%%s" /devname "%%s" /quiet ',$camcom;
$status = system sprintf $xfrm,$file,$dev;
} elsif ($wc) {
# WebCamImageSave.exe /capture /Filename "snap.bmp"
$xfrm = sprintf '"%s" /capture /Filename "%%s"',$camcom;
$status = system sprintf $xfrm,$file;
} elsif ($fm) {
my $input = sprintf 'video="%s"',$dev;
#$xfrm = sprintf '"%s" -loglevel quiet -y -f dshow -i %%s %%s -t 1 -r 1 -f image2 %%s',$ffmpeg;
$xfrm = sprintf '"%s" -nostats -hide_banner -loglevel quiet -y -f dshow -i %%s %%s -t 1 -r 1 -f image2 %%s',$ffmpeg;
#my $filter = '-vf drawtext="fontfile=FreeSans.ttf:text=%{localtime\\\\:%a %b %d %Y}"';
my $filter = '';
printf $xfrm."\n",$input,$filter,$file if $dbug;
$status = system sprintf $xfrm,$input,$filter,$file;
} elsif ($ic) {
$xfrm = $iccapture;
$status = system $xfrm;
}
# ------------------------------
return $?;
}
sub getframes {
	my ($dev,$crop,$time,$file) = @_;
  my $input = sprintf 'video="%s"',$dev;
  my $grab = sprintf '%s -y -an -sn -rtbufsize 768M -pix_fmt gray -ss 0.5 -f dshow -i %%s -framerate 30 %%s -t %%d -r 30 -f image2 %%s',$ffmpeg;
  my $filter = sprintf '-vf "crop=%s"',$crop;
	my $option = $filter; # . ' -strftime 1';
  my $cmd = sprintf "$grab",$input,$option,$time,$file;
  my $status = system sprintf $grab,$input,$option,$time,$file;
	return $?;
}

sub capture {
	# -vf drawbox=10:20:200:60:red@0.5
	my ($dev,$crop,$time,$file) = @_;
  my $input = sprintf 'video="%s"',$dev;
  my $grab = sprintf '%s -y -an -sn -rtbufsize 768M -pix_fmt gray -ss 0.5 -f dshow -i %%s -framerate 30 %%s -t %%d -r 30 -f mpegts %%s',$ffmpeg;
  my $filter = sprintf '-vf "crop=%s"',$crop;
	my $option = $filter . ' -updatefirst 1';
	  $option .= ' -strftime 1';
  $option = $filter . ' -c:v libx264' ;
  my $cmd = sprintf "$grab\n",$input,$option,$time,$file;
	print $cmd if 1;
  my $status = system sprintf $grab,$input,$option,$time,$file;
  return $?;
}
# ----------------------------------------------------
# keystone function ...
sub above {
  my ($D,$x,$y) = @_;
  if ($D->[0][0] != $D->[1][0]) { # not vertical
    my ($a,$yd) = &aby($D,$x);
    return ($y <=> $yd);
  } else {
    return undef;
  }
}
sub aby { # returns slope and ordinate at x
  my ($D,$x) = @_;
  my ($x0,$y0) = @{$D->[0]};
  my ($x1,$y1) = @{$D->[1]};
  my $a = ($x1!=$x0) ? ($y1-$y0)/($x1-$x0) : $y1-$y0;
  my $b = $y0 - $a * $x0;
  my $y = $a * $x + $b;
  return wantarray ? ($a,$y) : $y;
}

sub intercept {
  my ($D1,$D2) = @_;
  # [eq1] D1: (y-y0)/(x-x0) = (y1-y0)/(x1-x0)
  # [eq2] D2: (y-y2)/(x-x2) = (y3-y2)/(x3-x2)
  my ($x0,$y0) = @{$D1->[0]};
  my ($x1,$y1) = @{$D1->[1]};
  #
  my ($x2,$y2) = @{$D2->[0]};
  my ($x3,$y3) = @{$D2->[1]};
  #
  my $a1 = ($y1-$y0)/($x1-$x0); my $b1 = $y0 - $a1 * $x0;
  my $a2 = ($y3-$y2)/($x3-$x2); my $b2 = $y2 - $a2 * $x2;

  my $x = ($b2 - $b1) / ($a1 - $a2);
  my $y =  $a1 * $x + $b1;

  return ($x,$y); 
}


# ----------------------------------------------------
# compute the sum of pixels along the x-axis ...
# and return an average vertical slice 
sub sumx {
  my $pic = shift;
  my $pix = $pic->{raster};
  my $X = $pic->{x};
  my $Y = $pic->{y};
  my $data = [];
  foreach my $j ( 0 .. $Y-1 ) {
    my $sum = 0;
    foreach my $i ( 0 .. $X-1 ) {
      my $p = $j * $X + $i;
      my $px = $pix->[$p];
      my ($r,$g,$b) = unpack('CCC',$px); # only 8b greyscale image ...
      my $Y = 0.299 * $r + 0.587 * $g + 0.114 * $b; # sRGB/D65
      $sum += $Y;
    }
    push @$data,$sum/$X;
  }
  return $data;
}
# ----------------------------------------------------
sub slices { # both sumx and sumy
  my $pic = shift;
  my $pix = $pic->{raster};
  my $X = $pic->{x};
  my $Y = $pic->{y};
  my $sumx = [];
  my $sumy = [];
  foreach my $j ( 0 .. $Y-1 ) {
    foreach my $i ( 0 .. $X-1 ) {
      my $p = $j * $X + $i;
      my $px = $pix->[$p];
      my ($r,$g,$b) = unpack('CCC',$px); # only 8b greyscale image ...
      my $Yp = 0.299 * $r + 0.587 * $g + 0.114 * $b; # sRGB/D65
      $sumx->[$j] += $Yp/$X;
      $sumy->[$i] += $Yp/$Y;
    }
  }
  return ($sumx,$sumy);

}
# ----------------------------------------------------

# ----------------------------------------------------
sub bbox { # compute a boundary box based on average threshold
  my $pic = shift;
  my $X = $pic->{x};
  my $Y = $pic->{y};
  my $raster = $pic->{raster};
  printf "X,Y= $X,$Y\n";

  my $sumx = [];
  my $sumy = [];
  foreach my $j ( 0 .. $Y-1 ) {
    foreach my $i ( 0 .. $X-1 ) {
      my $p = $j * $X + $i;
      my $px = $raster->[$p];
      my ($r,$g,$b) = unpack('CCC',$px); # only 8b greyscale image ...
      $sumx->[$j] += $g;
      $sumy->[$i] += $g;
    }
  }
  # min max values
  my ($hmin,$vmin) = (255*$Y,255*$X);
  my ($hmax,$vmax) = (0,0);
  foreach my $j ( 0 .. $Y-1 ) { # find max on vertical slice (sumx)
    $vmax = $sumx->[$j] if ($sumx->[$j] > $vmax);
    $vmin = $sumx->[$j] if ($sumx->[$j] < $vmin);
  }   
  foreach my $i ( 0 .. $X-1 ) { # find max on horizontal slice (sumy)
    $hmax = $sumy->[$i] if ($sumy->[$i] > $hmax);
    $hmin = $sumy->[$i] if ($sumy->[$i] < $hmin);
  }
  # defines threshold to identify ROI
  my $ythres = ($vmin + 0.10 * ($vmax - $vmin) ) / $X;
  my $xthres = ($hmin + 0.10 * ($hmax - $hmin) ) / $Y;
  if ($dbug) {
  print "v: $vmin .. $vmax\n";
  print "h: $hmin .. $hmax\n";
  print "t: xthres=$xthres ythres=$ythres\n";
  }

  # boundary box  ...
  my ($xmin,$xmax) = (undef,undef);
  my ($ymin,$ymax) = (undef,undef);
  foreach my $j (0 .. $Y-1) {
    my $xavg = $sumx->[$j]/$X;
    foreach my $i (0 .. $X-1) {
      my $yavg = $sumy->[$i]/$Y;

      if ($xavg > $ythres && $xavg > $yavg ) {
        $ymin = $j-1 unless defined $ymin;
        $ymax = $j+1;
      }
      if ($yavg > $xthres && $yavg > $xavg) {
        $xmin = $i-1 unless defined $xmin;
        $xmax = $i+1;
      }
    }
  }

  # cliping ...
  $xmin = 0 if $xmin < 0;
  $ymin = 0 if $ymin < 0;
  $xmax = $X if $xmax > $X;
  $ymax = $Y if $ymax > $Y;

  printf " A: $xmin,$ymin; D: $xmax,$ymax\n" if $dbug;
  my $crop = sprintf "%d,%d:%dx%d",$xmin,$ymin,$xmax-$xmin,$ymax-$ymin;
  printf " crop: %s\n",$crop if $dbug;
  return $crop;
}

# ----------------------------------------------------
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
  print "file: $pnm\n" if $dbug;
  open PNM, "<$pnm";
  local $/ = "\n";
  local $_; # make $_ local as there is a loop above
  my $magic = <PNM>; chomp($magic);
  #print "magic: $magic\n" if $dbug;
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
    while (<PNM>) { last unless m/^#/} # skip comments
    ($x,$y) = ($1,$2) if (m/(\d+)\s+(\d+)/i);
    $max = <PNM>; chomp($max);
    print "magic: $magic ${x}x${y} $max\n" if $dbug;
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
# ----------------------------------------------------
sub dump_ppm {
  #my $pic = { 'x' => $xscan, 'y' => $yrmax, 'raster' => \@raster };
  my ($pic,$file) = @_;
  my ($x,$y) = ($pic->{x},$pic->{y});
  my $pix = $pic->{raster};
  printf "// dump: %dx%d for %s: %dpx\n",$x,$y,$file,scalar @$pix if ($::dbug || $dbug);
  return -1 unless (scalar @$pix);
  my $ascii=0;
  open PPM, ">$file"; binmode(PPM);
  printf PPM "P%d\n%d %d\n255\n",($ascii)?3:6,$x,$y if ($file =~ m/ppm/);
  print PPM @$pix;
  close PPM;
}
# ----------------------------------------------------
1;
