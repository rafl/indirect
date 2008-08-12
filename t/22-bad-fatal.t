#!perl

use strict;
use warnings;

use Test::More;

use IPC::Cmd qw/run/;

(my $success, my $err_code, undef, undef, my $stderr)
 = run command => [
          $^X,
          map('-I' . $_, @INC),
          $ENV{PERL5OPT} || '',
          '-M-indirect=:fatal',
          '-c',
          't/data/bad.d'
   ];

plan skip_all => "Couldn't capture buffers" if $success and not defined $stderr;
plan tests => 1;

$stderr = join '', @{$stderr || []};
ok(!$success && $err_code && $stderr =~ /^Indirect\s+call\s+of\s+method\s+"new"\s+on\s+object\s+"Hlagh1"/mg, 'croak when :fatal is specified');
