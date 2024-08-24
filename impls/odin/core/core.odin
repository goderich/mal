package core

import "core:fmt"
import "core:strings"
import "core:slice"
import "core:os"
import "core:unicode/utf8"

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

    ns["string?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        _, is_str := xs[0].(string)
        return is_str, true
    }

    ns["number?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        _, is_int := xs[0].(int)
        return is_int, true
    }

    ns["fn?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        _, is_core := xs[0].(Core_Fn)
        clos, is_closure := xs[0].(Closure)
        return is_core || (is_closure && !clos.is_macro), true
    }

    ns["macro?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        fn, is_closure := xs[0].(Closure)
        return is_closure && fn.is_macro, true
    }

    ns["symbol"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        str, is_str := xs[0].(string)
        if !is_str {
            return raise("argument must be a string.")
        }
        return Symbol(strings.clone(str)), true
    }

    ns["symbol?"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        _, is_sym := xs[0].(Symbol)
        return is_sym, true
    }

    ns["keyword"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        #partial switch arg in xs[0] {
        case string:
            return Keyword(fmt.aprintf("ʞ{:s}", arg)), true
        case Keyword:
            return arg, true
        }
        return raise("Argument must be a string or a keyword.")
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
        free_all(context.temp_allocator)
        return nil, true
    }

    ns["println"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        list: [dynamic]string
        for x in xs {
            append(&list, reader.pr_str(x, print_readably = false))
        }
        fmt.println(strings.join(list[:], " ", allocator = context.temp_allocator))
        free_all(context.temp_allocator)
        return nil, true
    }

    ns["readline"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        x, is_string := xs[0].(string)
        fmt.print(x)

        buf: [256]byte
        n, err := os.read(os.stdin, buf[:])
        if err < 0 {
            return raise("readline error")
        }
        input := strings.clone(string(buf[:n]))
        return strings.trim_right(input, "\n"), true
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
            if !ok do return raise("Not an integer.")
            acc += n
        }
        return acc, true
    }

    ns["*"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        acc := 1
        for x in xs {
            n, ok := x.(int)
            if !ok do return raise("Not an integer.")
            acc *= n
        }
        return acc, true
    }

    ns["-"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        acc := xs[0].(int)
        rest := xs[1:]
        for x in rest {
            n, ok := x.(int)
            if !ok do return raise("Not an integer.")
            acc -= n
        }
        return acc, true
    }

    ns["/"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        acc := xs[0].(int)
        rest := xs[1:]
        for x in rest {
            n, ok := x.(int)
            if !ok do return raise("Not an integer.")
            if n == 0 do return raise("Divide by zero.")
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

    ns["time-ms"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        return raise("not implemented")
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
            return raise("Uneven number of arguments.")
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
            return raise("Uneven number of arguments after the map.")
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
        return raise("Invalid type")
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
            case List, Vector:
            return is_empty(x), true
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
            return raise("Error: incorrect argument passed to function 'vec'.")
        }
        return Vector(vec[:]), true
    }

    ns["first"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        #partial switch t in xs[0] {
        case List:
            if !is_empty(t) do res = t[0]
        case Vector:
            if !is_empty(t) do res = t[0]
        }
        return res, true
    }

    ns["nth"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        i := xs[1].(int)
        seq, is_seq := lib.unpack_seq(xs[0])
        if !is_seq do return raise("Argument must be a sequence.")

        if len(seq) <= i {
            return raise("out of bounds!")
        } else {
            return seq[i], true
        }
    }

    ns["rest"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        acc: [dynamic]MalType
        #partial switch t in xs[0] {
        case List:
            if !is_empty(t) {
                append(&acc, ..cast([]MalType)t[1:])
            }
        case Vector:
            if !is_empty(t) {
                append(&acc, ..cast([]MalType)t[1:])
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
        seq, is_seq := lib.unpack_seq(xs[len(xs)-1])
        if !is_seq do return raise("Final argument must be a list or a vector")
        append(&args, ..seq)

        return types.apply(fn, ..args[:])
    }

    ns["map"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        fn := xs[0]
        seq, is_seq := lib.unpack_seq(xs[1])
        if !is_seq do return raise("Second argument to map must be a list or a vector")
        return _map(fn, seq)

        _map :: proc(fn: MalType, args: []MalType) -> (res: MalType, ok: bool) {
            acc: [dynamic]MalType
            for arg in args {
                new_arg, ok_arg := types.apply(fn, arg)
                if !ok_arg do return new_arg, false
                append(&acc, new_arg)
            }
            return List(acc[:]), true
        }
    }

    ns["conj"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        list: [dynamic]MalType
        #partial switch t in xs[0] {

        case List:
            #reverse for elem in t do append(&list, elem)
            for x in xs[1:] do append(&list, x)
            slice.reverse(list[:])
            return List(list[:]), true

        case Vector:
            append_elems(&list, ..cast([]MalType)t)
            append_elems(&list, ..xs[1:])
            return Vector(list[:]), true
        }

        return raise("incorrect argument. Expected List or Vector")
    }

    ns["seq"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        #partial switch t in xs[0] {
        case List:
            if is_empty(t) do return nil, true
            return t, true
        case Vector:
            if is_empty(t) do return nil, true
            return List(t), true
        case string:
            if is_empty(t) do return nil, true
            // TODO: Not sure if there is a better way
            // to split a string into a list of 1-char strings
            list: [dynamic]MalType
            for c in t {
                append_elem(&list, utf8.runes_to_string([]rune{c}))
            }
            return List(list[:]), true
        case nil:
            return nil, true
        }
        return raise("incorrect argument")
    }

    // Atoms

    ns["with-meta"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        return raise("not implemented")
    }

    ns["meta"] = proc(xs: ..MalType) -> (res: MalType, ok: bool) {
        return raise("not implemented")
    }

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

// Raise an exception
raise :: proc(str: string) -> (MalType, bool) {
    return str, false
}

is_empty :: proc(x: MalType) -> bool {
    #partial switch t in x {
        case List:
        return len(t) == 0
        case Vector:
        return len(t) == 0
        case string:
        return len(t) == 0
    }
    return false
}
