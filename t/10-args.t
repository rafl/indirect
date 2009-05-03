#!perl -T

use strict;
use warnings;

use Test::More tests => 4 + 1 + 1;

sub expect {
 my ($pkg) = @_;
 return qr/^Indirect\s+call\s+of\s+method\s+"new"\s+on\s+object\s+"$pkg"/;
}

{
 my @warns;
 local $SIG{__WARN__} = sub { push @warns, "@_" };
 eval <<'HERE';
  die qq{ok\n};
  no indirect;
  my $x = new Warn1;
  $x = new Warn2;
HERE
 my $w1 = shift @warns;
 my $w2 = shift @warns;
 is             $@, "ok\n",          'didn\'t croak without arguments';
 like          $w1, expect('Warn1'), 'first warning caught without arguments';
 like          $w2, expect('Warn2'), 'second warning caught without arguments';
 is_deeply \@warns, [ ],             'no more warnings without arguments';
}

{
 local $SIG{__WARN__} = sub { die "warn:@_" };
 eval <<'HERE';
  die qq{shouldn't even compile\n};
  no indirect ':fatal', hook => sub { die 'should not be called' };
  my $x = new Fatal;
  $x = new NotReached;
HERE
 like $@, expect('Fatal'), 'croaks when :fatal is specified';
}

{
 local $SIG{__WARN__} = sub { "warn:@_" };
 eval <<'HERE';
  die qq{shouldn't even compile\n};
  no indirect 'whatever', hook => sub { die 'hook:' . join(':', @_) . "\n" }, ':fatal';
  my $x = new Hooked;
  $x = new AlsoNotReached;
HERE
 is $@, "hook:Hooked:new\n", 'calls the specified hook';
}
