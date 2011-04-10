
package Grammar;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(OR RE LIST RULE TERM); 

use strict;
use warnings;
use feature 'switch';

# Grammar Nodes

sub NODE {
	my ($type, %rest) = @_;
	bless { type => $type, %rest }, 'Grammar::Node';
}
sub OR {
	my @list = map {_sanitize_subrule($_)} @_;
	return NODE ('OR',
		list	=> \@list,
	);
}
sub AND {
	my @list = map {_sanitize_subrule($_)} @_;
	return NODE ('AND',
		list	=> \@list,
	);
}
sub RE {
	return NODE ('RE',
		pattern	=> shift,
	);
}
sub LIST {
	return NODE ('LIST',
		name	=> _sanitize_subrule(shift),
		comma	=> _sanitize_subrule(shift),
	);
}
sub RULE {
	return NODE ('RULE',
		name	=> shift,
	);
}
sub TERM {
	return NODE ('TERM',
		val	=> quotemeta(shift),
	);
}

sub sanitize {
	my ($grammar) = @_;
	my $new_grammar = {};
	for my $rule (keys %$grammar) {
		$new_grammar->{$rule} = _sanitize_subrule($grammar->{$rule});
	}
	return $new_grammar;
}

sub _sanitize_subrule {
	my ($subrule) = @_;
	given (ref $subrule) {
		when ('ARRAY') {
			return AND(@$subrule);
		}
		when ('Grammar::Node') {
			return $subrule;
		}
		default {
			if (substr($subrule, 0, 1) eq '*') {
				return RULE(substr($subrule, 1));
			}
			else {
				return TERM($subrule);
			}
		}
	}
}

1
