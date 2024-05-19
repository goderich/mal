package core

import "../types"

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

    return ns
}
