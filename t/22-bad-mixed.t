#!perl -T

package Dongs;

sub new;

package main;

use strict;
use warnings;

use Test::More tests => 3 * 4;

sub meh;

{
 local $/ = "####\n";
 while (<DATA>) {
  chomp;
  s/\s*$//;
  local $SIG{__WARN__} = sub { die 'warn:' . join(' ', @_) };
  {
   use indirect;
   eval "die qq{ok\\n}; $_";
  }
  is($@, "ok\n", "use indirect: $_");
  {
   no indirect;
   eval "die qq{ok\n}; $_";
  }
  is($@, "ok\n", "no indirect: $_");
  s/Hlagh/Dongs/g;
  {
   use indirect;
   eval "die qq{ok\\n}; $_";
  }
  is($@, "ok\n", "use indirect, defined: $_");
  {
   no indirect;
   eval "die qq{the code compiled but it shouldn't have\n}; $_";
  }
  like($@, qr/^warn:Indirect\s+call\s+of\s+method\s+"meh"\s+on\s+object\s+"Dongs"/, "no indirect, defined: $_");
 }
}

__DATA__
meh Hlagh->new;
####
meh Hlagh->new();
####
meh Hlagh->new, "Wut";
