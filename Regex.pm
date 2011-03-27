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
		return 0;
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

package Regex;

	use strict;
	use warnings;
	use Data::Dumper;
	
	use feature 'switch';
	use feature 'say';

	sub dsay {
		say @_ if 1;
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
		my $base = new Regex::Node;
		my $goal = new Regex::Node;
		$base->link($goal);
		for (my $index = 0; $index < length($raw); ++$index) {
			my $last = $goal->parent;
			given (substr($raw, $index, 1)) {
				when ('.') {
					$last->link(new Regex::Any)->link($goal);
				}
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
		my $base = $self->{nfa};
		my $start = 0;
REDO:		my $mark = $start;
		my $offset = 0;
		my @next_states = ($base);
		my @new_states = ();
		for $offset ($start .. length($text)-1) {
			my $k = @next_states;
			for (my $i = 0; $i < $k; $i++) {
				my $elem = $next_states[$i];
				my $char = substr($text, $offset, 1);
				my $match = $elem->match($char);
				my $next;
				if ($match < 0) {
					# ignore the old object
					dsay "Failed '$char' at offset: $offset start: $start with rule ", ref($elem);
				} elsif ($match > 0) {
					# continue the chain
					dsay "Matched '$char' at offset: $offset start: $start with rule ", ref($elem);
					$next = $elem->next;
					if ('ARRAY' eq ref $next) {
						push @new_states, @$next;
					} else {
						push @new_states, $next;
					}
				} else {
					dsay "Zero '$char' at offset: $offset start: $start with rule ", ref($elem);
					# zero-length, next with same char
					$next = $elem->next;
					if ('ARRAY' eq ref $next) {
						if (!@$next) {
							$mark = $offset;
							next;
						}
						$k = push @next_states, @$next;
					} else {
						$k = push @next_states, $next;
					}
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
1;


package main;

use Data::Dumper;

my $re = new Regex('a.*');
#print Dumper $re;
say $re->match('abcd');

sub make_patho {
	my ($n) = @_;
	return ('a?'x$n).('a'x$n);
}
