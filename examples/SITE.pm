#!/usr/bin/perl

# This script is to bootstrap my perl script when SITE libraries are not installed
BEGIN {
   if (! exists $ENV{SITE}) {
      $ENV{SITE} = "$ENV{HOME}/.site";
   }
}

package SITE;
require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
#@EXPORT_OK = qw(nickname);
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};

use strict;


use Cwd qw();
my $pwd=Cwd::cwd();

our $verbose = $::verbose || 0;
our $update = $::update || 0;
printf "SITE: %s\n",$ENV{SITE} if $verbose;

if (! -d $ENV{SITE}) {
  printf "info: creating %s\n",$ENV{SITE} if $verbose;
  mkdir $ENV{SITE};
}

chdir $ENV{SITE};
if (! -d $ENV{SITE}.'/lib') {
  # import files from the net
  print "info: (cloning site.git): \n";
  system("git clone https://github.com/michel47/site.git/ .")
} elsif ($::update) {
  if ($verbose) {
    print "info: (site.git): "; # do a pull from the central repo
    system("git pull origin master");
  } else {
    #print "info: (updating site.git)\n";
    system('git pull origin master 1>/dev/null 2>&1');
  }
}
chdir $pwd;

use lib $ENV{SITE}.'/lib';

1; # $Source: /my/perl/modules/SITE.pm,v $
