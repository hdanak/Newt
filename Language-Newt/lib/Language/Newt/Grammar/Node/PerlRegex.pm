package Newt::Grammar::Node::PerlRegex;
use parent qw| Newt::Grammar::Node |;

use Modern::Perl;

=head1 Synopsis

=head1 Description

=cut

sub PerlRegex {
    __PACKAGE__->new(shift)
}
sub new {
    my ($class, $regexp) = @_;
    bless {
        regexp => $regexp
    }, $class
}
sub convert {
    my ($class, $struct) = @_;
    if ( ref($struct) eq 'Regexp' ) {
        return PerlRegex($struct)
    }
}

1
