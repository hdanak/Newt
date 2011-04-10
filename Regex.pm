package Regex::Node;
	use strict;
	use warnings;
	sub new {
		my ($class, $context) = @_;
		my $self = {
			next	=> [],
			parent	=> [],
			context	=> $context,
		};
		bless $self, $class;
	}
	sub match {
		return 0;
	}
	sub length {
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
	sub pp {
		my ($self) = @_;
		return '';
	}
	sub get_qid {
		my ($self) = @_;
		return $self->{qid};
	}
	sub set_qid {
		my ($self, $qid) = @_;
		$self->{qid} = $qid;
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
		my ($class, $atom, $context) = @_;
		die "Incorrect input to Regex::Atom.\n"
			if length($atom) > 1 && substr($atom, 0, 1) ne "\\";

		my $self = Regex::Node->new($context);
		$self->{atom} = $atom;
		bless $self, $class;
	}
	sub match {
		my ($self, $char) = @_;
		return 1 if $char eq $self->{atom};
		return -1;
	}
	sub length {
		return 1;
	}
	sub pp {
		my ($self) = @_;
		return "Atom('$self->{atom}')";
	}
1;
package Regex::Any;
	our @ISA=('Regex::Node');
	sub new {
		my ($class, $nl, $context) = @_;
		my $self = Regex::Node->new($context);
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
	sub length {
		return 1;
	}
	sub pp {
		my ($self) = @_;
		return "Any";
	}
1;
package Regex::Class;
	our @ISA=('Regex::Node');
	sub new {
		my ($class, $alts, $context, $inv) = @_;
		my $h = {};
		foreach (@$alts) {
			$h->{$_} = 1;
		}
		my $self = Regex::Node->new($context);
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
	sub length {
		return 1;
	}
	sub pp {
		my ($self) = @_;
		return "Class";
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
	sub new {
		my ($class, $name) = @_;
		my $self = Regex::Node->new();
		$self->{name} = $name;
		bless $self, $class;
	}
	sub name {
		my ($self) = @_;
		return $self->{name};
	}
	sub pp {
		my ($self) = @_;
		return "Start('$self->{name}')";
	}
1;
package Regex::End;
	our @ISA=('Regex::Node');
	sub new {
		my ($class, $name) = @_;
		my $self = Regex::Node->new();
		$self->{name} = $name;
		bless $self, $class;
	}
	sub name {
		my ($self) = @_;
		return $self->{name};
	}
	sub pp {
		my ($self) = @_;
		return "End('$self->{name}')";
	}
1;

package Regex::Feeder;
	sub new {
		my ($class, $text, $offset) = @_;
		my $self = {
			text	=> $text,
			index	=> $offset // 0,
			offset	=> $offset // 0,
		};
		bless $self, $class;
	}
	sub take {
		my ($self) = @_;
		if ($self->{index} >= length($self->{text})) {
			$self->{index} = length($self->{text});
			return undef;
		}
		return substr($self->{text}, $self->{index}++, 1);
	}
	sub give {
		my ($self, $char) = @_;
		if ($self->{index} <= $self->{offset}) {
			$self->{index} = $self->{offset};
			die "Put more than taken from feeder";
		}
		--$self->{index};
	}
	sub distance {
		my ($self) = @_;
		return $self->{index} - $self->{offset};
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
			nfa	=> _create_nfa($regex),
			captures=> {},
		};
		bless $self, $class;
	}
	
	sub _create_nfa {
		my ($raw) = @_;
		my $base = new Regex::Start(0);
		my $goal = new Regex::End(0);
		$base->link($goal);
		my @cap_stack;
		my $cap_count = 1;
		for (my $index = 0; $index < length($raw); ++$index) {
			given (substr($raw, $index, 1)) {
				when ('.') {
					my $node = new Regex::Any;
					$goal->prepend($node);
				}
				when ('?') {
					my $node = new Regex::Node;
					$node->parent(map {$_->parents} $goal->parents);
					$goal->prepend($node);
				}
				when ('*') {
					my $node = new Regex::Node;
					my @last = $goal->parents;
					$goal->prepend($node);
					$node->parent(map {$_->parents} @last);
					$node->link(@last);
				}
				when ('+') {
					my $node = new Regex::Node;
					my @last = $goal->parents;
					$goal->prepend($node);
					$node->link(@last);
				}
				when ("\\") {
					my $node = _lookup_spec(substr($raw, $index, 2));
					$goal->prepend($node);
					++$index;
				}
				when ('[') {
				}
				when ('(') {
					push @cap_stack, $cap_count;
					print @cap_stack, "\n";
					$goal->prepend(new Regex::Start($cap_count));
					$cap_count++;
				}
				when (')') {
					my $cap = pop @cap_stack;
					print @cap_stack, "\n";
					die "Unballanced parens in regex." if not defined $cap;
					$goal->prepend(new Regex::End($cap));
				}
				when ('|') {
				}
				default {
					my $node = new Regex::Atom($_);
					$goal->prepend($node);
				}
			}
		}
		die "Unballanced parens in regex." if @cap_stack;
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
		for my $start (0 .. length($text)) {
			my $feeder = new Regex::Feeder($text, $start);
			if ($self->_submatch($self->{nfa}, $feeder)) {
				return substr($text, $start, $feeder->distance);
			}
		}
		return 0;
	}
	sub _submatch {
		my ($self, $start, $feeder) = @_;
		my $queue = [];
		my $next = [];
		_enqueue($queue, $start->links);
		my $char;
		while (defined($char = $feeder->take)) {
			while (@$queue) {
				$_ = shift @$queue;
				$_->set_qid(undef);
				if (ref($_) eq 'Regex::Start') {
					$feeder->give($char);
					my $old_feeder_index = $feeder->{index};
					return 0 unless $self->_submatch($_, $feeder);
					$self->{captures}->{$_->name} = [
						$old_feeder_index,
						$feeder->{index} - $old_feeder_index,
					];
				} elsif (ref($_) eq 'Regex::End') {
					$feeder->give($char);
					return 1;
				} elsif ($_->length == 0) {
					_enqueue($queue, $_->links);
				} else {
					_enqueue($next, $_->links)
						if $_->match($char) > 0;
				}
			}
			$queue = $next;
			$next = [];
			return 0 unless @$queue;
		}
		if (!defined($char)) {
			return 1 if grep {ref($_) eq 'Regex::End'} @$queue;
			return 0;
		}
		return !!$char;
	}
	sub _enqueue {
		my ($queue, @elems) = @_;
		foreach (@elems) {
			unless (defined($_->get_qid) && $_->get_qid == $queue) {
				$_->set_qid($queue);
				push @$queue, $_;
			}
		}
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
			my $label = $elem->pp;
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

my $re = new Regex('aaa?abc.d');
open (my $df, '> test.dot');
print $df $re->to_dot;
close ($df);
system("dot -Tps test.dot -o outfile.ps");
#print Dumper $re;
say $re->match('acdddddde');
print Dumper $re->{captures};

sub make_patho {
	my ($n) = @_;
	return ('a?'x$n).('a'x$n);
}
