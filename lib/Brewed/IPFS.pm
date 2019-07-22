#!perl

# Note:
#   This work has been done during my time at AHE
# 
# -- Copyright GCM, 2016,2017 --

#
# Private : ipfs daemon --transport-shared-key <current-key>
#
package Brewed::IPFS;
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
my ($State) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------
$VERSION = &version(__FILE__) unless ($VERSION ne '0.00');

#
# Gateways :
our @gateways = qw(
https://mercury.i.ipfs.io
https://earth.i.ipfs.io
http://planets.everywhere.avid.com
);
#
# -------------------------------------------------------------------
my $fdow = 0;
{  my $tic = time;
   use Time::Local qw(timelocal);
##     0    1     2    3    4     5     6     7
#y ($sec,$min,$hour,$day,$mon,$year,$wday,$yday)
   my $year = (localtime($tic))[5]; my $yr4 = 1900 + $year ;
   my $first = timelocal(0,0,0,1,0,$yr4);
   $fdow = (localtime($first))[6];
   #printf "1st: %s -> fdow: %s\n",&hdate($first),$fdow;
}
# -----------------------------------------------------------------------
sub flush { my $h = select($_[0]); my $af=$|; $|=1; $|=$af; select($h); }
# -----------------------------------------------------------------------
sub dhash {
   my $alg = shift;
   my $rnd = 2;
   my $tmp = join('',@_);
   use Digest qw();
   my $msg = Digest->new($alg) or die $!;
   for (1 .. $rnd) {
      $msg->add($tmp);
      $tmp = $msg->digest();
      $msg->reset;
      #printf "#%d tmp: %s\n",$_,unpack'H*',$tmp;
   }
   return $tmp
}
# -----------------------------------------------------------------------
sub bindigest ($@) {
 my $alg = shift;
 my $msg = undef;
 use Digest qw();
 $msg = Digest->new($alg) or die $!;
 $msg->add(join'',@_);
 my $digest = $msg->digest();
 return $digest; # binary form !
}
# -----------------------------------------------------------------------
sub hexdigest ($@) {
 my $alg = shift;
 my $msg = undef;
 my $txt = join'',@_;
 use Digest qw();
 if ($alg eq 'GIT') {
   $msg = Digest->new('SHA1') or die $!;
   $msg->add(sprintf "blob %u\0",length($txt));
 } else {
   $msg = Digest->new($alg) or die $!;
 }
 $msg->add($txt);
 my $digest = lc( $msg->hexdigest() );
 return $digest; #hex form !
}
# -----------------------------------------------------------------------
sub get_digest ($@) {
 my $alg = shift;
 my $header = undef;
 use Digest qw();
 local *F; open F,$_[0] or do { warn qq{"$_[0]": $!}; return undef };
 #binmode F unless $_[0] =~ m/\.txt/;
 if ($alg eq 'GIT') {
   $header = sprintf "blob %u\0",(lstat(F))[7];
   $alg = 'SHA-1';
 }
 my $msg = Digest->new($alg) or die $!;
    $msg->add($header) if $header;
    $msg->addfile(*F);
 my $digest = uc( $msg->hexdigest() );
 return $digest; #hex form !
}
# -----------------------------------------------------------------------
sub word { # 20^4 * 6^3 words (25bit worth of data ...)
 my $n = $_[0];
 my $vo = [qw ( a e i o u y )]; # 6
 my $cs = [qw ( b c d f g h j k l m n p q r s t v w x z )]; # 20
 my $str = '';
 while ($n >= 20) {
   my $c = $n % 20;
      $n /= 20;
      $str .= $cs->[$c];
   my $c = $n % 6;
      $n /= 6;
      $str .= $vo->[$c];
 }
 $str .= $cs->[$n];
 return $str;	
}
# -----------------------------------------------------------------------
sub version {
  my @times = sort { $a <=> $b } (lstat($_[0]))[9,10];
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime($times[-1]))[0..7]; # most recent
  my $rweek=($yday+$fdow)/7;
  my $rev_id = int($rweek) * 4;
  my $low_id = int(($wday+($hour/24)+$min/(24*60))*4/7);
  my $version = ($rev_id + $low_id) / 100;
  #my ($atime,$mtime,$ctime) = (lstat($_[0]))[8,9,10];
  #print "y:$yday f:$fdow m:$mtime e:$etime, $mday.$mon.$yy -> rw=$rweek $rev_id $low_id $version\n";

  if (wantarray) {
     my $md6 = &get_digest('MD6',$_[0]);
     print "$_[0] : md6:$md6\n" if $dbug;
     my $pn = hex(substr($md6,-4)); # 16-bit
     my $build = &word($pn);
     return ($version, $build);
  } else {
     return sprintf '%g',$version;
  }
}
# -----------------------------------------------------------------------
sub rev {
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime($_[0]))[0..7];
  my $rweek=($yday+$fdow)/7;
  my $rev_id = int($rweek) * 4;
  my $low_id = int(($wday+($hour/24)+$min/(24*60))*4/7);
  my $revision = ($rev_id + $low_id) / 100;
  return (wantarray) ? ($rev_id,$low_id) : $revision;
}
# -----------------------------------------------------------------------
sub stamp36 {
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime(int $_[0]))[0..7];
  my $_1yr = 365.25 * 24;
  my $yhour = $yday * 24 + $hour + ($min / 60 + $sec / 3600);
  my $stamp = &base36(int($yhour/$_1yr * 36**4)); # 18 sec accuracy
  #print "$yy/$mon/$mday $hour:$min:$sec : $yday HH$yhour\n";
  return $stamp;
}
# -----------------------------------------------------------------------
sub minihash { # self signed hash
  my ($msg,$hash);
  my $digest = &hexdigest('GIT',$msg);


}
# -----------------------------------------------------------------------
sub nextcode { # compute code for reaching a certain hash ...
  my ($msg,$code,$level) = @_;
  my $digest;
  my $l = 3;
  my $n = &ubase58($code);
  my $final = unpack('H*',pack'N*',$n);
  my $target = substr($final,0,$l);
  while (1) {
    $code = &base58($n);
    $digest = &hexdigest('GIT',$msg.$code);
    my $hash = substr($digest,0,$l);
    #print "code: $code; hash: [$hash]\n";
    if ($hash eq $target) {
      printf "  digest: (%s)%s code: %s target: %s (l:%u)\n",$hash,substr($digest,$l),$code,$target,$l if $dbug;
      last if ($l == $level);
      $l++;
      $target = substr($final,0,$l);
    }
    $n++;
  }
  return ($digest,$code);
}
# -----------------------------------------
sub ipfspost {
  my $data = shift;
  use YAML::Syck qw(DumpFile);
  DumpFile('data.yml',$data);
  my $ipfs = 'ipfs.exe';
  my $cmd = sprintf '"%s" add %s',$ipfs,'data.yml';
  local *EXEC; open EXEC,"$cmd|"; local $/ = "\n";
   my ($mh58_i,$mh58);
   while (<EXEC>) {
     $mh58_i = $1 if m/added\s+(\w+)\s+data.yml/i;
     $mh58 = $1 if m/added\s+(\w+)/;
     $mh58 = $1 if m/^(Qm\S+)/;
     die $_ if m/Error/;
   }
   close EXEC;
   
   return $mh58;

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
      $mh->{$2} = $1 if m/added\s+(\w+)\s+(.*)/;
      $mh->{'wrap'} = $1 if m/added\s+(\w+)/;
      $mh->{'^'} = $1 if m/^(Qm\S+)/;
      die $_ if m/Error/;
   }
   close EXEC;

   return $mh;
}
# -------------------------------------------------------------------
sub version {
  my ($atime,$mtime,$ctime) = (lstat($_[0]))[8,9,10];
  #y $etime = ($ctime > $mtime) ? ($mtime > $atime) ? $atime : $mtime : $ctime;
  #y @times = sort { $a <=> $b } (lstat($_[0]))[9,10]; # ctime,mtime
  my $vtime = $mtime; # $times[-1];

  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime($vtime))[0..7]; # most recent
  printf "%s/%s/%s \@ %d:%02d:%02d\n",$mday,$mon+1,$yy+1900,$hour,$min,$sec if $dbug;
  our $fdow = &fdow($vtime) if (! defined $fdow || $fdow < 0);
  my $rweek=($yday+$fdow)/7;
  my $rev_id = int($rweek) * 4;
  my $low_id = int(($wday+($hour/24)+$min/(24*60))*4/7);
  my $version = ($rev_id + $low_id) / 100;

  return sprintf '%g',$version;
}
# -------------------------------------------------------------------
sub fdow {
   my $tic = shift;
   use Time::Local qw(timelocal);
##     0    1     2    3    4     5     6     7
#y ($sec,$min,$hour,$day,$mon,$year,$wday,$yday)
   my $year = (localtime($tic))[5]; my $yr4 = 1900 + $year ;
   my $first = timelocal(0,0,0,1,0,$yr4);
   $fdow = (localtime($first))[6];
   #printf "1st: %s -> fdow: %s\n",&hdate($first),$fdow;
   return $fdow;
}
# -------------------------------------------------------------------
sub _ipfsadd {
   my @content = @_;

   # base is last of first ...
   my $base = ($content[0] =~ m/^-/) ? $content[-1] : $content[0];

   my $ver = '411';
   #y $ipfs = sprintf '%s\ExtRepos\IPLD\go-ipfs\ipfs_%s.exe',$ENV{SYNC},$ver;
   #y $ipfs = 'c:\opt\tools\go-ipfs\ipfs.exe';
   my $ipfs = 'ipfs';
   my $wrap = (-f $base) ? '-w' : '';

   my $qbase = $1 if ($base =~ m/\\?([^\\]+)$/);
   $qbase =~ s/([\(\)])/\\\1/g; # protect special char for regexp
   #print "qbase = $qbase\n";
   my $cmd = sprintf '"%s" add %s %s',$ipfs,$wrap,
        join(' ',map { sprintf '"%s"',$_ } @content);
   local *EXEC; open EXEC,"$cmd|"; local $/ = "\n";
   my ($mh58_i,$mh58);
   while (<EXEC>) {
     print;
     $mh58_i = $1 if m/added\s+(\w+)\s+$qbase/i;
     $mh58 = $1 if m/added\s+(\w+)/;
     $mh58 = $1 if m/^(Qm\S+)/;
     die $_ if m/Error/;
   }
   close EXEC;
   #print "mh58_i : $mh58_i\n";
   #my $ans = <STDIN> if $dbug;

   # append mhash registry
   my $version = &version($base);
   open F,'>>','../misc/ipregistry.yml';
   printf F "%s: %s %s\n",$base,$version,$mh58_i;
   close F;

   return $mh58;
}
# -----------------------------------------------------------------------
sub base36 {
  use integer;
  my ($n) = @_;
  my $e = '';
  return('0') if $n == 0;
  while ( $n ) {
    my $c = $n % 36;
    $e .=  ($c<=9)? $c : chr(0x37 + $c); # 0x37: upercase, 0x57: lowercase
    $n = int $n / 36;
  }
  return scalar reverse $e;
}
# -----------------------------------------------------
sub base58 { # 62 char except 0IOl
  use integer;
  my ($n) = @_;
  my $e = '';
  return('1') if $n == 0;
  while ( $n ) {
    my $c = $n % 58;
    $e .=  chr(0x31 + $c); # 0x31: 0 excluded
    $n = int $n / 58;
  }
  $e =~ y/1-j/1-9A-HJ-NP-Za-km-z/;
  return scalar reverse $e;
}
# -----------------------------------------------------
sub ubase58 { # .123456789ABCDEFH.JKLMN.PQRSTUVWXYZabcdefghijk.mnopqrstuvwxyz
  my ($s) = @_;
  $s =~ y/1-9A-HJ-NP-Za-km-z/1-j/;
  my $n = 0;
  while ($s ne '') {
    my $c = substr($s,0,1,'');
    my $v = ord($c) - 0x31;
    #print "{c:$c}{v:$v}{n:$n}\n";
    $n *= 58; $n += $v;
  }
  return $n;
}
# -----------------------------------------------------
sub addr {
   my $version = 0x7;
   my $pkey = shift;
   my $hash160 = &bindigest('RIPEMD-160',&bindigest('SHA-256',$pkey)); # binary!
   my $khash = pack('C',$version) . $hash160;
   my $dhash = &dhash('SHA-256',$khash);
   my $chksum = substr($dhash,0,4);  
   my $addr = encode_base58($khash,$chksum); # 168 + 24 = 192
   return $addr;
}
# -----------------------------------------------------
sub encode_base58_gmp {
  use Math::BigInt;
  use Encode::Base58::GMP qw();
  my $hex = unpack'H*',join'',@_;
  my $bint = Math::BigInt->from_hex($hex);
  my $h58 = Encode::Base58::GMP::encode_base58($bint);
  return $h58;
}
sub encode_base58_from_hex {
  use Math::BigInt;
  use Encode::Base58::GMP qw();
  my $bint = Math::BigInt->from_hex($_[0]);
  my $h58 = Encode::Base58::GMP::encode_base58($bint);
  return $h58;
}
sub decode_base58_to_hex {
  use Math::BigInt;
  use Encode::Base58::GMP qw();
  my $bint = Math::BigInt->new(Encode::Base58::GMP::decode_base58($_[0]));
  #print "bi: $bint\n";
  my $h16 = $bint->as_hex();
  return $h16;
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
sub encode_basen {
  my ($n,$alphabet) = @_;
  my @alphabet = split //, $alphabet;
  my $base= scalar @alphabet;
  return $alphabet[0] if $n == 0;
  my $str = ""; # this will be the end value.
  while( $n > 0 ) {
    #printf "// c=%s\n", $alphabet[$n % $base];
    $str = $alphabet[$n % $base] . $str; # LSB
    $n = int( $n / $base ); # MSB reminder
  }
  #printf "// n=%d base=%d => %s\n",$n,$base,$str;
  return $str;
}

sub decode_basen {
  my ($str,$alphabet) = @_;
  my $i = 0;
  my %value = map { $_ => $i++; } split //, $alphabet;
  my $base= length $alphabet; # or scalar keys %value
  my $n = 0;
  for( split //, $str ) {
      $n *= $base;
      $n += $value{$_};
   }
   return $n;
}
# -----------------------------------------------------------------------
sub get_http {
  use Socket;
  my ($url) = @_;
  #print "url = $url\n";
  my ($host,$hport,$document) = ($url =~ m{http://([^/:]+)(?:\:(\d+))?(/.*)?}); #/#
  $hport = 80 unless $hport;
  my ($server,$port) = ($host,$hport);
  $document = '/' unless $document;
  if (exists $ENV{http_proxy}) {
     ($server,$port) = ($ENV{http_proxy} =~ m{http://([^/:]+)(?:\:(\d+))?}); #/#
  }
  my $iaddr = inet_aton($server);
  my $paddr = sockaddr_in($port, $iaddr);
  my $proto = (getprotobyname('tcp'))[2]||6;
  my $socket = undef;
  socket($socket, PF_INET, SOCK_STREAM, $proto)
                          or die "socket: $!";
  connect($socket, $paddr) or die "connect: $!";
  select((select($socket),$|=1)[0]) ;
  # 1.0 such that the connection is closed after ..
  printf $socket "GET %s HTTP/1.0\r\n",$document;
  printf $socket "Host: %s:%s\r\n",$host,$hport;
  print  $socket "Connection: close\r\n";
  print  $socket "\r\n";
  local $/ = undef;
  my $buf = <$socket>;
  close $socket or die "close: $!";
  return $buf;
}
# -----------------------------------------------------------------------
sub bname { # extract basename etc...
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
  
  $bname =~ s/\s+\(\d+\)$//; # remove (1) in names ...

  return ($fpath,$bname,$ext);

  }
}
# -----------------------------------------------------------------------
1; # $Source: /my/perl/modules/developped/at/AHE/IPFS.pm,v $
