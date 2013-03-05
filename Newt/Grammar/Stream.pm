package Newt::Grammar::Stream;

sub new {
    my ($class, $source) = @_;
    bless {
        source  => $source,
		line    => 0,
		pos     => 0,
		stack   => []
	}, $class
}
sub save {
    my ($self) = @_;
    push @{$$self{stack}}, [ @$self{qw[ line pos ]} ]
}
sub restore {
    my ($self) = @_;
    @$self{qw[ line pos ]} = @{ pop @{$$self{stack}} }
}
sub discard {
    my ($self) = @_;
    @{ pop @{$$self{stack}} }
}
sub consume {
	my ($self, $pattern) = @_;
    return unless defined $pattern;
    $pattern = quotemeta $pattern unless ref $pattern;
    while (substr($$self{source}, $$self{pos}, 1) eq "\n") {
        $self->{line}++;
        $self->{pos}++;
    }
    pos($$self{source}) = $$self{pos};
    if ($$self{source} =~ /\G($pattern)/) {
        my $match = $1;
        $self{pos} += length($match);
        $self{line} += $match =~ tr/\n//;
        return $match;
    }
}
