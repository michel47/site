#!perl

# BlockRing Module, part of the IPH*System platform 
#
# a block ring is 4 things :
#  3 pointers and a *bot
#
#  - latest block (top) : [{{QmLatest}}][top]
#  - first block (genesis) : [{{QmGenesis}}][genesis]
#  - previous block (prev) : [[{{QmPrevious}}][prev]
#
# A bot is
#  - a key pair (pk,sk)
#  - a DH secret to encrypt sk
#  - a script that sign document on behalf of owner
#  - a merge tool to update blockchain
#  - a set of routine for ownership and maintenance management

#
# read more: [IPHS](http://duckduckgo.com/?q=!g+IPH+System+platform+BlockRing)
#
# Note:
#   This work has been done during my time at GC-Bank
# 
# -- Copyright GCB, 2018 --

#
package BlockRing;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
#@EXPORT_OK = qw(nickname);
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};

use strict;
# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$dbug $VERSION/;
# ----------------------------------------------------
our $VERSION = sprintf "%d.%02d", q$Revision: 0.0 $ =~ /: (\d+)\.(\d+)/;
my ($State) = q$State: dbug $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------
my $mtime = (lstat(__FILE__))[9];
$VERSION = sprintf '%g',scalar &rev($mtime) unless ($VERSION ne '0.00');

if ($0 eq __FILE__) {

 exit $?;
}
# -----------------------------------------------------------------------
sub bringadd {
   my $nspace = shift; # symbolic namespace name
      my @files = @_;
   my $trigger = 'QmQmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
   my $genesis = 'QmakVdoJUfyvznTgySRKkKUQShr9AvxcxrHE56s2FZ3cqt';
   my $url = 'desktop'; # linux
      $url = 'url'; # windows
      $url = 'html'; # others
      mkdir '.brg' unless -d '.brg';
   my $ipyml = '.brg/registry.yml';
   my $brgfile = sprintf '.brg/%s.%s',$files[-1],$url;

   # ----------------------------
   # get current and previous hashes from files on disk
   my $pmh = {};
   my $lfile = 'ledger.md';
   my $logfile = '.brg/'.$lfile;
   my $hfile = 'ledger.html';
   my $htmfile = '.brg/'.$hfile;
   # ----------------------------
   if (-e '.brg/previous.yml') {
      my $mh = LoadFile('.brg/previous.yml'); 
      $pmh->{'previous'} = $mh->{'QmPrevious'};
      $pmh->{'HEAD'} = $mh->{'QmHEAD'};
      $pmh->{'trigger'} = $mh->{'QmTrigger'};
   } else {
      $pmh->{'previous'} = $genesis;
      $pmh->{'HEAD'} = $genesis;
      $pmh->{'trigger'} = $trigger;
   }
   printf "mh(prev): %s \n",$pmh->{'previous'};
   printf "mh(head): %s \n",$pmh->{'HEAD'};
   # ----------------------------


   if (0) {
      local *EXEC; open EXEC, sprintf "ipfs add -Q %s |",$logfile or die $!; local $/ = "\n";
      while (<EXEC>) {
         $pmh->{$2} = $1 if m/added\s+(\w+)\s+(.*)/;
         $pmh->{'etag'} = $1 if m/^(?:added\s+)?(Qm\S+)/;
      }
      close EXEC;
   }
   # ----------------------------
   # add files on IPFS !
   my $mh = &ipfsadd(@files);
   # ----------------------------
   local *LOG;
   if (-e $logfile) { # move old file out of the way
      unlink '.brg/prev-ledger.md';
      rename $logfile,'.brg/prev-ledger.md';
   }
   # ----------------------------
   # Check if Ledger need to be updated
   if ($pmh->{'trigger'} ne $mh->{'warp'}) { # /*\ CHANGES DETECTED !

   my $buf = sprintf "%% %s ledger update\n%% %s\n%% {{HDATE}}\n\n%s leger update\n====\n\n",
             $nspace,$ENV{USER},$nspace;
   # TBD : add a visu for mh->{wrap}
   foreach my $f (@files) {
      my (undef,$bname,$ext) = &bname($f);
      my $file = "$bname.$ext";
      my $mh58 = $mh->{$file};
      $buf .= sprintf "- [%s](http://gateway.ipfs.io/ipfs/%s)\n",$file,$mh58;
   }
   $buf .= "\n--&nbsp;\\\n<small>[previous additions](http://127.0.0.1:8080/ipfs/{{QmPrevious}}";
   $buf .= " ~ made w/ <3</small>\n";

   # --- update links ...
   my $log = $buf;
   $log =~ s/\{\{QmPrevious\}\}/$pmh->{'previous'}/;
   $log =~ s/\{\{HDATE\}\}/$pmh->{'HDATE'}/;
   open LOG,'>',$logfile;
   print LOG $log;
   close LOG;
   # test with new files old ledger link 
   my $mhb = &ipfsadd('-n',$logfile); # recompute hash without storing the file!
   # ----------------------------
      my $HDATE = &hdate($^T);
      printf "log %s -> %s \n",$pmh->{'etag'},$mhb->{$lfile};
      my $log = $buf;
      $log =~ s/\{\{QmPrevious\}\}/$pmh->{$hfile}}/;
      $log =~ s/\{\{HDATE\}\}/$HDATE/;
      open LOG,'>',$logfile;
      print LOG $log;
      close LOG;
      system "pandoc -t html -o $htmfile $logfile";
      # update HEAD !
      my $mhh = &ipfsadd('-n',$htmfile);
      local *F; open F,'>','.brg/mhashes.yml' or die $!;
      printf F "--- \nQmPrevious: %s\nQmHEAD: %s\nQmTrigger: %s\nHDATE: %s\n",
         $pmh->{'HEAD'},$mhh->{$hfile},$mh->{'warp'},$HDATE;
      close F;
   }

#exit;

use YAML::Syck qw(Dump); printf "pmh: %s.\n",Dump($pmh);
my ($etime,$ltime) = &etime(@files);
my $version = &rev($ltime);
my (undef,$bname,$ext) = &bname($logfile);
my $name = "$bname.$ext";
#printf "%s: %s http://127.0.0.1:8080/ipfs/%s\n",$nspace,$version,$mhb->{$name};

if (-e $ipyml) {
# append mhash registry
open F,'>>',$ipyml; # ~/odrive/Tommy/public_html/etc/ipregistry.yml
printf F "%s: %s %s\n",$nspace,$version,$mh->{wrap};
close F;
}
delete $mh->{$name};
return $mh;
}

# -----------------------------------------------------------------------
sub etime {
  my ($atime,$mtime,$ctime) = map { undef; } ( 0 .. 2);
  my ($etime,$ltime) = ($mtime,$ctime);
  foreach my $f (@_) {
    my ($a,$m,$c) = (lstat($_[0]))[8,9,10];
    my $e = ($c > $m) ? ($m > $a) ? $a : $m : $c; # pick the earliest
    my $l = ($c > $m) ? $c : $m; # latest of the two
    $etime = $e if ($e < $etime);
    $ltime = $l if ($l > $ltime);
  }
  return (wantarray) ? ($etime,$ltime) : $etime;
} 
# -----------------------------------------------------------------------
sub ipfsadd {
   if (! -e $_[-1]) { # empty dir !
      return { wrap => 'QmQmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'};
   }
   my @files = (); my @dirs = (); my @opts = ();
   while (@_) { # auto detect required options ...
      my $f = shift(@_);
      if (-f $f) {
         push @files, $f;
      } elsif (-d $f) {
         push @dirs, $f;
      } elsif ($f =~ m/^-/) {
         push @opts, $f;
      } 
   }
   if (scalar(@dirs) == 0) { # use wrap mode if no dir
      push @opts, '-w';
   } else {
      push @opts, '-r';
   }

   my $mh = {};
   my $cmd = sprintf 'ipfs add %s %s',join(' ',@opts),
      join(' ',map { sprintf '"%s"',$_ } @files, @dirs);
   print "$cmd\n" if $dbug;

   open EXEC,"$cmd|"; local $/ = "\n";
   while (<EXEC>) {
      print $_ if $dbug;
      $mh->{$2} = $1 if m/added\s+(\w+)\s+(.*)/;
      $mh->{'wrap'} = $1 if m/added\s+(\w+)/;
      $mh->{'^'} = $1 if m/^(Qm\S+)/;
      die $_ if m/Error/;
   }
   close EXEC;

   return $mh;
}
# -----------------------------------------------------------------------
sub rev {
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime($_[0]))[0..7];
  my $rweek=($yday+&fdow($_[0]))/7;
  my $rev_id = int($rweek) * 4;
  my $low_id = int(($wday+($hour/24)+$min/(24*60))*4/7);
  my $revision = ($rev_id + $low_id) / 100;
  #print "revision  : $revision ($rev_id, $low_id)\n";
  return (wantarray) ? ($rev_id,$low_id) : $revision;
}
# -------------------------------------------------------------------
sub fdow {
   my $tic = shift;
   use Time::Local qw(timelocal);
##     0    1     2    3    4     5     6     7
#y ($sec,$min,$hour,$day,$mon,$year,$wday,$yday)
   my $year = (localtime($tic))[5]; my $yr4 = 1900 + $year ;
   my $first = timelocal(0,0,0,1,0,$yr4);
   our $fdow = (localtime($first))[6];
   #printf "1st: %s -> fdow: %s\n",&hdate($first),$fdow;
   return $fdow;
}
# -----------------------------------------------------------------------
sub hdate { # return HTTP date (RFC-1123, RFC-2822) 
  my $DoW = [qw( Sun Mon Tue Wed Thu Fri Sat )];
  my $MoY = [qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec )];
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday) = (gmtime($_[0]))[0..6];
  my ($yr4,$yr2) =($yy+1900,$yy%100);
  # Mon, 01 Jan 2010 00:00:00 GMT

  my $date = sprintf '%3s, %02d %3s %04u %02u:%02u:%02u GMT',
             $DoW->[$wday],$mday,$MoY->[$mon],$yr4, $hour,$min,$sec;
  return $date;
}
# -----------------------------------------------------------------------
sub bname { # extrac basename etc...
  my $f = shift;
  $f =~ s,\\,/,g; # *nix style !
  my $s = rindex($f,'/');
  my $fpath = ($s > 0) ? substr($f,0,$s) : '.';
  my $file = substr($f,$s+1);

  if (-d $f) {
    return ($fpath,$file);
  } else {
     my $p = rindex($file,'.');
     my $bname = ($p>0) ? substr($file,0,$p) : $file;
     my $ext = lc substr($file,$p+1);
     $ext =~ s/\~$//;
     return ($fpath,$bname,$ext);

  }

}
# -----------------------------------------------------------------------
1; # $Source: /my/perl/modules/developped/at/GCB/BlockRing.pm,v $
