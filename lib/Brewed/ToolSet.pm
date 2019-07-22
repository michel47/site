#!perl

package Brewed::Toolset;
require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};
local $VERSION = sprintf "%d.%02d", q$Revision: 1.00 $ =~ /: (\d+)\.(\d+)/;
my ($STATE) = q$State: Exp $ =~ /: (\w+)/; our $dbug = $STATE eq 'dbug';

# setting paths and env for tools ...
#  create a config files for fast "reuse"
#
our $es = 'es.exe'; # path to everything
sub findpath {
  my $es = 'es.exe';
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

# -----------------------------------------
my $SHARE = $ENV{SHARE};
my $programs = $ENV{SHARE}.'/Programs';
my $software = $ENV{SHARE}.'/software';
my $tools = $ENV{SHARE}.'/tools';


my $BTSYNC = $ENV{USERPROFILE}.'/BitTorrents Sync';
my $QSYNC = $ENV{USERPROFILE}.'/Qsync';
# -----------------------------------------
$ENV{GNUPLOT_BINARY} = 'c:\usr\local\gnuplot\bin\gnuplot.exe';
# -----------------------------------------
# choices: fastcapture,CommandCam,webcamImageSave,ffmpeg
# get install path to ffmpeg and i_view
my $ffmpeg = &findpath('static\bin\ffmpeg.exe') || $QSYNC.'\programs\ffmpeg\static\bin\ffmpeg.exe';
my $fastcap = &findpath('fastcapture\fastcapture.exe') || $QSYNC.'\programs\fastcapture\fastcapture.exe';
my $camcom = &findpath('CommandCam.exe') || $QSYNC.'\programs\Camera\CommandCam.exe';
my $webcam = &findpath('WebCamImageSave.exe') || $QSYNC.'\programs\Camera\WebCamImageSave.exe';
my $iccapture = &findpath('\IC Capture.exe') || $QSYNC.'\programs\The Imaging Source Europe GmbH\IC Capture 2.3\IC Capture.exe';
# -----------------------------------------
my $ffplay = &findpath('ffplay.exe') || 'c:\usr\tools\bin\ffplay.exe';
our $djpeg = &findpath('djpeg.exe') || $ENV{SHARE}.'\programs\jpeg-6b-4\bin\djpeg.exe';
our $iview = &findpath('\bin\i_view32.exe !\qnap') || &findpath('i_view432.exe') || 'c:\usr\local\IrfanView\i_view32.exe';

#our $iview = 'c:\usr\local\IrfanView\i_view32.exe';
if (-e $djpeg) {
our $convert =sprintf '"%s" %%s -outfile "%%s" "%%s"',$djpeg;
} else {
our $convert =sprintf '"%s" %%s /convert="%%s" "%%s"',$iview;
}

push @EXPORT_OK, '$iview','$convert';

use strict;
# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$dbug $VERSION @EXPORT_OK @EXPORT/;
# ----------------------------------------------------
if ($0 eq __FILE__) {
	#&info(); exit;
}
# ----------------------------------------------------
1;
