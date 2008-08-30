#!perl -T

use strict;
use warnings;

my $tests;
BEGIN { $tests = 8 }

use Test::More tests => $tests + 1;

my %wrong = map { $_ => 1 } 2, 3, 5, 7;

{
 my $code = do { local $/; <DATA> };
 my @warns;
 {
  local $SIG{__WARN__} = sub { push @warns, join '', 'warn:', @_ };
  eval "die qq{ok\\n}; $code";
 }
 my $left = 0;
 my %res = map {
  if (/"P(\d+)"/) {
   $1 => $_
  } else {
   ++$left; ()
  }
 } @warns;
 for (1 .. $tests) {
  my $w = $res{$_};
  if ($wrong{$_}) {
   like($w, qr/^warn:Indirect\s+call\s+of\s+method\s+"new"\s+on\s+object\s+"P$_"/, "$_ should warn");
  } else {
   is($w, undef, "$_ shouldn't warn");
  }
 }
 is($left, 0, 'nothing left');
}

__DATA__
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
