package types

MalType :: union {
    // nil is implied in Odin

    int,
    string,
    bool,
    Symbol,
    Keyword,

    List,
    Vector,
    Hash_Map,

    Core_Fn,
    Closure,

    Atom,
}

Symbol :: distinct string
Keyword :: distinct string

List :: distinct []MalType
Vector :: distinct []MalType
// Odin does not allow MalType to be a key, but a pointer to it works.
Hash_Map :: map[^MalType]MalType

Core_Fn :: proc(..MalType) -> (MalType, bool)

Closure :: struct {
    params: [dynamic]Symbol,
    ast: ^MalType,
    env: Env,
    eval: proc(MalType, ^Env) -> (MalType, bool),
    is_macro: bool,
}

Atom :: ^MalType

