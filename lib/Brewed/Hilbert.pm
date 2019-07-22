#!perl
# -- $RCSfile: Hilbert.pm,v $


# Note:
#   This work has been done during my time HEIG-VD
#   65% employment (CTI 13916)
#
# $Author: michelc $
# 
# -- Copyright HEIG-VD, 2013,2014,2015 --
#
# vim: ts=2 et noai

package Brewed::Hilbert;
require Exporter;
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
our $VERSION = sprintf "%d.%02d", q$Revision: 0.1 $ =~ /: (\d+)\.(\d+)/;
my ($State) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------
# @(#) this module provides routine to build Hilbert curves
#
# method: 
#  quadrant rotation
#
#  a) identify quadrant w/ d :
#  rx = E/!W, ry = N/!S
#
# d/2 p=lm       E     l m   N         q=yx   NE
#  0: 'b00 => rx=0 ry= 0^0 = 0  => quadrant 'b00 (0) SW 
#  1: 'b01 => rx=0 ry= 1^0 = 1  => quadrant 'b10 (2) NW
#  2: 'b10 => rx=1 ry= 0^1 = 1  => quadrant 'b11 (3) NE
#  3: 'b11 => rx=1 ry= 1^1 = 0  => quadrant 'b01 (1) SE
#          +---+---+
#          |R+ |R+ |          +---+---+
#  [R+] => +---+---+          |L+ |U- |
#          |U- |D- |  [U-] => +---+---+
#          +---+---+          |R+ |U- |
#                             +---+---+
# U-Shape operations ...
my $flip = { 'UP' => 'DN', 'R.' => 'L.',
             'DN' => 'UP', 'L.' => 'R.',

             'R+' => 'L+', 'L+' => 'R+',
             'U+' => 'D+', 'D+' => 'U+',
             'R-' => 'L-', 'L-' => 'R-',
             'U-' => 'D-', 'D-' => 'U-'
     };
my $swap = { 'UP' => 'R.', 'DN' => 'L.',
             'R.' => 'UP', 'L.' => 'DN',

             'R+' => 'U-', 'U-' => 'R+',
             'U+' => 'R-', 'R-' => 'U+',
             'L+' => 'D-', 'D-' => 'L+',
             'D+' => 'L-', 'L-' => 'D-'
     };
my $op = { '00' => 'swap', '01' => 'flip+swap', '10' => ' nop', '11' => ' nop' };

# rot,dir:
#    0,00 : clockwise, right :  R+
#    0,01 : clockwise, up    :  U+
#    0,10 : clockwise, left  :  L+
#    0,11 : clockwise, down  :  D+

#    1,00 : counter-clockwise, right  : R-
#    1,01 : counter-clockwise, up     : U-
#    1,10 : counter-clockwise, left   : L-
#    1,11 : counter-clockwise, down   : D-
#
# t        00 01 11 10
# p        00 01 10 11
# q=yx     00 10 11 10
#    R+ => U-,R+,R+,D-
#    U- => R+,U-,U-,L+
#    D- => L+,D-,D-,R+
#    L+ => D-,L+,L+,U-
#

sub d2xy { # this works well
  my ($n,$d) = @_;
  my ($x,$y) = (0,0);
  my $t = int($d);
  my $f = $d - $t; # fractional part...
  my $m = $t%4;

  # initial U-shape
  my $rx0 = 1 & ($t>>1); # 1st or 2nd half
  my $ry0 = 1 & ($t ^ $rx0); # 
  $a = ($ry0 == 1) ? 'R+' : ($rx0 == 1) ? 'D-' : 'U-'; 

  my ($rx,$ry,$q);
  my $s = 1; # 1,2,4,8,...
  while ($s<$n) {
    # identify which quadrant ...
    $rx = 1 & ($t>>1); # 1st or 2nd half
    $ry = 1 & ($t ^ $rx); # 
    $q = $ry.$rx;
    printf "d=%-7.2f L=%-3u (x,y,a)=(%g,%g,%s) q:%s -%s-> ",$d,$s,
            $x,$y,$a,$q,$op->{$q} if $dbug;
    ($x,$y,$a) = &rot($s,$x,$y,$a,$rx,$ry);
    $x += $s * $rx;
    $y += $s * $ry;
    $t >>= 2 ;
    $s <<= 1;
    printf '(x,y,a)=(%g,%g,%s) %s'."\n",$x,$y,$a,($s>=$n)?'*':'' if $dbug;
  }

  # adding a fractional part at the cell level in the direction
  # of the next move (?)
  $y += $f if ($q eq '00');
  $x += $f if ($q eq '01');
  $y -= $f if ($q eq '10');
  $y -= $f if ($q eq '11');
  my ($xn,$yn) = &hilbert_inc($x,$y,$n);
  my $dx = $xn - $x;
  my $dy = $yn - $y;
  my $s = sprintf'%u,%u %u%u.%u%u',$x%4,$y%4,$ry0,$rx0,$rx,$ry;
  printf " // (x,y)=(%g,%g) next ? s:%s x%+d,y%+d) => (%g,%g)\n",$x,$y,$s,$dx,$dy,$x+$dx,$y+$dy if $dbug;

  return ($x,$y);
}
sub xy2d { # not working
  use integer;
  my ($n,$x,$y) = @_;
  my $d = 0;
  my $s = $n/2;
  while ($s>0) {
    my $rx = $x & $s > 0;
    my $ry = $y & $s > 0;
    $d += $s * $s * (3 * $rx) ^$ry;
    ($x,$y) = &rot($s,$x,$y,$rx,$ry);
    $s /=2;
  }
  return $d;
}
# rotate a quadrant
sub rot {
  my ($n,$x,$y,$a,$rx,$ry) = @_;
  if ($ry == 0) {
    if ($rx == 1) {
      $x = $n - 1 - $x;
      $y = $n - 1 - $y;
      $a = $flip->{$a};
    }
    ($x,$y) = ($y,$x);
    $a = $swap->{$a};
  }
  return ($x,$y,$a);
}

# ----------------------------------------------------------------
# from void hil_inc_xy(unsigned *xp, unsigned *yp, int n) { ... }
# see: http://icodeguru.com/Embedded/Hacker's-Delight/098.htm 
sub hilbert_inc {
  my ($x,$y,$n) = @_;
  my $state = 0;
  my $dx = - ( (1<<$n) - 1 ); # initialize to -2^n-1
  my $dy = 0;
  for my $i (0 .. $n-1) {
    my $j - $n-1 - $i;      
    my $row = 4 * $state | 2 * ( 1&($x>>$j) ) | 1&($y>>$j);
    my $change = 1&( 0xBDDB >> $row );
    if ($change) {
      $dx = 3&(0x16451659 >> 2*$row) - 1; 
      $dy = 3&(0x51166516 >> 2*$row) - 1; 
    } 
    $state = 3&(0x8FE65831 >> 2*$row);
  } 
  $x += $dx;
  $y += $dy;
  return ($x,$y);
} 
# ----------------------------------------------------------------
# an other approach see :
#
# http://my.safaribooksonline.com/book/information-technology-and-software-development/0201914654/hilbert-curve/ch14lev1sec4
#
# https://books.google.com/books?id=VicPJYM0I5QC&pg=PA355&dq=%22Hilbert+Curve%22+hacker&hl=en&sa=X&ved=0CCYQ6AEwAGoVChMIz9WN7JGzxwIVxHHbCh3pcAvb#v=onepage&q=%22Hilbert%20Curve%22%20hacker&f=false
#
# 14-4. Incrementing the Coordinates on the Hilbert Curve
# 
# Given the (x, y) coordinates of a point on the order n Hilbert curve,
# how can one find the coordinates of the next point? One way is to convert
# (x, y) to s, add 1 to s, and then convert the new value of s back to
# (x, y), using algorithms given above.

# A slightly (but not dramatically) better way is based on the fact that as
# one moves along the Hilbert curve, at each step either x or y, but not
# both, is either incremented or decremented (by 1). The algorithm to be
# described scans the coordinate numbers from left to right to determine
# the type of U-curve that the rightmost two bits are on. Then, based on
# the U-curve and the value of the rightmost two bits, it increments or
# decrements either x or y.
#

# ----------------------------------------------------------
# N integer ... -> Z-order on a 1D axis
#  in order to preserve order we interleae every bits
#  (5,9,1) = (0101,1001,0001) => 010001000111 = 1095
#
# (Morton code see : http://www.forceflow.be/2013/10/07/morton-encodingdecoding-through-bit-interleaving-implementations/)


sub morton_encode(@) {
 my $b = 64; # lagest word size supported by the machine
 my $answer = 0;
 my $n = scalar(@_);
 my $z = int($b / $n);
 for my $i (0 .. $z-1) { # all bit ... (from lsb to msb)
    my $partial = 0;
    for (0 .. $n-1) { # all passed elements
       my $bit = ($_[$_]>>$i) & 1;
       $partial |= $bit<<$_;
       $answer |= $partial<<($n*$i);
    }
 }
 return $answer;
}
sub morton_decode ($$) {
   my $b = 64; # lagest word size supported by the machine
   my ($n,$m) = @_; # m: morton code, n: dimension of output vector
   my $z = int($b/$n); # size in bit of each variable
   my @p = ();
   for my $i (0 .. $z-1) { # all bit ... (from lsb to msb)
      #my $j = $z - 1 - $i;
      my $j = $i;
      my $partial = 0;
      for (0 .. $n-1) {
	 my $bit = ( $m>>($n*$j+$_)) & 1;
         $partial |= $bit<<$_;
	 $p[$_] |= $bit<<$i;
      }
   }
   return @p;
}

# gvim: ts=2 et nowrap
1; # $Source: /my/perl/modules/developped/at/HEIG-VD/Hilbert.pm,v $
