package reader

///// Error types

Error :: enum {
    none = 0,
    unbalanced_parentheses,
    unbalanced_quotes,
    parse_int_error,
    read_metadata_error,
    unexpected_reader_macro,
    invalid_map_key,
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
    META,

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

///// Reader type

Reader :: struct {
    using tokenizer: Tokenizer,
    ast: MalType,
}

///// Data type aliases
import "../types"

MalType :: types.MalType
List :: types.List
Vector :: types.Vector
Symbol :: types.Symbol
Keyword :: types.Keyword
Hash_Map :: types.Hash_Map
Nil :: types.Nil
