package types

MalType :: union {
    int,
    string,
    bool,
    Nil,
    Symbol,
    Keyword,

    List,
    Vector,
    Hash_Map,

    Core_Fn,
    Fn,
}

Symbol :: distinct string
Keyword :: distinct string
Nil :: struct {}

List :: distinct []MalType
Vector :: distinct []MalType
// Odin does not allow MalType to be a key, but a pointer to it works.
Hash_Map :: map[^MalType]MalType

// A similar thing happens with functions,
// but I'm not sure why a pointer is needed here.
Core_Fn :: proc(..^MalType) -> MalType

Fn :: struct {
    params: [dynamic]Symbol,
    ast: ^MalType,
    env: Env,
}
