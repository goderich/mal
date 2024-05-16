package reader

import "core:fmt"
import "core:strings"

pr_str :: proc(ast: Ast) -> string {
    switch t in ast {
    case Atom:
        switch a in t {
        case int:
            sb := strings.builder_make()
            strings.write_int(&sb, a)
            return strings.to_string(sb)
        case string:
            sb := strings.builder_make()
            strings.write_quoted_string(&sb, a)
            return strings.to_string(sb)
        case Symbol:
            return string(a)
        case Keyword:
            s, _ := strings.replace(string(a), "ʞ", ":", 1)
            return string(s)
        case Primitives:
            s, ok := fmt.enum_value_to_string(a)
            return strings.to_lower(s)
        }
    case List:
        return pr_list(t)
    case Vector:
        return pr_vector(t)
    case Hash_Map:
        return pr_hash_map(t)
    }
    return ""
}

pr_list :: proc(ast: List) -> string {
    sb := strings.builder_make()
    strings.write_byte(&sb, '(')
    write_items(&sb, cast([]Ast)ast)
    strings.write_byte(&sb, ')')
    return strings.to_string(sb)
}

pr_vector :: proc(ast: Vector) -> string {
    sb := strings.builder_make()
    strings.write_byte(&sb, '[')
    write_items(&sb, cast([]Ast)ast)
    strings.write_byte(&sb, ']')
    return strings.to_string(sb)
}

pr_hash_map :: proc(m: Hash_Map) -> string {
    sb := strings.builder_make()
    strings.write_byte(&sb, '{')
    i := 0
    for k, v in m {
        if i > 0 {
            strings.write_rune(&sb, ' ')
        }
        strings.write_string(&sb, pr_str(k))
        strings.write_rune(&sb, ' ')
        strings.write_string(&sb, pr_str(v))
        i += 1
    }
    strings.write_byte(&sb, '}')
    return strings.to_string(sb)
}

write_items :: proc(sb: ^strings.Builder, items: []Ast) {
    for elem, i in items {
        strings.write_string(sb, pr_str(elem))
        if i < len(items) - 1 {
            strings.write_byte(sb, ' ')
        }
    }
}
