package Newt::Grammar::Node::And;
use parent qw| Newt::Grammar::Node |;

use Modern::Perl;

=head1 Synopsis

=head1 Description

=cut

sub All {
    __PACKAGE__->new([ map { Newt::Grammar->convert $_ } @_ ])
}
sub new {
    my ($class, $list) = @_;
    bless {
        list => $list
    }, $class
}
sub convert {
    my ($class, $struct) = @_;
    if ( ref($struct) eq 'SCALAR') {
        return All(@$struct);
    }
}

1
