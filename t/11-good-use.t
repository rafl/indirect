#!perl

use strict;
use warnings;

my $total = 32;

use Test::More;

use IPC::Cmd qw/run/;

(my $success, my $err_code, undef, undef, my $stderr)
 = run command => [
          $^X,
          map('-I' . $_, @INC),
          '-Mindirect',
          '-c',
          't/data/good.d'
   ];

plan skip_all => "Couldn't capture buffers" if $success and not defined $stderr;
plan tests => $total + 1;

$stderr = join '', @$stderr;
unless ($success) {
 diag $stderr;
 diag "Failed to execute data file (error $err_code)";
 fail "Couldn't run test $_" for 1 .. $total + 1;
}

my %fail;
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
  fail("test $id shouldn't have failed");
  $fail{$id} = 1;
 }
}

pass("test $_ hasn't failed") for grep { !$fail{$_} } 1 .. $total;
is($extra_fail, 0, 'no extra fails');
