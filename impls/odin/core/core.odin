package core

import "core:fmt"
import "core:strings"
import "core:os"

import "../types"
import "../reader"
import "../lib"

MalType :: types.MalType
List :: types.List
Vector :: types.Vector
Symbol :: types.Symbol
Keyword :: types.Keyword
Hash_Map :: types.Hash_Map
Core_Fn :: types.Core_Fn
Closure :: types.Closure
Atom :: types.Atom

make_ns :: proc() -> (ns: map[Symbol]Core_Fn) {

    // Equality and predicates

    ns["="] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        // TODO: make work with more than 2 args
        return is_equal(xs[0], xs[1]), true
    }

    ns["nil?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        return xs[0] == nil, true
    }

    ns["true?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        bl, is_bl := xs[0].(bool)
        return is_bl && bl, true
    }

    ns["false?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        bl, is_bl := xs[0].(bool)
        return is_bl && !bl, true
    }

    ns["symbol"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        str, is_str := xs[0].(string)
        if !is_str {
            return string("Argument must be a string."), false
        }
        return Symbol(strings.clone(str)), true
    }

    ns["symbol?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        _, is_sym := xs[0].(Symbol)
        return is_sym, true
    }

    ns["keyword"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        str, is_str := xs[0].(string)
        if !is_str {
            return string("Argument must be a string."), false
        }
        return Keyword(fmt.aprintf("ʞ{:s}", str)), true
    }

    ns["keyword?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        _, is_kw := xs[0].(Keyword)
        return is_kw, true
    }

    // Printing and reading

    ns["prn"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        list: [dynamic]string
        for x in xs {
            append(&list, reader.pr_str(x))
        }
        fmt.println(strings.join(list[:], " ", allocator = context.temp_allocator))
        return nil, true
    }

    ns["println"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        list: [dynamic]string
        for x in xs {
            append(&list, reader.pr_str(x, print_readably = false))
        }
        fmt.println(strings.join(list[:], " ", allocator = context.temp_allocator))
        return nil, true
    }

    ns["pr-str"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        list: [dynamic]string
        for x in xs {
            append(&list, reader.pr_str(x))
        }
        return strings.join(list[:], " "), true
    }

    ns["str"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        list: [dynamic]string
        for x in xs {
            append(&list, reader.pr_str(x, print_readably = false))
        }
        return strings.concatenate(list[:]), true
    }

    ns["read-string"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        #partial switch x in xs[0] {
        case string:
            return reader.read_str(x)
        }
        return nil, true
    }

    ns["slurp"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        #partial switch x in xs[0] {
        case string:
            buf, ok := os.read_entire_file_from_filename(x)
            if ok {
                return string(buf), true
            } else {
                fmt.println("Error: could not read file.")
            }
        }
        return nil, false
    }

    // Maths

    ns["+"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        acc := 0
        for x in xs {
            n, ok := x.(int)
            if !ok {
                fmt.printfln("Error...")
                return nil, false
            }
            acc += n
        }
        return acc, true
    }

    ns["*"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        acc := 1
        for x in xs {
            n := x.(int)
            acc *= n
        }
        return acc, true
    }

    ns["-"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        acc := xs[0].(int)
        rest := xs[1:]
        for x in rest {
            n := x.(int)
            acc -= n
        }
        return acc, true
    }

    ns["/"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        acc := xs[0].(int)
        rest := xs[1:]
        for x in rest {
            n := x.(int)
            acc /= n
        }
        return acc, true
    }

    ns["<"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        // TODO: make work with more than 2 args
        x := xs[0].(int)
        y := xs[1].(int)
        return x < y, true
    }

    ns["<="] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        // TODO: make work with more than 2 args
        x := xs[0].(int)
        y := xs[1].(int)
        return x <= y, true
    }

    ns[">"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        // TODO: make work with more than 2 args
        x := xs[0].(int)
        y := xs[1].(int)
        return x > y, true
    }

    ns[">="] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        // TODO: make work with more than 2 args
        x := xs[0].(int)
        y := xs[1].(int)
        return x >= y, true
    }

    // Data structures

    ns["list"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        list: [dynamic]MalType
        append(&list, ..xs)
        return List(list[:]), true
    }

    // Right now the function ignores any arguments
    // except the first one. Ideally it should throw an error.
    ns["list?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        _, is_list := xs[0].(List)
        return is_list, true
    }

    ns["vector"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        list: [dynamic]MalType
        append(&list, ..xs)
        return Vector(list[:]), true
    }

    ns["vector?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        _, is_vec := xs[0].(Vector)
        return is_vec, true
    }

    ns["vector"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        list: [dynamic]MalType
        append(&list, ..xs)
        return Vector(list[:]), true
    }

    ns["hash-map"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        if len(xs) % 2 != 0 {
            return string("Uneven number of arguments."), false
        }

        m := make(Hash_Map)
        for i := 0; i < len(xs); i += 2 {
            insert_in_map(&m, xs[i], xs[i+1])
        }
        return m, true
    }

    ns["map?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        _, is_map := xs[0].(Hash_Map)
        return is_map, true
    }

    ns["assoc"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        // Needs to be odd because the first arg is the map itself.
        if len(xs) % 2 == 0 {
            return string("Uneven number of arguments after the map."), false
        }

        old_map := xs[0].(Hash_Map) or_return
        m := lib.copy_map(old_map)
        for i := 1; i < len(xs); i += 2 {
            insert_in_map(&m, xs[i], xs[i+1])
        }
        return m, true
    }

    ns["dissoc"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        old_map := xs[0].(Hash_Map) or_return
        m := lib.copy_map(old_map)
        for k in xs[1:] {
            k_ptr, in_map := key_in_map(&m, k)
            if in_map {
                delete_key(&m, k_ptr)
            }
        }
        return m, true
    }

    ns["get"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        #partial switch &m in xs[0] {
            case Hash_Map:
            k_ptr, in_map := key_in_map(&m, xs[1])
            if in_map {
                return m[k_ptr], true
            } else {
                return nil, true
            }
            case nil:
            return nil, true
        }
        return string("Invalid type"), false
    }

    ns["contains?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        m := xs[0].(Hash_Map)
        _, in_map := key_in_map(&m, xs[1])
        return in_map, true
    }

    ns["keys"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        acc: [dynamic]MalType
        m := xs[0].(Hash_Map)
        for k in m {
            append(&acc, k^)
        }
        return List(acc[:]), true
    }

    ns["vals"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        acc: [dynamic]MalType
        m := xs[0].(Hash_Map)
        for _, v in m {
            append(&acc, v)
        }
        return List(acc[:]), true
    }

    // Sequences

    ns["sequential?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        #partial switch x in xs[0] {
        case List:
            return true, true
        case Vector:
            return true, true
        }
        return false, true
    }

    ns["empty?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        #partial switch x in xs[0] {
        case List:
            return len(x) == 0, true
        case Vector:
            return len(x) == 0, true
        }
        return nil, false
    }

    ns["count"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        #partial switch x in xs[0] {
        case List:
            return len(x), true
        case Vector:
            return len(x), true
        case string:
            return len(x), true
        case nil:
            return 0, true
        }
        return nil, false
    }

    ns["cons"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        arr: [dynamic]MalType
        append(&arr, xs[0])
        #partial switch t in xs[1] {
            case List:
            append(&arr, ..cast([]MalType)t)
            case Vector:
            append(&arr, ..cast([]MalType)t)
        }
        return List(arr[:]), true
    }

    ns["concat"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        arr: [dynamic]MalType
        for x in xs {
            #partial switch t in x {
                case List:
                append(&arr, ..cast([]MalType)t)
                case Vector:
                append(&arr, ..cast([]MalType)t)
            }
        }
        return List(arr[:]), true
    }

    ns["vec"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        vec: [dynamic]MalType
        #partial switch t in xs[0] {
        case List:
            append(&vec, ..cast([]MalType)t)
        case Vector:
            return t, true
        case:
            fmt.println("Error: incorrect argument passed to function 'vec'.")
            return nil, false
        }
        return Vector(vec[:]), true
    }

    ns["first"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        #partial switch t in xs[0] {
        case List:
            if len(t) > 0 do res = t[0]
        case Vector:
            if len(t) > 0 do res = t[0]
        }
        return res, true
    }

    ns["nth"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        i := xs[1].(int)
        #partial switch t in xs[0] {
        case List:
            if len(t) <= i {
                return string("Out of bounds!"), false
            } else {
                return t[i], true
            }
        case Vector:
            if len(t) <= i {
                return string("Out of bounds!"), false
            } else {
                return t[i], true
            }
        }
        return nil, false
    }

    ns["rest"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        acc: [dynamic]MalType
        #partial switch t in xs[0] {
        case List:
            if len(t) > 0 {
                for el in t[1:] do append(&acc, el)
            }
        case Vector:
            if len(t) > 0 {
                for el in t[1:] do append(&acc, el)
            }
        case nil:
            break
        case:
            return nil, false
        }
        return List(acc[:]), true
    }

    ns["apply"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        fn := xs[0]
        args: [dynamic]MalType

        for i := 1; i < len(xs)-1; i += 1 {
            append(&args, xs[i])
        }
        // Unpack final arg list/vector
        #partial switch list in xs[len(xs)-1] {
            case List:
            append(&args, ..cast([]MalType)list)
            case Vector:
            append(&args, ..cast([]MalType)list)
            case:
            return string("Final argument must be a list or a vector"), false
        }

        return types.apply(fn, ..args[:])
    }

    ns["map"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        fn := xs[0]
        #partial switch list in xs[1] {
            case List:
            return _map(fn, cast([]MalType)list)
            case Vector:
            return _map(fn, cast([]MalType)list)
        }
        return string("Second argument to map must be a list or a vector."), false

        _map :: proc(fn: MalType, args: []MalType) -> (res: MalType, ok: bool) {
            acc: [dynamic]MalType
            for arg in args {
                new_arg := types.apply(fn, arg) or_return
                append(&acc, new_arg)
            }
            return List(acc[:]), true
        }
    }

    // Atoms

    ns["atom"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        return Atom(&xs[0]), true
    }

    ns["atom?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        _, is_atom := xs[0].(Atom)
        return is_atom, true
    }

    ns["deref"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        a := xs[0].(Atom) or_else nil
        return a^, true
    }

    ns["reset!"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        a := xs[0].(Atom) or_else nil
        new_val := xs[1]
        a^ = new_val
        return a^, true
    }

    ns["swap!"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        a := xs[0].(Atom) or_else nil
        f := xs[1]

        // Extract the function arguments
        args: [dynamic]MalType
        defer delete(args)
        append(&args, a^)
        append(&args, ..xs[2:])

        res, ok = types.apply(f, ..args[:])
        a^ = res
        return a^, ok
    }

    // Throw error

    ns["throw"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        return xs[0], false
    }

    return ns
}

is_equal :: proc(x_outer, y_outer: MalType) -> bool {
    #partial switch x in x_outer {
    case nil:
        return y_outer == nil
    case int:
        y, ok := y_outer.(int)
        return ok && x == y
    case string:
        y, ok := y_outer.(string)
        return ok && x == y
    case bool:
        y, ok := y_outer.(bool)
        return ok && x == y
    case Symbol:
        y, ok := y_outer.(Symbol)
        return ok && x == y
    case Keyword:
        y, ok := y_outer.(Keyword)
        return ok && x == y
    case List:
        return is_equal_seqs(x, y_outer)
    case Vector:
        return is_equal_seqs(x, y_outer)
    case Hash_Map:
        y, ok := y_outer.(Hash_Map)
        return ok && is_equal_maps(x, y)
    }
    return false
}

is_equal_seqs :: proc(x_outer, y_outer: MalType) -> bool {
    xs := lib.unpack_seq(x_outer) or_return
    ys := lib.unpack_seq(y_outer) or_return

    if !(len(xs) == len(ys)) do return false

    for i in 0..<len(xs) {
        if !is_equal(xs[i], ys[i]) do return false
    }
    return true
}

is_equal_maps :: proc(m1, m2: Hash_Map) -> bool {
    m2 := m2 // shadowing m2 to pass to key_in_map
    if len(m1) != len(m2) do return false

    for key, val in m1 {
        k_ptr, in_m2 := key_in_map(&m2, key^)
        if !in_m2 do return false
        if !(is_equal(val, m2[k_ptr])) do return false
    }

    return true
}

// Equality test for pointers to MalType values
is_equal_ptrs :: proc(x, y: ^MalType) -> bool {
    return is_equal(x^, y^)
}

key_in_map :: proc(m: ^Hash_Map, key: MalType) -> (k_ptr: ^MalType, ok: bool) {
    for k in m {
        if is_equal(k^, key) do return k, true
    }
    return nil, false
}

// Insert value of a key into a map destructively,
// replacing any existing value
insert_in_map :: proc(m: ^Hash_Map, key: MalType, val: MalType) {
    // Check if key is already in map
    // This needs to be done manually,
    // because Hash_Map currently stores pointers as keys.
    k_ptr, in_map := key_in_map(m, key)

    if in_map {
        m[k_ptr] = val
    } else {
        k := new_clone(key)
        m[k] = val
    }
}
