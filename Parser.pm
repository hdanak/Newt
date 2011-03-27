#!/usr/bin/env perl

package Parser;

use strict;
use warnings;
use feature 'switch';
use feature 'say';

use ASTNode;

use Data::Dumper;

sub new {
	my ($class, $filename) = @_;
	die "No file provided to Parser.\n"
		unless defined $filename;
	open (my $fh, '<', $filename)
		or die "Cannot open file: $!\n";
	my @file_contents = <$fh>;
	close $fh;
	my $file_text = join '', @file_contents;
	$file_text =~ s/\n//g;
	my $self = {
		src	=> $file_text,
		lnum	=> 0,
		cnum	=> 0,
	};

	bless $self, $class;
}

sub parse {
	my ($self) = @_;

	while ($self->{src}) {
		my $tok;
		if ($tok = ($self->_next_call
			 || $self->_next_sub
			 || $self->_next_declr
			 || $self->_next_expr)) {
			print Dumper $tok;
		}
		else {
			die "Typo somewhere...\n";
		}
	}
}

sub _next_body {
	my ($self) = @_;
	my $node;
	if ($node = ($self->_next_call
		  || $self->_next_sub
		  || $self->_next_declr
		  || $self->_next_expr)) {
		return $ast_node;
	}
	else {
		return 0;
	}
}

sub _next_call {
	my ($self) = @_;
	if (my $tok = $self->_next_tok('\w+\(')) {
		my ($sub_name) = $tok =~ /(\w+)/;
		my @arg_list = ();
		while ($tok = $self->_next_tok('[^,)]*')) {
			push @arg_list, $tok;
			if ($self->_next_tok(',')) {
				next;
			} elsif ($self->_next_tok('\)')) {
				last;
			}
		}
		return new ASTNode(type	=> 'call',
				   sub	=> $sub_name,
				   args => \@arg_list);
	} else {
		return 0;
	}
}

sub _next_tok {
	my ($self, $pattern) = @_;
	say caller;
	$pattern = $pattern // '\w+';
	$pattern = '^('.$pattern.')(.*)$';
	if ($self->{src} =~ $pattern) {
		$self->{src} = $2;
		return $1;
	} else {
		return 0;
	}
}

1;

package Grammar;

our $grammar = {
	TOP	=> '*body',
	body	=> OR('*sub', '*declr', '*expr'),
	expr	=> OR('*call'),
	call	=> [RE('\w+'), RE('('), LIST('*expr', ','), RE(')')],
	sub	=> ['sub', '*ident', '{', '*body', '}'],
	declr	=> ['my', '*var', OR(['=', '*expr'], '')],
	ident	=> RE('\w+'),
	var	=> RE('\$\w+'),
};

sub OR {
	my $self = \@_;
	return {
		type	=> 'OR',
		list	=> \@_,
	};
}

sub RE {
	return {
		type	=> 'RE',
		pattern	=> shift,
	};
}

sub LIST {
	return {
		type	=> 'LIST',
		value	=> shift,
		comma	=> shift,
	};
}

1;
