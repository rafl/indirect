#!perl -T

use strict;
use warnings;

use Config qw/%Config/;

BEGIN {
 if (!$Config{useithreads}) {
  require Test::More;
  Test::More->import;
  plan(skip_all => 'This perl wasn\'t built to support threads');
 }
}

use threads;

use Test::More;

BEGIN {
 require indirect;
 if (indirect::I_THREADSAFE()) {
  plan tests => 10 * 2 * (2 + 3);
  defined and diag "Using threads $_" for $threads::VERSION;
 } else {
  plan skip_all => 'This indirect isn\'t thread safe';
 }
}

sub expect {
 my ($pkg) = @_;
 return qr/^Indirect\s+call\s+of\s+method\s+"new"\s+on\s+object\s+"$pkg"/;
}

{
 no indirect;

 sub try {
  my $tid = threads->tid();

  for (1 .. 2) {
   {
    my $class = "Coconut$tid";
    my @warns;
    {
     local $SIG{__WARN__} = sub { push @warns, "@_" };
     eval 'die "the code compiled but it shouldn\'t have\n";
           no indirect ":fatal"; my $x = new ' . $class . ' 1, 2;';
    }
    like         $@ || '', expect($class),
                      "\"no indirect\" in eval in thread $tid died as expected";
    is_deeply \@warns, [ ],
                      "\"no indirect\" in eval in thread $tid didn't warn";
   }

SKIP:
   {
    skip 'Hints aren\'t propagated into eval STRING below perl 5.10' => 3
                                                             unless $] >= 5.010;
    my $class = "Pineapple$tid";
    my @warns;
    {
     local $SIG{__WARN__} = sub { push @warns, "@_" };
     eval 'die "ok\n"; my $y = new ' . $class . ' 1, 2;';
    }
    is             $@, "ok\n",
    my $first = shift @warns;
    like $first || '', expect($class),
              "\"no indirect\" propagated into eval in thread $tid warned once";
    is_deeply \@warns, [ ],
         "\"no indirect\" propagated into eval in thread $tid warned just once";
   }
  }
 }
}

my @t = map threads->create(\&try), 1 .. 10;
$_->join for @t;
