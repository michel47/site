#!/usr/bin/perl

package IPFS;
require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
#@EXPORT_OK = qw(nickname);
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};

use strict;

# ---------------------------------------------------------------------
use if (exists $ENV{SITE}), lib => $ENV{SITE}.'/lib';
# ---------------------------------------------------------------------
use UTIL qw(version);

# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$dbug $VERSION/;
# ----------------------------------------------------
our $VERSION = sprintf "%d.%02d", q$Revision: 0.0 $ =~ /: (\d+)\.(\d+)/;
my ($State) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------
$VERSION = &version(__FILE__) unless ($VERSION ne '0.00');

our $PGW='https://gateway.ipfs.io';
    $PGW='https://cloudflare-ipfs.io';
# -----------------------------------------------------
sub encode_base58 {
  use Math::BigInt;
  use Encode::Base58::BigInt qw();
  my $bin = join'',@_;
  my $bint = Math::BigInt->from_bytes($bin);
  my $h58 = Encode::Base58::BigInt::encode_base58($bint);
  $h58 =~ tr/a-km-zA-HJ-NP-Z/A-HJ-NP-Za-km-z/;
  return $h58;
}
sub decode_base58 {
  use Math::BigInt;
  use Encode::Base58::BigInt qw();
  my $s = $_[0];
  # $e58 =~ tr/a-km-zA-HJ-NP-Z/A-HJ-NP-Za-km-z/;
  $s =~ tr/A-HJ-NP-Za-km-z/a-km-zA-HJ-NP-Z/;
  my $bint = Encode::Base58::BigInt::decode_base58($s);
  my $bin = Math::BigInt->new($bint)->as_bytes();
  return $bin;
}
sub encode_base32 {
  use MIME::Base32 qw();
  my $mh32 = uc MIME::Base32::encode($_[0]);
  return $mh32;
}
sub decode_base32 {
  use MIME::Base32 qw();
  my $bin = MIME::Base32::decode($_[0]);
  return $bin;
}
# -----------------------------------------------------
sub encode_base32z {
  use MIME::Base32 qw();
  my $mh32 = uc MIME::Base32::encode($_[0]);
  $mh32 =~ y/A-Z2-7/ybndrfg8ejkmcpqxotluwisza345h769/;
  return $mh32;

}

# -----------------------------------------------------
sub resolve {
  my $iaddr = shift;
  my $mh = &ipfsrun('resolve '.$iaddr);
  printf "mh:%s.\n",YAML::Syck::Dump($mh) if $::dbug;
  return $mh->{ipath};
}
# -----------------------------------------------------
sub get_key {
  my $symb = shift;
  my $keys = &ipfsrun('key list -l');
  printf qq'%s.\n',Dump($keys) if $dbug == 1;
  return $keys->{$symb};
}
# -----------------------------------------------------
sub get_content {
  my $key = shift;
     $key = substr($key,1) if ($key =~ /^z/);
  my $keybin = &decode_base58($key);
  my $key32 = &encode_base32($keybin);
  my $split = substr($key32,-3,2);
  my $blockf = sprintf '%s/blocks/%s/%s.data', $ENV{IPFS_PATH},$split,$key32;
  my $buf;
  if (-e $blockf) {
    local *F; open F,'<',$blockf; local $/ = undef;
    $buf = <F>; close F;
  } else {
    $buf = "Status: 404 blockRing™ Content not Found\r\n";
    my $body = sprintf "404 : %s not found !\n",$blockf;
    $buf .= "Content-Length: %u\r\n",length($body);
    $buf .= "Content-Type: text/plain\r\n\r\n";
    $buf .= $body;
  }
  return $buf;
}
# -----------------------------------------------------
sub ipfsapi {
# ipfs config Addresses.API
   my $api_url;
   if ($ENV{HTTP_HOST} =~ m/heliohost/) {
      $api_url = sprintf'https://%s/api/v0/%%s?arg=%%s%%s','ipfs.blockringtm.ml';
   } else {
      $api_url = sprintf'http://%s/api/v0/%%s?arg=%%s%%s','127.0.0.1:5001';
   }
   my $url = sprintf $api_url,@_;
   #printf "X-api-url: %s\n",$url;
   my $content = '';
   use LWP::UserAgent qw();
   use MIME::Base64 qw(decode_base64);
   my $ua = LWP::UserAgent->new();
   my $realm='Restricted Content';
   if ($ENV{HTTP_HOST} =~ m/heliohost/) {
      my $auth64 = 'YW5vbnltb3VzOnBhc3N3b3JkCg==';
      my ($user,$pass) = split':',&decode_base64($auth64);
      $ua->credentials('ipfs.blockringtm.ml:443', $realm, $user, $pass);

#     printf "X-Creds: %s:%s\n",$ua->credentials('ipfs.blockringtm.ml:443', $realm);
   }
   my $resp = $ua->get($url);
   if ($resp->is_success) {
#     printf "X-Status: %s<br>\n",$resp->status_line;
      $content = $resp->decoded_content;
   } else {
      printf "X-api-url: %s\n",$url;
      printf "Status: %s\n",$resp->status_line;
      $content = $resp->decoded_content;
      local $/ = "\n";
      chomp($content);
      printf "Content: %s\n",$content;
   }
   if ($_[0] =~ m{^(?:cat|files/read)}) {
     return $content;
   }
   use JSON qw(decode_json);
   if ($content =~ m/{/) { # }
      #printf "[DBUG] Content: %s\n",$content;
      my $resp = &decode_json($content);
      return $resp;
   } else {
      print "info: $_[0]\n" if ($dbug && ! $content);
      return $content;
   }
}
# -----------------------------------------------------
# add,list,key,name,object,dag,block
sub ipfsrun ($) { 
  my $cmd = shift;
  print "// $cmd:\n" if $::dbug;
  local *EXEC; open EXEC, 'ipfs '.$cmd.'|'; local $/ = "\n";
  my $mh = {};
  # -------------------------------------
  if ( $cmd =~ m/^(add|list|key|name|\w+store|\w+solve)/) {
     my $op = $1;
     while (<EXEC>) {
        print if ($::dbug || $dbug);
        $mh->{$2} = $1 if ($op eq 'ls' && m/(\w+)\s+\d+\s+(.*)\s*$/); # ls ...
        $mh->{$2} = $1 if ($op eq 'key' && m/^(Qm\S+)\s+(.*?)\s*$/); # key list -l

        $mh->{$2} = $1 if m/added\s+(\w+)\s+(.*)\s*$/; # add ...
        $mh->{'wrap'} = $1 if m/^(?:added\s+)?(\w+)\s*$/;

        $mh->{'hash'} = $1 if m/(Qm\S+|z[bd]\S+)/; # add -Q
        if (m,(/(ip[fn]s)/(Qm\S+|z[bd8]\S+)/?\S*),) {
            $mh->{'ipath'} = $1;
            $mh->{'hash'} = $3;
            $mh->{$2} = $3;
        } 
        if (m,ublished to (Qm\S+|z[bd8]\S+):,) {
            $mh->{'ipns'} = $1;
        }
        die $_ if m/Error/;
     }
     close EXEC;
     return $mh;
  # -------------------------------------
  } elsif ($cmd =~ m/^oneliner.../) {
     local $/ = "\n";
     my $buf = <EXEC>;
     chomp($buf);
     close EXEC;
     return $buf;
  # -------------------------------------
  } elsif ($cmd =~ m/^files/) {
     local $/ = undef;
     my $buf = <EXEC>;
     local $/ = "\n";
        chomp($buf);
     close EXEC;
     return $buf;

  # -------------------------------------
  } elsif ($cmd =~ m/^id/) {
     my $addrs = [];
     local $/ = "\n";
     while (<EXEC>) {
        chomp;
        push @$addrs, $_;
        die $_ if m/^Error/;
     }
     close EXEC;
     return $addrs;

  # -------------------------------------
  } elsif ($cmd =~ m/^cat/) {
     my $key = 'z83ajReAEg1SfNCAXGksPDMgNEW7YUN7J';
     if ($cmd =~ m/([\S]+)\s*$/) {
       my $arg = $1;
       if ($arg =~ m,/ipfs/([^/]+)$,) {
          $key = $1;
          $key = substr($key,1) if ($key =~ m/^z/);
       } else {
         #print "//info: resolve $arg\n";
         my $mh = &ipfsrun('resolve -r '.$arg);
         #printf "mh%s.\n",YAML::Syck::Dump($mh);
         $key = $mh->{hash};
       }
     }
     my $qm58 = ($key =~ m/^Qm/) ? $key : substr($key,1);
     my $id6 = substr($qm58,2,6);
     my $name5 = substr($qm58,4,5);
     my $cname = &cname($key);
     my $buf = '';
     while (<EXEC>) {
        $buf .= $_;
        die $_ if m/^Error/;
     }
     $mh->{key} = $key;
     $mh->{id6} = $id6;
     $mh->{name5} = $name5;
     $mh->{cname} = $cname;
     $mh->{content} = $buf;
# -------------------------------------
  } elsif ( $cmd =~ m/^dag\s+(\w+)/ ) {
        use JSON qw(decode_json);
        my $json = <EXEC>;
        $mh->{dag} = &decode_json($json);
     close EXEC;
     return $mh;
  # -------------------------------------
  } elsif ( $cmd =~ m/^block\s+(\w+)/ ) {
     my $op = $1;
     local $/ = undef;
     if ($op eq 'get') {
        $mh->{raw} = <EXEC>;
     } elsif ($op eq 'stat') {
        use YAML::Syck qw(Load);
        my $buf = <EXEC>;
        $mh = Load("--- \n".$buf);
     } else {
        local $/ = undef;
        $mh->{$op} = <EXEC>;
     }
     close EXEC;
     return $mh;

  } elsif ( $cmd =~ m/^object\s+(\w+)/ ) {
     my $op = $1;
     local $/ = undef;
     # ------------
     if ($cmd =~ /-encoding\s+protobuf/) {
        $mh->{proto} = <EXEC>;
     # ------------
     } elsif ($op eq 'get') {
        use JSON qw(decode_json);
        my $json = <EXEC>;
        $mh->{obj} = &decode_json($json);
     # ------------
     } elsif ($op eq 'links') {
        local $/ = "\n";
        while (<EXEC>) {
           if (m/^(\S+)\s+(\d+)(?:\s+(.*)\s*)?$/) { # links
             my ($key,$size,$name) = ($1,$2,$3);
             my $cname = &cname($key);
             my $mhash = &decode_mhash($key);
             my $mh32 = &encode_base32($mhash);
             my $split = substr($mh32,-3,2);
             my $file = sprintf'%s/%s.data',$split,$mh32;
             my $type = substr($mh32,0,3);
             my $hashid = substr($mh32,3,3);
             my $url = sprintf "%s/ipfs/b%s",$PGW,lc$mh32;
             $mh->{$cname} = { size => $size, key => $key, name => $name,
                file => $file, hashid => $hashid, url => $url
             };
           }
        }
     # ------------
     } elsif ($op eq 'stat') {
        use YAML::Syck qw(Load);
        my $buf = <EXEC>;
        $mh = Load("--- \n".$buf);
     } else {
        $mh->{$op} = <EXEC>;
     }
     close EXEC;
     return $mh;
  }
  # -------------------------------------
}
# -----------------------------------------------------------------------
sub decode_mhash {
  my $mh58 = shift;
  my $base = substr($mh58,0,1);
  my $mhxx = substr($mh58,1);
  my $addr;
  if ($base eq 'z') {
    $addr = &decode_base58($mhxx);
  } elsif ($base eq 'b') {
    $addr = &decode_base32($mhxx);
  } elsif ($base eq 'f') {
    $addr = pack'H*',$mhxx;
  } elsif ($base eq 'Q') {
    $addr = "\x01\x70".&decode_base58($mh58);
  } 

  my $maddr;
  my $cid = substr($addr,0,2);
  if ($cid eq "\x12\x20") { # ^Qm's case !
     $cid = "\x01\x70";
     $maddr = $cid.$addr;
  } else {
     $maddr = $addr;
  }
  my $hfunc = substr($maddr,2,2);
  my $mhash = substr($maddr,2);
  my $hash = substr($mhash,2);
  if (wantarray) {
    return ($addr,$maddr,$cid,$mhash, $hfunc,$hash);
  } else {
    return $addr;
  }
}


sub blockf {
  my $mh58 = shift;
  my $mhash = &decode_mhash($mh58);
  my $mh32 = &encode_base32($mhash);
  my $split = substr($mh32,-3,2);
  my $blockf = sprintf'blocks/%s/%s.data',$split,$mh32;
  return $blockf;
}
sub cname {
  my $mh58 = shift;
  my $mhash = &decode_mhash($mh58);
  my $mh32 = &encode_base32($mhash);
  my $qm58 = &encode_base58($mhash);
  my $type = substr($mhash,0,2);
  my $cname = '';
  if ($type eq "\x01\x55") {
    my $split = substr($mh32,-3,2);
    my $type = substr($mh32,0,3);
    my $name9 = substr($mh32,6,9);

    $cname=sprintf"%s/%s*%s",$split,$type,$name9;
  } elsif ($type eq "\x12\x20") {
    my $split = substr($mh32,-3,2);
    my $name4 = substr($mh32,3,4);
    $cname=sprintf"%s/CIQ%s",$split,$name4;
  } else {
    $cname = substr($mh32,0,9);
  }
  return $cname;
}
# -----------------------------------------------------------------------
1; # $Source: /my/perl/modules/IPFS.pm,v $
