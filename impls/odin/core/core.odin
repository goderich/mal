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

    ns["+"] = proc(xs: ..MalType) -> MalType {
        acc := 0
        for x in xs {
            n, ok := x.(int)
            if !ok {
                fmt.printfln("Error...")
                return nil
            }
            acc += n
        }
        return acc
    }

    ns["*"] = proc(xs: ..MalType) -> MalType {
        acc := 1
        for x in xs {
            n := x.(int)
            acc *= n
        }
        return acc
    }

    ns["-"] = proc(xs: ..MalType) -> MalType {
        acc := xs[0].(int)
        rest := xs[1:]
        for x in rest {
            n := x.(int)
            acc -= n
        }
        return acc
    }

    ns["/"] = proc(xs: ..MalType) -> MalType {
        acc := xs[0].(int)
        rest := xs[1:]
        for x in rest {
            n := x.(int)
            acc /= n
        }
        return acc
    }

    ns["list"] = proc(xs: ..MalType) -> MalType {
        list: [dynamic]MalType
        // TODO: no loop needed?
        for x in xs {
            append(&list, x)
        }
        return List(list[:])
    }

    // Right now the function ignores any arguments
    // except the first one. Ideally it should throw an error.
    ns["list?"] = proc(xs: ..MalType) -> MalType {
        _, ok := xs[0].(List)
        return ok
    }

    ns["prn"] = proc(xs: ..MalType) -> MalType {
        list: [dynamic]string
        for x in xs {
            append(&list, reader.pr_str(x))
        }
        fmt.println(strings.join(list[:], " ", allocator = context.temp_allocator))
        return nil
    }

    ns["println"] = proc(xs: ..MalType) -> MalType {
        list: [dynamic]string
        for x in xs {
            append(&list, reader.pr_str(x, print_readably = false))
        }
        fmt.println(strings.join(list[:], " ", allocator = context.temp_allocator))
        return nil
    }

    ns["pr-str"] = proc(xs: ..MalType) -> MalType {
        list: [dynamic]string
        for x in xs {
            append(&list, reader.pr_str(x))
        }
        return strings.join(list[:], " ")
    }

    ns["str"] = proc(xs: ..MalType) -> MalType {
        list: [dynamic]string
        for x in xs {
            append(&list, reader.pr_str(x, print_readably = false))
        }
        return strings.concatenate(list[:])
    }

    ns["read-string"] = proc(xs: ..MalType) -> MalType {
        #partial switch x in xs[0] {
        case string:
            return reader.read_str(x) or_else nil
        }
        return nil
    }

    ns["slurp"] = proc(xs: ..MalType) -> MalType {
        #partial switch x in xs[0] {
        case string:
            buf, ok := os.read_entire_file_from_filename(x)
            if ok {
                return string(buf)
            } else {
                fmt.println("Error: could not read file.")
            }
        }
        return nil
    }

    ns["empty?"] = proc(xs: ..MalType) -> MalType {
        #partial switch x in xs[0] {
        case List:
            return len(x) == 0
        case Vector:
            return len(x) == 0
        }
        return nil
    }

    ns["count"] = proc(xs: ..MalType) -> MalType {
        #partial switch x in xs[0] {
        case List:
            return len(x)
        case Vector:
            return len(x)
        case string:
            return len(x)
        case nil:
            return 0
        }
        return nil
    }

    ns["="] = proc(xs: ..MalType) -> MalType {
        // TODO: make work with more than 2 args
        return is_equal(xs[0], xs[1])
    }

    ns["<"] = proc(xs: ..MalType) -> MalType {
        // TODO: make work with more than 2 args
        x := xs[0].(int)
        y := xs[1].(int)
        return x < y
    }

    ns["<="] = proc(xs: ..MalType) -> MalType {
        // TODO: make work with more than 2 args
        x := xs[0].(int)
        y := xs[1].(int)
        return x <= y
    }

    ns[">"] = proc(xs: ..MalType) -> MalType {
        // TODO: make work with more than 2 args
        x := xs[0].(int)
        y := xs[1].(int)
        return x > y
    }

    ns[">="] = proc(xs: ..MalType) -> MalType {
        // TODO: make work with more than 2 args
        x := xs[0].(int)
        y := xs[1].(int)
        return x >= y
    }

    ns["atom"] = proc(xs: ..MalType) -> MalType {
        return Atom(&xs[0])
    }

    ns["atom?"] = proc(xs: ..MalType) -> MalType {
        _, ok := xs[0].(Atom)
        return ok
    }

    ns["deref"] = proc(xs: ..MalType) -> MalType {
        a := xs[0].(Atom) or_else nil
        return a^
    }

    ns["reset!"] = proc(xs: ..MalType) -> MalType {
        a := xs[0].(Atom) or_else nil
        new_val := xs[1]
        a^ = new_val
        return a^
    }

    ns["swap!"] = proc(xs: ..MalType) -> MalType {
        a := xs[0].(Atom) or_else nil
        f := xs[1]

        // Extract the function arguments
        args: [dynamic]MalType
        defer delete(args)
        append(&args, a^)
        append(&args, ..xs[2:])

        res, ok := types.apply(f, ..args[:])
        a^ = res
        return a^
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
    // TODO: Hash_Map equality?
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
