package reader

///// Error types

Error :: enum {
    none = 0,
    unbalanced_parentheses,
    parse_int_error,
}

///// Tokenizer types

Token :: struct {
    tag: Tag,
    loc: Loc,
}

Tag :: enum {
    number,
    symbol,
    keyword,

    NIL,
    TRUE,
    FALSE,

    left_paren,
    right_paren,
    left_square,
    right_square,
    left_curly,
    right_curly,

    end,
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
