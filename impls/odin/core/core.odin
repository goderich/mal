package core

import "core:fmt"

import "../types"
import "../reader"

MalType :: types.MalType
List :: types.List
Vector :: types.Vector
Symbol :: types.Symbol
Keyword :: types.Keyword
Hash_Map :: types.Hash_Map
Nil :: types.Nil
Fn :: types.Fn
Closure :: types.Closure

make_ns :: proc() -> (ns: map[Symbol]Fn) {

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
        x := xs[0]
        fmt.println(reader.pr_str(x^))
        return Nil{}
    }

    ns["empty?"] = proc(xs: ..^MalType) -> MalType {
        list := xs[0].(List)
        return len(list) == 0
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

        return equal(x_outer, y_outer)
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

equal :: proc(x_outer, y_outer: MalType) -> bool {
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
        y, ok := y_outer.(List)
        if !ok do return false
        eq_len := len(x) == len(y)
        if !eq_len do return false
        for i in 0..<len(x) {
            if !equal(x[i], y[i]) do return false
        }
        return true
    }
    return false
}