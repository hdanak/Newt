package Newt::Grammar::Node::Term;
use parent qw| Newt::Grammar::Node |;

use Modern::Perl;

=head1 Description

Matches any single character, similar to the regex '.' metacharacter.

=cut

sub AnyChar {
    __PACKAGE__->new()
}
sub match {
}

1
