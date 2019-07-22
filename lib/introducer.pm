#!perl

# vim: nospell
our @diceware;

package introducer; 
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = grep { $_ =~ m/^get_/ && defined &$_; } keys %{__PACKAGE__ . '::'};
# Subs we will export if asked.
#@EXPORT_OK = qw(nickname);
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};
#
# compute introducer for /etc/passwd

use strict;
# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$dbug $VERSION @EXPORT_OK @EXPORT/;
# ----------------------------------------------------
local $VERSION = sprintf "%d.%02d", q$Revision: 0.0 $ =~ /: (\d+)\.(\d+)/;
my ($State) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------


# ------------------------------------------
# constants ... file-scoped
#my $cloud = $ENV{SYSTEMDRIVE}.'/mnt/Cloud'; $cloud = '' unless -d $cloud;
my $DICT = (exists $ENV{DICT}) ? $ENV{DICT} : '/usr/share/dict';

if ($0 eq __FILE__) {
	my $name = 'mgcombes@gmail.com';
  my $h32 = &h32_mmhash($name);
  my ($n1,$n2,$n3,$n4) = map { $h32 % $_ } (13,29,37, 999);
  my $letter = &letter($n3);
  printf "sn: %s-%s\n",$letter,$n4;
	#  $name = 'sabrina@mint.com';
  printf "number: %s\n",&get_number($name);
  printf "city: %s\n",&get_city($name);

  printf "color: %s %s\n",&color($n1),&flower($n2);

	printf "%s:%s <%s> (%s)\n",&get_username($name),'***',$name,&get_displayname($name);
	exit 1;
}

sub get_displayname { 
  my ($key) = @_;
  my $nick = get_nickname($key);
  my $ini = substr($nick,0,1);
  my $lastname = get_lastname($key);
  my $lni = uc(substr($lastname,0,1));
  my $name = "$nick $lni.";
  return $name;
}
sub get_username { 
  my ($key) = @_;
  my $nick = get_nickname($key);
  my $ini = substr($nick,0,1);
  my $lastname = get_lastname($key);
  my $name = lc(substr($nick,0,1) . $lastname);
  return $name;
}
#
sub get_city { # compute nickname
  my ($key) = @_;
  my $h32 = &h32_mmhash($key);
  my $dico = sprintf '%s/TZcities.txt',$DICT;
  open F,'<', $dico or die "$dico: $!" ;
  my $size = (stat(F))[7];
  my $n = int($h32 % $size + .9999) - 6;
  seek(F,$n,0);
  local $/ = "\n";
  my $city = <F>;$city = <F>;
   $city = $1 if ($city =~ m/^([^\(]+)\s+\(/);
   
  close F;
  chomp($city);
  return $city;
}
sub get_word5 { # compute 5 letter words
  my ($key) = @_;
  my $h32 = &h32_mmhash($key);
  my $dico = sprintf '%s/dic-0294/length05.txt',$DICT;
  open F,'<', $dico or die "$dico: $!" ;
  my $size = (stat(F))[7];
  my $n = int($h32 % $size + .9999) - 6;
  seek(F,$n,0);
  local $/ = "\n";
  my $word = <F>;$word = <F>;
  close F;
  chomp($word);
  return $word;
}
sub get_snumber { # get sovereign number ...
   my $hash = &hashr('SHA-256',1,@_);
   my $id40 = substr($hash,0,5); # 40 bit ID
   my $nu = hex unpack'H*',$id40;
   return ($nu);
}
sub get_number {
  my ($key) = @_; # key is alphanumeric + some specials
  my $h32 = &h32_mmhash($key);
  my $len = length($key);
  my $spe = $key; $spe =~ tr/0-9a-z//d;
  my $s = length($spe);
  my $n = 1 << (1 + $len * log(10 + 26 - 1 + $s ) / log(2));

  my $num = int ($h32) % $n; # modulo !
  return $num;
}
sub letter {
  my $c = int($_[0]) % 26;
  return chr(0x41 + $c);
}
sub color { # 10 colors
  my $colors = [qw{red orange yellow green aquamarine blue violet indigo pink}];
  my $n = scalar(@$colors);
  my $key = int ($_[0]) % $n; # modulo !
  my $color = $colors->[$key];
  return $color;
}
sub flower { # 26 flowers
  my $flowers = [qw{acacia begonia coriander dahlia echinacea foxglove geranium
               hyacinth iris jonquil kurume lavander mimosa narciss ochidea
	       pensea qween_lily rose saffron tulip urn violet wahlenbergia xerophyta yarrow zephyranthes}];
  my $n = scalar(@$flowers);
  my $key = int ($_[0]) % $n; # modulo !
  my $flower = $flowers->[$key];
  return $flower;
}
sub word13 { # a word from Diceware list
  my $i = shift;
  my $dw = scalar @diceware;
  if ($dw < 1) {
    my $dico = $DICT.'/Diceware7776.txt';
    local *DIC; open DIC,'<',$dico or die "$dico $!";
    local $/ = "\n"; our @diceware = map { chomp($_); $_ } <DIC>;
    close DIC;
    $dw = scalar @diceware;
  }
  return $diceware[$i%$dw];
}
sub wordn {
  my ($i,$dico) = @_;
   local *DIC; open DIC,'<',$dico or die "$dico $!";
   local $/ = "\n"; our @wordlist = map { chomp($_); $_ } <DIC>;
   close DIC;
   my $dw = scalar @wordlist;
  return $wordlist[$i%$dw];
}

sub get_nickname { # compute nickname
  my ($key) = @_;
  my $h32 = &h32_mmhash($key);
  open F,'<', $DICT.'/firstnames.txt';
  local $/ = "\n";
  my $size = (stat(F))[7];
  my ($n0,$n1) = (0,$size);
  #print "h32 = $h32\n";
  while ($n0 < $n1) {
    my $n = int ( ($n0 + $n1)/2 );
    seek(F,$n,0);
    my $line = <F>;$line = <F>;
    my ($name,undef,$cpf) = split /\s+/,$line,3;
    #printf "%.1f<%.1f<%.1f cpf=%.1f%s%u (%f) l=%.1f: %s\n",$n0,$n,$n1,$cpf,
    #  ($cpf<$h32)?'<':'>',$h32,$n1-$n0,$n/74,$name;
    last if ($n1-$n0<=1);
    if ($cpf > $h32) {
      $n1 = $n;
    } else {
      $n0 = $n;
    }
  }
  seek(F,$n1,0);
  my $line = <F>;$line = <F>;
  close F;
  my ($name,undef,$cpf) = split /\s+/,$line;
  return $name;

}

sub get_lastname { # compute introducer for /etc/passwd
  my ($key) = @_;
  my $h32 = &h32_jhash($key);
  open F,'<', $DICT.'/lastnames.txt';
  local $/ = "\n";
  # (Percent Point Function = inverse of the cumulative distribution function)
  my $size = (stat(F))[7];
  my ($n0,$n1) = (0,$size);
  #print "h32 = $h32\n";
  while ($n0 < $n1) {
    my $n = int ( ($n0 + $n1)/2 );
    seek(F,$n,0);
    my $line = <F>;$line = <F>;
    my ($name,undef,$cpf) = split /\s+/,$line,3;
    #printf "%.1f<%.1f<%.1f cpf=%.1f%s%u (%f) l=%.1f: %s\n",$n0,$n,$n1,$cpf,
    #  ($cpf<$h32)?'<':'>',$h32,$n1-$n0,$n/74,$name;
    last if ($n1-$n0<=1);
    if ($cpf > $h32) {
      $n1 = $n;
    } else {
      $n0 = $n;
    }
  }
  seek(F,$n1,0); # select upper bound word
  my $line = <F>;$line = <F>;
  my ($name,undef,$cpf) = split /\s+/,$line;
  return $name;

}

sub h32_jhash { # Bob Jenkins' hash
 use Digest::JHash;
 my $digest = Digest::JHash::jhash(join'',@_);
 return $digest;
}
sub h32_mmhash { #  Austin Appleby's hash
 use Digest::MurmurHash;
 my $digest = Digest::MurmurHash::murmur_hash(join'',@_);
 return $digest;
}

sub hashr {
   my $alg = shift;
   my $rnd = shift;
   my $tmp = join('',@_);
   use Digest qw();
   my $msg = Digest->new($alg) or die $!;
   for (1 .. $rnd) {
      $msg->add($tmp);
      $tmp = $msg->digest();
      $msg->reset;
   }
   return $tmp
}

1;
