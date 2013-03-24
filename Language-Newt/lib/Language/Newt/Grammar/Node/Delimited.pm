package Newt::Grammar::Node::Delimited;
use parent qw| Newt::Grammar::Node |;

use Modern::Perl;

=head1 Synopsis

=head1 Description

=cut

sub Delim {
    __PACKAGE__->new(shift, [ map { Newt::Grammar->convert $_ } @_ ])
}

sub new {
    my ($class, $comma, $body) = @_;
    bless {
        comma => $comma,
        body  => $body,
    }, $class
}

1
