use strings;

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
	begin: uint,
	end: uint,
};

type tokenizer = struct {
	iter: strings::iterator,
	pos: uint,
};

// Borrows string for the duration of the tokenizer
fn new_tokenizer(s: str) tokenizer = tokenizer {
	iter = strings::iter(s),
	pos = 0,
};

fn next_token(t: *tokenizer) token = {
	const rn = match (strings::next(t)) {
        case done =>
		return token { tag = tag::END, ... };
        case let rn: rune =>
		yield rn;
	};

	switch (rn) {
	case '(' =>
		return token { tag = tag::LEFT_PAREN, ... };
	case ')' =>
		return token { tag = tag::RIGHT_PAREN, ... };
        case =>
		yield;
	};

	if (ascii::isdigit(rn)) {
		return tokenize_number(t);
	};
};

fn tokenize_number(t: *tokenizer) token = {};
fn tokenize_symbol(t: *tokenizer) token = {};

// READER

fn read_str(s: str) ast = {
	const t = &new_tokenizer(s);
	return read_form(t);
};

fn read_form(t: *tokenizer) ast = {
	switch (next_token(t).tag) {
        case tag::END =>
	     return;
        case =>
	     return;
	};
};

fn read_atom() atom = {};

fn read_list() []ast = {};

// TYPES
type symbol = str;
type atom = (int | symbol);
type ast = (*atom | []ast);

// TESTS
// Step 1: a single int "42"
// Step 2: a simple list "(1 2 4)"
// Step 3: a nested list "(1 13 (24 47) 8)"
// Step 4: nested lists with symbols
// Step 5: wrong syntax, errors
// const s5a = "(+ 13 ";
// const s5b = ")";
