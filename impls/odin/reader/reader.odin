package reader

import "core:fmt"
import "core:unicode/utf8"
import "core:strings"
import "core:strconv"

import "../types"

EOF :: utf8.RUNE_EOF

////////////////////
// TOKENIZER
////////////////////

next_token :: proc(tokenizer: ^Tokenizer) -> (t: Token) {
    eofp := tokenizer_skip_whitespace(tokenizer)
    for !eofp && rune(tokenizer.str[tokenizer.pos]) == ';' {
        eofp = tokenizer_skip_comment(tokenizer)
    }
    if eofp {
        t.tag = Tag.END
        return t
    }

    switch rune(tokenizer.str[tokenizer.pos]) {
    case '(', ')', '[', ']', '{', '}':
        t = tokenize_brace(tokenizer)
    case '0'..='9':
        t = tokenize(tokenizer, Tag.NUMBER)
    case '-':
        t = tokenize_minus(tokenizer)
    case ':':
        t = tokenize(tokenizer, Tag.KEYWORD)
    case '"':
        t = tokenize_string(tokenizer)
    case '\'', '`', '~', '@', '^':
        t = tokenize_quote(tokenizer)
    case:
        t = tokenize(tokenizer, Tag.SYMBOL)
    }
    return t
}

tokenizer_skip_whitespace :: proc(tokenizer: ^Tokenizer) -> (eofp: bool) {
    for {
        if tokenizer.pos >= len(tokenizer.str) {
            return true
        }
        if tokenizer_on_whitespace(tokenizer) {
            tokenizer.pos += 1
        } else {
            break
        }
    }
    return false
}

get_char :: proc(tokenizer: ^Tokenizer) -> rune {
    if tokenizer.pos < len(tokenizer.str) {
        return rune(tokenizer.str[tokenizer.pos])
    }
    else {
        return EOF
    }
}

next_char :: proc(tokenizer: ^Tokenizer) -> rune {
    tokenizer.pos += 1
    return get_char(tokenizer)
}

tokenize :: proc(tokenizer: ^Tokenizer, tag: Tag) -> Token {
    begin := tokenizer.pos
    for {
        if tokenizer_not_on_atom(tokenizer) do break
        tokenizer.pos += 1
        continue
    }
    end := tokenizer.pos - 1
    return Token{ tag, Loc{ begin, end } }
}

tokenize_brace :: proc(tokenizer: ^Tokenizer) -> (t: Token) {
    loc := Loc{tokenizer.pos, tokenizer.pos}

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
    tokenizer.pos += 1
    return t
}

// A minus could begin a negative number or a symbol.
// Look ahead to the next character to decide how to tokenize it.
tokenize_minus :: proc(tokenizer: ^Tokenizer) -> (t: Token) {
    snd := next_char(tokenizer)
    tokenizer.pos -= 1
    switch snd {
    case '0'..='9':
        t = tokenize(tokenizer, Tag.NUMBER)
    case:
        t = tokenize(tokenizer, Tag.SYMBOL)
    }
    return t
}

tokenize_number :: proc(tokenizer: ^Tokenizer) -> Token {
    begin := tokenizer.pos

    for {
        switch next_char(tokenizer) {
        case '0'..='9':
            continue
        }
        break
    }
    end := tokenizer.pos - 1
    return Token{ Tag.NUMBER, Loc{begin, end} }
}

tokenize_string :: proc(tokenizer: ^Tokenizer) -> Token {
    begin := tokenizer.pos

    loop: for {
        switch next_char(tokenizer) {
        case '\\':
            tokenizer.pos += 1
        case EOF:
            tokenizer.pos -= 1
            break loop
        case '"':
            break loop
        }
    }
    end := tokenizer.pos
    tokenizer.pos += 1
    return Token{ Tag.STRING, Loc{begin, end} }
}

tokenize_quote :: proc(tokenizer: ^Tokenizer) -> Token {
    begin := tokenizer.pos
    tag: Tag
    switch get_char(tokenizer) {
    case '\'':
        tag = .QUOTE
    case '`':
        tag = .QUASIQUOTE
    case '~':
        if next_char(tokenizer) == '@' {
            tag = .SPLICE_UNQUOTE
        } else {
            tag = .UNQUOTE
            tokenizer.pos -= 1
        }
    case '@':
        tag = .DEREF
    case '^':
        tag = .META
    }
    tokenizer.pos += 1
    return Token{ tag, Loc{ begin, tokenizer.pos - 1 }}
}

tokenizer_not_on_atom :: proc(tokenizer: ^Tokenizer, offset := 0) -> bool {
    tokenizer.pos += offset
    return tokenizer_on_eof(tokenizer) ||
           tokenizer_on_whitespace(tokenizer) ||
           tokenizer_on_brace(tokenizer) ||
           tokenizer_on_semicolon(tokenizer)
}

tokenizer_on_eof :: proc(tokenizer: ^Tokenizer) -> bool {
    return tokenizer.pos >= len(tokenizer.str)
}

tokenizer_on_brace :: proc(tokenizer: ^Tokenizer) -> bool {
    switch rune(tokenizer.str[tokenizer.pos]) {
    case '(', ')', '[', ']', '{', '}':
        return true
    }
    return false
}

tokenizer_on_whitespace :: proc(tokenizer: ^Tokenizer) -> bool {
    switch rune(tokenizer.str[tokenizer.pos]) {
    case ' ', ',', '\t', '\n', '\r':
        return true
    }
    return false
}

tokenizer_on_semicolon :: proc(tokenizer: ^Tokenizer) -> bool {
    return rune(tokenizer.str[tokenizer.pos]) == ';'
}

tokenizer_skip_comment :: proc(tokenizer: ^Tokenizer) -> (eofp: bool) {
    for {
        switch next_char(tokenizer) {
        case EOF:
            return true
        case '\n':
            return tokenizer_skip_whitespace(tokenizer)
        }
    }
}

////////////////////
// READER
////////////////////

read_str :: proc(str: string) -> (MalType, bool) {
    r := reader_create(str)
    defer free(&r)
    return read_form(&r)
}

reader_create :: proc(str: string) -> Reader {
    t := Tokenizer{str = str, pos = 0}
    return Reader{tokenizer = t, ast = nil}
}

read_form :: proc(reader: ^Reader) -> (ast: MalType, ok: bool) {
    token := next_token(&reader.tokenizer)
    return read_token(reader, token)
}

read_token :: proc(reader: ^Reader, t: Token) -> (ast: MalType, ok: bool) {
    #partial switch t.tag {
    case .LEFT_PAREN:
        return read_list(reader)
    case .LEFT_SQUARE:
        return read_vector(reader)
    case .LEFT_CURLY:
        return read_hash_map(reader)
    case .QUOTE, .QUASIQUOTE, .UNQUOTE, .SPLICE_UNQUOTE, .DEREF:
        return read_reader_macro(reader, t.tag)
    case .META:
        return read_metadata(reader)
    case:
        return read_atom(reader, t)
    }
}

read_atom :: proc(reader: ^Reader, t: Token) -> (atom: MalType, ok: bool) {
    switch t.tag {
    case .NUMBER:
        s := reader.str[t.loc.begin:t.loc.end + 1]
        return strconv.parse_int(s, 10)
    case .SYMBOL:
        str := string(reader.str[t.loc.begin:t.loc.end + 1])
        switch str {
        case "nil":
            return nil, true
        case "true":
            return true, true
        case "false":
            return false, true
        case:
            return Symbol(strings.clone(str)), true
        }
    case .KEYWORD:
        str := string(reader.str[t.loc.begin + 1:t.loc.end + 1])
        return Keyword(fmt.aprintf("ʞ{:s}", str)), true
    case .STRING:
        return read_string(reader.str[t.loc.begin:t.loc.end + 1])
    case .RIGHT_PAREN, .RIGHT_SQUARE, .RIGHT_CURLY:
        fmt.println("unbalanced parentheses")
        return
    case .LEFT_PAREN, .LEFT_SQUARE, .LEFT_CURLY:
        fmt.println("unbalanced parentheses")
        return
    case .QUOTE, .QUASIQUOTE, .UNQUOTE, .SPLICE_UNQUOTE, .DEREF, .META:
        fmt.println("unexpected reader macro.")
        return
    case .END:
        return nil, true
    }
    return
}

read_list :: proc(reader: ^Reader) -> (res: MalType, ok: bool) {
    list: [dynamic]MalType
    defer delete(list)
    for {
        t := next_token(&reader.tokenizer)

        #partial switch t.tag {
        case .END:
            fmt.println("unbalanced parentheses")
            return
        case .RIGHT_PAREN:
            return types.to_list(list[:]), true
        case .RIGHT_SQUARE, .RIGHT_CURLY:
            fmt.println("unbalanced parentheses")
            return
        case:
            form := read_token(reader, t) or_return
            append(&list, form)
        }
    }
}

read_vector :: proc(reader: ^Reader) -> (res: MalType, ok: bool) {
    list: [dynamic]MalType
    defer delete(list)
    for {
        t := next_token(&reader.tokenizer)

        #partial switch t.tag {
        case .END:
            fmt.println("unbalanced parentheses")
            return
        case .RIGHT_SQUARE:
            return types.to_vector(list[:]), true
        case .RIGHT_PAREN, .RIGHT_CURLY:
            fmt.println("unbalanced parentheses")
            return
        case:
            form := read_token(reader, t) or_return
            append(&list, form)
        }
    }
}

read_hash_map :: proc(reader: ^Reader) -> (res: MalType, ok: bool) {
    m := new(Hash_Map)
    for {
        t := next_token(&reader.tokenizer)
        #partial switch t.tag {
        case .END, .RIGHT_PAREN, .RIGHT_SQUARE:
            fmt.println("unbalanced parentheses")
            return
        case .RIGHT_CURLY:
            return m^, true
        }
        // Because keys are pointers, they have to be
        // allocated on the heap.
        k := new(MalType)
        k^ = read_atom(reader, t) or_return

        t2 := next_token(&reader.tokenizer)
        #partial switch t.tag {
        case .END, .RIGHT_PAREN, .RIGHT_SQUARE, .RIGHT_CURLY:
            fmt.println("unbalanced parentheses")
            return
        }
        v := read_token(reader, t2) or_return

        m.data[k] = v
    }
}

read_string :: proc(s: string) -> (res: MalType, ok: bool) {
    if len(s) < 2 || s[len(s) - 1] != '"' {
        fmt.println("unbalanced quotes")
        return
    }
    sb := strings.builder_make()

    for i := 1; i < len(s) - 1; i += 1 {
        if rune(s[i]) == '\\' {
            if i == len(s) - 2 {
                fmt.println("unbalanced quotes")
                return
            }
            switch rune(s[i+1]) {
            case '\\':
                strings.write_rune(&sb, '\\')
            case 'n':
                strings.write_rune(&sb, '\n')
            case '"':
                strings.write_rune(&sb, '"')
            }
            i += 1
            if i >= len(s) - 1 do break
        } else {
            strings.write_rune(&sb, rune(s[i]))
        }
    }
    return strings.to_string(sb), true
}

read_reader_macro :: proc(reader: ^Reader, t: Tag) -> (ast: List, ok: bool) {
    list: [dynamic]MalType
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
    f := read_form(reader) or_return
    append(&list, Symbol(sym), f)
    return types.to_list(list[:]), true
}

read_metadata :: proc(reader: ^Reader) -> (ast: MalType, ok: bool) {
    list: [dynamic]MalType
    defer delete(list)
    if next_token(&reader.tokenizer).tag != .LEFT_CURLY {
        fmt.println("read metadata error.")
        return
    }
    m := read_hash_map(reader) or_return
    data := read_form(reader) or_return
    sym := Symbol("with-meta")
    append(&list, sym, data, m)
    return types.to_list(list[:]), true
}
