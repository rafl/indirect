#!perl

use strict;
use warnings;

my $total;
BEGIN {
 $total = 32;
}

use Test::More tests => $total + 1;

use IPC::Cmd qw/run/;

(my $success, my $err_code, undef, undef, my $stderr)
 = run command => [
          $^X,
          map('-I' . $_, @INC),
          '-M-indirect',
          '-c',
          't/data/good.d'
   ];
unless ($success) {
 $stderr = pop @$stderr if ref $stderr eq 'ARRAY';
 BAIL_OUT("Failed to execute data file (error $err_code) : $stderr");
}
$stderr = join "\n", @$stderr if ref $stderr eq 'ARRAY';

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
