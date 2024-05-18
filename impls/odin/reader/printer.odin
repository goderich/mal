package reader

import "core:fmt"
import "core:strings"

pr_str :: proc(ast: MalType) -> string {
    switch t in ast {
    case int:
        sb := strings.builder_make()
        strings.write_int(&sb, t)
        return strings.to_string(sb)
    case string:
        sb := strings.builder_make()
        strings.write_quoted_string(&sb, t)
        return strings.to_string(sb)
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
        return pr_list(t)
    case Vector:
        return pr_vector(t)
    case Hash_Map:
        return pr_hash_map(t)
    case Fn:
        return "{function}"
    }
    return ""
}

pr_list :: proc(ast: List) -> string {
    sb := strings.builder_make()
    strings.write_byte(&sb, '(')
    write_items(&sb, cast([]MalType)ast)
    strings.write_byte(&sb, ')')
    return strings.to_string(sb)
}

pr_vector :: proc(ast: Vector) -> string {
    sb := strings.builder_make()
    strings.write_byte(&sb, '[')
    write_items(&sb, cast([]MalType)ast)
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
        strings.write_string(&sb, pr_str(k^))
        strings.write_rune(&sb, ' ')
        strings.write_string(&sb, pr_str(v))
        i += 1
    }
    strings.write_byte(&sb, '}')
    return strings.to_string(sb)
}

write_items :: proc(sb: ^strings.Builder, items: []MalType) {
    for elem, i in items {
        strings.write_string(sb, pr_str(elem))
        if i < len(items) - 1 {
            strings.write_byte(sb, ' ')
        }
    }
}
