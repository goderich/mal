package reader

///// Tokenizer types

Token :: struct {
    tag: Tag,
    loc: Loc,
}

Tag :: enum {
    number,
    symbol,
    keyword,
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
}

Symbol :: distinct string
Keyword :: distinct string

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
