package Newt::Grammar::Node::Rule;
use parent qw| Newt::Grammar::Node |;

use Modern::Perl;

=head1 Synopsis

=head1 Description

=cut

sub Rule {
    __PACKAGE__->new(shift)
}
sub new {
    my ($class, $name) = @_;
    bless {
        name => $name
    }, $class
}
sub convert {
    my ($class, $struct) = @_;
    if ( ref($struct) eq 'SCALAR') {
        return Rule($$struct);
    }
}

1
