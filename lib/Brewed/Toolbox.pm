#!perl
# $RCSfile: toolbox.pm,v $
BEGIN { push @INC, '\perl\site\lib\Brewed' }

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
package templ;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};

use strict;
# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$exp $dbug $pgm $VERSION @EXPORT_OK/;
# ----------------------------------------------------
my $self = __PACKAGE__; $self =~ s,::,/,g; $self .= '.pm';
my ($sep) = ($0 =~ m:([/\\]):);
local $pgm = substr($0,rindex($0,$sep)+1);
local $VERSION = sprintf "%d.%02d", q$Revision: 1.4 $ =~ /: (\d+)\.(\d+)/;
my ($STATE) = q$State: Exp $ =~ /: (\w+)/; $exp = $STATE eq 'Exp';
# ----------------------------------------------------
{ # limited scope variables ...
  my ($RCSid)= q$Id: templ.pm,v 1.4 2009/08/16 23:32:57 michel Exp $ =~ /: (.*)/; # ident
  my $SCCS= sprintf '@(%s) %s: %s','#',__PACKAGE__,$VERSION; # what
}
# ----------------------------------------------------
$::dbug = ($::STATE eq 'dbug')?1:0 if defined $::STATE; # update main debug flag
# ----------------------------------------------------
# export all if State: dbug
if ($STATE eq 'dbug') {
  no strict 'refs';
  @EXPORT_OK = grep { defined &$_; } keys %{__PACKAGE__ . '::'};
  $dbug++;
}
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
use vars qw/ $testmode $pwd/;

use Cwd qw();
my $pwd = &Cwd::cwd();

if (exists $INC{$self}) { # imported ...
  printf "// %s v%s: \n",__PACKAGE__,$VERSION;
  #printf "loaded modules: %s\n",join "\n",keys %INC;
}

# -----------------------------------------
# install dir setup
use Brewed::HEIG qw(findpath);
our $es = 'es.exe'; # path to everything
my $QSYNC = $ENV{USERPROFILE}.'/Qsync';
# -----------------------------------------
# get various install path
our $ffmpeg = &findpath('ffmpeg.exe') || 'c:\sandbox\bin\ffmpeg.exe';
our $fastcap = &findpath('fastcapture\fastcapture.exe') || $QSYNC.'\programs\fastcapture\fastcapture.exe';
our $camcom = &findpath('CommandCam.exe') || $QSYNC.'\programs\Camera\CommandCam.exe';
our $webcam = &findpath('WebCamImageSave.exe') || $QSYNC.'\programs\Camera\WebCamImageSave.exe';
our $iccapture = &findpath('\IC Capture.exe') || $QSYNC.'\programs\The Imaging Source Europe GmbH\IC Capture 2.3\IC Capture.exe';
our $ffplay = &findpath('ffplay.exe') || 'c:\sandbox\bin\ffplay.exe';
our $iview = &findpath('\bin\i_view32.exe') || &findpath('i_view432.exe') || 'c:\sandbox\bin\i_view32.exe';

our $py = 'python.exe';
   $py = &findpath('"<27\|34\>" python.exe') || 'c:\Python\python.exe';
our $listport = &findpath('list Port .exe');
#my $usbsearch = &findpath('usbSearch.exe');
# ----------------------------------------------------

our $PROJ = $ENV{PROJ} || 'SL1';
our $projectdir = &findpath("\\$ENV{USERNAME} Projects") || $QSYNC.'\Projects';

our $GoogleDrive = &findpath(sprintf'Google Drive %s',$PROJ);


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if ($0 eq __FILE__) {
  $testmode++;
  $ENV{PATH} .= ';F:\toolbox\bin';
  $\ = "\012";
# ----------------------------------------------------------------------------
#understand variable=value on the command line...
eval "\$$1=$2"while ($ARGV[0]||'N/A') =~ /^(\w+)=(.*)/ && shift;
$verbose = ($quiet) ? 0 : 1;
# ======================================
if ($test) { # test follows ...
$| = 1;

print "Press any key to continue ..."; local $_ = <>; print;
}
# ======================================

}
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



# -----------------------------------------------
# -----------------------------------------------
# -----------------------------------------------

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
1+1==2;
