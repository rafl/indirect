#!perl

use strict;
use warnings;

use Test::More tests => 1;

{
 local $SIG{__WARN__} = sub { die 'warn:' . join(' ', @_) };
 eval <<HERE;
die qq{shouldn't even compile\n};
no indirect ':fatal';
my \$x = new Hlagh;
\$x = new Fail;
HERE
 like($@, qr/^Indirect\s+call\s+of\s+method\s+"new"\s+on\s+object\s+"Hlagh"/, 'croak when :fatal is specified');
}
