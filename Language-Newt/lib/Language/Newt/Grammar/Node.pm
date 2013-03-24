package Newt::Grammar::Node;

use Modern::Perl;

sub new {
    my ($class) = @_;
    bless {
        parents => [],
        links   => []
    }, $class
}

sub convert {
    my ($class, $struct) = @_;
    if ( ref($struct) =~ /^Newt::Grammar::Node/ ) {
        return $struct
    }
}


sub match { 0 }
sub length { 0 }
sub find_parent {
    my ($self, $node) = @_;
    return !!grep {$node == $_} @{$$self{parents}};
}
sub parent {
    my ($self, @nodes) = @_;
    my $to_append = _list_minus(\@nodes, $$self{parents});
    push @{$$self{parents}}, @$to_append;
    map { $_->link($self) } @$to_append;
    return @nodes;
}
sub unparent {
    my ($self, @nodes) = @_;
    if (@nodes) {
        $self->{parent} = _list_minus($self->{parent}, \@nodes);
        foreach (@nodes) {
            $_->unlink($self) if $_->has_link($self);
        }
    } else {
        my @parents = $self->parents;
        $self->{parent} = [];
        foreach (@parents) {
            $_->unlink($self) if $_->has_link($self);
        }
    }
}
sub reparent {
    my ($self, @nodes) = @_;
    $self->unparent;
    $self->parent(@nodes);
}
sub links {
    my ($self) = @_;
    return @{$self->{next}};
}
sub has_link {
    my ($self, $node) = @_;
    return !!grep {$node == $_} $self->links;
}
sub link {
    my ($self, @nodes) = @_;
    my $to_append = _list_minus(\@nodes, $self->{next});
    push @{$self->{next}}, @$to_append;
    for (@$to_append) {
        $_->parent($self);
    }
    return @nodes;
}
sub unlink {
    my ($self, @nodes) = @_;
    if (@nodes) {
        $self->{next} = _list_minus($self->{next}, \@nodes);
        foreach (@nodes) {
            $_->unparent($self) if $_->find_parent($self);
        }
    } else {
        my @links = $self->links;
        $self->{next} = [];
        foreach (@links) {
            $_->unparent($self) if $_->find_parent($self);
        }
    }
}
sub relink {
    my ($self, @nodes) = @_;
    $self->unlink;
    $self->link(@nodes);
}
sub insert {
    my ($self, @nodes) = @_;
    my $next = $self->{next};
    foreach my $node (@nodes) {
        $self->relink($node);
        $node->relink($next);
    }
    return @nodes;
}
sub prepend {
    my ($self, @nodes) = @_;
    foreach my $node (@nodes) {
        foreach ($self->parents) {
            $_->unlink($self);
            $_->link($node);
        }
        $node->relink($self);
    }
    return @nodes;
}
sub pp {
    my ($self) = @_;
    return '';
}
sub get_qid {
    my ($self) = @_;
    return $self->{qid};
}
sub set_qid {
    my ($self, $qid) = @_;
    $self->{qid} = $qid;
}
sub _list_minus {
    my ($a, $b) = @_;
    my @res = grep {
        my $elem = $_;
        !(grep {$elem == $_} @$b);
    } @$a;
    return \@res;
}


1
