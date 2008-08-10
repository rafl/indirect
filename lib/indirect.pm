package indirect;

use strict;
use warnings;

=head1 NAME

indirect - Lexically warn about using the indirect object syntax.

=head1 VERSION

Version 0.01

=cut

our $VERSION;
BEGIN {
 $VERSION = '0.01';
}

=head1 SYNOPSIS

    no indirect;
    my $x = new Apple 1, 2, 3; # warns
    {
     use indirect;
     my $y = new Pear; # ok
    }
    no indirect ':fatal';
    if (defied $foo) { ... } # croaks, note the typo

=head1 DESCRIPTION

When enabled (or disabled as some may prefer, since you actually turn it on by calling C<no indirect>), this pragma warns about indirect object syntax constructs that may have slipped into your code. This syntax is now considered harmful, since its parsing has many quirks and its use is error prone (when C<sub> isn't defined, C<sub $x> is actually interpreted as C<< $x->sub >>).

It currently does not warn when the object is enclosed between braces (like C<meth { $obj } @args>) or for core functions (C<print> or C<say>). This may change in the future, or may be added as optional features that would be enabled by passing options to C<unimport>.

=head1 METHODS

=head2 C<unimport @opts>

Magically called when C<no indirect @args> is encountered. Turns the module on. If C<@opts> contains C<':fatal'>, the module will croak on the first indirect syntax met.

=head2 C<import>

Magically called at each C<use indirect>. Turns the module off.

=cut

BEGIN {
 require XSLoader;
 XSLoader::load(__PACKAGE__, $VERSION);
}

sub import {
 $^H{indirect} = undef;
}

sub unimport {
 (undef, my $type) = @_;
 $^H{indirect} = (defined $type and $type eq ':fatal') ? 2 : 1;
}

=head1 DEPENDENCIES

L<perl> 5.9.4.

L<XSLoader> (standard since perl 5.006).

Tests require L<IPC::Cmd> (standard since 5.9.5).

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on #perl @ FreeNode (vincent or Prof_Vince).

=head1 BUGS

Please report any bugs or feature requests to C<bug-indirect at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=indirect>.  I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc indirect

=head1 ACKNOWLEDGEMENTS

Bram, for motivation and advices.

=head1 COPYRIGHT & LICENSE

Copyright 2008 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of indirect
