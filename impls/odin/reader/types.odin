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

///// Reader types

MalType :: union {
    int,
    string,
    bool,
    Nil,
    Symbol,
    Keyword,

    List,
    Vector,
    Hash_Map,
}

Symbol :: distinct string
Keyword :: distinct string
Nil :: struct {}

List :: distinct []MalType
Vector :: distinct []MalType
// Odin does not allow MalType to be a key, but a pointer to it works.
Hash_Map :: map[^MalType]MalType

Reader :: struct {
    using tokenizer: Tokenizer,
    ast: MalType,
}
