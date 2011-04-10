
package Parser;

use strict;
use warnings;
use feature 'switch';
use feature 'say';

use Grammar;

use Data::Dumper;

sub new {
	my ($class, $grammar) = @_;
	die "No grammar provided to Parser.\n"
		unless defined $grammar;
	die "Grammar doesn't containt TOP rule.\n"
		unless defined $grammar->{TOP};
	my $self = {
		grammar	=> Grammar::sanitize($grammar),
		src	=> undef,
		lnum	=> 0,
		cnum	=> 0,
		state_stack => []
	};
	#print Dumper $self->{grammar};

	bless $self, $class;
}

sub parse {
	my ($self, $filename) = @_;

	die "No file provided to Parser.\n"
		unless defined $filename;
	open (my $fh, '<', $filename)
		or die "Cannot open file: $!\n";
	my @file_contents = <$fh>;
	close $fh;
	my $file_text = join '', @file_contents;
	$self->{src} = $file_text;

	my $syntax_tree = $self->_process_rule($self->{grammar}->{TOP});
	if ($syntax_tree == 0) {
		my $ecnum = 0;
		my $eline = $self->{lnum}+1;
		do {
			last if substr($self->{src},$self->{cnum}, -1*$ecnum) eq "\n";
		} while ($ecnum++);
		die "Syntax error on line $eline, char $ecnum.\n";
	}
	print Dumper $syntax_tree;
}

sub _process_rule {
	my ($self, $rule) = @_;
	die "Unsanitized rule at "
		if ref($rule) ne 'Grammar::Node' && not defined $self->{grammar}->{$rule};
	$rule = $self->{grammar}->{$rule} if ref($rule) eq '';
	given ($rule->{type}) {
		when ('TERM') {
			if ($_ = $self->_next_tok($rule->{val})) {
				return $_;
			} else {
				return 0;
			}
		}
		when ('RULE') {
			if ($_ = $self->_process_rule($rule->{name})) {
				return $_;
			} else {
				return 0;
			}
		}
		when ('RE') {
			if ($self->_next_tok($rule->{pattern})) {
				return $_;
			} else {
				return 0;
			}
		}
		when ('AND') {
			my @list = ();
			for my $elem (@{$rule->{list}}) {
				if ($_ = $self->_process_rule($elem)) {
					push @list, $_;
				} else {
					return 0;
				}
			}
			return \@list;
		}
		when ('OR') {
			for my $elem (@{$rule->{list}}) {
				$self->_save_state;
				if ($_ = $self->_process_rule($elem)) {
					$self->_pop_state;
					return $_;
				} elsif( \$elem != \$rule->{list}->[-1] ) {
					$self->_restore_state;
				}
			}
			return 0;
		}
		when ('LIST') {
			my @list = ();
			push @list, $self->_process_rule($rule->{name});
			while ($self->_process_rule($rule->{comma})) {
				push @list, $self->_process_rule($rule->{name});
			}
			return \@list;
		}
	}
}

sub _save_state {
	my ($self) = @_;
	push @{$self->{state_stack}}, [
		$self->{lnum},
		$self->{cnum},
	];
}

sub _restore_state {
	my ($self) = @_;
	(	$self->{lnum},
		$self->{cnum},
	) = @{pop @{$self->{state_stack}}};
}

sub _pop_state {
	my ($self) = @_;
	pop @{$self->{state_stack}};
}

sub _next_tok {
	my ($self, $pattern) = @_;
	while (substr($self->{src}, $self->{cnum}, 1) eq "\n") {
		$self->{cnum}++;
		$self->{lnum}++;
	}
	$pattern = $pattern // '\w+';
	$pattern = '\G('.$pattern.')';
	if ($self->{src} =~ $pattern) {
		my $out = $1;
		$self->{cnum} += length($1);
		$self->{lnum} += $out =~ tr/\n//;
		return $out;
	} else {
		return 0;
	}
}

1
