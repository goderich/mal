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
    if !eofp && rune(str[pos]) == ';' {
        tokenizer_skip_comment(tokenizer)
    }
    if eofp {
        t.tag = Tag.END
        return t
    }

    switch rune(str[pos]) {
    case '(', ')', '[', ']', '{', '}':
        t = tokenize_brace(tokenizer)
    case '0'..='9':
        t = tokenize(tokenizer, Tag.NUMBER)
    case ':':
        t = tokenize(tokenizer, Tag.KEYWORD)
    case '"':
        t = tokenize_string(tokenizer)
    case '\'', '`', '~', '@':
        t = tokenize_quote(tokenizer)
    case:
        t = tokenize(tokenizer, Tag.SYMBOL)
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

get_char :: proc(using tokenizer: ^Tokenizer) -> rune {
    return rune(str[pos]) if pos < len(str) else EOF
}

next_char :: proc(using tokenizer: ^Tokenizer) -> rune {
    pos += 1
    return get_char(tokenizer)
}

tokenize :: proc(using tokenizer: ^Tokenizer, tag: Tag) -> Token {
    begin := pos
    for {
        if tokenizer_not_on_atom(tokenizer) do break
        pos += 1
        continue
    }
    end := pos - 1
    return Token{ tag, Loc{ begin, end } }
}

tokenize_brace :: proc(using tokenizer: ^Tokenizer) -> Token {
    loc := Loc{pos, pos}

    t: Token
    switch get_char(tokenizer) {
    case '(':
        t = Token{ Tag.LEFT_PAREN, loc}
    case ')':
        t = Token{ Tag.RIGHT_PAREN, loc}
    case '[':
        t = Token{ Tag.LEFT_SQUARE, loc}
    case ']':
        t = Token{ Tag.RIGHT_SQUARE, loc}
    case '{':
        t = Token{ Tag.LEFT_CURLY, loc}
    case '}':
        t = Token{ Tag.RIGHT_CURLY, loc}
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
    return Token{ Tag.NUMBER, Loc{begin, end} }
}

tokenize_string :: proc(using tokenizer: ^Tokenizer) -> Token {
    begin := pos

    loop: for {
        switch next_char(tokenizer) {
        case '\\':
            pos += 1
        case EOF:
            pos -= 1
            break loop
        case '"':
            break loop
        }
    }
    end := pos
    pos += 1
    return Token{ Tag.STRING, Loc{begin, end} }
}

tokenize_quote :: proc(using tokenizer: ^Tokenizer) -> Token {
    begin := pos
    t: Tag
    switch get_char(tokenizer) {
    case '\'':
        t = .QUOTE
    case '`':
        t = .QUASIQUOTE
    case '~':
        if next_char(tokenizer) == '@' {
            t = .SPLICE_UNQUOTE
        } else {
            t = .UNQUOTE
            pos -= 1
        }
    case '@':
        t = .DEREF
    }
    pos += 1
    return Token{ t, Loc{ begin, pos - 1 }}
}

tokenizer_not_on_atom :: proc(tokenizer: ^Tokenizer, offset := 0) -> bool {
    tokenizer.pos += offset
    return tokenizer_on_eof(tokenizer) ||
           tokenizer_on_whitespace(tokenizer) ||
           tokenizer_on_brace(tokenizer) ||
           tokenizer_on_semicolon(tokenizer)
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
    case ' ', ',', '\t', '\n':
        return true
    }
    return false
}

tokenizer_on_semicolon :: proc(using tokenizer: ^Tokenizer) -> bool {
    return rune(str[pos]) == ';'
}

tokenizer_skip_comment :: proc(tokenizer: ^Tokenizer) {
    for {
        switch next_char(tokenizer) {
        case EOF, '\n':
            return
        }
        continue
    }
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
    case Tag.LEFT_PAREN:
        ast, err = read_list(reader)
    case Tag.LEFT_SQUARE:
        ast, err = read_vector(reader)
        case .QUOTE, .QUASIQUOTE, .UNQUOTE, .SPLICE_UNQUOTE, .DEREF:
        ast, err = reader_macro(reader, t.tag)
    case:
        ast, err = read_atom(reader, t)
    }
    return ast, err
}

read_atom :: proc(reader: ^Reader, t: Token) -> (atom: Atom, err: Error) {
    switch t.tag {
    case .NUMBER:
        s := reader.str[t.loc.begin:t.loc.end + 1]
        ok: bool
        atom, ok = strconv.parse_int(strings.trim(s, "\n"), 10)
        if !ok do err = .parse_int_error
    case .SYMBOL:
        sym := reader.str[t.loc.begin:t.loc.end + 1]
        switch sym {
        case "nil":
            atom = Primitives.Nil
        case "true":
            atom = Primitives.True
        case "false":
            atom = Primitives.False
        case:
            atom = Symbol(sym)
        }
    case .KEYWORD:
        ss := [2]string{ "ʞ", reader.str[t.loc.begin + 1:t.loc.end + 1] }
        s := strings.concatenate(ss[:])
        atom = Keyword(s)
    case .STRING:
        if rune(reader.str[t.loc.end]) != '"' {
            return string(""), .unbalanced_quotes
        }
        atom = read_string(reader.str[t.loc.begin + 1:t.loc.end])
    case .RIGHT_PAREN, .RIGHT_SQUARE, .RIGHT_CURLY:
        return nil, .unbalanced_parentheses
    case .LEFT_PAREN, .LEFT_SQUARE, .LEFT_CURLY:
        return nil, .unbalanced_parentheses
    case .QUOTE, .QUASIQUOTE, .UNQUOTE, .SPLICE_UNQUOTE, .DEREF:
        return nil, .other_error
    case .END:
        return nil, .unbalanced_parentheses
    }
    return atom, err
}

read_list :: proc(reader: ^Reader, until: rune = ')') -> (elems: []Ast, err: Error) {
    list: [dynamic]Ast
    for {
        eofp := tokenizer_skip_whitespace(&reader.tokenizer)
        if eofp do return list[:], .unbalanced_parentheses

        using reader.tokenizer
        switch rune(str[pos]) {
        case until:
            pos += 1
            return list[:], .none
        case ']', ')', '}':
            return list[:], .unbalanced_parentheses
        case:
            f := read_form(reader) or_return
            append(&list, f)
        }
    }
}

read_vector :: proc(reader: ^Reader) -> (v: Vector, err: Error) {
    list := read_list(reader, ']') or_return
    return Vector(list), err
}

read_string :: proc(s: string) -> string {
    sb := strings.builder_make()

    for i := 0; i < len(s); i += 1 {
        if rune(s[i]) == '\\' {
            switch rune(s[i+1]) {
            case '\\':
                strings.write_rune(&sb, '\\')
            case 'n':
                strings.write_rune(&sb, '\n')
            case '"':
                strings.write_rune(&sb, '\"')
            }
            i += 1
            if i >= len(s) - 1 do break
        } else {
            strings.write_rune(&sb, rune(s[i]))
        }
    }
    return strings.to_string(sb)
}

reader_macro :: proc(reader: ^Reader, t: Tag) -> (ast: []Ast, err: Error) {
    list: [dynamic]Ast
    f := read_form(reader) or_return
    sym: string
    #partial switch t {
    case .QUOTE:
        sym = "quote"
    case .QUASIQUOTE:
        sym = "quasiquote"
    case .UNQUOTE:
        sym = "unquote"
    case .SPLICE_UNQUOTE:
        sym = "splice-unquote"
    case .DEREF:
        sym = "deref"
    }
    append(&list, Atom(Symbol(sym)), f)
    return list[:], err
}
