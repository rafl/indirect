#!perl

use strict;
use warnings;

my $total;
BEGIN {
 $total = 8;
}

use Test::More tests => $total + 1;

use IPC::Cmd qw/run/;

(my $success, my $err_code, undef, undef, my $stderr)
 = run command => [
          $^X,
          map('-I' . $_, @INC),
          '-c',
          't/data/mixed.d'
   ];
unless ($success) {
 $stderr = pop @$stderr if ref $stderr eq 'ARRAY';
 BAIL_OUT("Failed to execute data file (error $err_code) : $stderr");
}
$stderr = join "\n", @$stderr if ref $stderr eq 'ARRAY';

my %fail = map { $_ => 1 } 2, 3, 5, 7;
my %failed;
my $extra_fail = 0;

while ($stderr =~ /^Indirect\s+call\s+of\s+method\s+"([^"]+)"\s+on\s+object\s+"([^"]+)"/mg) {
 my ($m, $o) = ($1, $2);
 my $id;
 if ($o =~ /^P(\d+)$/) {
  $id = $1;
 } else {
  diag "$m $o";
  ++$extra_fail;
 }
 if ($id) {
  if (exists $fail{$id}) {
   pass("test $id failed as expected");
   delete $fail{$id};
   $failed{$id} = 1;
  } else {
   fail("test $id shouldn't have failed");
  }
 }
}

pass("test $_ hasn't failed") for grep { !$failed{$_} } 1 .. $total;
fail("test $_ should have failed") for sort { $a <=> $b } keys %fail;
is($extra_fail, 0, 'no extra fails');
