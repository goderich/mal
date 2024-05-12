package reader

import "core:fmt"
import "core:unicode/utf8"
import "core:strings"
import "core:strconv"

EOF :: utf8.RUNE_EOF

////////////////////
// TOKENIZER
////////////////////

next_token :: proc(using tokenizer: ^Tokenizer) -> (t: Token) {
    eofp := tokenizer_skip_whitespace(tokenizer)
    if eofp {
        t.tag = Tag.end
        return t
    }

    switch rune(str[pos]) {
    case '(', ')', '[', ']', '{', '}':
        t = tokenize_brace(tokenizer)
    case '0'..='9':
        t = tokenize(tokenizer, Tag.number)
    case ':':
        t = tokenize(tokenizer, Tag.keyword)
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
    case '[':
        t = Token{ Tag.left_square, loc}
    case ']':
        t = Token{ Tag.right_square, loc}
    case '{':
        t = Token{ Tag.left_curly, loc}
    case '}':
        t = Token{ Tag.right_curly, loc}
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
    case '(', ')', '[', ']', '{', '}':
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

read_str :: proc(str: string) -> (Ast, Error) {
    r := reader_create(str)
    f, err := read_form(&r)
    return f, err
}

reader_create :: proc(str: string) -> Reader {
    t := Tokenizer{str = str, pos = 0}
    return Reader{tokenizer = t, ast = nil}
}

read_form :: proc(reader: ^Reader) -> (ast: Ast, err: Error) {
    t := next_token(&reader.tokenizer)
    #partial switch t.tag {
    case Tag.left_paren:
        ast, err = read_list(reader)
    case Tag.left_square:
        ast, err = read_vector(reader)
    case:
        ast, err = read_atom(reader, t)
    }
    return ast, err
}

read_atom :: proc(reader: ^Reader, t: Token) -> (atom: Atom, err: Error) {
    switch t.tag {
    case .number:
        s := reader.str[t.loc.begin:t.loc.end + 1]
        ok: bool
        atom, ok = strconv.parse_int(s, 10)
        if !ok do err = .parse_int_error
    case .symbol:
        atom = Symbol(reader.str[t.loc.begin:t.loc.end + 1])
    case .keyword:
        atom = Keyword(reader.str[t.loc.begin:t.loc.end + 1])
    case .right_paren, .right_square, .right_curly:
        return nil, .unbalanced_parentheses
    case .left_paren, .left_square, .left_curly:
        return nil, .unbalanced_parentheses
    case .end:
        return nil, .unbalanced_parentheses
    }
    return atom, err
}

read_list :: proc(reader: ^Reader, until: rune = ')') -> ([]Ast, Error) {
    list: [dynamic]Ast
    for {
        eofp := tokenizer_skip_whitespace(&reader.tokenizer)
        if eofp do return list[:], .unbalanced_parentheses

        using reader.tokenizer
        if rune(str[pos]) == until {
            pos += 1
            return list[:], .none
        } else {
            f, _ := read_form(reader)
            append(&list, f)
        }
    }
}

read_vector :: proc(reader: ^Reader) -> (Vector, Error) {
    list, err := read_list(reader, ']')
    return Vector(list), err
}

// main :: proc() {
//     s := "(+ 1 [* 4 5 :kw] 2 3)"
//     ast := read_str(s)
//     fmt.println(ast)
// }
