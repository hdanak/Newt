package Newt::Grammar::Node::Repeat;
use parent qw| Newt::Grammar::Node |;

use Modern::Perl;

=head1 Synopsis

=head1 Description

=cut

sub Repeat {
    new(shift, Newt::Grammar::Node->convert(@_))
}
sub new {
    my ($class, $body) = @_;
    bless {
        body => $body,
    }, $class
}

sub match {
}

1
