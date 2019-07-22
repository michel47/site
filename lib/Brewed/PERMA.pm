#!perl
# vim: ts=2 et noai nowrap

package Brewed::PERMA;
# Note:
#   This work has been done during my time HEIG-VD
#   65% employment (CTI 13916)
# 
# -- Copyright HEIG-VD, 2014,2015 --

# -----------------------------------------------------
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
local $VERSION = sprintf "%d.%02d", q$Revision: 0.0 $ =~ /: (\d+)\.(\d+)/;
my ($State) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------
our $alphabet = join('',grep(!/[0OlI]/,split//,
  '-0123456789'. 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
                 'abcdefghijklmnopqrstuwvxyz')). 
  q/+.@$%_,~`'=;!^[]{}()#&/. 'lOI0'. #
  '<>:"/\\|?*'; #;

use Time::Local qw(timelocal);
my $yepoch = 1970; my $yoffset = 100 * int($yepoch/100);
my $year = $yoffset + (localtime($^T))[5]; # this year
my $first = timelocal(0,0,0,1,0,$year);
my $fdow = (localtime($first))[6];

my $windows = (-e '/dev/null') ? 0 : 1;

# ----------------------------------------------------
sub dircut {
  my $dir = shift;
  $dir =~ s/^[a-z]://io;
  $dir =~ y,\\,/,;
  $dir =~ s,/[\.\d]+[_ ],/,g;
  $dir =~ s,/([^/])[^/]*,/\1,g;
  return $dir;
}
# -----------------------------------------------------
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
  
  $bname =~ s/(F[0-9]{5}|[a-f0-9]{7})[0-9]{4,8}\s+[0-9]{4}_[0-9]{5}$/\1/;
  $bname =~ s/\s+([a-z]{5}-)?v[0-9.]{4}$//; # remove version ...
  
  $bname =~ s/\s+[0-9]{4}_[0-9]{5}$//;
  $bname =~ s/\s-\s[A-Z0-9]{4}$//;
  $bname =~ s/\s[a-f0-9]{7}$//;
  $bname =~ s/\s+\(\d+\)$//;
  $bname =~ s/\s*\(.*[Cc]onflict(?:ed)?[^)]*\)$//;
  $bname =~ s/_conflict-\d+-\d+$//;
  $bname =~ s/\s+[b-z][aeiouy][a-z][aeiouy][b-z]$//;   

  return ($fpath,$bname,$ext);

  }

}
# ----------------------------------------------------
#printf "%s\n",&sname('c:\$Recycle.Bin\@archives\orphans'); exit 0;
sub sname { # shortpath/name ... (only first letters)
	my ($file) = @_;
	 	  $file =~ s,\\+,/,go;
  my $s = rindex($file,'/');
  my $fpath = ($s>0) ? substr($file,0,$s) : '.';
	my $fname = ($s) ? substr($file,$s+1) : $file;
  #print "p:$fpath f:$fname\n";
  my $spath = lc $fpath;
		$spath =~ y[/@a-z0-9][]dc;
    $spath =~ s,/(.)[^/]*,\1,g;
  return "$spath/$fname";
}
# -----------------------------------------------------
# CamelCase
sub camel {
  #use re 'debug';
  my $str = $_[0];
  $str =~ s/(?:www|http|com)/ /igo; # certain names
  $str =~ s/[^a-z0-9#]/ /igo; # remove all odd char
  $str =~ s/\s*(.)([^ ]*)/\u$1\L$2\E/go;
  return $str; 
}
# -----------------------------------------------------
sub has_same_content {
  my ($f1,$f2) = @_;
  my ($z1,$z2) = map { (lstat($_))[7];} ($f1,$f2); # size
  return 0 if ($z1 != $z2);
  my ($t1,$t2) = map { (lstat($_))[10];} ($f1,$f2); # ctime
  local *F1,*F2;
  open F1,'<',$f1 or warn $!; open F2,'<',$f2;
  my $chunk = 0x4b000; # 300K
  my $same = 1;
  my ($buf1,$buf2) = ('','');
  while (!eof(F1)) {
    read(F1,$buf1,$chunk,0);
    read(F2,$buf2,$chunk,0);
    if ($buf1 eq $buf2) { $same = 1 } else { $same = 0; last }
  }
  close F1; close F2;
  return ($same) ? ($t1<$t2) ? -1 : +1 : 0;
}
# --- WINDOS Specifics --------------------------------
if ($windows) {
# load windows module at runtime !  NOT TESTED YET !
foreach my $module ('Win32::File') {
  my $file = $module;
  $file =~ s[::][/]g;
  $file .= '.pm';
  require $file;
  $module->import;
}

# -----------------------------------------------------
sub is_junction {
  my ($path) = @_;
  eval "use Win32API::File qw(GetFileAttributes :FILE_ATTRIBUTE_);" or die $@ if $@;
  my $uAttrs = GetFileAttributes( $path );
  return ($uAttrs & &FILE_ATTRIBUTE_REPARSE_POINT) ? 1 : undef;
}
# ------------------------
sub resolve_junction {
  my ($path) = @_;
  my $target = undef;
  open F,sprintf'junction.exe "%s"|',$path;
  while (<F>) {
	  #print;
    $target = $1 if (m/Name:\s+(.*)/);
  }
  return $target;
}
# ------------------------
sub read_lnk {
  eval "use Win32::Shortcut;" or die $@ if $@;
  my $link = Win32::Shortcut->new();
  $link->Load($_[0]);
  #print "Shortcut to: $link->{'Path'} $link->{'Arguments'} \n";
  my $cmd = undef;
  if ($link->{'Arguments'}) {
    $cmd = join' ',$link->{'Path'},$link->{'Arguments'};
  } else {
    $cmd = $link->{'Path'};
  }
  $link->Close();
  return $cmd;
}
# --- OTHER OSes --------------------------------------
} else {
}
# -----------------------------------------------------
# is system doesn't have inode ... guess with metadata
# likelyhood a file has all same parameters is low!
#
sub get_inode { # purpose to identify hardlinked files (heuristic)
 my ($dev,$inode,$mode,$nlink,$uid,$gid,$rdev,$size,
     $atime,$mtime,$ctime,$blksize,$blocks)  =
    (defined $_[1]) ? @_ : lstat($_[0]);

 if ($inode == 0) {
    $dev = $rdev = $atime = undef;
    my $ino = reverse sprintf '%02d%02d:%db%dx%dz%dn%d,%d:%d,%d:%d:%d',$dev,$rdev,
       $inode,$blocks,$blksize,$size,$nlink, $uid,$gid,
       $atime,$mtime,$ctime;
    return $ino; 
 } else {
    return $inode; 
 }
}
# -----------------------------------------------------

sub is_identical {
  # bit to bit identical
  # /!\ load both file in memory, can do a buffered version later
  my ($f1,$f2) = @_;
  local *F1,*F2;
  open F1,'<',$f1; binmode F1;
  open F2,'<',$f2; binmode F2;
  my $b1 = <F1>;
  my $b2 = <F2>;
  return ($b1 eq $b2) ? 1 : 0;
  
}
# -----------------------------------------------------
sub is_pidentical { # heuristic for pseudo-identical file (false positive possible)
  my ($f1,$f2) = @_;
  return 1 if ($f1 eq $f2); # same name
  my ($n1,$n2) = map { (lstat($_))[3];} ($f1,$f2);
  return 0 if ($n1 == 1 || $n1 != $n2); # file not (hard)linked
  my ($i1,$i2) = map { &get_inode($_);} ($f1,$f2);
  return ($i1 == $i2) ? 1 : 0;
}

# ------------------------
sub get_etag ($;@){ # ETag validator
  my @data = ($#_ < 1) ? (stat($_[0]))[7,9,10,1] : @_;
  my $version = scalar grep { $_ } @data;
  use Digest::MurmurHash qw(murmur_hash);
  my $etag = murmur_hash(join ':','ETag'.$version,@_);
  return $etag;
}
# ------------------------
sub get_uuhash { # hash similar to one used on FastTrack network (Kazaa)
 local *F = shift; seek(F,0,0);
 my $size = (lstat(F))[7];
 my $chunk = 0x4b000; # 300K
 my $buf = undef; read(F,$buf,$chunk,0);
 use Digest::MD5 qw//;
 my $md5 = Digest::MD5::md5($buf);

 use Digest::CRC qw//;
 $Digest::CRC::_typedef{'smallhash'} =
#          [width,init,xorout,refout,poly,refin,cont];
           [32,0xffffffff,0x00000000,1,0x04C11DB7,1,0],
# crc32 => [32,0xffffffff,0xffffffff,1,0x04C11DB7,1,0],
 my $msg = Digest::CRC->new( type => 'smallhash' );

 my $p = 0x10_0000; # offset position ...
 while ($p + 2 * $chunk < $size ) {
   #printf "%.1fM n:%u\n",$p/0x10_0000,$n;
   seek(F,$p,0); read(F,$buf,$chunk,0); $msg->add($buf);
   #my $crc = $msg->clone->digest;
   $p <<= 1;
 }
 seek(F,-$chunk,2); # 300K before the end;
 read(F,$buf,$chunk,0); $msg->add($buf);
 my $crc = $msg->digest;
 my $uuhash = $md5 . pack 'V',$crc^$size; # little-endien
 #printf "// crc: %08x\n",$crc;
 #printf "// crc^size: %08x\n",$crc^$size;
 #printf "// md5: %s\n",unpack'H*',$md5;
 #printf "// uuhash: %s\n",unpack'H*',$uuhash;
 use MIME::Base64 qw/encode_base64/;
 return &encode_base64($uuhash,'');

}
# -----------------------------------------------------
sub etime {
  my ($atime,$mtime,$ctime) = (lstat($_[0]))[8,9,10];
  my $etime = ($ctime > $mtime) ? ($mtime > $atime) ? $atime : $mtime : $ctime; # pick the earliest
  my $ltime = ($ctime > $mtime) ? $ctime : $mtime; # latest of the two
  return (wantarray) ? ($etime,$ltime) : $etime;
} 
# -----------------------------------------------------
sub ver {

  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime(int $_[0]))[0..7];
  my $rweek=($yday+$fdow)/7;
  my $rev_id = int($rweek) * 4;
  my $low_id = int(($wday+($hour/24)+$min/(24*60))*4/7);
  my $version = ($rev_id + $low_id) / 100;
  return ( wantarray ) ? ($rev_id,$low_id) : $version;
}
# -----------------------------------------------------
sub color {
  my $colors = [qw{red orange yellow green aquamarine blue violet indigo pink}];
  my $n = scalar(@$colors);
  my $key = int ($_[0]) % $n; # modulo !
  my $color = $colors->[$key];
  return $color;
}
# -----------------------------------------------------
sub flower { # return a flower name based on time
  my $flowers = [qw{acacia begonia coriander dahlia echinacea foxglove geranium
               hyacinth iris jonquil kurume lavander mimosa narciss ochidea
	       pensea qween_lily rose saffron tulip urn violet wahlenbergia xerophyta yarrow zephyranthes}];
  my $n = scalar(@$flowers);
  my $key = int ($_[0]) % $n; # modulo !
  my $flower = $flowers->[$key];
  return $flower;
}
# -----------------------------------------------------
sub word { # 20^4 * 6^3 words (25bit worth of data ...)
 my $vo = [qw ( a e i o u y )]; # 6
 my $cs = [qw ( b c d f g h j k l m n p q r s t v w x z )]; # 20
 my ($nc,$nv) = (scalar(@{$cs}),scalar(@{$vo}));
 my $n = $_[0];
 my $str = '';
 while ($n >= $nc) {
   my $i = $n % $nc;
      $n /= $nc;
      $str .= $cs->[$i];
   my $i = $n % $nv;
      $n /= $nv;
      $str .= $vo->[$i];
 }
 $str .= $cs->[$n];
 return $str;	
}
# -----------------------------------------------------
sub digest {
 my $alg = shift;
 my $msg = undef;
 use Digest qw();
 if ($alg eq 'GIT') {
   $msg = Digest->new('SHA1') or die $!;
   $msg->add(sprintf "blob %u\0",length($_[0]));
 } else {
   $msg = Digest->new($alg) or die $!;
 }
 $msg->add($_[0]);
 my $digest = lc( $msg->hexdigest() );
 return $digest; #hex form !
}
# -----------------------------------------------------
sub digestf {
 my $alg = shift;
 my $msg = undef;
 use Digest qw();
 my $type = ref(\$_[0]);
 #print "type: $type\n";
 local *F;
 if ($type eq 'GLOB') {
   *F = shift;
 } else { # SCALAR
   open F,'<',$_[0] or do { warn qq{"$_[0]": $!}; return undef };
   binmode(F) unless $_[0] =~ m/\.txt$/;
 }
 seek(F,0,0);
 if ($alg eq 'GIT') {
   $msg = Digest->new('SHA1') or die $!;
   $msg->add(sprintf "blob %u\0",(lstat(F))[7])
 } else {
   $msg = Digest->new($alg) or die $!;
 }
 $msg->addfile(*F);
 close F unless ($type eq 'GLOB');
 my $digest = lc( $msg->hexdigest() );
 return $digest; #hex form !
}
# -----------------------------------------------------
sub get_digest {
 my $alg = shift;
 my $msg = undef;
 use Digest qw();
 local *F;
 open F,'<',$_[0] or do { warn qq{"$_[0]": $!}; return undef };
 binmode(F) unless $_[0] =~ m/\.txt$/;
 if ($alg eq 'GIT') {
   $msg = Digest->new('SHA1') or die $!;
   $msg->add(sprintf "blob %u\0",(lstat($_[0]))[7])
 } else {
   $msg = Digest->new($alg) or die $!;
 }
 $msg->addfile(*F);
 close F;
 my $digest = lc( $msg->hexdigest() );
 return $digest; #hex form !
}
# -----------------------------------------------------
sub get_md5 ($) {
 use Digest::MD5 qw();
 my $msg = Digest::MD5->new or die $!;
 local *F;
 open F, "<$_[0]" or do { warn qq{"$_[0]": $!}; return undef };
 binmode(F) unless $_[0] =~ m/\.txt$/;
 $msg->addfile(*F);
 close F;
 my $digest = uc( $msg->hexdigest() );
 return $digest; #hex form !
}
# -----------------------------------------------------
sub githash ($) {
 use Digest::SHA1 qw();
 my $msg = Digest::SHA1->new or die $!;
 local *F;
 open F, "<$_[0]" or do { warn qq{"$_[0]": $!}; return undef };
 my $header = sprintf "blob %u\x00",(lstat(F))[7];
 $msg->add($header);
 binmode(F) unless $_[0] =~ m/\.txt$/o;
 $msg->addfile(*F);
 close F;
 my $digest = lc( $msg->hexdigest() );
 return $digest; #hex form !
}
# -----------------------------------------------------

sub tiger {
 use Digest::Tiger qw();
 local *F;
 open F,'<',$_[0]; binmode F; local $/ = undef;
 my $buf = <F>; close F;
 return &Digest::Tiger::hexhash($buf);
}
# -----------------------------------------------------
sub b2a { # binary to ascii85 (little endian)
  no integer;
  my $s = '';
  my $symb = [split //,'-0123456789'. 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
            'abcdefghijklmnopqrstuwvxyz'.  q/+.@$%_,~`'=;!^[]{}()#&/. #
            '<>:"/\\|?*' ]; #
  foreach my $n (unpack 'N*',$_[0]) {
    my $e = '';
    while($n) {
      $e = $symb->[$n % 85] . $e; # LSB
      $n = int( $n / 85); # MSB reminder
    }
    $s .= substr('-----'.$e,-5);
  }
  return $s;
}
# -----------------------------------------------------
sub base36 { # letters and numbers
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
sub base37 { # letters + numbers + .
  use integer;
  my $n = shift;
  my $e = '';
  #return('a') if $n == 0;
  while ( $n ) {
    my $c = $n % 37;
    $e .=  ($c<=9)? $c : chr(0x37 + $c); # 0x37: upercase, 0x57: lowercase
    $n = int $n / 37;
  }
  return $e; # scalar reverse $e;
}
# -----------------------------------------------------
# alphabet: abcdefghijklmnopqrstuvwxyz {}!(),#;&- 0-9 (26*2+10)
# bitcoin: 123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz
sub mhash58 {
  my $sha2 = shift;
  my $mhash = pack('H*','1220'.$sha2);
  my $ipfs = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  my $mhash58 = &encode_base($mhash,$ipfs);
  return $mhash58;
}
# -----------------------------------------------------
sub decode_base {
  use Math::BigInt;
	my ($s,$alphab) = @_;
  my $radix = Math::BigInt->new(length($alphab));
  my $n = Math::BigInt->new(0);
  my $j = Math::BigInt->new(1);
  while($s ne '') {
    my $c = substr($s,-1,1,''); # consume chr from the end !
    my $i = index($alphab,$c);
    return '' if ($i < 0);
    my $w = $j->copy();
    $w->bmul($i);
    $n->badd($w);
    $j->bmul($radix);
  }
  my $h = $n->as_hex();
  # byte alignment ...
  my $d = int( (length($h)+1-2)/2 ) * 2;
  $h = substr('0' x $d . substr($h,2),-$d);
  return pack('H*',$h);
}

sub encode_base {
  use Math::BigInt;
	my ($d,$alphab) = @_;
  my $radix = Math::BigInt->new(length($alphab));
  my $h = '0x'.unpack('H*',$d);
  my $n = Math::BigInt->from_hex($h);
  my $e = '';
  while ($n->bcmp(0) == +1)  {
    my $c = Math::BigInt->new();
    my ($n,$c) = $n->bdiv($radix);
    $e .= substr($alphab,$c->numify,1);
  }
  return reverse $e;
}

sub decode_basen {
  use Math::BigInt;
	my ($s,$radix) = @_;
  my $n = Math::BigInt->new(0);
  my $j = Math::BigInt->new(1);
  while($s ne '') {
    my $c = substr($s,-1,1,''); # consume chr from the end !
    my $i = index($alphabet,$c);
    return '' if ($i < 0);
    my $w = $j->copy();
    $w->bmul($i);
    $n->badd($w);
    $j->bmul($radix);
  }
  my $h = $n->as_hex();
  # byte alignment ...
  my $d = int( (length($h)+1-2)/2 ) * 2;
  $h = substr('0' x $d . substr($h,2),-$d);
  return pack('H*',$h);
}
sub encode_basen {
  use Math::BigInt;
	my ($d,$radix) = @_;
  my $h = '0x'.unpack('H*',$d);
  my $n = Math::BigInt->from_hex($h);
  my $e = '';
  while ($n->bcmp(0) == +1)  {
    my $c = Math::BigInt->new();
    my ($n,$c) = $n->bdiv($radix);
    $e .= substr($alphabet,$c->numify,1);
  }
  return reverse $e;
}
# -----------------------------------------------------
sub flush { my $h = select($_[0]); my $af=$|; $|=1; $|=$af; select($h); }
# -----------------------------------------------------
sub copy ($$) {
 my ($src,$trg) = @_;
 local *F1, *F2;
 return undef unless -r $src;
 return undef if (-e $trg && ! -w $trg);
 open F2,'>',$trg or warn "-w $trg $!"; binmode(F2);
 open F1,'<',$src or warn "-r $src $!"; binmode(F1);
 local $/ = undef;
 my $tmp = <F1>; print F2 $tmp;
 close F1;

 my ($atime,$mtime,$ctime) = (lstat(F1))[8,9,10];
 #my $etime = ($mtime < $ctime) ? $mtime : $ctime;
 utime($atime,$mtime,$trg);
 close F2;
 return $?;
}
# -----------------------------------------------------
1; # $Source: /my/perl/modules/at/HEIG-VD/PERMA.pm,v $
