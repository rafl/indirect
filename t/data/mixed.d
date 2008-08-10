#!perl

use strict;
use warnings;

my $a = new P1;

{
 no indirect;
 my $b = new P2;
 {
  my $c = new P3;
 }
 {
  use indirect;
  my $d = new P4;
 }
 my $e = new P5;
}

my $f = new P6;

no indirect;

my $g = new P7;

use indirect;

my $h = new P8;
