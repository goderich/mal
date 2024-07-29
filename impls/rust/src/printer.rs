use itertools::{intersperse, Itertools};

use crate::types::MalType;
use crate::types::MalType::{Bool, Int, List, Nil, Str, Symbol};

pub fn pr_str(input: &MalType, print_readably: bool) -> String {
    match input {
        Nil => "nil".to_string(),
        Int(n) => n.to_string(),
        Bool(b) => b.to_string(),
        Symbol(s) => s.clone(),
        Str(s) => {
            if print_readably {
                print_string_readably(s)
            } else {
                print_string_unreadably(s)
            }
        }
        List(list) => pr_list(list),
    }
}

fn print_string_readably(input: &String) -> String {
    let mut s = String::new();
    s.push('"');
    for c in input.chars() {
        match c {
            '\\' => s.push_str("\\\\"),
            '\n' => s.push_str("\\n"),
            '\"' => s.push_str("\\\""),
            _ => s.push(c),
        }
    }
    s.push('"');
    s
}

fn print_string_unreadably(input: &String) -> String {
    let mut s = String::new();
    s.push('"');
    s.push_str(input);
    s.push('"');
    s
}

// to use .intersperse from itertools
#[allow(unstable_name_collisions)]
fn pr_list(list: &Vec<MalType>) -> String {
    let mut str = String::new();
    str.push('(');
    list.iter()
        .map(|x| pr_str(x, true))
        .intersperse(" ".to_string())
        .for_each(|s: String| str.push_str(&s));
    str.push(')');
    str
}
