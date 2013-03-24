package Newt::Grammar::Node::Any;
use parent qw| Newt::Grammar::Node |;

use Modern::Perl;

=head1 Synopsis

# Match either 'a' or 'b' or 'c'.
Any(
    'a',
    'b'
    'c'
)
# Inside a Grammar structure, you can also use a hashref with numeric keys;
# the keys determine the order in which the subpatterns are tried.
{
    1 => 'a',
    2 => 'b',
    3 => 'c',
}

=head1 Description

Matches if at least one child node matches.

=cut

sub Any {
}

1
