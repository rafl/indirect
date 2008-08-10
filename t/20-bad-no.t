#!perl

use strict;
use warnings;

my $total;
BEGIN {
 $total = 28;
}

use Test::More tests => $total + 1;

use IPC::Cmd qw/run/;

(my $success, my $err_code, undef, undef, my $stderr)
 = run command => [
          $^X,
          map('-I' . $_, @INC),
          '-M-indirect',
          '-c',
          't/data/bad.d'
   ];
unless ($success) {
 $stderr = pop @$stderr if ref $stderr eq 'ARRAY';
 BAIL_OUT("Failed to execute data file (error $err_code) : $stderr");
}
$stderr = join "\n", @$stderr if ref $stderr eq 'ARRAY';

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
