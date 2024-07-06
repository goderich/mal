package reader

import "core:fmt"
import "core:strings"

pr_str :: proc(ast: MalType, print_readably := true) -> string {
    switch t in ast {
    case int:
        sb := strings.builder_make()
        strings.write_int(&sb, t)
        return strings.to_string(sb)
    case string:
        if print_readably {
            sb := strings.builder_make()
            strings.write_quoted_string(&sb, t)
            return strings.to_string(sb)
        } else {
            return t
        }
    case Symbol:
        return string(t)
    case Keyword:
        s, _ := strings.replace(string(t), "ʞ", ":", 1)
        return string(s)
    case Nil:
        return "nil"
    case bool:
        if t {
            return "true"
        } else {
            return "false"
        }
    case List:
        return pr_list(t, print_readably)
    case Vector:
        return pr_vector(t, print_readably)
    case Hash_Map:
        return pr_hash_map(t, print_readably)
    case Core_Fn:
        return "#<function>"
    case Fn:
        return "#<function>"
    case Atom:
        return fmt.aprintf("(atom {:v})", t^)
    }
    return ""
}

pr_list :: proc(ast: List, print_readably: bool) -> string {
    sb := strings.builder_make()
    strings.write_byte(&sb, '(')
    write_items(&sb, cast([]MalType)ast, print_readably)
    strings.write_byte(&sb, ')')
    return strings.to_string(sb)
}

pr_vector :: proc(ast: Vector, print_readably: bool) -> string {
    sb := strings.builder_make()
    strings.write_byte(&sb, '[')
    write_items(&sb, cast([]MalType)ast, print_readably)
    strings.write_byte(&sb, ']')
    return strings.to_string(sb)
}

pr_hash_map :: proc(m: Hash_Map, print_readably: bool) -> string {
    sb := strings.builder_make()
    strings.write_byte(&sb, '{')
    i := 0
    for k, v in m {
        if i > 0 {
            strings.write_rune(&sb, ' ')
        }
        strings.write_string(&sb, pr_str(k^, print_readably))
        strings.write_rune(&sb, ' ')
        strings.write_string(&sb, pr_str(v, print_readably))
        i += 1
    }
    strings.write_byte(&sb, '}')
    return strings.to_string(sb)
}

write_items :: proc(sb: ^strings.Builder, items: []MalType, print_readably: bool) {
    for elem, i in items {
        strings.write_string(sb, pr_str(elem, print_readably))
        if i < len(items) - 1 {
            strings.write_byte(sb, ' ')
        }
    }
}
