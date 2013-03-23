package Newt;

use Modern::Perl;
use Data::Dumper;
use Newt::Grammar;

our $grammar = Newt::Grammar->new {
    body    => Repeat(0)->(\q<expr>),

    expr    => [
        Either(
            \q<struct>,
            \q<literal>,
            \q<call>,
            \q<query>,
            \q<self>,
        ),
        Maybe( \q<assert> )
    ],
    assert  => [
        Repeat(1)->('::', Either(
            Label( Type => \q<ident>),
        )
    ],

    define  => [ \q<ident>, ':=', \q<expr> ]
    ident   => qr/\w+/,

    func    => [
        NoBreak(\q<ident>, Maybe(\q<tuple>), ':='), \q<expr>
        NoBreak('\\\\', Maybe(\q<ident>), Maybe(\q<tuple>)),
        \q<block>
    ],

    sigil   => Either(qw[ $ @ % ]),
    var     => Token(
        Maybe(
            Label( Local => \q<sigil>)
        ),
        \q<sigil>,
        Maybe(
            Maybe(qr/\d+/), '^'
        ),
        Maybe(
            Label( Type => \q<ident>), ':'
        ),
        \q<ident>
    ),
    query   => NoBreak(\q<var>, \q<expr>),
    assign  => [ \q<var>, '=', \q<expr> ]
    self    => [ \q<sigil>, Maybe(\q<sigil>) ]

    struct  => Either(
        \q<tuple>, \q<list>, \q<hash>
    ),
    tuple   => Circumfix('(', ')')->(
        Delim(',', 0)->(\q<expr>), \q<expr>
    ),
    list    => Circumfix('[', ']')->(
        Delim(',', 0)->(\q<expr>), \q<expr>
    ),
    pair    => [
        Label( Key => Either( \q<literal>, \q<ident>, \q<var> )),
        ':',
        Label( Value => \q<expr>),
    ],
    hash    => Circumfix('{', '}')->(
        Delim(',', 0)->(\q<expr>)
    ),

    literal => Either(
        \q<symbol>,
        \q<string>,
        \q<pattern>,
        \q<number>,
    ),
    symbol  => Token(
        '.', \q<ident>
    ),
    string  => Token(
        Either(
            Circumfix('"', Unescaped('"'))->( Repeat(0)->(AnyChar) ),
            Circumfix("'", Unescaped("'"))->( Repeat(0)->(AnyChar) ),
            \q<quote>,
        )
    ),
    quote   => Token( Either(
        [ '`', qr/(\\.|\w)+/ ],
        [ '`', Let(delim => qr/\W/)->(
            Circumfix(\q<delim>, Unescaped(\q<delim>))->(
                Repeat(0)->(AnyChar)
            )
        )]
    )),
    pattern => Token(
        'm', Let(delim => qr/\W/)->(
            Circumfix(\q<delim>, Unescaped(\q<delim>))->(
                Repeat(0)->(AnyChar)
            )
        )
    ),
    number => Token(
        Label( Sign => Either('+', '-', Anyway('+')),
        Either(
            Label( Hex => '0x'),
            Label( Bin => '0b'),
            Label( Oct => '0'),
            Label( Dec => ''),
        ),
        Label( Whole => qr/\d+/ ),
        Maybe(
            '.'
            Label( Part => qr/\d+/ ),
        ),
        Maybe(
            Either('e', 'E'),
            Label( Exp  => qr/[+-]\d+/ ),
        ),
    ),
};

unless (caller) {
    my $ast = $Newt->parse_lines(<>);
    print Dumper $ast;
}

1
__END__

(), [], {}
Flat, Label
Not, Maybe, Discard
Delim, Repeat
Either, Longest, Shortest
Break, SameLine
Indent, Dedent
