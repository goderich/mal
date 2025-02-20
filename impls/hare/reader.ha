use ascii;
use strconv;
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
	begin: size,
	end: size,
};

fn next_token(iter: *iterator) token = {
        // Check if we are at the end of input
	let rn = match (strings::next(iter)) {
        case done =>
		return token { tag = tag::END, ... };
        case let rn: rune =>
		yield rn;
	};

        // Skip whitespace
	if (ascii::isspace(rn)) {
		for (let c => strings::next(iter)) {
			if (!ascii::isspace(c)) {
                                rn = c;
				break;
			};
		};
	};

	// Check for end of input again before matching
        if (iter.dec.offs > len(iter.dec.src)) {
		return token { tag = tag::END, ... };
	} else if (rn == '(') {
		return token { tag = tag::LEFT_PAREN, ... };
	} else if (rn == ')') {
		return token { tag = tag::RIGHT_PAREN, ... };
	} else if (ascii::isdigit(rn)) {
		return tokenize_number(iter);
	} else {
		return tokenize_symbol(iter);
	};
};

fn tokenize_number(iter: *iterator) token = {
        let begin = iter.dec.offs - 1;
	for (let rn => strings::next(iter)) {
                if (!ascii::isdigit(rn)) {
			break;
		};
	};
        strings::prev(iter); // rewind
	return token { tag = tag::NUMBER,
	loc = loc { begin = begin, end = iter.dec.offs } };
};

fn tokenize_symbol(iter: *iterator) token = {
        let begin = iter.dec.offs - 1;
	for (let rn => strings::next(iter)) {
                if (ascii::isspace(rn) || rn == '(' || rn == ')') {
			break;
		};
	};
        strings::prev(iter); // rewind
	return token { tag = tag::SYMBOL,
	loc = loc { begin = begin, end = iter.dec.offs } };
};

// READER

fn read_str(s: str) ast = {
        // Initialize iterator
	const iter = strings::iter(s);
        // Read first token
        const token = next_token(&iter);
	return read_form(&iter, token);
};

fn read_form(iter: *iterator, t: token) ast = {
	switch (t.tag) {
        case tag::END =>
		return [];
        case tag::LEFT_PAREN =>
		return read_list(iter);
        case =>
		return read_atom(iter, t);
	};
};

fn read_atom(iter: *iterator, t: token) *atom = {
        const slice = iter.dec.src[t.loc.begin..t.loc.end];
        const substr = strings::fromutf8_unsafe(slice);
	switch (t.tag) {
	case tag::NUMBER =>
                const num = strconv::stoi(substr)!;
		return alloc(num: atom);
        // TODO: stub
        case =>
                const sym = substr: symbol;
		return alloc(sym: atom);
	};
};

// Heap-allocated list, need to free recursively?
fn read_list(iter: *iterator) list = {
	let list: []ast = [];
	for (true) {
        let token = next_token(iter);
        
	switch (token.tag) {
        // TODO: need to raise error on END
        case tag::RIGHT_PAREN =>
		return list;
	case =>
		const elem = read_form(iter, token);
		append(list, elem);
	};
	};
};

// TESTS

// Step 1: a single int "42"
@test fn test_read_int() void = {
	const s = "  42 ";
	const result = read_str(s) as *atom;
	assert(*result == 42);
	free(result);
};

@test fn test_read_sym() void = {
	const s = "  xyz ";
        const sym: symbol = "xyz";
	const result = read_str(s) as *atom;
	assert(*result: symbol == sym);
	free(result);
};

// Step 2: a simple list "(1 23 4)"
@test fn test_read_list() void = {
	const s = "(1 23 4)";
	const result = read_str(s) as []ast;
	assert(len(result) == 3);
        assert(*(result[0]: *atom) == 1);
	assert(*(result[1]: *atom) == 23);
	assert(*(result[2]: *atom) == 4);
};

// Step 3: a nested list "(1 13 (24 47) 8)"
@test fn test_nested_list() void = {
	const s = "(1 13 (24 47) 8)";
	const result = read_str(s) as []ast;
	assert(len(result) == 4);
        assert(*(result[3]: *atom) == 8);
        const inner = result[2] as []ast;
        assert(*(inner[1]: *atom) == 47);
};

// Step 4: nested lists with symbols
// Step 5: wrong syntax, errors
// const s5a = "(+ 13 ";
// const s5b = ")";
// empty string ""
