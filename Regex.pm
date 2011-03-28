package Regex::Node;
	use strict;
	use warnings;
	sub new {
		my ($class) = @_;
		my $self = {
			next	=> [],
			parent	=> [],
		};
		bless $self, $class;
	}
	sub match {
		return 0;
	}
	sub parents {
		my ($self) = @_;
		return @{$self->{parent}};
	}
	sub has_parent {
		my ($self, $node) = @_;
		return !!grep {$node == $_} $self->parents;
	}
	sub parent {
		my ($self, @node) = @_;
		my $to_append = _list_minus(\@node, $self->{parent});
		push @{$self->{parent}}, @$to_append;
		for (@$to_append) {
			$_->link($self);
		}
		return @node;
	}
	sub unparent {
		my ($self, @node) = @_;
		if (@node) {
			$self->{parent} = _list_minus($self->{parent}, \@node);
			foreach (@node) {
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
		my ($self, @node) = @_;
		$self->unparent;
		$self->parent(@node);
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
		my ($self, @node) = @_;
		my $to_append = _list_minus(\@node, $self->{next});
		push @{$self->{next}}, @$to_append;
		for (@$to_append) {
			$_->parent($self);
		}
		return @node;
	}
	sub unlink {
		my ($self, @node) = @_;
		if (@node) {
			$self->{next} = _list_minus($self->{next}, \@node);
			foreach (@node) {
				$_->unparent($self) if $_->has_parent($self);
			}
		} else {
			my @links = $self->links;
			$self->{next} = [];
			foreach (@links) {
				$_->unparent($self) if $_->has_parent($self);
			}
		}
	}
	sub relink {
		my ($self, @node) = @_;
		$self->unlink;
		$self->link(@node);
	}
	sub insert {
		my ($self, @node) = @_;
		my $next = $self->{next};
		foreach my $node (@node) {
			$self->relink($node);
			$node->relink($next);
		}
		return @node;
	}
	sub prepend {
		my ($self, @node) = @_;
		foreach my $node (@node) {
			foreach ($self->parents) {
				$_->unlink($self);
				$_->link($node);
			}
			$node->relink($self);
		}
		return @node;
	}
	sub _list_minus {
		my ($a, $b) = @_;
		my @res = grep {
			my $elem = $_;
			!(grep {$elem == $_} @$b);
		} @$a;
		return \@res;
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
		my ($self, $char) = @_;
		return 1 if $char eq $self->{atom};
		return -1;
	}
1;
package Regex::Any;
	our @ISA=('Regex::Node');
	sub new {
		my ($class, $nl) = @_;
		my $self = Regex::Node->new();
		$self->{nl} = $nl // 1;
		bless $self, $class;
	}
	sub match {
		my ($self, $char) = @_;
		if ($self->{nl}) {
			return 1 if $char;
		} else {
			return 1 if $char ne "\n";
		}
		return -1;
	}
1;
package Regex::Class;
	our @ISA=('Regex::Node');
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
		my ($self, $char) = @_;
		my $m = defined $self->{alts}->{$char};
		$m = !$m if $self->{inv};
		return 1 if $m;
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
		return new Regex::Class($alts, $inv)
	}
1;
package Regex::Start;
	our @ISA=('Regex::Node');
1;
package Regex::End;
	our @ISA=('Regex::Node');
1;

package Regex::Feeder;
	sub new {
		my ($class, $text) = @_;
		my $self = {
			text	=> $text,
			index	=> 0,
		};
		bless $self, $class;
	}
	sub take {
		my ($self) = @_;
		if ($self->{index} >= length($self->{text})) {
			$self->{index} = length($self->{text});
			return -1;
		}
		return substr($self->{text}, $self->{index}++, 1);
	}
	sub put {
		my ($self, $char) = @_;
		if ($self->{index} <= 0) {
			$self->{index} = 0;
			return -1;
		}
	}
1;

package Regex;

	use strict;
	use warnings;
	use Data::Dumper;
	
	use feature 'switch';
	use feature 'say';

	sub dsay {
		say @_ if 0;
	}

	sub new {
		my ($class, $regex) = @_;
		my $self = {
			nfa	=> _create_nfa($regex)
		};
		bless $self, $class;
	}
	
	sub _create_nfa {
		my ($raw) = @_;
		my $base = new Regex::Start;
		my $goal = new Regex::End;
		$base->link($goal);
		for (my $index = 0; $index < length($raw); ++$index) {
			given (substr($raw, $index, 1)) {
				when ('.') {
					my $node = new Regex::Any;
					$goal->prepend($node);
				}
				when ('?') {
					$goal->parent(map {$_->parents} $goal->parents);
				}
				when ('*') {
					foreach my $l1 ($goal->parents) {
						$l1->relink($l1);
						foreach my $l2 ($l1->parents) {
							$l2->link($goal);
						}
					}
				}
				when ('+') {
				}
				when ("\\") {
					my $node = _lookup_spec(substr($raw, $index, 2));
					$goal->prepend($node);
					++$index;
				}
				default {
					my $node = new Regex::Atom($_);
					$goal->prepend($node);
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
		my $base = $self->{nfa};
		my $start = 0;
REDO:		my $mark = $start;
		my $offset = 0;
		my @next_states = $base->links;
		my @new_states = ();
		for $offset ($start .. length($text)-1) {
			my $k = @next_states;
			for (my $i = 0; $i < $k; $i++) {
				my $elem = $next_states[$i];
				my $char = substr($text, $offset, 1);
				my $match = $elem->match($char);
				my @next;
				if ($match < 0) {
					# ignore the old object
					dsay "Failed '$char' at offset: $offset start: $start with rule ", ref($elem);
				} elsif ($match > 0) {
					# continue the chain
					dsay "Matched '$char' at offset: $offset start: $start with rule ", ref($elem);
					@next = $elem->links;
					push @new_states, @next;
				} else {
					dsay "Zero '$char' at offset: $offset start: $start with rule ", ref($elem);
					# zero-length, next with same char
					@next = $elem->links;
					if (!@next) {
						$mark = $offset;
						next;
					}
					$k = push @next_states, @next;
				}
			}
			@next_states = @new_states;
			@new_states = ();
			if (!@next_states) {
				if ($mark == $start) {
					$start++;
					goto 'REDO';
				}
				last;
			}
		}
		return substr($text, $start, $mark - $start);
	}
	sub to_dot {
		my ($self) = @_;
		use GraphViz;
		my $g = GraphViz->new();
		my @q = ($self->{nfa});
		my %chalk;
		while (@q) {
			my $elem = shift @q;
			if ($chalk{$elem}) {
				next;
			} else {
				$chalk{$elem} = 1;
			}
			my $label = ref $elem;
			$label .= "('$elem->{atom}')" if $label eq 'Regex::Atom';
			$g->add_node($elem, label => $label);
			my @next = $elem->links;
			push @q, @next;
			my @parents = $elem->parents;
			foreach my $parent (@parents) {
				$g->add_edge($parent, $elem);
			}
		}
		return $g->as_text;
	}
1;


package main;

use Data::Dumper;

my $re = new Regex(make_patho(5));
open (my $df, '> test.dot');
print $df $re->to_dot;
close ($df);
system("dot -Tps test.dot -o outfile.ps");
#print Dumper $re;
say $re->match('aaaaa');

sub make_patho {
	my ($n) = @_;
	return ('a?'x$n).('a'x$n);
}
