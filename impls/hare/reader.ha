use ascii;
use strings;
use strings::{iterator};
use fmt; // testing only

// TOKENIZER

type token = struct {
	tag: tag,
	loc: loc,
};

type tag = enum {
	NUMBER,
	SYMBOL,
	// KEYWORD,
	LEFT_PAREN,
	RIGHT_PAREN,

	END,
};

type loc = struct {
	begin: iterator,
	end: iterator,
};

fn next_token(iter: iterator) token = {
	let rn = match (strings::next(&iter)) {
        case done =>
		return token { tag = tag::END, ... };
        case let rn: rune =>
		yield rn;
	};

	if (ascii::isspace(rn)) {
		for (let c => strings::next(&iter)) {
			if (!ascii::isspace(c)) {
                                rn = c;
				break;
			};
		};
	};
	// TODO: need to check for 'done' again
        
	switch (rn) {
	case '(' =>
		return token { tag = tag::LEFT_PAREN, ... };
	case ')' =>
		return token { tag = tag::RIGHT_PAREN, ... };
        case =>
		yield;
	};

	if (ascii::isdigit(rn)) {
		return tokenize_number(iter);
	};

	return tokenize_symbol(iter);
};

fn tokenize_number(iter: iterator) token = {
        strings::prev(&iter);
        let begin = iter;
	for (let rn => strings::next(&iter)) {
                if (!ascii::isdigit(rn)) {
			break;
		};
	};
        strings::prev(&iter); // rewind
	return token { tag = tag::NUMBER,
	loc = loc { begin = begin, end = iter } };
};

fn tokenize_symbol(iter: iterator) token = {
        strings::prev(&iter); // rewind
        let begin = iter;
	for (let rn => strings::next(&iter)) {
                if (ascii::isspace(rn) || rn == '(' || rn == ')') {
			break;
		};
	};
        strings::prev(&iter); // rewind
	return token { tag = tag::SYMBOL,
	loc = loc { begin = begin, end = iter } };
};

fn curr_char(iter: *iterator) rune = {
	return iter.dec.src[iter.dec.offs]: rune;
};

// READER

// fn read_str(s: str) ast = {
// 	const t = &strings::iter(s);
// 	return read_form(t);
// };

// fn read_form(iter: *iterator) ast = {
//         const token = next_token(iter);
// 	switch (token.tag) {
//         case tag::END =>
// 		return [];
//         case =>
// 		return read_atom(iter, token);
// 	};
// };

// fn read_atom(iter: *iterator, t: token) *atom = {

// 	switch (token.tag) {
// 	case tag::NUMBER =>

// 	};
// };

// fn read_list() []ast = {};

// TYPES
type symbol = str;
type atom = (int | symbol);
type ast = (*atom | []ast);

// TESTS
// Step 0: tokenizer test
@test fn test_tokenizer() void = {
	const s = "   123  ";
        const iter = strings::iter(s);
	const tok = next_token(iter);
	assert(tok.tag == tag::NUMBER);
        const slice = strings::slice(&tok.loc.begin, &tok.loc.end);
	assert(slice == "123", fmt::asprintf("slice = '{}'", slice));
};

@test fn test_tokenizer_2() void = {
	const s = "123  ";
        const iter = &strings::iter(s);
	assert(curr_char(iter) == '1');
};

// Step 1: a single int "42"
// Step 2: a simple list "(1 2 4)"
// Step 3: a nested list "(1 13 (24 47) 8)"
// Step 4: nested lists with symbols
// Step 5: wrong syntax, errors
// const s5a = "(+ 13 ";
// const s5b = ")";
// empty string ""
