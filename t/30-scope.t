#!perl -T

use strict;
use warnings;

my $tests;
BEGIN { $tests = 18 }

use Test::More tests => 1 + $tests + 1 + 2 + 3 + 5;

use lib 't/lib';

my %wrong = map { $_ => 1 } 2, 3, 5, 7, 9, 10, 14, 15, 17, 18;

sub expect {
 my ($pkg, $file) = @_;
 $file = $file ? quotemeta $file : '\(eval\s+\d+\)';
 return qr/^warn:Indirect\s+call\s+of\s+method\s+"new"\s+on\s+object\s+"$pkg"\s+at\s+$file\s+line\s+\d+/;
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
  if ($] < 5.009005) {
   is($w, '', "eval 'no indirect; my \$x = new Bar'");
  } else {
   like($w, expect('Bar'), "no indirect; eval 'my \$x = new Bar'");
  }
 }
}

{
 my @w;
 {
  local $SIG{__WARN__} = sub { push @w, join '', 'warn:', @_ };
  eval "die qq{ok\\n}; no indirect; use indirect::TestRequired1; my \$x = new Foo;";
 }
 is         $@, "ok\n",        'first require test doesn\'t croak prematurely';
 my $w = shift @w;
 like       $w, expect('Foo'), 'first require test catch errors in current scope';
 is_deeply \@w, [ ],           'first require test doesn\'t propagate into the required file';
}

{
 my @w;
 {
  local $SIG{__WARN__} = sub { push @w, join '', 'warn:', @_ };
  eval "die qq{ok\\n}; no indirect; use indirect::TestRequired2; my \$x = new Bar;";
 }
 @w = grep !/^warn:Attempt\s+to\s+free\s+unreferenced/, @w if $] <= 5.008003;
 is   $@, "ok\n", 'second require test doesn\'t croak prematurely';
 my $w = shift @w;
 like $w, expect('Baz', 't/lib/indirect/TestRequired2.pm'),
                                     'second require test caught error for Baz';
 SKIP: {
  skip 'The pragma doesn\'t propagte into eval STRING before perl 5.10' => 1
                                                               if $] < 5.009005;
  $w = shift @w;
  like $w, expect('Blech'), 'second require test caught error for Blech';
 }
 $w = shift @w;
 like       $w, expect('Bar'), 'second require test caught error for Bar';
 is_deeply \@w, [ ],           'second require test doesn\'t have more errors';
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
