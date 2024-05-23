package core

import "core:fmt"
import "core:strings"

import "../types"
import "../reader"
import "../lib"

MalType :: types.MalType
List :: types.List
Vector :: types.Vector
Symbol :: types.Symbol
Keyword :: types.Keyword
Hash_Map :: types.Hash_Map
Nil :: types.Nil
Core_Fn :: types.Core_Fn
Fn :: types.Fn

make_ns :: proc() -> (ns: map[Symbol]Core_Fn) {

    ns["+"] = proc(xs: ..^MalType) -> MalType {
        acc := 0
        for x in xs {
            n := x^.(int)
            acc += n
        }
        return acc
    }

    ns["*"] = proc(xs: ..^MalType) -> MalType {
        acc := 1
        for x in xs {
            n := x^.(int)
            acc *= n
        }
        return acc
    }

    ns["-"] = proc(xs: ..^MalType) -> MalType {
        acc := xs[0].(int)
        rest := xs[1:]
        for x in rest {
            n := x^.(int)
            acc -= n
        }
        return acc
    }

    ns["/"] = proc(xs: ..^MalType) -> MalType {
        acc := xs[0].(int)
        rest := xs[1:]
        for x in rest {
            n := x^.(int)
            acc /= n
        }
        return acc
    }

    ns["list"] = proc(xs: ..^MalType) -> MalType {
        list: [dynamic]MalType
        for x in xs {
            append(&list, x^)
        }
        return List(list[:])
    }

    // Right now the function ignores any arguments
    // except the first one. Ideally it should throw an error.
    ns["list?"] = proc(xs: ..^MalType) -> MalType {
        x := xs[0]
        _, ok := x.(List)
        return ok
    }

    ns["prn"] = proc(xs: ..^MalType) -> MalType {
        list: [dynamic]string
        for x in xs {
            append(&list, reader.pr_str(x^))
        }
        fmt.println(strings.join(list[:], " ", allocator = context.temp_allocator))
        return Nil{}
    }

    ns["println"] = proc(xs: ..^MalType) -> MalType {
        list: [dynamic]string
        for x in xs {
            append(&list, reader.pr_str(x^, print_readably = false))
        }
        fmt.println(strings.join(list[:], " ", allocator = context.temp_allocator))
        return Nil{}
    }

    ns["pr-str"] = proc(xs: ..^MalType) -> MalType {
        list: [dynamic]string
        for x in xs {
            append(&list, reader.pr_str(x^))
        }
        return strings.join(list[:], " ")
    }

    ns["str"] = proc(xs: ..^MalType) -> MalType {
        list: [dynamic]string
        for x in xs {
            append(&list, reader.pr_str(x^, print_readably = false))
        }
        return strings.concatenate(list[:])
    }

    ns["empty?"] = proc(xs: ..^MalType) -> MalType {
        #partial switch x in xs[0] {
        case List:
            return len(x) == 0
        case Vector:
            return len(x) == 0
        }
        return Nil{}
    }

    ns["count"] = proc(xs: ..^MalType) -> MalType {
        #partial switch x in xs[0] {
        case List:
            return len(x)
        case Vector:
            return len(x)
        case string:
            return len(x)
        case Nil:
            return 0
        }
        return Nil{}
    }

    ns["="] = proc(xs: ..^MalType) -> MalType {
        x_outer := xs[0]^
        y_outer := xs[1]^

        return is_equal(x_outer, y_outer)
    }

    ns["<"] = proc(xs: ..^MalType) -> MalType {
        x := xs[0]^.(int)
        y := xs[1]^.(int)
        return x < y
    }

    ns["<="] = proc(xs: ..^MalType) -> MalType {
        x := xs[0]^.(int)
        y := xs[1]^.(int)
        return x <= y
    }

    ns[">"] = proc(xs: ..^MalType) -> MalType {
        x := xs[0]^.(int)
        y := xs[1]^.(int)
        return x > y
    }

    ns[">="] = proc(xs: ..^MalType) -> MalType {
        x := xs[0]^.(int)
        y := xs[1]^.(int)
        return x >= y
    }

    return ns
}

is_equal :: proc(x_outer, y_outer: MalType) -> bool {
    #partial switch x in x_outer {
    case int:
        y, ok := y_outer.(int)
        return ok && x == y
    case string:
        y, ok := y_outer.(string)
        return ok && x == y
    case bool:
        y, ok := y_outer.(bool)
        return ok && x == y
    case Nil:
        _, ok := y_outer.(Nil)
        return ok
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
