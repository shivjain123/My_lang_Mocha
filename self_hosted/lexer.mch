from "./token.mch" import *;
from "./utils.mch" import *;

// ============================================================
// lexer.mch — Mocha Self-Hosted Lexer
// Converts raw Mocha source code into a stream of tokens
// ============================================================


// ============================================================
// LEXER ERROR
// ============================================================

class MochaLexError {
    var message: str;
    var line:    int;
    var col:     int;

    function constructor(msg: str, l: int, c: int) -> null {
        this.message = msg;
        this.line    = l;
        this.col     = c;
    };
};


// ============================================================
// LEXER
// ============================================================

class Lexer {
    var source:  str;
    var pos:     int;
    var line:    int;
    var col:     int;
    var tokens:  Token[];

    function constructor(src: str) -> null {
        this.source = src;
        this.pos    = 0;
        this.line   = 1;
        this.col    = 1;
        this.tokens = [];
    };

    // --------------------------------------------------------
    // Character helpers
    // --------------------------------------------------------

    function current() -> str {
        if (this.pos < this.source.length) {
            return this.source.charAt(this.pos);
        };
        return "\0";
    };

    function peek(offset: int) -> str {
        var idx: int = this.pos + offset;
        if (idx < this.source.length) {
            return this.source.charAt(idx);
        };
        return "\0";
    };

    function advance() -> str {
        var ch: str = this.source.charAt(this.pos);
        this.pos = this.pos + 1;
        this.col = this.col + 1;
        if (ch == "\n") {
            this.line = this.line + 1;
            this.col  = 1;
        };
        return ch;
    };

    function match_char(expected: str) -> bool {
        if (this.current() == expected) {
            this.advance();
            return true;
        };
        return false;
    };

    // --------------------------------------------------------
    // Token factory
    // --------------------------------------------------------

    function make_token(t: TokenType, v: str, l: int, c: int) -> Token {
        return Token(t, v, l, c);
    };

    // --------------------------------------------------------
    // Skip whitespace
    // --------------------------------------------------------

    function skip_whitespace() -> null {
        while (this.current() == " " || this.current() == "\t" ||
               this.current() == "\r" || this.current() == "\n") {
            this.advance();
        };
    };

    // --------------------------------------------------------
    // Skip single line comment
    // --------------------------------------------------------

    function skip_comment() -> null {
        while (this.current() != "\0" && this.current() != "\n") {
            this.advance();
        };
    };

    // --------------------------------------------------------
    // Skip multiline comment  """..."""
    // --------------------------------------------------------

    function skip_multiline_comment() -> null {
        while (this.current() != "\0") {
            if (this.current() == "\"" && this.peek(1) == "\"" && this.peek(2) == "\"") {
                this.advance();
                this.advance();
                this.advance();
                return;
            };
            this.advance();
        };
        mocha_error("MochaLexError: Unterminated multiline comment");
    };

    // --------------------------------------------------------
    // Lex string literal  "..."
    // --------------------------------------------------------

    function lex_string(l: int, c: int) -> Token {
        var result: str = "";
        while (this.current() != "\0" && this.current() != "\"") {
            if (this.current() == "\n") {
                mocha_error("MochaLexError: Unterminated string literal");
                return this.make_token(TokenType.UNKNOWN, "", l, c);
            };
            if (this.current() == "\\") {
                this.advance();
                var esc: str = this.advance();
                if (esc == "n")  { result = result + "\n"; };
                if (esc == "t")  { result = result + "\t"; };
                if (esc == "\"") { result = result + "\""; };
                if (esc == "\\") { result = result + "\\"; };
            } else {
                result = result + this.advance();
            };
        };
        if (this.current() == "\0") {
            mocha_error("MochaLexError: Unterminated string literal");
            return this.make_token(TokenType.UNKNOWN, "", l, c);
        };
        this.advance(); // closing "
        return this.make_token(TokenType.STR_LIT, result, l, c);
    };

    // --------------------------------------------------------
    // Lex number  42  3.14  2.5im
    // --------------------------------------------------------

    function lex_number(first: str, l: int, c: int) -> Token {
        var num: str = first;
        var is_float: bool = false;

        while (this.current() != "\0" && this.current() >= "0" && this.current() <= "9") {
            num = num + this.advance();
        };

        // Float: digit.digit (not ..)
        if (this.current() == "." && this.peek(1) != "." &&
            this.peek(1) >= "0" && this.peek(1) <= "9") {
            is_float = true;
            num = num + this.advance(); // consume .
            while (this.current() != "\0" && this.current() >= "0" && this.current() <= "9") {
                num = num + this.advance();
            };
        };

        // Complex suffix: 3im or 3.14im
        if (this.current() == "i" && this.peek(1) == "m") {
            this.advance();
            this.advance();
            return this.make_token(TokenType.COMPLEX_LIT, num, l, c);
        };

        if (is_float) {
            return this.make_token(TokenType.FLOAT_LIT, num, l, c);
        };
        return this.make_token(TokenType.INT_LIT, num, l, c);
    };

    // --------------------------------------------------------
    // Lex identifier or keyword
    // --------------------------------------------------------

    function lex_identifier(first: str, l: int, c: int) -> Token {
        var word: str = first;
        while (this.current() != "\0" &&
               ((this.current() >= "a" && this.current() <= "z") ||
                (this.current() >= "A" && this.current() <= "Z") ||
                (this.current() >= "0" && this.current() <= "9") ||
                this.current() == "_")) {
            word = word + this.advance();
        };

        // Keywords
        if (word == "var")        { return this.make_token(TokenType.VAR,        word, l, c); };
        if (word == "const")      { return this.make_token(TokenType.CONST,      word, l, c); };
        if (word == "function")   { return this.make_token(TokenType.FUNCTION,   word, l, c); };
        if (word == "return")     { return this.make_token(TokenType.RETURN,     word, l, c); };
        if (word == "lambda")     { return this.make_token(TokenType.LAMBDA,     word, l, c); };
        if (word == "async")      { return this.make_token(TokenType.ASYNC,      word, l, c); };
        if (word == "await")      { return this.make_token(TokenType.AWAIT,      word, l, c); };
        if (word == "didLoad")    { return this.make_token(TokenType.DID_LOAD,   word, l, c); };
        if (word == "class")      { return this.make_token(TokenType.CLASS,      word, l, c); };
        if (word == "interface")  { return this.make_token(TokenType.INTERFACE,  word, l, c); };
        if (word == "extends")    { return this.make_token(TokenType.EXTENDS,    word, l, c); };
        if (word == "implements") { return this.make_token(TokenType.IMPLEMENTS, word, l, c); };
        if (word == "shared")     { return this.make_token(TokenType.SHARED,     word, l, c); };
        if (word == "private")    { return this.make_token(TokenType.PRIVATE,    word, l, c); };
        if (word == "protected")  { return this.make_token(TokenType.PROTECTED,  word, l, c); };
        if (word == "this")       { return this.make_token(TokenType.THIS,       word, l, c); };
        if (word == "alloc")      { return this.make_token(TokenType.ALLOC,      word, l, c); };
        if (word == "if")         { return this.make_token(TokenType.IF,         word, l, c); };
        if (word == "else")       { return this.make_token(TokenType.ELSE,       word, l, c); };
        if (word == "match")      { return this.make_token(TokenType.MATCH,      word, l, c); };
        if (word == "case")       { return this.make_token(TokenType.CASE,       word, l, c); };
        if (word == "default")    { return this.make_token(TokenType.DEFAULT,    word, l, c); };
        if (word == "when")       { return this.make_token(TokenType.WHEN,       word, l, c); };
        if (word == "for")        { return this.make_token(TokenType.FOR,        word, l, c); };
        if (word == "each")       { return this.make_token(TokenType.EACH,       word, l, c); };
        if (word == "while")      { return this.make_token(TokenType.WHILE,      word, l, c); };
        if (word == "do")         { return this.make_token(TokenType.DO,         word, l, c); };
        if (word == "in")         { return this.make_token(TokenType.IN,         word, l, c); };
        if (word == "break")      { return this.make_token(TokenType.BREAK,      word, l, c); };
        if (word == "continue")   { return this.make_token(TokenType.CONTINUE,   word, l, c); };
        if (word == "import")     { return this.make_token(TokenType.IMPORT,     word, l, c); };
        if (word == "from")       { return this.make_token(TokenType.FROM,       word, l, c); };
        if (word == "as")         { return this.make_token(TokenType.AS,         word, l, c); };
        if (word == "ok")         { return this.make_token(TokenType.OK,         word, l, c); };
        if (word == "error")      { return this.make_token(TokenType.ERROR,      word, l, c); };
        if (word == "print")      { return this.make_token(TokenType.PRINT,      word, l, c); };
        if (word == "true")       { return this.make_token(TokenType.BOOL_LIT,   word, l, c); };
        if (word == "false")      { return this.make_token(TokenType.BOOL_LIT,   word, l, c); };
        if (word == "null")       { return this.make_token(TokenType.NULL,       word, l, c); };
        if (word == "int")        { return this.make_token(TokenType.TYPE_INT,   word, l, c); };
        if (word == "vast")       { return this.make_token(TokenType.TYPE_VAST,  word, l, c); };
        if (word == "float")      { return this.make_token(TokenType.TYPE_FLOAT, word, l, c); };
        if (word == "str")        { return this.make_token(TokenType.TYPE_STR,   word, l, c); };
        if (word == "bool")       { return this.make_token(TokenType.TYPE_BOOL,  word, l, c); };
        if (word == "Result")     { return this.make_token(TokenType.TYPE_RESULT,word, l, c); };
        if (word == "newLine")    { return this.make_token(TokenType.NEWLINE_ARG,word, l, c); };
        if (word == "start")      { return this.make_token(TokenType.START_ARG,  word, l, c); };
        if (word == "dict")       { return this.make_token(TokenType.TYPE_DICT,  word, l, c); };
        if (word == "set")        { return this.make_token(TokenType.TYPE_SET,   word, l, c); };
        if (word == "extend")     { return this.make_token(TokenType.EXTEND,     word, l, c); };
        if (word == "native")     { return this.make_token(TokenType.NATIVE,     word, l, c); };
        if (word == "tag")        { return this.make_token(TokenType.TAG,        word, l, c); };

        // SCREAMING_CASE check: all uppercase + digits + underscores, at least one letter
        var is_screaming: bool = true;
        var has_letter:   bool = false;
        var si: int = 0;
        while (si < word.length) {
            var sc: str = word.charAt(si);
            if ((sc >= "a" && sc <= "z")) {
                is_screaming = false;
            };
            if ((sc >= "A" && sc <= "Z")) {
                has_letter = true;
            };
            si = si + 1;
        };
        if (is_screaming && has_letter) {
            return this.make_token(TokenType.CONST_IDENT, word, l, c);
        };

        return this.make_token(TokenType.IDENTIFIER, word, l, c);
    };

    // --------------------------------------------------------
    // Main tokenise loop
    // --------------------------------------------------------

    function tokenise() -> Token[] {
        while (true) {
            this.skip_whitespace();

            if (this.current() == "\0") {
                this.tokens.push(this.make_token(TokenType.EOF, "", this.line, this.col));
                break;
            };

            var l: int  = this.line;
            var c: int  = this.col;
            var ch: str = this.advance();

            // Single line comment
            if (ch == "/" && this.current() == "/") {
                this.advance();
                this.skip_comment();
                continue;
            };

            // String or multiline comment
            if (ch == "\"") {
                if (this.current() == "\"" && this.peek(1) == "\"") {
                    this.advance();
                    this.advance();
                    this.skip_multiline_comment();
                    continue;
                };
                this.tokens.push(this.lex_string(l, c));
                continue;
            };

            // Char literal — not supported
            if (ch == "'") {
                mocha_error("MochaLexError: Single-quoted char literals are not supported; use double-quoted strings");
                continue;
            };

            // Numbers
            if (ch >= "0" && ch <= "9") {
                this.tokens.push(this.lex_number(ch, l, c));
                continue;
            };

            // Identifiers and keywords
            if ((ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") || ch == "_") {
                this.tokens.push(this.lex_identifier(ch, l, c));
                continue;
            };

            // Operators and delimiters
            if (ch == "+") {
                if (this.match_char("+")) { this.tokens.push(this.make_token(TokenType.PLUS_PLUS,   "++", l, c)); }
                else if (this.match_char("=")) { this.tokens.push(this.make_token(TokenType.PLUS_ASSIGN, "+=", l, c)); }
                else { this.tokens.push(this.make_token(TokenType.PLUS, "+", l, c)); };
                continue;
            };
            if (ch == "-") {
                if (this.match_char("-")) { this.tokens.push(this.make_token(TokenType.MINUS_MINUS,  "--", l, c)); }
                else if (this.match_char("=")) { this.tokens.push(this.make_token(TokenType.MINUS_ASSIGN, "-=", l, c)); }
                else if (this.match_char(">")) { this.tokens.push(this.make_token(TokenType.ARROW,        "->", l, c)); }
                else { this.tokens.push(this.make_token(TokenType.MINUS, "-", l, c)); };
                continue;
            };
            if (ch == "*") {
                if (this.match_char("=")) { this.tokens.push(this.make_token(TokenType.STAR_ASSIGN,  "*=", l, c)); }
                else { this.tokens.push(this.make_token(TokenType.STAR, "*", l, c)); };
                continue;
            };
            if (ch == "/") {
                if (this.match_char("=")) { this.tokens.push(this.make_token(TokenType.SLASH_ASSIGN, "/=", l, c)); }
                else { this.tokens.push(this.make_token(TokenType.SLASH, "/", l, c)); };
                continue;
            };
            if (ch == "%") { this.tokens.push(this.make_token(TokenType.PERCENT,   "%",  l, c)); continue; };
            if (ch == "=") {
                if (this.match_char("=")) { this.tokens.push(this.make_token(TokenType.EQ,     "==", l, c)); }
                else { this.tokens.push(this.make_token(TokenType.ASSIGN, "=", l, c)); };
                continue;
            };
            if (ch == "!") {
                if (this.match_char("=")) { this.tokens.push(this.make_token(TokenType.NEQ,    "!=", l, c)); }
                else { this.tokens.push(this.make_token(TokenType.NOT, "!", l, c)); };
                continue;
            };
            if (ch == "<") {
                if (this.match_char("=")) { this.tokens.push(this.make_token(TokenType.LTE,    "<=", l, c)); }
                else { this.tokens.push(this.make_token(TokenType.LT, "<", l, c)); };
                continue;
            };
            if (ch == ">") {
                if (this.match_char("=")) { this.tokens.push(this.make_token(TokenType.GTE,    ">=", l, c)); }
                else { this.tokens.push(this.make_token(TokenType.GT, ">", l, c)); };
                continue;
            };
            if (ch == "&") {
                if (this.match_char("&")) { this.tokens.push(this.make_token(TokenType.AND,    "&&", l, c)); }
                else { mocha_error("MochaLexError: Single '&' is not valid in Mocha. Use '&&'"); };
                continue;
            };
            if (ch == "|") {
                if (this.match_char("|")) { this.tokens.push(this.make_token(TokenType.OR,     "||", l, c)); }
                else { mocha_error("MochaLexError: Single '|' is not valid in Mocha. Use '||'"); };
                continue;
            };
            if (ch == ".") {
                if (this.match_char(".")) { this.tokens.push(this.make_token(TokenType.RANGE,  "..", l, c)); }
                else { this.tokens.push(this.make_token(TokenType.DOT, ".", l, c)); };
                continue;
            };
            if (ch == "(") { this.tokens.push(this.make_token(TokenType.LPAREN,    "(", l, c)); continue; };
            if (ch == ")") { this.tokens.push(this.make_token(TokenType.RPAREN,    ")", l, c)); continue; };
            if (ch == "{") { this.tokens.push(this.make_token(TokenType.LBRACE,    "{", l, c)); continue; };
            if (ch == "}") { this.tokens.push(this.make_token(TokenType.RBRACE,    "}", l, c)); continue; };
            if (ch == "[") { this.tokens.push(this.make_token(TokenType.LBRACKET,  "[", l, c)); continue; };
            if (ch == "]") { this.tokens.push(this.make_token(TokenType.RBRACKET,  "]", l, c)); continue; };
            if (ch == ",") { this.tokens.push(this.make_token(TokenType.COMMA,     ",", l, c)); continue; };
            if (ch == ":") { this.tokens.push(this.make_token(TokenType.COLON,     ":", l, c)); continue; };
            if (ch == ";") { this.tokens.push(this.make_token(TokenType.SEMICOLON, ";", l, c)); continue; };
            if (ch == "#") { this.tokens.push(this.make_token(TokenType.HASH,      "#", l, c)); continue; };

            // Unknown character — skip silently if unicode for superscripts and emojis
            // else emit UNKNOWN
            this.tokens.push(this.make_token(TokenType.UNKNOWN, ch, l, c));
        };
        return this.tokens;
    };
};