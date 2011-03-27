package Regex::Node;
	sub new {
		my ($class) = @_;
		my $self = {
			next	=> [],
			parent	=> undef,
		};
		bless $self, $class;
	}
	sub match {
		my ($self, $text, $offset) = @_;
		if (!@{$self->{next}}) {
			return 0;
		}
		my @results = grep {$_ > -1}
				  map {$_->match($text, $offset)}
				      @{$self->{next}};
		return $self->_max(@results);
	}
	sub parent {
		my ($self, $parent) = @_;
		$self->{parent} = $parent if defined $parent;
		return $self->{parent};
	}
	sub link {
		my $self = shift;
		$self->unlink;
		$self->branch(@_);
	}
	sub branch {
		my ($self, $node) = @_;
		if (ref($node) eq 'ARRAY') {
			push @{$self->{next}}, @$node;
			for (@$node) {
				$_->parent($self);
			}
		} else {
			push @{$self->{next}}, $node;
			$node->parent($self);
		}
		return $node;
	}
	sub unlink {
		my ($self) = @_;
		$self->{next} = [];
	}
	sub next {
		my ($self) = @_;
		return $self->{next}->[0] if @{$self->{next}} == 1;
		return $self->{next};
	}
	sub _max {
		my @list = @_;
		sort @list;
		return $list[-1];
	}
1;
package Regex::Atom;
	our @ISA=('Regex::Node');
	sub new {
		my ($class, $atom) = @_;
		die "Incorrect input to Regex::Atom.\n"
			if length($atom) > 1 && substr($atom, 0, 1) ne "\\";

		my $self = Regex::Node->new();
		$self->{atom} = $atom;
		bless $self, $class;
	}
	sub match {
		my ($self, $text, $offset) = @_;
		$offset = $offset // 0;
		if ($self->{atom} eq substr($text, $offset, 1)) {
			if (!@{$self->{next}}) {
				return 1;
			} else {
				my @results = grep {$_ > -1}
						  map {$_->match($text, $offset+1)}
						      @{$self->{next}};
				if (@results) {
					return 1 + $self->_max(@results);
				}
			}
		}
		return -1;
	}
1;
package Regex::Class;
	our @ISA=('Regex::Node');
	my $special_classes = {};
	sub new {
		my ($class, $alts, $inv) = @_;
		my $h = {};
		foreach (@$alts) {
			$h->{$_} = 1;
		}
		my $self = Regex::Node->new();
		$self->{alts} = $h;
		$self->{inv} = $inv // 0;
		bless $self, $class;
	}
	sub match {
		my ($self, $text, $offset) = @_;
		$offset = $offset // 0;
		my $m = defined $self->{alts}->{substr($text, $offset, 1)};
		$m = !$m if $self->{inv};
		if ($m) {
			if (!@{$self->{next}}) {
				return 1;
			} else {
				my @results = grep {$_ > -1}
						  map {$_->match($text, $offset+1)}
						      @{$self->{next}};
				if (@results) {
					return 1 + $self->_max(@results);
				}
			}
		}
		return -1;
	}
	sub alpha {
		my ($inv) = @_;
		$inv = $inv // 0;
		return _special(['a'..'Z','_'], $inv);
	}
	sub alpha_inv {
		return _special(['a'..'Z','_'], 1);
	}
	sub num {
		my ($inv) = @_;
		$inv = $inv // 0;
		return _special(['0'..'9'], $inv);
	}
	sub num_inv {
		return _special(['0'..'9'], 1);
	}
	sub space {
		my ($inv) = @_;
		$inv = $inv // 0;
		return _special([' ', "\t"], $inv);
	}
	sub space_inv {
		return _special([' ', "\t"], 1);
	}
	sub _special {
		my ($alts, $inv) = @_;
		my ($name) = caller;
		$inv = $inv // 0;
		$special_classes->{$name} = new Regex::Class($alts, $inv)
			if not defined $special_classes->{$name};
		return $special_classes->{$name};
	}
1;

package Regex;

	use strict;
	use warnings;
	use Data::Dumper;
	
	use feature 'switch';
	use feature 'say';
	
	sub new {
		my ($class, $regex) = @_;
		my $self = {
			nfa	=> _create_nfa($regex)
		};
		bless $self, $class;
	}
	
	sub _create_nfa {
		my ($raw) = @_;
		my $base = new Regex::Node;
		my $goal = new Regex::Node;
		$base->link($goal);
		for (my $index = 0; $index < length($raw); ++$index) {
			my $last = $goal->parent;
			given (substr($raw, $index, 1)) {
				when ('?') {
					my $next = new Regex::Node;
					$last->link($next);
					$last->parent->branch($next);
					$next->link($goal);
				}
				when ('*') {
					$last->link($last->parent);
					$last->parent->link($goal);
				}
				when ('+') {
					$last->link(new Regex::Node);
					$last->next->link($last);
					$last->next->branch($goal);
				}
				when ("\\") {
					$last->link(_lookup_spec(substr($raw, $index, 2)))->link($goal);
					++$index;
				}
				default {
					$last->link(new Regex::Atom($_))->link($goal);
				}
			}
		}
		return $base;
	}
	
	sub _lookup_spec {
		my ($spec) = @_;
		my $inv = $spec ne lc $spec;
		given (lc $spec) {
			when ('\d') {
				return Regex::Class::num($inv);
			}
			when ('\s') {
				return Regex::Class::space($inv);
			}
			when ('\w') {
				return Regex::Class::alpha($inv);
			}
			default {
				warn "Warning: Special character '$spec' not recognized in regex.\n";
				return new Regex::Node;
			}
		}
	}

	sub match {
		my ($self, $text) = @_;
		my $offset = 0;
		my $base = $self->{nfa};
		my @current = ($base);
		for (0 .. length($text)) {
			@current = map {
				$_->match(substr($text, $_, 1));
				my $x = $_->next;
				return @$x if ref($x) eq 'ARRAY';
				return $x
			} @current;

				foreach (@$next) {
					push @q, $_;
				}
			}
			if ($base->match($text, $offset) > -1) {
				return 1;
			} else {
				return 0;
			}
			$next = $base->next;
		}
	}
1;


package main;

use Data::Dumper;

my $re = new Regex(make_patho(20));
#print Dumper $re;
say $re->match('a'x20);

sub make_patho {
	my ($n) = @_;
	return ('a?'x$n).('a'x$n);
}
