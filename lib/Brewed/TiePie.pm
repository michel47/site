#!perl
# $RCSfile: $
BEGIN { push @INC, '/strawberry/perl/site/lib','/strawberry/perl/site/lib/Brewed' }

package Brewed::TiePie;
require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw($ST_SINE $ST_ARBITRARY);
# Subs we will export if asked.
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};
local $VERSION = sprintf "%d.%02d", q$Revision: 1.00 $ =~ /: (\d+)\.(\d+)/;
my ($STATE) = q$State: Exp $ =~ /: (\w+)/; our $dbug = $STATE eq 'dbug';

use strict;
# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$dbug $VERSION @EXPORT_OK @EXPORT/;
# ----------------------------------------------------
{ local $0 = $::0; # extract program name !
$0 =~ s,\\,/,g; # unix style fs
$0 =~ s,(.*)/([^/]+)$,$2,;
our ($bin,$pgm)=($1||'.',$2||$0);
$pgm =~ s,\.[^.]+$,,; # suppress any extension
}
# ----------------------------------------------------
if ($0 eq __FILE__) { # interactive mode 
	printf "pkg: %s\n",__PACKAGE__;
  my $hDev = &tiePieConnect();
  &getstatus();
  exit 1;
}
# ----------------------------------------------------
# Documentation :
# tiePieConnect
#   return a dev handle
#
# -------------------------------------------------------------------------
my $NULL = undef;
# TIEPIE INITIAL CONFIG ...
my $STB_SINE = 0;
my $STB_TRIANGLE = 1;
my $STB_SQUARE = 2;
my $STB_DC = 3;
my $STB_NOISE = 4;
my $STB_ARBITRARY = 5;

my $ST_UNKNOWN = 0;
our $ST_SINE = (1<<$STB_SINE);
our $ST_TRIANGLE = (1<<$STB_TRIANGLE);
our $ST_SQUARE = (1<<$STB_SQUARE);
our $ST_ARBITRARY = (1<<$STB_ARBITRARY);
use Win32::API;
# -------------------------------------------------------------------------
#
# TiePie access functions
sub tiePieConnect {
				my $ST_TYPE = shift;
my $IDB_HS5 = 5;
my $IDM_ALL = 0xffff_ffff;
my $IDM_DEVID = 0x8000_0000;
my $ID_HS5 = $IDM_DEVID | ( 1 << $IDB_HS5);
our $LstUpdate = new Win32::API("libtiepie","LstUpdate",'I','V') or warn $!;
#$LstUpdate->Call($IDM_ALL);
$LstUpdate->Call($ID_HS5);
# check connected devices:
our $GetCount = new Win32::API("libtiepie","LstGetCount",'','I') or warn $!;
my $n = $GetCount->Call();
printf "%u devices detected\n",$n; return 0 if ($n == 0); # warn or die ?
# ---------------------------------------
my $DEVICETYPE_OSCILLOSCOPE = 0x00000001;
my $DEVICETYPE_GENERATOR = 0x00000002;
my $DEVICETYPE_I2CHOST = 0x00000004;
#
my $IDKIND_INDEX = 0x00000002; # Id parameter is an index
my $hDev = 0;
for my $id (0 .. $n-1) {
  if (&deviceCanOpen($IDKIND_INDEX,$id,$DEVICETYPE_GENERATOR) ) {
	  $hDev = &openGenerator($IDKIND_INDEX, $id);
          # Check Signal types
	  if ($hDev && (&signalTypes($hDev) & $ST_TYPE)) {
		  last;
	  } else {
		  $hDev = undef;
	  }
  }
}

return $hDev;
}
sub genConfig {
 my ($hDev,$type,$freq,$ampl,$symmetry,$offset) = @_;


  my ($ON,$OFF) = (0x1,0x0);
  &setOutputOn($hDev,$OFF);
  &setSignalType($hDev,$type);
  &setAmplitude($hDev,0.002); # 2mV amplitude for resonance
  &setFrequency($hDev,$freq); # fps
  &setAmplitude($hDev,$ampl); # amplitude
  &setSymmetry($hDev,$symmetry) if defined $symmetry; # symmetry
  &setOffset($hDev,$offset) if defined $offset; # offset
  &setOutputOn($hDev,$ON);
	#&genStart($hDev);
}
# -------------------------------------------------------------------------
sub deviceName {
  my ($idK,$id) = @_;
  our $LstGetDeviceName = new Win32::API("libtiepie","LstGetDeviceName",'IIPI','I') or warn $!;
  my $len = $LstGetDeviceName->Call($idK,$id,$NULL,0);
  my $name = "\0"x$len;
  $LstGetDeviceName->Call($idK,$id,$name,$len);
  #printf "device #%u: '%s' (%uc)\n",$id,$name,$len;
  return $name;
}
sub deviceNameShort {
  my ($idK,$id) = @_;
  our $LstGetDeviceNameShort = new Win32::API("libtiepie","LstGetDeviceNameShort",'IIPI','I') or warn $!;
  my $len = $LstGetDeviceNameShort->Call($idK,$id,$NULL,0);
  my $shortname = "\0"x$len;
  $LstGetDeviceNameShort->Call($idK,$id,$shortname,$len);
  #printf "device #%u: '%s' (%uc)\n",$id,$shortname,$len;
  return $shortname;
}
sub devNameShortest {
  my ($idK,$id) = @_;
  our $LstDevGetNameShortest = new Win32::API("libtiepie","LstDevGetNameShortest",'IIPI','I') or warn $!;
  my $len = $LstDevGetNameShortest->Call($idK,$id,$NULL,0);
  my $shortestname = "\0"x$len;
  $LstDevGetNameShortest->Call($idK,$id,$shortestname,$len);
  #printf "device #%u: '%s' (%uc)\n",$id,$shortestname,$len;
  return $shortestname;
}
sub deviceSerialNumber {
  my ($idK,$id) = @_;
  our $LstGetDeviceSerialNumber = new Win32::API("libtiepie","LstGetDeviceSerialNumber",'II','I') or warn $!;
  my $SN = $LstGetDeviceSerialNumber->Call($idK,$id);
  #printf "device #%u: SN:%08x\n",$id,$SN;
  return $SN;
}
sub devCalibrationDate {
  my ($idK,$id) = @_;
  our $LstDevGetCalibrationDate = new Win32::API("libtiepie","LstDevGetCalibrationDate",'II','P') or warn $!;
  my $cdate = $LstDevGetCalibrationDate->Call($idK,$id);
  #printf "device #%u: Calibrated on : %u\n",$id,$cdate;
  return $cdate;
}
sub deviceProductId {
  my ($idK,$id) = @_;
  our $LstGetDeviceProductId = new Win32::API("libtiepie","LstGetDeviceProductId",'II','I') or warn $!;
  my $PN = $LstGetDeviceProductId->Call($idK,$id);
  #printf "device #%u: ProductId:%08x\n",$id,$PN;
  return $PN;
}
sub deviceVendorId {
  my ($idK,$id) = @_;
  our $LstGetDeviceVendorId = new Win32::API("libtiepie","LstGetDeviceVendorId",'II','I') or warn $!;
  my $VendorId = $LstGetDeviceVendorId->Call($idK,$id);
  #printf "device #%u: VendorId:%08x\n",$id,$VendorId;
  return $VendorId;
}
sub deviceTypes {
  my ($idK,$id) = @_;
  our $LstGetDeviceTypes = new Win32::API("libtiepie","LstGetDeviceTypes",'II','I') or warn $!;
  my $types = $LstGetDeviceTypes->Call($idK,$id);
  #printf "device #%u: types:%08x\n",$id,$types;
  return $types;
}
sub deviceCanOpen {
  my ($idK,$id,$type) = @_;
  our $LstGetDeviceCanOpen = new Win32::API("libtiepie","LstGetDeviceCanOpen",'III','I') or warn $!;
  my $canopen = $LstGetDeviceCanOpen->Call($idK,$id,$type);
  return $canopen;
}
sub openGenerator {
  my ($idK,$id) = @_;
  our $LstOpenGenerator = new Win32::API("libtiepie","LstOpenGenerator",'II','I') or warn $!;
  my $handle = $LstOpenGenerator->Call($idK,$id);
  return $handle; # 0 on error ...
}
sub removeDevice {
  my ($idK,$id) = @_;
  my $sn = &deviceSerialNumber($idK,$id);
  our $LstRemoveDevice = new Win32::API("libtiepie","LstRemoveDevice",'I','V') or warn $!;
  return $LstRemoveDevice->Call($sn);
}
sub closeGenerator {
  my ($hDev) = @_;
  our $DevClose = new Win32::API("libtiepie","DevClose",'I','V') or warn $!;
  return $DevClose->Call($hDev);
}
sub signalTypes {
  my ($hDev) = @_;
  our $GenGetSignalTypes = new Win32::API("libtiepie","GenGetSignalTypes",'I','I') or warn $!;
  my $signaltypes = $GenGetSignalTypes->Call($hDev);
  return $signaltypes;
}
sub getSignalType {
  my ($hDev) = @_;
  our $GenGetSignalType = new Win32::API("libtiepie","GenGetSignalType",'I','I') or warn $!;
  my $signaltype = $GenGetSignalType->Call($hDev);
  return $signaltype;
}
sub setSignalType {
  my ($hDev,$type) = @_;
  our $GenSetSignalType = new Win32::API("libtiepie","GenSetSignalType",'II','I') or warn $!;
  my $signaltype = $GenSetSignalType->Call($hDev,$type);
  return ($signaltype == $type) ? 0 : 1;
}
sub setFrequency {
  my ($hDev,$freq) = @_;
	return 1 unless $hDev;
  our $GenSetFrequency = new Win32::API("libtiepie","GenSetFrequency",'ID','D') or warn $!;
  my $setfrequency = $GenSetFrequency->Call($hDev,$freq);
  if ($setfrequency == $freq) {
    return 1;
  } else {
    printf " set freq: %f\n",$setfrequency if $dbug;
    return 0;
  }
}
sub getFrequency {
  my ($hDev) = @_;
  our $GenGetFrequency = new Win32::API("libtiepie","GenGetFrequency",'I','D') or warn $!;
  my $frequency = $GenGetFrequency->Call($hDev);
  return $frequency;
}

sub getAmplitudeRanges {
  my ($hDev) = @_;
  our $genGetAmplitudeRanges = new Win32::API("libtiepie","GenGetAmplitudeRanges",'IPI','I') or warn $!;
  my $rangeCount = $genGetAmplitudeRanges->Call($hDev,$NULL,0);
  my $pRanges = "\0"x(8*$rangeCount); # range buffer;
     $rangeCount = $genGetAmplitudeRanges->Call($hDev,$pRanges,$rangeCount);
  printf "GenGetAmplitudeRanges:\n";
  for my $r (unpack('d'.$rangeCount,$pRanges) ) {
	  printf "- %f\n", $r;
  }
  print ".\n";
  return $rangeCount;
}
sub getAmplitudeRange {
  my ($hDev) = @_;
  our $genGetAmplitudeRange = new Win32::API("libtiepie","GenGetAmplitudeRange",'I','D') or warn $!;
  my $range = $genGetAmplitudeRange->Call($hDev);
  return $range;
}

sub setAmplitude {
  my ($hDev,$ampl) = @_;
	return 1 unless $hDev;
  our $GenSetAmplitude = new Win32::API("libtiepie","GenSetAmplitude",'ID','D') or warn $!;
  my $setamplitude = $GenSetAmplitude->Call($hDev,$ampl);
  #printf "set ampl: %g\n",$setamplitude;
  return ($setamplitude == $ampl) ? 1 : 0;
}
sub getAmplitude {
  my ($hDev) = @_;
  our $GenGetAmplitude = new Win32::API("libtiepie","GenGetAmplitude",'I','D') or warn $!;
  my $getamplitude = $GenGetAmplitude->Call($hDev);
  return $getamplitude;
}

sub setSymmetry {
  my ($hDev,$sym) = @_;
	return 1 unless $hDev;
  our $GenSetSymmetry = new Win32::API("libtiepie","GenSetSymmetry",'ID','D') or warn $!;
  my $setsymmetry = $GenSetSymmetry->Call($hDev,$sym);
  #printf "set sym %g\n",$setsymmetry;
  return ($setsymmetry == $sym) ? 1 : 0;
}
sub getSymmetry {
  my ($hDev) = @_;
  our $GenGetSymmetry = new Win32::API("libtiepie","GenGetSymmetry",'I','D') or warn $!;
  my $getsymmetry = $GenGetSymmetry->Call($hDev);
  return $getsymmetry;
}

sub setOffset {
  my ($hDev,$off) = @_;
	return 1 unless $hDev;
  our $GenSetOffset = new Win32::API("libtiepie","GenSetOffset",'ID','D') or warn $!;
  my $setoffset = $GenSetOffset->Call($hDev,$off);
  #printf "set off %g\n",$setoffset;
  return ($setoffset == $off) ? 1 : 0;
}
sub getOffset {
  my ($hDev) = @_;
  our $GenGetOffset = new Win32::API("libtiepie","GenGetOffset",'I','D') or warn $!;
  my $getoffset = $GenGetOffset->Call($hDev);
  return $getoffset;
}

sub getDataRawType {
  my ($hDev) = @_;
  our $GenGetDataRawType = new Win32::API("libtiepie","GenGetDataRawType",'I','N') or warn $!;
  my $getdatarawtype = $GenGetDataRawType->Call($hDev);
  return $getdatarawtype;
}
sub setDataRaw {
  my ($hDev,@data) = @_;
	return 1 unless $hDev;
  our $GenSetDataRaw = new Win32::API("libtiepie","GenSetDataRaw",'IPN','V') or warn $!;
	my $data = pack('v*', @data); # data = uint16
  printf "set dataraw: %s (%s)\n",substr(unpack('H*',$data),-16),join',', (unpack('v*',$data))[0..5];

  my $setdataraw = $GenSetDataRaw->Call($hDev,$data,scalar(@data));
  return $setdataraw;
}

sub setData {
  my ($hDev,@data) = @_;
	return 1 unless $hDev;
  our $GenSetData = new Win32::API("libtiepie","GenSetData",'IPN','V') or warn $!;
	#my $data = pack 'd*', @data;
	#my $data = [ map { pack 'f', $_ } @data ];
	my $data = pack('f*', @data) . "\x00";
  printf "set data: %s (%s)\n",substr(unpack('H*',$data),-16),join',', map { sprintf "%f",$_ }(unpack('f*',$data))[0..5];
  my $setdata = $GenSetData->Call($hDev,$data,scalar(@data));
  return $setdata;
}
sub getDataLength {
  my ($hDev) = @_;
  our $GenGetDataLength = new Win32::API("libtiepie","GenGetDataLength",'I','I') or warn $!;
  my $getdatalength = $GenGetDataLength->Call($hDev);
  return $getdatalength;
}
sub getDataLengthMin {
  my ($hDev) = @_;
  our $GenGetDataLengthMin = new Win32::API("libtiepie","GenGetDataLengthMin",'I','I') or warn $!;
  my $getdatalengthmin = $GenGetDataLengthMin->Call($hDev);
  return $getdatalengthmin;
}

sub getDataLengthMax {
  my ($hDev) = @_;
  our $GenGetDataLengthMax = new Win32::API("libtiepie","GenGetDataLengthMax",'I','I') or warn $!;
  my $getdatalengthmax = $GenGetDataLengthMax->Call($hDev);
  return $getdatalengthmax;
}

# control
sub setOutputOn {
  my ($hDev,$boolean) = @_;
  my $out = pack'C',$boolean;
  our $GenSetOutputOn = new Win32::API("libtiepie","GenSetOutputOn",'IC','C') or warn $!;
  my $setoutput = $GenSetOutputOn->Call($hDev,$out);
  #if ($setoutput eq $out) { printf "set output =0x%02X (%x successful)\n",$boolean, unpack('C',$setoutput); }
  return ($setoutput eq $out) ? 0 : 1;
}
sub getOutputOn {
  my ($hDev) = @_;
  our $GenGetOutputOn = new Win32::API("libtiepie","GenGetOutputOn",'I','C') or warn $!;
  return unpack'C',$GenGetOutputOn->Call($hDev);
}
sub genStart {
  my ($hDev) = @_;
  our $GenStart = new Win32::API("libtiepie","GenStart",'I','V') or warn $!;
  return $GenStart->Call($hDev);
}
sub genStop {
  my ($hDev) = @_;
  our $GenStop = new Win32::API("libtiepie","GenStop",'I','V') or warn $!;
  return $GenStop->Call($hDev);
}
sub genIsControllable {
  my ($hDev) = @_;
  our $GenIsControllable = new Win32::API("libtiepie","GenIsControllable",'I','I') or warn $!;
  return $GenIsControllable->Call($hDev);
}
# -------------------
sub getstatus {
 my $GetLastStatusStr = new Win32::API("libtiepie","LibGetLastStatusStr",'V','P') or warn $!;
 my $statusstr = $GetLastStatusStr->Call();
 printf "statusstr: %s.\n",$statusstr; # join'.',map {chr($_);} unpack'C*',$statusstr;
 my $GetLastStatus = new Win32::API("libtiepie","LibGetLastStatus",'V','N') or warn $!;
 my $status = $GetLastStatus->Call();
 return $status;
}
# -------------------------------------------------------------------------
1; # vim: ts=2
