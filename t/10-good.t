#!perl -T

use strict;
use warnings;

use Test::More tests => 33 * 2;

my ($obj, $pkg, $cb, $x);
sub meh;

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
   eval "die qq{ok\n}; $_";
  }
  is($@, "ok\n", $_);
 }
}

__DATA__
$obj = Hlagh->new;
####
$obj = Hlagh->new();
####
$obj = Hlagh->new(1);
####
$obj = Hlagh->new(q{foo}, bar => $obj);
####
$obj = Hlagh   ->   new   ;
####
$obj = Hlagh   ->   new   (   )   ;
####
$obj = Hlagh   ->   new   (   1   )   ;
####
$obj = Hlagh   ->   new   (   'foo'   ,   bar =>   $obj   );
####
$obj = Hlagh
            ->
                          new   ;
####
$obj = Hlagh  

      ->   
new   ( 
 )   ;
####
$obj = Hlagh
                                       ->   new   ( 
               1   )   ;
####
$obj = Hlagh   ->
                              new   (   "foo"
  ,    bar     
               =>        $obj       );
####
$obj = Hlagh->$cb;
####
$obj = Hlagh->$cb();
####
$obj = Hlagh->$cb($pkg);
####
$obj = Hlagh->$cb(sub { 'foo' },  bar => $obj);
####
$obj = $pkg->new   ;
####
$obj = $pkg  ->   new  (   );
####
$obj = $pkg       
           -> 
        new ( $pkg );
####
$obj = 
         $pkg
->
new        (     qr/foo/,
      foo => qr/bar/   );
####
$obj 
  =  
$pkg
->
$cb
;
####
$obj = $pkg    ->   ($cb)   ();
####
$obj = $pkg->$cb( $obj  );
####
$obj = $pkg->$cb(qw/foo bar baz/);
####
$obj = new { $x };
####
$obj = new
  {
     $x  }
  ();
####
$obj = new {
  $x  } qq/foo/;
####
$obj = new
   {
      $x
    }(qw/bar baz/);
####
meh $x;
####
meh $x, 1 , 2;
####
print STDOUT "bananananananana\n";
####
print $x "oh hai\n";
####
$x->foo($pkg->$cb)
