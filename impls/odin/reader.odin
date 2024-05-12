package reader

import "core:fmt"
import "core:unicode/utf8"
import "core:strings"
import "core:strconv"

////////////////////
// TOKENIZER
////////////////////

EOF :: utf8.RUNE_EOF

Token :: struct {
    tag: Tag,
    loc: Loc,
}

Tag :: enum {
    number,
    symbol,
    // keyword,
    left_paren,
    right_paren,
    // left_square,
    // right_square,
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

next_token :: proc(using tokenizer: ^Tokenizer) -> (t: Token) {
    eofp := tokenizer_skip_whitespace(tokenizer)
    if eofp {
        t.tag = Tag.end
        return t
    }

    switch rune(str[pos]) {
    case '(', ')':
        t = tokenize_brace(tokenizer)
    case '0'..='9':
        t = tokenize(tokenizer, Tag.number)
    case:
        t = tokenize(tokenizer, Tag.symbol)
    }
    return t
}

tokenizer_skip_whitespace :: proc(using tokenizer: ^Tokenizer) -> (eofp: bool) {
    t: Token
    for {
        if pos >= len(str) {
            return true
        }
        if tokenizer_on_whitespace(tokenizer) {
            pos += 1
        } else {
            break
        }
    }
    return false
}

tokenizer_get_char :: proc(using tokenizer: ^Tokenizer) -> rune {
    return rune(str[pos]) if pos < len(str) else EOF
}

next_char :: proc(using tokenizer: ^Tokenizer) -> rune {
    pos += 1
    char := rune(str[pos]) if pos < len(str) else EOF
    return char
}

tokenizer_peek :: proc(using tokenizer: ^Tokenizer) -> Token {
    old_pos := pos
    t := next_token(tokenizer)
    pos = old_pos
    return t
}

tokenize :: proc(using tokenizer: ^Tokenizer, tag: Tag) -> Token {
    begin := pos
    for {
        if tokenizer_on_eof(tokenizer) ||
           tokenizer_on_whitespace(tokenizer) ||
           tokenizer_on_brace(tokenizer) {
            break
           }
        pos += 1
        continue
    }
    end := pos - 1
    return Token{ tag, Loc{ begin, end } }
}

tokenize_brace :: proc(using tokenizer: ^Tokenizer) -> Token {
    loc := Loc{pos, pos}

    t: Token
    switch tokenizer_get_char(tokenizer) {
    case '(':
        t = Token{ Tag.left_paren, loc}
    case ')':
        t = Token{ Tag.right_paren, loc}
    }
    pos += 1
    return t
}

tokenize_number :: proc(using tokenizer: ^Tokenizer) -> Token {
    begin := pos

    for {
        switch next_char(tokenizer) {
        case '0'..='9':
            continue
        }
        break
    }
    end := pos - 1
    return Token{ Tag.number, Loc{begin, end} }
}

tokenizer_on_eof :: proc(using tokenizer: ^Tokenizer) -> bool {
    return pos >= len(str)
}

tokenizer_on_brace :: proc(using tokenizer: ^Tokenizer) -> bool {
    switch rune(str[pos]) {
    case '(', ')':
        return true
    }
    return false
}

tokenizer_on_whitespace :: proc(using tokenizer: ^Tokenizer) -> bool {
    switch rune(str[pos]) {
    case ' ', ',', '\t':
        return true
    }
    return false
}

////////////////////
// READER
////////////////////

Atom :: union {
    int,
    string,
}

Ast :: union {
    Atom,
    []Ast,
}

Reader :: struct {
    using tokenizer: Tokenizer,
    ast: Ast,
}

reader_create :: proc(str: string) -> Reader {
    t := Tokenizer{str = str, pos = 0}
    return Reader{tokenizer = t, ast = nil}
}

read_str :: proc(str: string) -> Ast {
    // Instructions:
    // This function will call tokenize and then create a new Reader object instance with the tokens.
    // Then it will call read_form with the Reader instance.
    r := reader_create(str)
    f, ok := read_form(&r)
    return f
}

read_form :: proc(reader: ^Reader) -> (ast: Ast, ok: bool) {
    t := next_token(&reader.tokenizer)
    #partial switch t.tag {
    case Tag.left_paren:
        ast = read_list(reader, t)
    case:
        ast, ok = read_atom(reader, t)
    }
    return ast, ok
}

read_atom :: proc(reader: ^Reader, t: Token) -> (atom: Atom, ok: bool) {
    switch t.tag {
    case .number:
        s := reader.str[t.loc.begin:t.loc.end + 1]
        atom, ok = strconv.parse_int(s, 10)
    case .symbol:
        s := reader.str[t.loc.begin:t.loc.end + 1]
        atom = s
    case .left_paren, .right_paren, .end:
        return nil, false
    }
    return atom, true
}

read_list :: proc(reader: ^Reader, t: Token) -> []Ast {
    until: rune
    #partial switch t.tag {
    case Tag.left_paren:
        until = ')'
    }

    list: [dynamic]Ast
    for {
        using reader.tokenizer
        eofp := tokenizer_skip_whitespace(&reader.tokenizer)
        // TODO: handle eofp

        if rune(str[pos]) == until {
            pos += 1
            return list[:]
        } else {
            f, _ := read_form(reader)
            append(&list, f)
        }
    }
}

main :: proc() {
    s := "(+ 1 (* 4 5) 2 3)"
    // t := Tokenizer{str = s, pos = 0}
    // toc: Token
    // for {
    //     toc := next_token(&t)
    //     if toc.tag == Tag.end do break
    //     fmt.println(toc)
    //     fmt.println("pos =", t.pos)
    // }

    ast := read_str(s)
    fmt.println(ast)
}
