use itertools::{intersperse, Itertools};

use crate::types::MalType::{self, Bool, Int, Keyword, List, Nil, Str, Symbol, Vector};

pub fn pr_str(input: &MalType, print_readably: bool) -> String {
    match input {
        Nil => "nil".to_string(),
        Int(n) => n.to_string(),
        Bool(b) => b.to_string(),
        Symbol(s) => s.clone(),
        Keyword(s) => pr_keyword(s),
        Str(s) => {
            if print_readably {
                pr_string_readably(s)
            } else {
                pr_string_unreadably(s)
            }
        }
        List(list) => pr_list(list),
        Vector(vec) => pr_vector(vec),
    }
}

fn pr_string_readably(input: &String) -> String {
    let mut s = String::new();
    s.push('"');
    for c in input.chars() {
        match c {
            '\\' => s += "\\\\",
            '\n' => s += "\\n",
            '\"' => s += "\\\"",
            _ => s.push(c),
        }
    }
    s.push('"');
    s
}

fn pr_string_unreadably(input: &String) -> String {
    let mut s = String::new();
    s.push('"');
    s += input;
    s.push('"');
    s
}

fn pr_keyword(input: &String) -> String {
    let mut s = String::new();
    s.push(':');
    s += input;
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
        .for_each(|s: String| str += &s);
    str.push(')');
    str
}

#[allow(unstable_name_collisions)]
fn pr_vector(list: &Vec<MalType>) -> String {
    let mut str = String::new();
    str.push('[');
    list.iter()
        .map(|x| pr_str(x, true))
        .intersperse(" ".to_string())
        .for_each(|s: String| str += &s);
    str.push(']');
    str
}
