#!perl

use strict;
use warnings;

my $total = 8;

use Test::More;

use IPC::Cmd qw/run/;

(my $success, my $err_code, undef, undef, my $stderr)
 = run command => [
          $^X,
          map('-I' . $_, @INC),
          '-c',
          't/data/mixed.d'
   ];

plan skip_all => "Couldn't capture buffers" if $success and not defined $stderr;
plan tests => $total + 1;

$stderr = join '', @$stderr;
unless ($success) {
 diag $stderr;
 diag "Failed to execute data file (error $err_code)";
 fail "Couldn't run test $_" for 1 .. $total + 1;
}

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
