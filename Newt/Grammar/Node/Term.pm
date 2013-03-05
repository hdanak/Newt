package Newt::Grammar::Node::Term;
use parent qw| Newt::Grammar::Node |;

use Modern::Perl;

=head1 Description

Matches the specified text.

=cut

sub Term {
    __PACKAGE__->new(shift)
}
sub new {
    my ($class, $text) = @_;
    bless {
        text => $text
    }, $class
}
sub convert {
    my ($class, $struct) = @_;
    if ( ref($struct) eq '') {
        return Term($struct);
    }
}

1
