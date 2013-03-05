package Newt;

use Modern::Perl;
use Data::Dumper;
use Newt::Grammar;

our $grammar = Newt::Grammar->new {
    TOP     => \q<body>,
    body    => Repeat( \q<expr> ),
    block   => [
        '{', \q<body>, '}'
    ],
    expr    => [
        \q<block>,
        \q<assign>,
        \q<call>,
    ],
    assign  => [
        \q<ident>, '=', \q<expr>
    ]
    call    => [
        qr/\w+/, (Not Break), \q<tuple>
    ],
    tuple   => [
        '(', Delim(',', [ \q<expr> ]), ')'
    ],
    infix_expr  => Any(
        \q<infix_op>,
        \q<expr>,
    ),
    infix_op    => Any(
        Label( op_plus  => Infix('+') ),
        Label( op_minus => Infix('-') ),
        Label( op_mult  => Infix('*') ),
        Label( op_div   => Infix('/') ),
    ),
    ident   => qr/\w+/,
};

unless (caller) {
    my $ast = $Newt->parse_file($ARGV[0]);
    print Dumper $ast;
}

1
__END__

sub, [], {}
Flat, Label
Not, Maybe, Discard
Delim, Repeat
Any, Longest, Shortest
Break, SameLine
Indent, Dedent
