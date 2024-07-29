use nom::branch::alt;
use nom::bytes::complete::{is_not, tag, take_while1};
use nom::character::complete::i64;
use nom::character::complete::{char, one_of};
use nom::combinator::{map, value};
use nom::multi::{fold_many0, many0};
use nom::sequence::{delimited, preceded};
use nom::{IResult, Parser};

use crate::types::MalType;

#[derive(Debug)]
pub struct ReaderError {
    message: String,
}

pub fn read_str(s: String) -> Result<MalType, ReaderError> {
    match form_parser(s.trim()) {
        Ok((_, output)) => Ok(output),
        Err(_) => Err(ReaderError {
            message: String::from("Reader Error!"),
        }),
    }
}

fn form_parser(input: &str) -> IResult<&str, MalType> {
    alt((list_parser, atom_parser))(input)
}

fn atom_parser(input: &str) -> IResult<&str, MalType> {
    alt((
        nil_parser,
        true_parser,
        false_parser,
        int_parser,
        string_parser,
        symbol_parser,
    ))(input)
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

fn int_parser(input: &str) -> IResult<&str, MalType> {
    let (rest, num) = i64(input)?;
    Ok((rest, MalType::Int(num)))
}

fn list_parser(input: &str) -> IResult<&str, MalType> {
    let (rest, list) = delimited(
        char('('),
        preceded(
            many0(whitespace),
            many0(delimited(many0(whitespace), form_parser, many0(whitespace))),
        ),
        char(')'),
    )(input)?;
    Ok((rest, MalType::List(list)))
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
    let (rest, s) = delimited(char('"'), build_string, char('"')).parse(input)?;
    Ok((rest, MalType::Str(s)))
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

fn whitespace(input: &str) -> IResult<&str, ()> {
    value((), one_of(" \t\n\r,"))(input)
}

#[cfg(test)]
mod reader_tests {
    use super::*;

    #[test]
    fn symbol() {
        match symbol_parser("symbol1, symbol2") {
            Ok((rest, output)) => {
                assert_eq!(rest, ", symbol2");
                assert_eq!(output, MalType::Symbol("symbol1".to_string()));
            }
            Err(e) => panic!("{}", e),
        }
    }

    #[test]
    fn integers() {
        match int_parser("123 456") {
            Ok((rest, output)) => {
                assert_eq!(rest, " 456");
                assert_eq!(output, MalType::Int(123));
            }
            Err(e) => panic!("{}", e),
        }
    }

    #[test]
    fn negative_integers() {
        match int_parser("-123 456") {
            Ok((rest, output)) => {
                assert_eq!(rest, " 456");
                assert_eq!(output, MalType::Int(-123));
            }
            Err(e) => panic!("{}", e),
        }
    }

    #[test]
    fn list() {
        match form_parser("(+ 123 456 789)") {
            Ok((rest, output)) => {
                assert_eq!(rest, "");
                assert_eq!(
                    output,
                    MalType::List(vec![
                        MalType::Symbol(String::from("+")),
                        MalType::Int(123),
                        MalType::Int(456),
                        MalType::Int(789)
                    ])
                );
            }
            Err(e) => panic!("{}", e),
        }
    }

    #[test]
    fn comma_sep_list() {
        match form_parser("(123,456,789)") {
            Ok((rest, output)) => {
                assert_eq!(rest, "");
                assert_eq!(
                    output,
                    MalType::List(vec![
                        MalType::Int(123),
                        MalType::Int(456),
                        MalType::Int(789)
                    ])
                );
            }
            Err(e) => panic!("{}", e),
        }
    }

    #[test]
    fn list_whitespace() {
        match form_parser("(  123     456   789  )  ") {
            Ok((_, output)) => {
                assert_eq!(
                    output,
                    MalType::List(vec![
                        MalType::Int(123),
                        MalType::Int(456),
                        MalType::Int(789)
                    ])
                );
            }
            Err(e) => panic!("{}", e),
        }
    }

    #[test]
    fn nested_lists() {
        match form_parser("(+ 123 (- 456 789))") {
            Ok((_, output)) => {
                assert_eq!(
                    output,
                    MalType::List(vec![
                        MalType::Symbol(String::from("+")),
                        MalType::Int(123),
                        MalType::List(vec![
                            MalType::Symbol(String::from("-")),
                            MalType::Int(456),
                            MalType::Int(789)
                        ])
                    ])
                );
            }
            Err(e) => panic!("{}", e),
        }
    }

    #[test]
    fn empty_lists_no_space() {
        match form_parser("(()())") {
            Ok((_, output)) => {
                assert_eq!(
                    output,
                    MalType::List(vec![MalType::List(vec![]), MalType::List(vec![])])
                );
            }
            Err(_) => panic!("Test error."),
        }
    }
}
