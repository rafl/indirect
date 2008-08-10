#!perl

use strict;
use warnings;

my $obj;
my $pkg;
my $cb;

$obj = new Hlagh1;
$obj = new Hlagh2();
$obj = new Hlagh3(1);
$obj = new Hlagh4(1, 2);

$obj = new        Hlagh5            ;
$obj = new        Hlagh6     (      )      ;
$obj = new        Hlagh7     (      1        )     ;
$obj = new        Hlagh8     (      1        ,       2        )     ;

$obj = new    
                      Hlagh9		
        ;
$obj = new   
                                       Hlagh10     (    
                  )      ;
$obj =
              new    
    Hlagh11     (      1   
            )     ;
$obj =
new      
Hlagh12    
                   (      1        ,  
                2        )     ;

my $x;
$obj = new13 $x;
$obj = new14 $x();
$obj = new15 $x('foo');
$obj = new16 $x qq{foo}, 1;
$obj = new17 $x qr{foo\s+bar}, 1 .. 1;
$obj = new18 $x(qw/bar baz/);

$obj = new19
          $_;
$obj = new20
             $_     (        );
$obj = new21 $_      qr/foo/  ;
$obj = new22 $_     qq(bar baz);

potato23 $x;
potato24 $x, 1, 2;

$obj = Hlagh25Hlagh25 Hlagh25;
$obj = Hlagh26Hlagh26 Hlagh26; # Hlagh26Hlagh26 Hlagh26
$obj = new27 new27new27;
$obj = new28 new28new28; # new28 new28new28
