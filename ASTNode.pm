#!/usr/bin/env perl

package ASTNode;

sub new {
	my ($class, %args) = @_;

	my $self = \%args;

	bless $self, $class;
}

1
