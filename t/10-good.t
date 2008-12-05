#!perl -T

package Dongs;

sub new;

package main;

use strict;
use warnings;

use Test::More tests => 52 * 4;

my ($obj, $pkg, $cb, $x, @a);
our $y;
sub meh;

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
   skip "$_: $skip" => 4 if eval $skip;

   local $SIG{__WARN__} = sub { die 'warn:' . join(' ', @_) };

   eval "die qq{ok\\n}; $prefix; use indirect; $_";
   is($@, "ok\n", "use indirect: $_");

   eval "die qq{ok\n}; $prefix; no indirect; $_";
   is($@, "ok\n", "no indirect: $_");

   s/Hlagh/Dongs/g;

   eval "die qq{ok\\n}; $prefix; use indirect; $_";
   is($@, "ok\n", "use indirect, defined: $_");

   eval "die qq{ok\\n}; $prefix; no indirect; $_";
   is($@, "ok\n", "no indirect, defined: $_");
  }
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
meh;
####
meh $_;
####
meh $x;
####
meh $x, 1, 2;
####
meh $y;
####
meh $y, 1, 2;
#### $] < 5.010 # use feature 'state'; state $z
meh $z;
#### $] < 5.010 # use feature 'state'; state $z
meh $z, 1, 2;
####
print;
####
print $_;
####
print $x;
####
print $x "oh hai\n";
####
print $y;
####
print $y "dongs\n";
#### $] < 5.010 # use feature 'state'; state $z
print $z;
#### $] < 5.010 # use feature 'state'; state $z
print $z "hlagh\n";
####
print STDOUT "bananananananana\n";
####
$x->foo($pkg->$cb)
####
$obj = "apple ${\(new Hlagh)} pear"
####
$obj = "apple @{[new Hlagh]} pear"
####
exec $x $x, @a;
####
exec { $a[0] } @a;
####
system $x $x, @a;
####
system { $a[0] } @a;
