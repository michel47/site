#!perl

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ vim: nowrap syntax=perl
package CIE;
@ISA = qw(Exporter);
@EXPORT = grep { $_ =~ m/from/ && defined &$_; } keys %{__PACKAGE__ . '::'};
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};
use vars qw($VERSION); # ... NEED VERSION for Import to work
$VERSION = sprintf "%d.%02d", q$Revision: 0.1 $ =~ /: (\d+)\.(\d+)/;
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ vim: nowrap syntax=perl

# color boost
my $boost= {};
sub set_boost { $boost->{$_[0]} = $_[1]; }

# primaries place holder
my @rXYZ = ();
my @gXYZ = ();
my @bXYZ = ();

# ------------------------------------------------------------
my %System = (
# Colors weight in different color space :
#
#          red   green blue
# ITU    : 22.0% 70.7% 7.1%
# Rec 709: 21.3% 71.5% 7.2%
# SMPTE  : 21.2% 70.1% 8.7%
# NTSC   : 29.9% 58.7% 11.4% *
# GREY   : 33.3% 33.4% 33.3%

# Observer. = 2°, Illuminant = D65
    # X = R * 0.4124 + G * 0.3576 + B * 0.1805
    # Y = R * 0.2126 + G * 0.7152 + B * 0.0722 (ITU-R BT.709)
    # Z = R * 0.0193 + G * 0.1192 + B * 0.9505

# http://www.brucelindbloom.com/Eqn_RGB_XYZ_Matrix.html

# format:
# 'spacename' => [XYX_coord_R,XYX_coord_G,XYX_coord_B]
# Adobe RGB (1998)	D50
'Adobe' => [qw/
 0.6097559  0.3111242  0.0194811
 0.2052401  0.6256560  0.0608902
 0.1492240  0.0632197  0.7448387 /],
# 1.9624274 -0.9787684  0.0286869
#-0.6105343  1.9161415 -0.1406752
#-0.3413404  0.0334540  1.3487655
# AppleRGB	D50
'Apple' => [qw/
 0.4755678  0.2551812  0.0184697
 0.3396722  0.6725693  0.1133771
 0.1489800  0.0722496  0.6933632 /],
# 2.8510695 -1.0927680  0.1027403
#-1.3605261  2.0348871 -0.2964984
#-0.4708281  0.0227598  1.4510659
# Bruce RGB	D50
'BruceRGB' => [qw/
 0.4941816  0.2521531  0.0157886
 0.3204834  0.6844869  0.0629304
 0.1495550  0.0633600  0.7464909 /],
# 2.6502856 -0.9787684  0.0264570
#-1.2014485  1.9161415 -0.1361227
#-0.4289936  0.0334540  1.3458542
# CIE RGB	D50
'CIE' => [qw/
 0.4868870  0.1746583 -0.0012563
 0.3062984  0.8247541  0.0169832
 0.1710347  0.0005877  0.8094831 /],
# 2.3638081 -0.5005940  0.0141712
#-0.8676030  1.3962369 -0.0306400
#-0.4988161  0.1047562  1.2323842
# NTSC RGB	D50
'NTSC' => [qw/
 0.6343706  0.3109496 -0.0011817
 0.1852204  0.5915984  0.0555518
 0.1446290  0.0974520  0.7708399 /],
# 1.8464881 -0.9826630  0.0736477
#-0.5521299  2.0044755 -0.1453020
#-0.2766458 -0.0690396  1.3018376
# PAL/SECAM RGB	D50
'PAL' => [qw/
 0.4552773  0.2323025  0.0145457
 0.3675500  0.7077956  0.1049154
 0.1413926  0.0599019  0.7057489 /],
# 2.9603944 -0.9787684  0.0844874
#-1.4678519  1.9161415 -0.2545973
#-0.4685105  0.0334540  1.4216174
# SMPTE-C RGB	D50
'SMPTE' => [qw/
 0.4163290  0.2216999  0.0136576
 0.3931464  0.7032549  0.0913604
 0.1547446  0.0750452  0.7201920 /],
# 3.3921940 -1.0770996  0.0723073
#-1.8264027  2.0213975 -0.2217902
#-0.5385522  0.0207989  1.3960932
# sRGB	D50
'sRGB' => [qw/
 0.4360747  0.2225045  0.0139322
 0.3850649  0.7168786  0.0971045
 0.1430804  0.0606169  0.7141733 /],
# 3.1338561 -0.9787684  0.0719453
#-1.6168667  1.9161415 -0.2289914
#-0.4906146  0.0334540  1.4052427


#  [ R ]   [  3.240479 -1.537150 -0.498535 ]   [ X ]
#  [ G ] = [ -0.969256  1.875992  0.041556 ] * [ Y ]
#  [ B ]   [  0.055648 -0.204043  1.057311 ]   [ Z ].
 
 
);

my %SystemD50 = (
# RGB system w/ white = D50 !
# Adobe RGB / D65 (1998)
'Adobe' => [ qw/
 0.576700    0.297361    0.0270328
 0.185556    0.627355    0.0706879
 0.188212    0.0752847   0.991248 /],
# Apple RGB / D65
'Apple' => [ qw/
 0.4497288  0.2446525  0.0251848
 0.3162486  0.6720283  0.1411824
 0.1844926  0.0833192  0.9224628 /],
# Best RGB / D50
'BestRGB' => [ qw/
 0.6326696  0.2284569  0.0000000
 0.2045558  0.7373523  0.0095142
 0.1269946  0.0341908  0.8156958 /],
# Beta RGB / D50
'betaRGB' => [ qw/
 0.671254    0.303273    0.000000   
 0.174583    0.663786    0.040701 
 0.118383    0.0329413   0.784509 /],
# Bruce RGB / D65
'bruceRGB' => [ qw/
 0.4674162  0.2410115  0.0219101
 0.2944512  0.6835475  0.0736128
 0.1886026  0.0754410  0.9933071 /],
# CIE / E 
'CIE-E' => [ qw/
 0.4887180  0.1762044  0.0000000
 0.3106803  0.8129847  0.0102048
 0.2006017  0.0108109  0.9897952 /],
# ColorMatch / D50
'ColorMatch' => [ qw/
 0.5093439  0.2748840  0.0242545
 0.3209071  0.6581315  0.1087821
 0.1339691  0.0669845  0.6921735 /],
# DonRGB4 / D50
'DonRGB' => [ qw/
 0.645771    0.278350    0.00371134 
 0.193351    0.687970    0.0179862  
 0.125098    0.0336802   0.803513 /],
# ECI / D50
'ECI' => [ qw/
 0.650204    0.320250    0.000000   
 0.178077    0.602071    0.0678390  
 0.135938    0.0776791   0.757371 /],
# Ekta Space PS5 / D50
'PS5' => [ qw/
 0.593891    0.260629    0.000000   
 0.272980    0.734946    0.0419970  
 0.0973486   0.00442493  0.783213 /],
# (ITU BT.601)
'601' => [ qw/
 0.606734    0.298839    0.000000   
 0.173564    0.586811    0.0661196  
 0.200112    0.114350    1.11491 /],
# NTSC / C
'NTSC' => [ qw/
 0.6068909  0.2989164 -0.0000000
 0.1735011  0.5865990  0.0660957
 0.2003480  0.1144845  1.1162243 /],
# PAL / SECAM / D65
'PAL' => [ qw/
 0.4306190  0.2220379  0.0201853
 0.3415419  0.7066384  0.1295504
 0.1783091  0.0713236  0.9390944 /],
# ProPhoto / D50
'ProPhoto' => [ qw/
 0.797675    0.288040    0.000000   
 0.135192    0.711874    0.000000   
 0.0313534   0.000086    0.825210 /],
# SMPTE-C / D65
'SMPTE' => [ qw/
 0.3935891  0.2124132  0.0187423
 0.3652497  0.7010437  0.1119313
 0.1916313  0.0865432  0.9581563 /],
# (ITU BT.709)
'709' => [ qw/
 0.412424    0.212656    0.0193324  
 0.357579    0.715158    0.119193   
 0.180464    0.0721856   0.950444 /],
# sRGB / D65
'sRGB' => [ qw/
 0.4124564  0.2126729  0.0193339
 0.3575761  0.7151522  0.1191920
 0.1804375  0.0721750  0.9503041 /],
 

# WideGamut / D50
'WideGamut' => [ qw/
 0.7161046  0.2581874  0.0000000
 0.1009296  0.7249378  0.0517813
 0.1471858  0.0168748  0.7734287 /],
# Grey / color blind !
'Grey' => [ qw/
 0.334 0.333 0.333
 0.333 0.334 0.333
 0.333 0.333 0.334 /]

);
# ------------------------------------
# primaries coordinates ...
my (@rXYZ,@gXYZ,@bXYZ);
# System choice :
&SetSystem('sRGB');
printf "System: '%s'\n",'sRGB';
# xy ...
my ($xr,$yr,$Yr) = &xyY(@rXYZ);
my ($xg,$yg,$Yg) = &xyY(@gXYZ);
my ($xb,$yb,$Yb) = &xyY(@bXYZ);
my ($xe,$ye) = (($xr+$xg+$xb)/3,($yr+$yg+$yb)/3);

printf "xy primaries:\n";
printf "RED   : xy=%.4f,%.4f (%s)\n",$xr,$yr, join ',',@rXYZ;
printf "GREEN : xy=%.4f,%.4f (%s)\n",$xg,$yg, join ',',@gXYZ;
printf "BLUE  : xy=%.4f,%.4f (%s)\n",$xb,$yb, join ',',@bXYZ;
printf "White : xy=%.4f,%.4f (%s)\n",$xe,$ye, join ',',&XYZ_from_RGB(1,1,1);
# ------------------------------------
sub SetSystem {
  my $ColorSystem = $System{$_[0]} || $System{'Grey'};
  #my @ColorSystem = grep !/^#/, split /\n/, $ColorSystem;
  #@rXYZ = split (/\s+/, $ColorSystem[0]);
  #@gXYZ = split (/\s+/, $ColorSystem[1]);
  #@bXYZ = split (/\s+/, $ColorSystem[2]);
  #($rXYZ[0],$gXYZ[0],$bXYZ[0]) = @$ColorSystem[0..2];
  #($rXYZ[1],$gXYZ[1],$bXYZ[1]) = @$ColorSystem[3..5];
  #($rXYZ[2],$gXYZ[2],$bXYZ[2]) = @$ColorSystem[6..8];

  (@rXYZ) = @$ColorSystem[0..2];
  (@gXYZ) = @$ColorSystem[3..5];
  (@bXYZ) = @$ColorSystem[6..8];
}
# ------------------------------------------------------------

# LMS /w D65 :
@lLMS = (1.9102,0.3709,0.0);
@mLMS = (-1.1122,0.6291,0.0);
@sLMS = (0.2019,0.0, 1.0);

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ vim: nowrap syntax=perl
if ($0 eq __FILE__) {

if (0) {
# inversion test ...
my @M = (
 0.6326696,  0.2284569,  0.0000000,
 0.2045558,  0.7373523,  0.0095142,
 0.1269946,  0.0341908,  0.8156958
);
@M = (
  1.7552599,-0.5441336, 0.0063467,
 -0.4836786, 1.5068789,-0.0175761,
 -0.2530000, 0.0215528, 1.2256959
);

print 'M: ',$/; &display(3,3,@M);
my @I = inv3(@M);
print 'I: ',$/; &display(3,3,@I);
exit;
}


# --------------------------------------------
# rgb->XYZ->rgb
printf "XYZ= %.3f,%.3f,%.3f ",
   &XYZ_from_rgb(160,20,240);
printf "rgb=%.3g,%.3g,%.3g ",
   &rgb_from_XYZ(&XYZ_from_rgb(160,20,240));
printf "\n";
# --------------------------------------------
# XYZ->rgb->XYZ
printf "rgb=%.3g,%.3g,%.3g ",
   &rgb_from_XYZ(0.33,0.40,.20);
printf "XYZ=%.3g,%.3g,%.3g ",
   &XYZ_from_rgb(&rgb_from_XYZ(0.33,0.40,.20));
printf "\n";
# --------------------------------------------

   exit;


printf "// full colors\n";
printf "100%%-RED:     Yuv=%.2f %+.4f,%+.4f HSV=%+6.1f° %.3f %.3f\n",
       &yuv_from_rgb(1,0,0),&hsv_from_yuv(yuv_from_rgb(1,0,0));
printf "100%%-YELLOW:  Yuv=%.2f %+.4f,%+.4f HSV=%+6.1f° %.3f %.3f\n",
       &yuv_from_rgb(1,1,0),&hsv_from_yuv(yuv_from_rgb(1,1,0));
printf "100%%-GREEN:   Yuv=%.2f %+.4f,%+.4f HSV=%+6.1f° %.3f %.3f\n",
       &yuv_from_rgb(0,1,0),&hsv_from_yuv(yuv_from_rgb(0,1,0));
printf "100%%-CYAN:    Yuv=%.2f %+.4f,%+.4f HSV=%+6.1f° %.3f %.3f\n",
       &yuv_from_rgb(0,1,1),&hsv_from_yuv(yuv_from_rgb(0,1,1));
printf "100%%-BLUE:    Yuv=%.2f %+.4f,%+.4f HSV=%+6.1f° %.3f %.3f\n",
       &yuv_from_rgb(0,0,1),&hsv_from_yuv(yuv_from_rgb(0,0,1));
printf "100%%-MAGENTA: Yuv=%.2f %+.4f,%+.4f HSV=%+6.1f° %.3f %.3f\n",
       &yuv_from_rgb(1,0,1),&hsv_from_yuv(yuv_from_rgb(1,0,1));
printf "// 75%% colors\n";
printf "75%%-RED:     Yuv=%.2f %+.4f,%+.4f HSV=%+6.1f° %.3f %.3f\n",
       &yuv_from_rgb(.75,0,0),&hsv_from_yuv(yuv_from_rgb(.75,0,0));
printf "75%%-YELLOW:  Yuv=%.2f %+.4f,%+.4f HSV=%+6.1f° %.3f %.3f\n",
       &yuv_from_rgb(.75,.75,0),&hsv_from_yuv(yuv_from_rgb(.75,.75,0));
printf "75%%-GREEN:   Yuv=%.2f %+.4f,%+.4f HSV=%+6.1f° %.3f %.3f\n",
       &yuv_from_rgb(0,.75,0),&hsv_from_yuv(yuv_from_rgb(0,.75,0));
printf "75%%-CYAN:    Yuv=%.2f %+.4f,%+.4f HSV=%+6.1f° %.3f %.3f\n",
       &yuv_from_rgb(0,.75,.75),&hsv_from_yuv(yuv_from_rgb(0,.75,.75));
printf "75%%-BLUE:    Yuv=%.2f %+.4f,%+.4f HSV=%+6.1f° %.3f %.3f\n",
       &yuv_from_rgb(0,0,.75),&hsv_from_yuv(yuv_from_rgb(0,0,.75));
printf "75%%-MAGENTA: Yuv=%.2f %+.4f,%+.4f HSV=%+6.1f° %.3f %.3f\n",
       &yuv_from_rgb(.75,0,.75),&hsv_from_yuv(yuv_from_rgb(.75,0,.75));
printf "// 75%%^2.2 colors\n";
printf "53%%-RED:     Yuv=%.2f %+.4f,%+.4f HSV=%+6.1f° %.3f %.3f\n",
       &yuv_from_rgb(.75**2.2,0,0),&hsv_from_yuv(yuv_from_rgb(.75**2.2,0,0));
printf "53%%-YELLOW:  Yuv=%.2f %+.4f,%+.4f\n",&yuv_from_rgb(.75**2.2,.75**2.2,0);
printf "53%%-GREEN:   Yuv=%.2f %+.4f,%+.4f HSV=%+6.1f° %.3f %.3f\n",
       &yuv_from_rgb(0,.75**2.2,0),&hsv_from_yuv(yuv_from_rgb(0,.75**2.2,0));
printf "53%%-CYAN:    Yuv=%.2f %+.4f,%+.4f\n",&yuv_from_rgb(0,.75**2.2,.75**2.2);
printf "53%%-BLUE:    Yuv=%.2f %+.4f,%+.4f HSV=%+6.1f° %.3f %.3f\n",
       &yuv_from_rgb(0,0,.75**2.2),&hsv_from_yuv(yuv_from_rgb(0,0,.75**2.2));
printf "53%%-MAGENTA: Yuv=%.2f %+.4f,%+.4f\n",&yuv_from_rgb(.75**2.2,0,.75**2.2);

}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# color functions ...
#
sub y601 { # ITU BT.601
  my ($R, $G, $B) = @_;
  my $Y = 0.299 * $R + 0.587 * $G + 0.114 * $B; # sRGB/D65
  return $Y;
}
# ---------------------------------------------------------
sub White_from_RGB {
# illuminant ref ($Xr,$Yr,$Zr) = (0.950166,1.0,1.087654)
#  sRGB space: D65 as ref;
# ICC profile: D50 as ref;
#
  my ($R,$G,$B) = @_;
  my ($W);
  $W = &min($R,$G,$B);

  # Colors weight in different color space :
  #
  #          red   green blue
  # ITU    : 22.0% 70.7% 7.1%
  # Rec 709: 21.3% 71.5% 7.2%
  # SMPTE  : 21.2% 70.1% 8.7%
  # NTSC   : 29.9% 58.7% 11.4% * Rec 601
  # GREY   : 33.3% 33.4% 33.3%

  # BestRGB/D50
  #$Y = 0.204556 * $R + 0.737352 * $G + 0.00951424 * $B;
  #$Y = 0.299 * $R + 0.587 * $G + 0.114 * $B; # NTSC
  $Y = $rXYZ[1] * $R + $gXYZ[1] * $G + $bXYZ[1] * $B;

return $Y;
}

sub chroma_from_Yuv {
  my ($Y,$u,$v) = @_;
  return sqrt($u*$u + $v*$v);
}
sub chroma_from_rgb {
  my ($Y,$u,$v) = &Yuv_from_rgb(@_);
  return sqrt($u*$u + $v*$v);
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# color space conversion ...
my $convert = {
  uv => sub { (&Yuv_from_RGB(@_))[1,2] },
  tu => sub { (&Ytuv_from_RGB(@_))[1,2] }, # M/G,Y/B
  hs => sub { (&HSV_from_RGB(@_))[0,1] },
  Ag => sub { (&YAg_from_RGB(@_))[1,2] },
  CM => sub { (&CMY_from_RGB(@_))[0,1] },
  MY => sub { (&CMY_from_RGB(@_))[1,2] },
  CY => sub { (&CMY_from_RGB(@_))[0,2] },
  CrA => sub { (&skin_from_RGB(@_))[1,2] }, # Y,Cr,A,g,H,S,V,u,v
  CrS => sub { (&skin_from_RGB(@_))[1,5] },  # Y,Cr,A,g,H,S,V,u,v
  xy => sub { (&xyY_from_RGB(@_))[0,1] }
};

# ------------------------
# Definition : a color is gamma'd if compress i.e. in non linear space
#
# compress (log) to linear space
sub degamma { # linearization ... gamma ~ 2.2 (CRT / phosphor xfer)
  # return linear ... color 
  return map { ($_/255) ** (1/.45) } (@_);
}
# linear to compress (log)
sub gamma { # bright color compression gamma = .45
  return map { ($_**(.45))*255 } (@_);
}
# ------------------------
# see http://www.brucelindbloom.com/Eqn_RGB_XYZ_Matrix.html
# 
sub XYZ_from_RGB {
  my ($R,$G,$B) = @_;
  my ($X,$Y,$Z);
  &SetSystem('NTSC') unless defined $gXYZ[1];
  $X = $rXYZ[0] * $R + $gXYZ[0] * $G + $bXYZ[0] * $B;
  $Y = $rXYZ[1] * $R + $gXYZ[1] * $G + $bXYZ[1] * $B;
  $Z = $rXYZ[2] * $R + $gXYZ[2] * $G + $bXYZ[2] * $B;

  return ($X,$Y,$Z);
}
sub XYZ_from_rgb {
  my ($R,$G,$B) = &degamma(@_);
  return &XYZ_from_RGB($R,$G,$B);
}
sub rgb2_from_XYZ { # Determinant methods ...
  my ($X,$Y,$Z) = @_;
  # X = ax.R + bx.G + cx.B         *  ay
  # Y = ay.R + by.G + cy.B  *  az  * -ax
  # Z = az.R + bz.G + cz.B  * -ay
  # ----------------------- +
  # Guass-Jordan elimination ...
  #
  my $D = &det3($rXYZ[0],$gXYZ[0],$bXYZ[0],   #      |ax bx cx|
                $rXYZ[1],$gXYZ[1],$bXYZ[1],   #  D = |ay by cy|
                $rXYZ[2],$gXYZ[2],$bXYZ[2] ); #      |az bz cz|
  #
  #     |X bx cx|           |ax X cx|            |ax bx X|
  # R = |Y by cy| / D;  G = |ay Y cy| / D;   B = |ay by Y| / D;
  #     |Z bz cz|           |az Z cz|            |az bz Z|
  #
  my $Nr= &det3( $X,     $gXYZ[0],$bXYZ[0],   #      | X bx cx|
                 $Y,     $gXYZ[1],$bXYZ[1],   # Nr = | Y by cy|
                 $Z,     $gXYZ[2],$bXYZ[2] ); #      | Z bz cz|
  #
  my $Ng= &det3($rXYZ[0],  $X,    $bXYZ[0],   #      |ax  G cx|
                $rXYZ[1],  $Y,    $bXYZ[1],   # Ng = |ay  G cy|
                $rXYZ[2],  $Z,    $bXYZ[2] ); #      |az  G cz|
  #
  my $Nb= &det3($rXYZ[0],$gXYZ[0],   $X,      #      |ax bx cx|
                $rXYZ[1],$gXYZ[1],   $Y,      #  D = |ay by cy|
                $rXYZ[2],$gXYZ[2],   $Z    ); #      |az bz cz|
  #
  #
  my ($R,$G,$B) = ($Nr/$D,$Ng/$D,$Nb/$D);
  return &gamma($R,$G,$B);
}
sub rgb_from_XYZ { # matrix inversion methods..
  my ($X,$Y,$Z) = @_;
  my @M = ( $rXYZ[0],$gXYZ[0],$bXYZ[0],
            $rXYZ[1],$gXYZ[1],$bXYZ[1],
            $rXYZ[2],$gXYZ[2],$bXYZ[2]);
  my @I = inv3(@M);
  my ($R,$G,$B) = &prod3($X,$Y,$Z,@I);
  return &gamma($R,$G,$B);
}
sub prod3 {
   # |X|   | 0 1 2 |   |a|
   # |Y| = | 3 4 5 | x |b|
   # |Z|   | 6 7 8 |   |c|

   my ($a,$b,$c,@M) = @_;
   #printf "\nprod: in : [%s]".$/,join(', ',$a,$b,$c);

   my  $X = $M[0] * $a + $M[1] * $b + $M[2] * $c;
   my  $Y = $M[3] * $a + $M[4] * $b + $M[5] * $c;
   my  $Z = $M[6] * $a + $M[7] * $b + $M[8] * $c;

   #printf "prod: out : [%s]".$/,join(', ',$X,$Y,$Z);
   return ($X,$Y,$Z);
}
# -----------------------------
sub display {
  my ($x,$y,@M) = @_;
  print $x,'x',$y,$/;
  my $p = 0;
  foreach $i (0 .. $y-1) {
    foreach $j (0 .. $x-1) {
      printf '%7f ',$M[$p];
      $p++;
    }
    print $/;
  }
  print '.',$/;
}
# -----------------------------
sub inv3 {
  # see . http://www.wikihow.com/Inverse-a-3X3-Matrix
  my ($ax, $bx, $cx,
      $ay, $by, $cy,
      $az, $bz, $cz) = @_;

  # 1) compute Determinant :
  my $D = &det3(@_);
  # 2) Transpose :
  my @T = ($ax, $ay, $az,
           $bx, $by, $bz,
           $cx, $cy, $cz);
         #&display(3,3,@T); # OK
  # 3) cofactors = Matrix of minors
  my @CF = ( ($by*$cz-$cy*$bz),  ($bx*$cz-$cx*$bz), ($bx*$cy-$cx*$by),
             ($ay*$cz-$cy*$az),  ($ax*$cz-$cx*$az), ($ax*$cy-$cx*$ay),
             ($ay*$bz-$by*$az),  ($ax*$bz-$bx*$az), ($ax*$by-$bx*$ay));
           #&display(3,3,@CF); # OK
  # 4) adjugate
  my $i = 0;
  my @Adj= map { ($i++%2)? -$_ : $_; } @CF;
  # 5) M^-1 = 1/D(M) . adj(M)
  my @I = map { $_ / $D } @Adj;
  # voilà
  return @I;
}
sub det3 {
  my ($ax,$bx,$cx,$ay,$by,$cy,$az,$bz,$cz) = @_;
  # sum of cofactors
  my $D = $ax*($by*$cz-$cy*$bz)
        - $bx*($ay*$cz-$cy*$az)
        + $cx*($ay*$bz-$by*$az);
  return $D;
} 
# ------------------------
# skin tone space :
sub YAg_from_CMY {
  my ($C,$M,$J) = @_;
  my $D = $rXYZ[1] * $C + $gXYZ[1] * $M + $bXYZ[1] * $J;
  my ($A,$g) = ($M != 0) ? ($J/$M - 1,$C/$M) : ($J - 1, $C);
  return (1 - $D,$A,$g);
}
sub YAg_from_RGB {
  my @CMY = 
  return &YAg_from_CMY(@CMY);
}
sub skin_from_RGB {
  my $pi = atan2(0,-1);
  my ($C,$M,$J) = map { 1 - $_ } @_;
  my ($Y,$u,$v) = &Yuv_from_RGB(@_);
  my $Cr = sqrt($u*$u + $v*$v);
  my ($A,$g) = ($M != 0) ? ($J/$M - 1,$C/$M) : ($J - 1, $C); # goshty asian !
  my $a0 = atan2(0.5 / (1 - $bXYZ[1])*(-$rXYZ[1]),.5);
  my $H = (atan2($u,$v)-$a0)*180/$pi;
  my ($tint,$tone,$V) = sort {$a <=> $b} (@_);
  my $sat = ($V) ? ($V - $tint) / $V : 0;

  return ($Y,$Cr,$A,$g,$H,$Sat,$V,$u,$v);

}
# ------------------------
sub CMY_from_YAg {
  my ($Y,$A,$g) = @_;

  # J = M x ( 1 + A)
  # C = g  x M
  # D = a C + b M + c J (i.e. Y = a.R + b.G + c.B)
  # w/ D = 1 - Y : darkness

  # few definitions ...
  my $U = (1+$A); # unfair ness
  my $D = (1-$Y); # dark ness

  # a.C + b.M + c.J = D    x 1
  #  -C + g.M       = 0    x a
  #     + U.M    -J = 0    x 0
  # ------------------- +
  #  (b+ga).M + c.J = D    x 1
  #
  #       U.M    -J = 0    x c
  # ------------------- +
  #  (b+ga+cU).M    = D
  #            M    = D / (b+ga+cU)

  # solution ...
  my $M =   $D / ($gXYZ[1] + $rXYZ[1] * $g + $bXYZ[1]*$U);

  # a.C + b.M + c.J = D    x 1
  #  -C + g.M       = 0    x 0
  #     + U.M    -J = 0    x c
  # ------------------- +
  # a.C+(b+cU).M    = D    x g
  #
  #  -C+     g.M    = 0    x -(b+cU)
  # ------------------- +
  # (b+cU+ag).C      = gD
  #           C      = gD / (b+gacU)
  # 
  my $C = $g * $M;
  my $J = $U * $M;

  return ($C,$M,$J);

}
# ------------------------
sub xyY {
  my ($X,$Y,$Z) = @_;
  my ($x,$y) = (0.0, 0.0);

  my $scale = $X + $Y + $Z;
  $x = ($scale) ? $X/$scale : 0;
  $y = ($scale) ? $Y/$scale : 0;
  #$z = (1 - $x - $y);
  return ($x,$y,$Y);
}
sub XYZ_from_xyY {
  my ($x,$y,$Y) = @_;
  # x * ( X + Y + Z ) = X
  # y * ( X + Y + Z ) = Y
  #
  # (x-1).X +     x.Y + x.Z = 0     * -y
  #     y.X + (y-1).Y + y.Z = 0     * (x-1)
  # ---------------------------- +
  # ((y-1)(x-1)-xy).Y + ((x-1)y - xy).Z = 0
  # 
  # Z = ((y-1)(x-1)-xy).Y / (xy - (x-1)y)
  my $Z = (($y-1)*($x-1) - $x*$y)*$Y / ($x*$y - ($x-1)*$y);
  # x.(Y + Z) = (1-x).X
  #
  # X = x/(1-x) * (Y + Z)
  my $X = $x/(1-$x) * ($Y + $Z);
  return ($X,$Y,$Z);
}
# ------------------------
sub xyY_from_RGB {
  my ($X,$Y,$Z) = &XYZ_from_RGB(@_);
  my ($x,$y,$Y) = &xyY($X,$Y,$Z);
  #print "x=$x, y=$y, Y=$Y\n";
  return ($x,$y,$Y);
}
sub xyY_from_rgb {
  my ($X,$Y,$Z) = &XYZ_from_rgb(@_);
  return &xyY($X,$Y,$Z)
}
# ------------------------
sub CMY_from_RGB {
  return map { 1 - $_ } (@_);
}
sub CMY_from_rgb {
  my ($R,$G,$B) = &degamma(@_);
  return map { 1 - $_ } ($R,$G,$B);
}
# ------------------------
# CMY space
# RGB <-> CMY
sub complement {
  return map { 1 - $_ } @_;
}
# ------------------------
# CMYK space 
# J used instead of Y to avoid confusion with CIE-Y !
#
# parameter : black boost
sub CMYK_from_RGB {
  my ($C,$M,$Y) = &complement(@_);
  my $K = $boost->{'K'} * &min($C,$M,$J);
  my $scale = (1 - $K);
    $C = ($C - $K) / $scale;
    $M = ($M - $K) / $scale;
    $J = ($J - $K) / $scale;
  return ($C,$M,$Y,$K);
}

sub RGBX_from_RGB {
  my ($R,$G,$B) = @_;
  my $W = $boost->{'W'} * &min(@_);
  my $scale = (1 - $W);
    $R = ($R - $W) / $scale;
    $G = ($G - $W) / $scale;
    $B = ($B - $W) / $scale;
  return ($R,$G,$B,$W);
}
sub Ytuv_from_RGB {
  my ($R,$G,$B) = @_;

    # YPbPr (analog version of Y'CbCr) from R'G'B'
    # ====================================================
    # Y' = Kr * R'    + (1 - Kr - Kb) * G' + Kb * B'
    # Pb = 0.5 * (B' - Y') / (1 - Kb)
    # Pr = 0.5 * (R' - Y') / (1 - Kr)
    # ....................................................
    # R', G', B' in [0; 1]
    # Y' in [0; 1]
    # Pb in [-0.5; 0.5]
    # Pr in [-0.5; 0.5]

    # ITU BT.601 :       ITU-R BT.709 :    SMPTE : 
    # ------------       --------------    -------
    # Kr = 0.299         Kb = 0.0722       Kb = 0.087
    # Kb = 0.114         Kr = 0.2126       Kr = 0.212

    #y $Y = 0.299 * $R + 0.587 * $G + 0.114 * $B; # sRGB/D65 (ITU BT.601)
    my $Y = $rXYZ[1] * $R + $gXYZ[1] * $G + $bXYZ[1] * $B;
    my $t = 0.5 / (1 - $gXYZ[1]) * ($G-$Y); # t magenta/green
    my $u = 0.5 / (1 - $bXYZ[1]) * ($B-$Y); # u yellow/blue
    my $v = 0.5 / (1 - $rXYZ[1]) * ($R-$Y); # v cyan/red
    return ($Y,$t,$u,$v);
}
sub tuv_from_rgb {
  my @RGB = &degamma(@_);
  my (undef,$t,$u,$v) = &Ytuv_from_RGB(@RGB);
  return ($t,$u,$v);
}
sub RGB_from_Yuv {
  my ($Y,$u,$v) = @_;
  
  # $Y = $rXYZ[1] * $R + $gXYZ[1] * $G + $bXYZ[1] * $B;
  my $R = $Y + 2*(1-$rXYZ[1])*$V;
  my $G = $Y - 2*(1-$bXYX[1])*$bXYX[1]/$gXYZ[1] * $u
             - 2*(1-$rXYX[1])*$rXYZ[1]/$gXYZ[1] * $v;
  my $B = $Y + 2*(1-$bXYX[1])*$U;
  return ($R,$G,$B);
}

# -------------------------------------------------------------------------
sub gamut {
  my ($space) = @_;
  return if ! exists $convert->{$space};
  # range detection ...
  # primary triangle
  # xy walk ...
  my ($xr,$yr) = &ygY(@rXYZ);
  my ($xg,$yg) = &ygY(@gXYZ);
  my ($xb,$yb) = &ygY(@bXYZ);

  my @dot = ();
  my ($x,$y);
  # -------------------------------------------
  my ($cmax,$rmax) = (1023,767); # XGA screen
  my ($xmin,$ymin) = (0,0); # track min,max
  my ($xmax,$ymax) = (undef,undef);
  # scann all the point in the CIE triangle :
  for $row (reverse (0 .. $rmax)) {
    $y = $yg * $row/$rmax;
    foreach $col (0 .. $cmax) {
      my $a = $col/$cmax;
      $x = $xb * $a + $xb * (1 - $a);
      my @XYZ = &XYZ_from_xyY($x,$y,1);
      my @RGB = &RGB_from_XYZ(@XYZ);
      my $color = pack 'C3', &gamma(@RGB);
      my @coord = &{$convert->{$space}}(@RGB);
      push @dot,[@coord,$color];
      $xmin = $coord[0] if ($xmin < $coord[0]);
      $xmax = $coord[0] if ($xmax > $coord[0]);
      $ymin = $coord[1] if ($ymin < $coord[1]);
      $ymax = $coord[1] if ($ymax > $coord[1]);
    }
  }
  # compute gamut scale ...



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
  open PNM, "<$pnm"; binmode(PNM);
  $/ = "\n";
  local $_; # make $_ local as there is a loop above
  my $magic = <PNM>; chomp($magic);
  #printf "// magic : '%s'\n",$magic;

  #PBM P1 P4 --  1b/px (portable bit map)
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
        printf "// magic : '%s' %dx%d\n",$magic,$x,$y;
      } else {
        push @raster, map { $_ ? 0x000000 : 0x7F7F7F; } split(' ',$_);
	#printf "%s %dpx\n",$_,scalar @$raster;
      }
    }
    
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
        printf "// magic : '%s' %dx%d\n",$magic,$x,$y;
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
    $/ = "\n";
    $line = <PNM>;
    while ($line =~ m/^#/) { $line = <PNM>; }
    my $px = ($magic eq 'P5') ? 8 : 24; # pixel size;
    ($x,$y) = ($1,$2) if ($line =~ m/(\d+)\s+(\d+)/i);

    my ($xmin,$xmax) = (0,1280);
    my ($ymin,$ymax) = (0,960);
    # crop if bigger than 1280x960
    if ($x > 1024/$rescale || $y > 768/$rescale) {
       printf "scaling: %f i.e. %dx%d cropped to %dx%d\n",
          $rescale,$x,$y,1024/$rescale,768/$rescale;
       $xmin = ($x - (1024 / $rescale)) / 2;
       $xmax = ($x + (1024 / $rescale)) / 2 -1;
       $ymin = ($y - (768 / $rescale)) / 2;
       $ymax = ($y + (768 / $rescale)) / 2 - 1;
    }
    $max = <PNM>; chomp($max);
    $/ = undef;
    $buf = <PNM>;
    $np = int(8*length($buf)/$px);
    #printf "DBUG> buf : %d\n",length($buf);
    print "// magic: $magic ${x}x${y} $max ${np}px (limited to $xmin..$xmax x $ymin $ymax)\n";
    my @pix = unpack('C*',$buf);
    if ($magic ne 'P5') {
    for (0 .. $np-1) {
      # horizontal crop in necessary ...
      my ($i,$j) = ($_ % $x,int($_/$x));
      next if ($j < $ymin || $i < $xmin || $j > $ymax || $i > $xmax);
      #printf ".", unless $_ % $x;
      #printf "%d %d\n",int($_/$x),$_ unless $_ % $x;
      push @raster, pack('CCC',$pix[$_*3],$pix[$_*3+1],$pix[$_*3+2]);
    }
    printf "\n";
    } else { # P5
      @raster = map { pack('CCC',$_,$_,$_); } @pix;
    }
    undef @pix;
    if ($y > 768/$rescale) {
       printf "image cropped vertically to fit 768 array-height %d..%d (%drows)\n",
               $ymin,$ymax,768/$rescale;
       $y = 768/$rescale;
    }
    if ($x > 1024/$rescale) {
       printf "image cropped horizontally to fit 1024 array-width %d..%d (%dpix/row)\n",
               $xmin,$xmax,1024/$rescale;
       $x = 1024/$rescale;
    }
  }
  close PNM;

#use YAML;
#YAML::DumpFile( "loadpnm.yml", \@raster[0-1025] );

  my $pic = { 'x' => $x, 'y' => $y, 'raster' => $raster };
  undef $raster; # dereference @raster for future garbage collection
  return ($pic);  

}
# -------------------------------------------------------------------------
sub dump_ppm {
  my ($pic,$file) = @_;
  my ($x,$y) = ($pic->{x},$pic->{y});
  my $pix = $pic->{raster};
  printf "// dump: %dx%d for %s: %dpx\n",$x,$y,$file,scalar @$pix;
  return -1 unless (scalar @$pix);
  my $ascii=0;
  open PPM, ">$file"; binmode(PPM);
  printf PPM "P%d\n%d %d\n255\n",($ascii)?3:6,$x,$y if ($file =~ m/ppm/);
  print PPM @$pix;
  close PPM;
}
# -------------------------------------------------------------------------

# The following 2 sets of formulae are taken from information from Keith
# Jack's excellent book "Video Demystified" (ISBN 1-878707-09-4).
#
# RGB to YUV Conversion

# Y  =      (0.257 * R) + (0.504 * G) + (0.098 * B) + 16
# Cr = V =  (0.439 * R) - (0.368 * G) - (0.071 * B) + 128
# Cb = U = -(0.148 * R) - (0.291 * G) + (0.439 * B) + 128

# YUV to RGB Conversion

# B = 1.164(Y - 16)                   + 2.018(U - 128)
# G = 1.164(Y - 16) - 0.813(V - 128) - 0.391(U - 128)
# R = 1.164(Y - 16) + 1.596(V - 128)

# In both these cases, you have to clamp the output values to keep them
# in the [0-255] range. Rumour has it that the valid range is actually a
# subset of [0-255] (I've seen an RGB range of [16-235] mentioned)

# --------------------------------------------------------------------------
# Y = 0.299R + 0.587G + 0.114B
# U = 0.564 (B-Y)
# V = 0.713 (R-Y)
# U' = 0.492 (B-Y)
# V' = 0.877 (R-Y)
#
# R = Y + 1.403V
# G = Y - 0.344U - 0.714V
# B = Y + 1.770U
# 
# R' = Y + 1.140V'
# G' = Y - 0.395U' - 0.581V'
# B' = Y + 2.032U'

sub HSV_from_Yuv {
  my ($Y, $U, $V) = @_;

  my $pi = 3.14159265;
  #my $R = $Y + 1.403*$V;
  #my $G = $Y - 0.344*$U - 0.714*$V;
  #my $B = $Y + 1.770*$U;
  #my $a0 = atan2(-0.299*0.564,0.713*(1-0.299));

  my $R = $Y + 2*(1-.299)*$V;
  my $G = $Y - 2*(1-.114)*.114/.587 * $U
             - 2*(1-.299)*.299/.587 * $V;
  my $B = $Y + 2*(1-.114)*$U;
  my $a0 = atan2(0.5 / (1 - 0.114)*(-.299),.5);

  my $S = sqrt($U**2 + $V**2);
  my $H = (atan2($U,$V)-$a0)*180/$pi;
  my $V = &max($R,$G,$B);

  return ($H,$S,$V);
}
sub HSV_from_RGB {
  my ($Y,undef,$u,$v) = &Yuv_from_RGB(@_);
  return &HSV_from_Yuv($Y,$u,$v);
}
sub hsv_from_rgb {
  my ($Y,$u,$v) = &Yuv_from_rgb(@_);
  return &HSV_from_Yuv($Y,$u,$v);
}
sub y_from_px {
  my ($R, $G, $B) = &degamma( unpack('CCC',$_[0]) );
  my $Y = 0.299 * $R + 0.587 * $G + 0.114 * $B; # sRGB/D65
  return $Y;
}

sub Yuv_from_RGB {
  my ($Y, undef,$u,$v) = &Ytuv_from_RGB(@_);
  return ($Y,$u,$v);
}
sub Yuv_from_rgb {
  my @RGB = &degamma(@_); # (de)gamma'd
  my ($Y, undef,$u,$v) = &Ytuv_from_RGB(@RGB);
  return ($Y,$u,$v);
  #my $Y = 0.299 * $R + 0.587 * $G + 0.114 * $B; # sRGB/D65
  #my $X = 0.5 / (1 - 0.587) * ($G-$Y);
  #my $U = 0.5 / (1 - 0.114) * ($B-$Y);
  #my $V = 0.5 / (1 - 0.299) * ($R-$Y);
  #return ($Y,$U,$V);
}

sub rgb_from_Yuv {
  my ($Y, $u, $v) = @_;
  my $R = $Y + 2*(1-.299)*$v;
  my $G = $Y - 2*(1-.114)*.114/.587 * $u
             - 2*(1-.299)*.299/.587 * $v;
  my $B = $Y + 2*(1-.114)*$u;
  # de-gamma'd
  return &gamma($R,$G,$B);
}

sub min { (sort { $a <=> $b } @_ )[0] }
sub max { (sort { $b <=> $a } @_ )[0] }
# --------------------------------------------------------------------------
1;# Provence Technology Confidential and Proprietary
# --------------------------------------------------------------------------

