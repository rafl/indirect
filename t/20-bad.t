#!perl -T

package Dongs;

sub new;

package main;

use strict;
use warnings;

use Test::More tests => 50 * 6 + 2;

my ($obj, $x);
our ($y, $bloop);

sub expect {
 my ($pkg) = @_;
 return qr/^warn:Indirect call of method "(?:new|meh|$pkg$pkg)" on object "(?:$pkg|newnew|\$(?:[xyz_\$]|(?:sploosh::)?sploosh|(?:main::)?bloop))"/
}

{
 local $/ = "####";
 while (<DATA>) {
  chomp;
  s/\s*$//;
  s/(.*?)$//m;
  my ($skip, $prefix) = split /#+/, $1;
  $skip   = 0  unless defined $skip;
  $prefix = '' unless defined $prefix;
  s/\s*//;

SKIP:
  {
   skip "$_: $skip" => 6 if eval $skip;

   local $SIG{__WARN__} = sub { die 'warn:' . join(' ', @_) };

   eval "die qq{ok\\n}; $prefix; use indirect; $_";
   is($@, "ok\n", "use indirect: $_");

   eval "die qq{the code compiled but it shouldn't have\n}; $prefix; no indirect; $_";
   like($@, expect('Hlagh'), "no indirect: $_");

   s/Hlagh/Dongs/g;

   eval "die qq{ok\\n}; $prefix; use indirect; $_";
   is($@, "ok\n", "use indirect, defined: $_");

   eval "die qq{the code compiled but it shouldn't have\n}; $prefix; no indirect; $_";
   like($@, expect('Dongs'), "no indirect, defined: $_");

   s/\$/\$ \n\t /g;
   s/Dongs/Hlagh/g;

   eval "die qq{ok\\n}; $prefix; use indirect; $_";
   is($@, "ok\n", "use indirect, spaces: $_");

   eval "die qq{the code compiled but it shouldn't have\n}; $prefix; no indirect; $_";
   like($@, expect('Hlagh'), "no indirect, spaces: $_");
  }
 }
}

eval {
 my $warn;
 local $SIG{__WARN__} = sub { $warn = join ' ', @_ };
 eval "die qq{ok\n}; no indirect 'hlagh'; \$obj = new Hlagh1;";
 is($@, "ok\n", 'no indirect "hlagh" didn\'t croak');
 like($warn, qr/^Indirect\s+call\s+of\s+method\s+"new"\s+on\s+object\s+"Hlagh1"/, 'no indirect "hlagh" enables the pragma');
}

__DATA__

$obj = new Hlagh;
####
$obj = new Hlagh();
####
$obj = new Hlagh(1);
####
$obj = new Hlagh(1, 2);
####
$obj = new        Hlagh            ;
####
$obj = new        Hlagh     (      )      ;
####
$obj = new        Hlagh     (      1        )     ;
####
$obj = new        Hlagh     (      1        ,       2        )     ;
####
$obj = new    
                      Hlagh		
        ;
####
$obj = new   
                                       Hlagh     (    
                  )      ;
####
$obj =
              new    
    Hlagh     (      1   
            )     ;
####
$obj =
new      
Hlagh    
                   (      1        ,  
                2        )     ;
####
$obj = new $x;
####
$obj = new $x();
####
$obj = new $x('foo');
####
$obj = new $x qq{foo}, 1;
####
$obj = new $x qr{foo\s+bar}, 1 .. 1;
####
$obj = new $x(qw/bar baz/);
####
$obj = new
          $_;
####
$obj = new
             $_     (        );
####
$obj = new $_      qr/foo/  ;
####
$obj = new $_     qq(bar baz);
####
meh $_;
####
meh $_ 1, 2;
####
meh $$;
####
meh $$ 1, 2;
####
meh $x;
####
meh $x 1, 2;
####
meh $x, 1, 2;
####
meh $y;
####
meh $y 1, 2;
####
meh $y, 1, 2;
#### $] < 5.010 # use feature 'state'; state $z
meh $z;
#### $] < 5.010 # use feature 'state'; state $z
meh $z 1, 2;
#### $] < 5.010 # use feature 'state'; state $z
meh $z, 1, 2;
####
package sploosh;
our $sploosh;
meh $sploosh::sploosh;
####
package sploosh;
our $sploosh;
meh $sploosh;
####
package sploosh;
meh $main::bloop;
####
package sploosh;
meh $bloop;
####
package ma;
meh $bloop;
####
package sploosh;
our $sploosh;
package main;
meh $sploosh::sploosh;
####
new Hlagh->wut;
####
new Hlagh->wut();
####
new Hlagh->wut, "Wut";
####
$obj = HlaghHlagh Hlagh;
####
$obj = HlaghHlagh Hlagh; # HlaghHlagh Hlagh
####
$obj = new newnew;
####
$obj = new newnew; # new newnew
####
new Hlagh (meh $x)
####
Hlagh->new(meh $x)
