package mal

import "core:fmt"
import "core:os"

READ :: proc(s: string) -> string {
    return s
}

EVAL :: proc(s: string) -> string {
    return s
}

PRINT :: proc(s: string) -> string {
    return s
}

rep :: proc(s: string) -> string {
    r := READ(s)
    e := EVAL(r)
    p := PRINT(e)
    return p
}

main :: proc() {
    buf: [256]byte
    fmt.println("Welcome to MAL-Odin 0.0.0")

    for {
        fmt.print("user> ")
        n, err := os.read(os.stdin, buf[:])
        if err < 0 {
            // Handle error
            return
        }
        r := rep(string(buf[:n]))
        fmt.println(r)
    }
}
