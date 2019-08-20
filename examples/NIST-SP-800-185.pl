#!/usr/bin/perl

#use lib $ENV{SITE}.'/lib';
BEGIN {our$update=1;my$p=rindex($0,'/');push@INC,($p>0)?substr($0,0,$p):'.'} # for SITE.pm
use SITE qw();
use KMAC qw(KMAC enc encode_base58);

printf qq(K:%s\n),'key';
printf qq(X:%s\n),'message';
my $km = &KMAC('key',"message",224);
printf qq(km:%s\n),enc($km);
printf qq(KMAC(K,X,224): %s\n),&encode_base58($km);

exit $?;
1;
