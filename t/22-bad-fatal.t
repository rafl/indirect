#!perl

use strict;
use warnings;

my $total;
BEGIN {
 $total = 20;
}

use Test::More tests => 1;

use IPC::Cmd qw/run/;

(my $success, my $err_code, undef, undef, my $stderr)
 = run command => [
          $^X,
          map('-I' . $_, @INC),
          '-M-indirect=:fatal',
          '-c',
          't/data/bad.d'
   ];

$stderr = join "\n", @$stderr if ref $stderr eq 'ARRAY';
ok(!$success && $err_code && $stderr =~ /^Indirect\s+call\s+of\s+method\s+"new"\s+on\s+object\s+"Hlagh1"/mg, 'croak when :fatal is specified');
