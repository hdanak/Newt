package Newt::Grammar::Node::Regex;
use parent qw| Newt::Grammar::Node |;

use Modern::Perl;
use Data::Dumper;

sub new {
    my ($class, $regex) = @_;
    my $self = {
        nfa  => create_nfa($regex),
        caps => {},
    };
    bless $self, $class;
}

sub create_nfa {
    my ($raw) = @_;
    my $base = new Grammar::Node::Regex::Start(0);
    my $goal = new Grammar::Node::Regex::End(0);
    $base->link($goal);
    my @cap_stack;
    my $cap_count = 1;
    for (my $index = 0; $index < length($raw); ++$index) {
        given (substr($raw, $index, 1)) {
            when ('.') {
                my $node = new Grammar::Node::Regex::Any;
                $goal->prepend($node);
            }
            when ('?') {
                my $node = new Grammar::Node::Regex::Node;
                $node->parent(map {$_->parents} $goal->parents);
                $goal->prepend($node);
            }
            when ('*') {
                my $node = new Grammar::Node::Regex::Node;
                my @last = $goal->parents;
                $goal->prepend($node);
                $node->parent(map {$_->parents} @last);
                $node->link(@last);
            }
            when ('+') {
                my $node = new Grammar::Node::Regex::Node;
                my @last = $goal->parents;
                $goal->prepend($node);
                $node->link(@last);
            }
            when ("\\") {
                my $node = special_symbol(substr($raw, $index, 2));
                $goal->prepend($node);
                ++$index;
            }
            when ('[') {
            }
            when ('(') {
                push @cap_stack, $cap_count;
                print @cap_stack, "\n";
                $goal->prepend(new Grammar::Node::Regex::Start($cap_count));
                $cap_count++;
            }
            when (')') {
                my $cap = pop @cap_stack;
                print @cap_stack, "\n";
                die "Unballanced parens in regex." if not defined $cap;
                $goal->prepend(new Grammar::Node::Regex::End($cap));
            }
            when ('|') {
            }
            default {
                my $node = new Grammar::Node::Regex::Atom($_);
                $goal->prepend($node);
            }
        }
    }
    die "Unballanced parens in regex." if @cap_stack;
    return $base;
}

sub special_symbol {
    my ($spec) = @_;
    my $inv = $spec ne lc $spec;
    given (lc $spec) {
        when ('\d') {
            return Grammar::Node::Regex::Class::num($inv);
        }
        when ('\s') {
            return Grammar::Node::Regex::Class::space($inv);
        }
        when ('\w') {
            return Grammar::Node::Regex::Class::alpha($inv);
        }
        default {
            warn "Warning: Special character '$spec' not recognized in regex.\n";
            return new Grammar::Node::Regex::Node;
        }
    }
}

sub match {
    my ($self, $text) = @_;
    for my $start (0 .. length($text)) {
        my $feeder = new Grammar::Node::Regex::Feeder($text, $start);
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
            if (ref($_) eq 'Grammar::Node::Regex::Start') {
                $feeder->give($char);
                my $old_feeder_index = $feeder->{index};
                return 0 unless $self->_submatch($_, $feeder);
                $self->{caps}->{$_->name} = [
                    $old_feeder_index,
                    $feeder->{index} - $old_feeder_index,
                ];
            } elsif (ref($_) eq 'Grammar::Node::Regex::End') {
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
        return 1 if grep {ref($_) eq 'Grammar::Node::Regex::End'} @$queue;
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

package Grammar::Node::Regex::Start;
    use parent qw|Grammar::Node::Regex::Node|;
    sub new {
        my ($class, $name) = @_;
        my $self = Grammar::Node::Regex::Node->new();
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
package Grammar::Node::Regex::End;
    use parent qw|Grammar::Node::Regex::Node|;
    sub new {
        my ($class, $name) = @_;
        my $self = Grammar::Node::Regex::Node->new();
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

package Grammar::Node::Regex::Feeder;
    sub new {
        my ($class, $text, $offset) = @_;
        my $self = {
            text    => $text,
            index   => $offset // 0,
            offset  => $offset // 0,
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


package main;

use Data::Dumper;

my $re = new Grammar::Node::Regex('aaa?abc.d');
open (my $df, '> test.dot');
print $df $re->to_dot;
close ($df);
system("dot -Tps test.dot -o outfile.ps");
#print Dumper $re;
say $re->match('acdddddde');
print Dumper $re->{caps};

sub make_patho {
    my ($n) = @_;
    return ('a?'x$n).('a'x$n);
}
