#!perl
# $RCSfile: Brewed.pm,v $
use strict;

# Note:
#   This work has been done during my time HEIG-VD
#   65% employment (CTI 13916)
# 
# -- Copyright HEIG-VD, 2013,2014,2015 --

package Brewed;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
#@EXPORT_OK = qw(nickname);
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$dbug $VERSION/;
# ----------------------------------------------------
my $self = __PACKAGE__; $self =~ s,::,/,g; $self .= '.pm';
my ($sep) = ($0 =~ m:([/\\]):); # /
local $::pgm = substr($0,rindex($0,$sep)+1);
local $VERSION = sprintf "%d.%02d", q$Revision: 1.4 $ =~ /: (\d+)\.(\d+)/;
my ($STATE) = q$State: Exp $ =~ /: (\w+)/;
$dbug = $STATE eq 'dbug'; $Brewed::exp = $STATE eq 'Exp';
# ----------------------------------------------------
{ # limited scope variables ...
    my ($RCSid)= q$Id: Brewed.pm,v 1.4 2009/08/16 23:32:57 michel Exp $ =~ /: (.*)/; # ident
    my $SCCS= sprintf '@(%s) %s: %s','#',__PACKAGE__,$VERSION; # what
}
# ----------------------------------------------------

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if (exists $INC{$self}) { # imported ...
    printf "// %s v%s: \n",__PACKAGE__,$VERSION;
    #printf "loaded modules: %s\n",join "\n",keys %INC;
}

if ($0 eq __FILE__) { # interactive !
    our $testmode++;
    $ENV{PATH} .= ';F:\toolbox\bin';
    $\ = "\012";
    # ----------------------------------------------------------------------------
    our ($verbose,$quiet);
    #understand variable=value on the command line...
    eval "\$$1=$2"while ($ARGV[0]||'N/A') =~ /^(\w+)=(.*)/ && shift;
    $verbose = ($quiet) ? 0 : 1;
    # ======================================
    if ($testmode) { # test follows ...
	$| = 1;
	use Brewed::PROV qw();
	use Brewed::HEIG qw();
	use Brewed::PERMA qw();
	use Brewed::STAMP qw();

	print "Press any key to continue ..."; local $_ = <>; print;
    }
    # ======================================

}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

10628206; # $Source: /my/perl/modules/developped/at/HEIG-VD/Brewed.pm,v $
