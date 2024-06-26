package lib

// Helper functions that don't belong in a specific system

import "../types"

MalType :: types.MalType
List :: types.List
Vector :: types.Vector
Symbol :: types.Symbol
Keyword :: types.Keyword
Hash_Map :: types.Hash_Map
Nil :: types.Nil
Core_Fn :: types.Core_Fn
Fn :: types.Fn

unpack_seq :: proc(seq: MalType) -> (arr: []MalType, ok: bool) {
    #partial switch type in seq {
    case List:
        return cast([]MalType)type, true
    case Vector:
        return cast([]MalType)type, true
    }
    return nil, false
}
