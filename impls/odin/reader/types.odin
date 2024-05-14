package reader

///// Error types

Error :: enum {
    none = 0,
    unbalanced_parentheses,
    unbalanced_quotes,
    parse_int_error,
    other_error,
}

///// Tokenizer types

Token :: struct {
    tag: Tag,
    loc: Loc,
}

Tag :: enum {
    NUMBER,
    SYMBOL,
    KEYWORD,
    STRING,

    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_SQUARE,
    RIGHT_SQUARE,
    LEFT_CURLY,
    RIGHT_CURLY,

    QUOTE,
    QUASIQUOTE,
    UNQUOTE,
    SPLICE_UNQUOTE,
    DEREF,

    END,
}

Loc :: struct {
    begin: int,
    end: int,
}

Tokenizer :: struct {
    str: string,
    pos: int,
}

///// Reader types

Atom :: union {
    int,
    string,
    Symbol,
    Keyword,
    Primitives,
}

Symbol :: distinct string
Keyword :: distinct string

Primitives :: enum {
    True,
    False,
    Nil,
}

Ast :: union {
    Atom,
    []Ast,
    Vector,
}

Vector :: distinct []Ast

Reader :: struct {
    using tokenizer: Tokenizer,
    ast: Ast,
}
