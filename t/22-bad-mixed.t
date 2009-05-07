#!perl -T

package Dongs;

sub new;

package main;

use strict;
use warnings;

use Test::More tests => 3 * 4;

sub meh;

{
 local $/ = "####";
 while (<DATA>) {
  chomp;
  s/\s*$//;
  s/(.*?)$//m;
  my ($skip, $prefix) = split /#+/, $1;
  $skip   = 0  unless defined $skip;
  $prefix = '' unless defined $prefix;
  s/\s*//;

SKIP:
  {
   skip "$_: $skip" => 4 if eval $skip;

   local $SIG{__WARN__} = sub { die 'warn:' . join(' ', @_) };

   eval "die qq{ok\\n}; $prefix; use indirect; $_";
   is($@, "ok\n", "use indirect: $_");

   eval "die qq{ok\n}; $prefix; no indirect; $_";
   is($@, "ok\n", "no indirect: $_");

   s/Hlagh/Dongs/g;

   eval "die qq{ok\\n}; $prefix; use indirect; $_";
   is($@, "ok\n", "use indirect, defined: $_");

   eval "die qq{the code compiled but it shouldn't have\n}; $prefix; no indirect; $_";
   like($@, qr/^warn:Indirect\s+call\s+of\s+method\s+"meh"\s+on\s+object\s+"Dongs"\s+at\s+\(eval\s+\d+\)\s+line\s+\d+/, "no indirect, defined: $_");
  }
 }
}

__DATA__

meh Hlagh->new;
####
meh Hlagh->new();
####
meh Hlagh->new, "Wut";
