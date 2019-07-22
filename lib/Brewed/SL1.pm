#!perl
# vim: ts=2 et noai nowrap

package Brewed::SL1;
# Note:
#
# Config file and misc settings for SL1
#
# -- Copyright Intel, 2015 --
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
use vars qw/$dbug $VERSION @EXPORT_OK/;
# ----------------------------------------------------
local $VERSION = sprintf "%d.%02d", q$Revision: 0.0 $ =~ /: (\d+)\.(\d+)/;
my ($State) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------
use YAML::Syck qw(LoadFile);
use Brewed::HEIG qw(findpath);
# ----------------------------------------------------
# project setup :
our $es = 'es.exe';
my $PROJ = $ENV{PROJ} || 'SLx';

our $MACroot = 0xCAFE;
our $stmid = 0x00_0000;
# ----------------------------------------------------
our ($GoogleDrive,$deviceidfile,$py,$listport,$getSTMIDpy,$SLNDBfile,$projectdir);
# ----------------------------------------------------
if (-e 'settings.pl') {
  require 'settings.pl';
} else {
# config folder ...
our $GoogleDrive = &findpath(sprintf'Google Drive %s',$PROJ);
# ----------------------------------------------------
my $configpath = 'Shared with Me\superlight-asw';
$deviceidfile = &findpath('deviceid.txt') || $GoogleDrive.'\\'.$configpath.'\deviceid.txt';

# installation folders ...
our $py = 'c:\python34\python.exe';
#  $py = &findpath('"<27\|34\>" python.exe') || 'c:\Python\python.exe';
   $py = &findpath('34\ python.exe') || 'c:\Python\python.exe';
printf "py: %s\n",$py;

$listport = &findpath('list Port .exe');
#my $usbsearch = &findpath('usbSearch.exe');
# python's scripts ...
$getSTMIDpy = &findpath('getSTMid.py !.sw !~');
$SLNDBfile = &findpath('SLNumberDB.yml !.sw !~');
printf 'using %s'."\n",$SLNDBfile;

our $projectdir = &findpath("\\$ENV{USERNAME} Projects") || $ENV{USERPROFILE}.'\Qsync\Projects';

local *F;
open F,'>','settings.pl';
printf F <<'EOF','#',$PROJ,$GoogleDrive,$deviceidfile,$py,$listport,$getSTMIDpy,$SLNDBfile,$projectdir;
#!perl

# @(%s) Settings for %s 
#
our $GoogleDrive = '%s';
our $deviceidfile = '%s';
our $py = '%s';
our $listport = '%s';

our $getSTMIDpy = '%s';
our $SLNDBfile = '%s';

our $projectdir = '%s';
1;
EOF
close F;
}
my $IDtable = &loadIDtable($deviceidfile);
our $SLNDB = LoadFile($SLNDBfile);
our $SLN = { map { (hex($SLNDB->{$_}{STMid}) => $_) } (keys %$SLNDB) };
die if (hex($SLNDB->{'hans'}{STMid}) != 0x27002a);

push @EXPORT_OK, '$SLNDB' if defined $SLNDB; # allow export !
push @EXPORT_OK, '$GoogleDrive' if defined $GoogleDrive; # allow export !

my $commdir = sprintf '%s\%s\common',$projectdir,$PROJ;
my $pydir = sprintf '%s\%s\TestPuck',$projectdir,$PROJ;
my $iaspdir = sprintf '%s\%s\iasp34',$projectdir,$PROJ;

our $read;

sub getSLN {
  $ENV{COM} = &getCOM() unless exists $ENV{COM};
  my $sid = &getSTMid();
  printf "sid = $sid\n" if $dbug;
  my $SL = $SLN->{$sid};
  return $SL;
}

sub getCOM {
  # get device ID
  # COM6: FTDIBUS\VID_0403+PID_6001+A9Z1CA0GA\0000
  my $enum = sprintf '"%s" -vid %%s',$listport,$PROJ;
  local *L; open L,sprintf("$enum|",'0403'); local $\ = "\n"; my @buf = <L>; close L;
  my $USB = undef;
  foreach (@buf) {
    chomp();
    my ($com,$manuf,$desc) = split(' - ',$_);
    printf " %s: %s\n",$com,$desc if $dbug;
    $USB = $com if ($desc =~ m/FTDIBUS/);
  }
  return $USB;
}

sub getSTMid {
  my $getIDcmd = sprintf '"%s" "%s"',$py,$getSTMIDpy;
  local $read;
  open $read,"$getIDcmd|" or warn $!;
  local $/ = "\n";
  while (<$read>) {
    print $_ if $::verbose;
    chomp;
    $stmid = hex($1) if (m/0x(\w+)/);
  }
  close $read;
  return $stmid || 0xF400CD01;
}

sub getBTAddr {
# read out during boot ... (UART config : 115200 8-N-1)
#  5586|   | BT-Tcmd| INFO| 	Local Address:CA:FE:FA:DE:01:DB
#  
# note STM IDs are used to generates BT MAC addresses ...
  $ENV{COM} = &getCOM() unless exists $ENV{COM};
  my $stmid = &getSTMid(); 
  my $btaddr = ($MACroot<<32) | $stmid;
  return $btaddr;
}

sub loadIDtable {
   my $list = shift;
   local *L; open L,'<',$list or return undef or die $!;
   local $/ = "\n";
   my @IDtable = ();
   while (<L>) {
      chomp;
      my ($id,$add) = split(/\s*=\s*/,$_,2);
      $IDtable[$id], $add;
   }
   return \@IDtable;
}

# -----------------------------------
sub getTemp {
  my $Temp = undef;
  local $read;
  open $read,sprintf'%s %s/getTemp.py|',$py,$commdir;
  my $buf = <$read>; print <$read>; close $read;
	chomp($buf);
  my $Temp = 0.0 + $buf;
  print "T=$Temp\n";
  return $Temp||24.999;
}
# -----------------------------------
sub readTemp {
  my $Temp = undef;
  local $read;
  open $read,sprintf'%s %s/readTemp.py|',$py,$commdir;
	my ($sum,$m) = (0,0);
  while (<$read>) {
		chomp;
		if (m/ALS Temp\s*:\s*([\d.]+)/) {
		  my $T = $1;
			#printf "T %f\n",$T;
		  $sum += $T; $m++;
		} else {
		  printf "%s\n",$_;
		}
  }
	close $read;
	$Temp = $sum/$m;
  print "Temp $Temp\n";
	return $Temp;
}
# -----------------------------------
sub getdivR {
  my $divRreading = undef;
  local $read;
  open $read,sprintf'%s %s/readFac.py|',$py,$commdir;
	my ($sum,$m) = (0,0);
	my @DR = ();
  while (<$read>) {
		chomp;
		if (m/Div Ratio\s*:\s*([\d.]+)/) {
		  my $dr = $1;
			#printf "dr: %f\n",$dr;
		  $sum += $dr; $m++;
		} else {
		  printf "%s\n",$_;
		}
  }
	close $read;
	$divRreading = ($m) ? $sum/$m : $sum;
  print "divRreading: $divRreading\n";
	return $divRreading;
}
sub switchList {
  my $switch = sprintf('%s %s/loadDcdrv.py -s',$py,$pydir);
  my $status = system $switch unless $dbug;
  warn "! $status" if $status;
}
sub uploadUSBList { # via USB ...
  my ($listfile,$p) = @_;
  my $load = sprintf('%s %s/loadDcdrv.py -s -p %u %s > NUL',$py,$pydir,$p,$listfile);
  my $status = system $load unless $dbug;
  printf "[loadList] status: %s\n",$status if $?;
  warn "! $status" if $status;
}
# -----------------------------------
sub uploadBTList { # via BT ...
  my ($binfile,$addr) = @_;
  my $load = sprintf('%s %s/iasp_mini.py %s send_dc %s > NUL',$py,$iaspdir,$addr,$binfile);
  my $status = system $load unless $dbug;
  printf "[loadList] status: %s\n",$status if $?;
  warn "! $status" if $status;
}
# -----------------------------------

# ===========================================================================================
1; # $Source: /my/perl/module/SL1.pm $
