#!perl

use strict;
use warnings;

my $obj;
my $pkg;
my $cb;

$obj = Hlagh1->new;
$obj = Hlagh2->new();
$obj = Hlagh3->new(1);
$obj = Hlagh4->new(q{foo}, bar => $obj);

$obj = Hlagh5   ->   new   ;
$obj = Hlagh6   ->   new   (   )   ;
$obj = Hlagh7   ->   new   (   1   )   ;
$obj = Hlagh8   ->   new   (   'foo'   ,   bar =>   $obj   );

$obj = Hlagh9
            ->
                          new   ;
$obj = Hlagh10  

      ->   
new   ( 
 )   ;
$obj = Hlagh11
                                       ->   new   ( 
               1   )   ;
$obj = Hlagh12   ->
                              new   (   "foo"
  ,    bar     
               =>        $obj       );

$obj = Hlagh13->$cb;
$obj = Hlagh14->$cb();
$obj = Hlagh15->$cb($pkg);
$obj = Hlagh16->$cb(sub { 'foo' },  bar => $obj);

$obj = $pkg->new17   ;
$obj = $pkg  ->   new18  (   );
$obj = $pkg       
           -> 
        new19 ( $pkg );
$obj = 
         $pkg
->
new20        (     qr/foo/,
      foo => qr/bar/   );

$obj 
  =  
$pkg
->
$cb
;
$obj = $pkg    ->   ($cb)   ();
$obj = $pkg->$cb( $obj  );
$obj = $pkg->$cb(qw/foo bar baz/);

my $x;

$obj = new25 { $x };
$obj = new26
  {
     $x  }
  ();
$obj = new27 {
  $x  } qq/foo/;
$obj = new28
   {
      $x
    }(qw/bar baz/);

sub potato29;
sub potato30;

potato29 $x;
potato30 $x, 1 , 2;

print STDOUT "bananananananana\n";
print $x "oh hai\n";
