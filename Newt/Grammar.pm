package Grammar;

use Modern::Perl;
use Module::Pluggable search_path   => qw| Newt::Grammar::Node |,
                      sub_name      => 'node_types';


sub new {
	my ($class, $rules) = @_;
    $rules = \%{@_[1 .. $#@_]} if 'HASH' ne ref $rules;
	die "No grammar provided to Parser.\n"
		unless defined $rules;
	bless {
        map {
            $_ => $class->convert($$rules{$_})
        } keys %$rules
    }, $class
}

sub convert {
    my ($class, $struct) = @_;
    for my $node_type($class->node_types) {
        if (my $node = $node_type->convert($struct)) {
            return $node;
        }
    }
}

## TODO: Refactor the following into Node classes

sub parse_file {
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


1
