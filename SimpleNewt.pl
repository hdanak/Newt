#!/usr/bin/env perl

use Parser;
use Data::Dumper;

use Grammar qw/OR RE LIST/;

my $grammar = {
	TOP	=> '*body',
	body	=> OR('*sub', '*declr', '*expr'),
	expr	=> '*call',
	call	=> [RE('\w+'), '(', LIST('*expr', ','), ')'],
	sub	=> ['sub', '*ident', '{', '*body', '}'],
	declr	=> ['my', '*var', OR(['=', '*expr'], '')],
	ident	=> RE('\w+'),
	var	=> RE('\$\w+'),
};

my $parser = new Parser($grammar);

my $ast = $parser->parse($ARGV[0]);
#print Dumper $ast;
