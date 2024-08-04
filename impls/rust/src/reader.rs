use nom::{
    branch::alt,
    bytes::complete::{is_not, tag, take_while1},
    character::complete::{char, i64, one_of},
    combinator::{cut, map, value},
    multi::{fold_many0, many0},
    sequence::{delimited, preceded, terminated},
    IResult, Parser,
};

use crate::types::MalType;

#[derive(Debug)]
pub struct ReaderError {}

pub fn read_str(s: String) -> Result<MalType, ReaderError> {
    match form_parser(s.trim()) {
        Ok((_, output)) => Ok(output),
        Err(_) => Err(ReaderError {}),
    }
}

fn form_parser(input: &str) -> IResult<&str, MalType> {
    alt((
        preceded(char('('), cut(list_parser)),
        preceded(char('['), cut(vector_parser)),
        quote_parser,
        quasiquote_parser,
        splice_unquote_parser,
        unquote_parser,
        atom_parser,
    ))(input)
}

fn atom_parser(input: &str) -> IResult<&str, MalType> {
    alt((
        nil_parser,
        true_parser,
        false_parser,
        int_parser,
        preceded(char('"'), cut(string_parser)),
        keyword_parser,
        symbol_parser,
    ))(input)
}

fn quote_parser(input: &str) -> IResult<&str, MalType> {
    let (rest, inner) = preceded(char('\''), form_parser).parse(input)?;
    let sym = MalType::Symbol(String::from("quote"));
    Ok((rest, MalType::List(vec![sym, inner])))
}

fn quasiquote_parser(input: &str) -> IResult<&str, MalType> {
    let (rest, inner) = preceded(char('`'), form_parser).parse(input)?;
    let sym = MalType::Symbol(String::from("quasiquote"));
    Ok((rest, MalType::List(vec![sym, inner])))
}

fn unquote_parser(input: &str) -> IResult<&str, MalType> {
    let (rest, inner) = preceded(char('~'), form_parser).parse(input)?;
    let sym = MalType::Symbol(String::from("unquote"));
    Ok((rest, MalType::List(vec![sym, inner])))
}

fn splice_unquote_parser(input: &str) -> IResult<&str, MalType> {
    let (rest, inner) = preceded(tag("~@"), form_parser).parse(input)?;
    let sym = MalType::Symbol(String::from("splice-unquote"));
    Ok((rest, MalType::List(vec![sym, inner])))
}

fn nil_parser(input: &str) -> IResult<&str, MalType> {
    let (rest, _output) = tag("nil")(input)?;
    Ok((rest, MalType::Nil))
}

fn true_parser(input: &str) -> IResult<&str, MalType> {
    let (rest, _output) = tag("true")(input)?;
    Ok((rest, MalType::Bool(true)))
}

fn false_parser(input: &str) -> IResult<&str, MalType> {
    let (rest, _output) = tag("true")(input)?;
    Ok((rest, MalType::Bool(false)))
}

fn symbol_parser(input: &str) -> IResult<&str, MalType> {
    let (rest, output) = symbol_name_parser(input)?;
    Ok((rest, MalType::Symbol(output.to_string())))
}

fn keyword_parser(input: &str) -> IResult<&str, MalType> {
    let (rest, output) = preceded(char(':'), symbol_name_parser).parse(input)?;
    Ok((rest, MalType::Keyword(output.to_string())))
}

fn int_parser(input: &str) -> IResult<&str, MalType> {
    let (rest, num) = i64(input)?;
    Ok((rest, MalType::Int(num)))
}

fn list_parser(input: &str) -> IResult<&str, MalType> {
    let result = terminated(
        preceded(
            many0(whitespace),
            many0(delimited(many0(whitespace), form_parser, many0(whitespace))),
        ),
        char(')'),
    )(input);
    match result {
        Ok((rest, list)) => Ok((rest, MalType::List(list))),
        Err(e) => {
            println!("Error: unbalanced parentheses.");
            Err(e)
        }
    }
}

fn vector_parser(input: &str) -> IResult<&str, MalType> {
    let result = terminated(
        preceded(
            many0(whitespace),
            many0(delimited(many0(whitespace), form_parser, many0(whitespace))),
        ),
        char(']'),
    )(input);
    match result {
        Ok((rest, list)) => Ok((rest, MalType::Vector(list))),
        Err(e) => {
            println!("Error: unbalanced parentheses.");
            Err(e)
        }
    }
}

fn symbol_name_parser(input: &str) -> IResult<&str, &str> {
    take_while1(|c: char| {
        !(c.is_whitespace()
            || c == ','
            || c == '('
            || c == ')'
            || c == '['
            || c == ']'
            || c == '{'
            || c == '}'
            || c == '\\')
    })(input)
}

fn whitespace(input: &str) -> IResult<&str, ()> {
    value((), one_of(" \t\n\r,"))(input)
}

// Strings with escaped chars are quite involved in nom

enum StringParser<'a> {
    StringFragment(&'a str),
    EscapedChar(char),
}

fn string_parser(input: &str) -> IResult<&str, MalType> {
    let build_string = fold_many0(
        string_fragment_parser,
        String::new,
        |mut string, fragment| {
            match fragment {
                StringParser::StringFragment(s) => string.push_str(s),
                StringParser::EscapedChar(c) => string.push(c),
            }
            string
        },
    );
    let result = terminated(build_string, char('"')).parse(input);

    match result {
        Ok((rest, s)) => Ok((rest, MalType::Str(s))),
        Err(e) => {
            println!("Error: unbalanced quotes.");
            Err(e)
        }
    }
}

fn string_fragment_parser(input: &str) -> IResult<&str, StringParser> {
    alt((
        map(is_not("\"\\"), StringParser::StringFragment),
        map(escaped_char_parser, StringParser::EscapedChar),
    ))
    .parse(input)
}

fn escaped_char_parser(input: &str) -> IResult<&str, char> {
    preceded(
        char('\\'),
        alt((
            value('\n', char('n')),
            value('"', char('"')),
            value('\\', char('\\')),
        )),
    )
    .parse(input)
}
