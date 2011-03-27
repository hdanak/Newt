#!/usr/bin/env perl

use Parser;
use Data::Dumper;

my $grammar = {
	TOP	=> ['*body'],
	body	=> [OR('*call')],
	body
};

my $parser = new Parser($ARGV[0]);

my $ast = $parser->parse();
print Dumper $ast;
