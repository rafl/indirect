#!perl

use strict;
use warnings;

my $total = 28;

use Test::More;

use IPC::Cmd qw/run/;

(my $success, my $err_code, undef, undef, my $stderr)
 = run command => [
          $^X,
          map('-I' . $_, @INC),
          '-M-indirect',
          '-c',
          't/data/bad.d'
   ];

plan skip_all => "Couldn't capture buffers" if $success and not defined $stderr;
plan tests => $total + 1;

$stderr = join '', @$stderr;
unless ($success) {
 diag $stderr;
 diag "Failed to execute data file (error $err_code)";
 fail "Couldn't run test $_" for 1 .. $total + 1;
}

my %fail = map { $_ => 1 } 1 .. $total;
my $extra_fail = 0;

while ($stderr =~ /^Indirect\s+call\s+of\s+method\s+"([^"]+)"\s+on\s+object\s+"([^"]+)"/mg) {
 my ($m, $o) = ($1, $2);
 my $id;
 if ($m =~ /^(?:new|potato)(\d+)$/) {
  $id = $1;
 } elsif ($o =~ /^Hlagh(\d+)$/) {
  $id = $1;
 } else {
  diag "$m $o";
  ++$extra_fail;
 }
 if ($id) {
  ok($fail{$id}, "test $id failed as expected");
  delete $fail{$id};
 }
}

fail("test $_ hasn't failed") for sort { $a <=> $b } keys %fail;
is($extra_fail, 0, 'no extra fails');
