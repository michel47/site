#!perl

package Brewed::seed;

# $Author: michelc $
# $WWID: 10628206 $

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw($seed); # exporting a variable ...
our %EXPORT_TAGS = (all => [ @EXPORT ]);

use strict;
# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$dbug $VERSION/;
# ----------------------------------------------------
our $VERSION = sprintf "%d.%02d", q$Revision: 0.0 $ =~ /: (\d+)\.(\d+)/;
my ($STATE) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($STATE eq 'dbug')?1:0;
# ----------------------------------------------------

if (defined $::dbug && $::dbug) {
use Brewed::PERMA qw();
my ($package, $filename, $line) = caller(0);
my $git = &Brewed::PERMA::githash($filename);
my $id7 = lc substr($git,0,7);
my $nu = hex($id7); # 28-bit

#printf "p:%s f:%s l:%u\n",$package,$filename,$line;
our $seed = srand($nu);
printf "// id7: %s\n",$id7;

} else {
our $seed = srand();
}

1;
