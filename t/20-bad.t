#!perl -T

use strict;
use warnings;

use Test::More tests => 30 * 2;

my ($obj, $x);

{
 local $/ = "####\n";
 while (<DATA>) {
  chomp;
  {
   use indirect;
   local $SIG{__WARN__} = sub { die 'warn:' . join(' ', @_) };
   eval "die qq{ok\\n}; $_";
  }
  is($@, "ok\n", $_);
  {
   no indirect;
   local $SIG{__WARN__} = sub { die 'warn:' . join(' ', @_) };
   eval "die qq{the code compiled but it shouldn't have\n}; $_";
  }
  like($@, qr/^warn:Indirect\s+call\s+of\s+method\s+"(?:new|meh|HlaghHlagh)"\s+on\s+object\s+"(?:Hlagh|newnew|\$x|\$_)"/, $_);
 }
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
meh $x;
####
meh $x, 1, 2;
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
