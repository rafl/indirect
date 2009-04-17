#!perl -T

use strict;
use warnings;

my $tests;
BEGIN { $tests = 18 }

use Test::More tests => 1 + $tests + 1 + 2;

my %wrong = map { $_ => 1 } 2, 3, 5, 7, 9, 10, 14, 15, 17, 18;

sub expect {
 my ($pkg) = @_;
 return qr/^warn:Indirect\s+call\s+of\s+method\s+"new"\s+on\s+object\s+"$pkg"/;
}

{
 my $code = do { local $/; <DATA> };
 my (%res, $num, @left);
 {
  local $SIG{__WARN__} = sub {
   ++$num;
   my $w = join '', 'warn:', @_;
   if ($w =~ /"P(\d+)"/ and not exists $res{$1}) {
    $res{$1} = $w;
   } else {
    push @left, "[$num] $w";
   }
  };
  eval "die qq{ok\\n}; $code";
  is($@, "ok\n", 'DATA compiled fine');
 }
 for (1 .. $tests) {
  my $w = $res{$_};
  if ($wrong{$_}) {
   like($w, expect("P$_"), "$_ should warn");
  } else {
   is($w, undef, "$_ shouldn't warn");
  }
 }
 is(@left, 0, 'nothing left');
 diag "Extraneous warnings:\n", @left if @left;
}

{
 my $w = '';
 local $SIG{__WARN__} = sub {
  $w = 'more than 2 warnings' if $w;
  $w = join '', 'warn:', @_
 };
 {
  eval 'no indirect; my $x = new Foo';
  like($w, expect('Foo'), "eval 'no indirect; my \$x = new Foo'");
 }
 $w = '';
 {
  {
   no indirect;
   eval 'my $x = new Bar';
  }
  if ($] < 5.010) {
   is($w, '', "eval 'no indirect; my \$x = new Bar'");
  } else {
   like($w, expect('Bar'), "no indirect; eval 'my \$x = new Bar'");
  }
 }
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

{
 no indirect;
 eval { my $i = new P9 };
}

eval { no indirect; my $j = new P10 };

{
 use indirect;
 new P11 do { use indirect; new P12 };
}

{
 use indirect;
 new P13 do { no indirect; new P14 };
}

{
 no indirect;
 new P15 do { use indirect; new P16 };
}

{
 no indirect;
 new P17 do { no indirect; new P18 };
}
