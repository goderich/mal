package lib

// Helper functions that don't belong in a specific system

import "../types"

MalType :: types.MalType
List :: types.List
Vector :: types.Vector
Symbol :: types.Symbol
Keyword :: types.Keyword
Hash_Map :: types.Hash_Map
Core_Fn :: types.Core_Fn
Closure :: types.Closure

unpack_seq :: proc(seq: MalType) -> (arr: []MalType, ok: bool) {
    #partial switch type in seq {
    case List:
        return cast([]MalType)type, true
    case Vector:
        return cast([]MalType)type, true
    }
    return nil, false
}

concat :: proc(xs: ..MalType) -> [dynamic]MalType {
    arr: [dynamic]MalType
    for x in xs {
        append(&arr, x)
    }
    return arr
}

copy_map :: proc(m: Hash_Map) -> Hash_Map {
    res := new(Hash_Map)
    for k, v in m {
        res[k] = v
    }
    return res^
}
