package indirect;

use 5.008;

use strict;
use warnings;

=head1 NAME

indirect - Lexically warn about using the indirect object syntax.

=head1 VERSION

Version 0.14

=cut

our $VERSION;
BEGIN {
 $VERSION = '0.14';
}

=head1 SYNOPSIS

    # In a script
    no indirect;
    my $x = new Apple 1, 2, 3; # warns
    {
     use indirect;
     my $y = new Pear; # ok
     {
      no indirect hook => sub { die "You really wanted $_[0]\->$_[1]" };
      my $z = new Pineapple 'fresh'; # croaks 'You really wanted Pineapple->new'
     }
    }
    no indirect ':fatal';
    if (defied $foo) { ... } # croaks, note the typo

    # From the command-line
    perl -M-indirect -e 'my $x = new Banana;' # warns

    # Or each time perl is ran
    export PERL5OPT="-M-indirect"
    perl -e 'my $y = new Coconut;' # warns

=head1 DESCRIPTION

When enabled (or disabled as some may prefer to say, since you actually turn it on by calling C<no indirect>), this pragma warns about indirect object syntax constructs that may have slipped into your code.
This syntax is now considered harmful, since its parsing has many quirks and its use is error prone (when C<swoosh> isn't defined, C<swoosh $x> actually compiles to C<< $x->swoosh >>).

It currently does not warn when the object is enclosed between braces (like C<meth { $obj } @args>) or for core functions (C<print> or C<say>).
This may change in the future, or may be added as optional features that would be enabled by passing options to C<unimport>.

This module is B<not> a source filter.

=cut

BEGIN {
 require XSLoader;
 XSLoader::load(__PACKAGE__, $VERSION);
}

=head1 METHODS

=head2 C<< unimport [ hook => $hook | ':fatal' ] >>

Magically called when C<no indirect @opts> is encountered.
Turns the module on.
The policy to apply depends on what is first found in C<@opts> :

=over 4

=item *

If it's the string C<':fatal'>, the compilation will croak on the first indirect syntax met.

=item *

If the key/value pair C<< hook => $hook >> comes first, C<$hook> will be called for each error with the object name as C<$_[0]>, the method name as C<$_[1]>, the current file as C<$_[2]> and the line number as C<$_[3]>.

=item *

Otherwise, a warning will be emitted for each indirect construct.

=back

=cut

my $msg = sub {
 "Indirect call of method \"$_[1]\" on object \"$_[0]\" at $_[2] line $_[3].\n"
};

sub unimport {
 shift;

 my $hook;
 while (@_) {
  my $arg = shift;
  if ($arg eq 'hook') {
   $hook = shift;
  } elsif ($arg eq ':fatal') {
   $hook = sub { die $msg->(@_) };
  }
  last if $hook;
 }
 $hook = sub { warn $msg->(@_) } unless defined $hook;

 $^H |= 0x00020000;
 $^H{+(__PACKAGE__)} = _tag($hook);

 ();
}

=head2 C<import>

Magically called at each C<use indirect>. Turns the module off.

=cut

sub import {
 $^H{+(__PACKAGE__)} = undef;
 ();
}

=head1 CONSTANTS

=head2 C<I_THREADSAFE>

True iff the module could have been built when thread-safety features.

=head1 CAVEATS

The implementation was tweaked to work around several limitations of vanilla C<perl> pragmas : it's thread safe, and doesn't suffer from a C<perl 5.8.x-5.10.0> bug that causes all pragmas to propagate into C<require>d scopes.

C<meth $obj> (no semicolon) at the end of a file won't be seen as an indirect object syntax, although it will as soon as there is another token before the end (as in C<meth $obj;> or C<meth $obj 1>).

With 5.8 perls, the pragma does not propagate into C<eval STRING>.
This is due to a shortcoming in the way perl handles the hints hash, which is addressed in perl 5.10.

=head1 DEPENDENCIES

L<perl> 5.8.

L<XSLoader> (standard since perl 5.006).

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-indirect at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=indirect>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc indirect

Tests code coverage report is available at L<http://www.profvince.com/perl/cover/indirect>.

=head1 ACKNOWLEDGEMENTS

Bram, for motivation and advices.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of indirect
