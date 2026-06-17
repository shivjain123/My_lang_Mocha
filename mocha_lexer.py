# ============================================================
# Mocha Language Lexer v0.9
# mocha_lexer.py
#
# Converts raw Mocha source code into a stream of tokens
#
# ============================================================
#
#   ── Token Types ────────────────────────────────────────────
#   Comprehensive token catalog covering:
#     - Literals: INT_LIT, FLOAT_LIT, STR_LIT, BOOL_LIT,
#       COMPLEX_LIT (with 'im' suffix), NULL
#     - Identifiers: IDENTIFIER, CONST_IDENT (SCREAMING_CASE),
#       NATIVE
#     - Keywords: 50+ reserved words (var, function, class,
#       if, while, for, import, try, etc.)
#     - Types: int, vast, float, str, bool, Result, dict, set
#     - Operators: arithmetic, comparison, logical, bitwise,
#       compound assignment (+=, -=, etc.), increment/decrement
#     - Delimiters: (), {}, [], comma, colon, semicolon, dot,
#       hash (#)
#     - Special: ARROW (->), RANGE (..), DOC_COMMENT (~~),
#       EOF
#
#   ── Number Lexing ──────────────────────────────────────────
#   - Integers and floats (3.14, 1E10, 2.5E-3 all valid)
#   - Scientific notation with UPPERCASE E ONLY — lowercase 'e'
#     raises explicit error guiding user to Mocha convention
#     (consistency across codebase; prevents silent misparse)
#   - Underscores for readability (1_000_000 → stored as
#     1000000; validation: underscores only between digits,
#     never leading/trailing/consecutive)
#   - Complex numbers via imaginary suffix: 3im, 2.5im
#     (stored with TokenType.COMPLEX_LIT)
#   - Compile-time error on malformed numbers (e.g. 1.2.3,
#     E with no exponent digits)
#
#   ── String Lexing ──────────────────────────────────────────
#   - Double-quoted literals only ("hello", "line\nbreak")
#   - Escape sequences: \n, \t, \\, \" (others preserved
#     verbatim: \x → stored as \x)
#   - No single-quoted chars ('a') — explicit error directing
#     to strings ("a"); char-literal syntax is foreign to
#     Mocha's vision and confuses intent
#   - Unterminated string → compile error with line/col
#   - Multiline strings via triple quotes ("""...""")
#   - No raw string prefix (r"..."); raw behavior via explicit
#     escape handling in string methods (mocha-string)
#
#   ── Comments ───────────────────────────────────────────────
#   - Single-line: // comment (ignored, not tokenized)
#   - Doc comments: ~~ docstring (tokenized as DOC_COMMENT,
#     passed to docs generator; file-top-level only per spec)
#   - Multiline: """comment""" (ignored, not tokenized)
#   - Nesting not supported (first closing """ ends comment)
#
#   ── Identifiers & Keywords ─────────────────────────────────
#   - Identifiers: alphanumeric + underscore, leading letter
#     or underscore (standard)
#   - CONST_IDENT detection: all uppercase, letters + digits +
#     underscores, at least one letter (signals Tag members,
#     module constants to type checker)
#   - Keyword map: 50+ reserved words mapped at lex time
#     (immutable; no user-defined keywords)
#   - Reserved words case-sensitive (If, CLASS rejected as
#     identifiers — user must use lowercase keywords)
#
#   ── Operators ──────────────────────────────────────────────
#   - Arithmetic: + - * / %
#   - Comparison: < > <= >=
#   - Equality: == !=
#   - Logical: && ||, ! (not compound from & and |)
#   - Bitwise: & | ^ ~ << >>
#   - Compound assignment: += -= *= /=
#   - Increment/decrement: ++ --
#   - Function arrow: ->
#   - Range operator: ..
#   - All two-char operators detected via lookahead (match_char)
#   - No ** operator — scientific notation uses E, exponentiation
#     via fast_pow(base, exp_int) or c_pow(base, exp_float)
#
#   ── Error Reporting ────────────────────────────────────────
#   - MochaLexError class: line/column pinpointing, message +
#     context (e.g. "Single-quoted char literals not supported;
#     use double-quoted strings")
#   - Compile fails fast on syntax error; no error recovery
#   - Unicode non-ASCII characters silently skipped (emoji in
#     comments, etc.); raises error only on non-printable
#     ASCII (ord(ch) < 127 check)
#
#   ── Special Cases ──────────────────────────────────────────
#   - Whitespace: space, tab, CR, LF all consumed; NL bumps
#     line counter, resets column to 1
#   - Position tracking: line, column maintained for all tokens
#     (enables type checker to report errors at exact location)
#   - No automatic semicolon insertion (explicit ; required)
#   - No string interpolation (use .format(...) from mocha-string)
#
# ============================================================

from enum import Enum, auto
from dataclasses import dataclass
from typing import Optional


# ============================================================
# TOKEN TYPES
# ============================================================

class TokenType(Enum):

    # --- Literals ---
    INT_LIT      = auto()   # 42
    FLOAT_LIT    = auto()   # 3.14
    STR_LIT      = auto()   # "hello"
    BOOL_LIT     = auto()   # true / false
    COMPLEX_LIT = auto()
    NULL     = auto()   # null (doubles as Java's null and Java's void)

    # --- Identifiers & Keywords ---
    IDENTIFIER   = auto()   # variable/function/class names
    CONST_IDENT  = auto()   # SCREAMING_CASE constants
    NATIVE = auto()

    # --- Variable / Constant ---
    VAR          = auto()
    CONST        = auto()

    # --- Types ---
    TYPE_INT     = auto()
    TYPE_VAST    = auto()
    TYPE_FLOAT   = auto()
    TYPE_STR     = auto()
    TYPE_BOOL    = auto()
    TYPE_RESULT  = auto()
    TYPE_DICT    = auto()
    TYPE_SET = auto()

    # --- Functions ---
    FUNCTION     = auto()
    RETURN       = auto()
    LAMBDA       = auto()
    ASYNC        = auto()
    AWAIT        = auto()
    DID_LOAD     = auto()
    ARROW        = auto()   # ->

    # --- Classes & Interfaces ---
    CLASS        = auto()
    INTERFACE    = auto()
    EXTENDS      = auto()
    IMPLEMENTS   = auto()
    SHARED       = auto()
    PRIVATE      = auto()
    PROTECTED    = auto()
    THIS         = auto()
    ALLOC        = auto()

    # --- Control Flow ---
    IF           = auto()
    ELSE         = auto()
    MATCH        = auto()
    CASE         = auto()
    DEFAULT      = auto()
    WHEN         = auto()

    # --- Loops ---
    FOR          = auto()
    EACH         = auto()
    WHILE        = auto()
    DO           = auto()
    IN           = auto()
    BREAK        = auto()
    CONTINUE     = auto()

    # --- Imports ---
    IMPORT       = auto()
    FROM         = auto()
    AS           = auto()

    # --- Result ---
    OK           = auto()
    ERROR        = auto()

    # --- Print ---
    PRINT        = auto()
    NEWLINE_ARG  = auto()   # newLine=true
    START_ARG    = auto()   # start (named arg for push)

    # --- Operators ---
    PLUS         = auto()   # +
    MINUS        = auto()   # -
    STAR         = auto()   # *
    SLASH        = auto()   # /
    PERCENT      = auto()   # %
    ASSIGN       = auto()   # =
    EQ           = auto()   # ==
    NEQ          = auto()   # !=
    LT           = auto()   # <
    GT           = auto()   # >
    LTE          = auto()   # <=
    GTE          = auto()   # >=
    AND          = auto()   # &&
    OR           = auto()   # ||
    NOT          = auto()   # !
    RANGE        = auto()   # ..
    #Bitwise
    BIT_AND      = auto()   # &
    BIT_OR       = auto()   # |
    BIT_XOR      = auto()   # ^
    BIT_NOT      = auto()   # ~
    BIT_SHL      = auto()   # 
    BIT_SHR      = auto()   # >>

    # --- Increment / Decrement ---
    PLUS_PLUS    = auto()   # ++
    MINUS_MINUS  = auto()   # --

    # --- Compound Assignment ---
    PLUS_ASSIGN  = auto()   # +=
    MINUS_ASSIGN = auto()   # -=
    STAR_ASSIGN  = auto()   # *=
    SLASH_ASSIGN = auto()   # /=

    # --- Delimiters ---
    LPAREN       = auto()   # (
    RPAREN       = auto()   # )
    LBRACE       = auto()   # {
    RBRACE       = auto()   # }
    LBRACKET     = auto()   # [
    RBRACKET     = auto()   # ]
    COMMA        = auto()   # ,
    COLON        = auto()   # :
    SEMICOLON    = auto()   # ;
    DOT          = auto()   # .
    HASH         = auto()   # #

    # --- Exception Handling ---
    TRY          = auto()
    RESCUE       = auto()
    FAIL         = auto()
    RETHROW      = auto()

    # --- Special ---
    EOF          = auto()
    UNKNOWN      = auto()
    EXTEND       = auto()
    TAG = auto()            # My Enum!
    DOC_COMMENT = auto ()


# ============================================================
# KEYWORD MAP
# ============================================================

KEYWORDS = {
    "var":        TokenType.VAR,
    "const":      TokenType.CONST,
    "function":   TokenType.FUNCTION,
    "return":     TokenType.RETURN,
    "lambda":     TokenType.LAMBDA,
    "async":      TokenType.ASYNC,
    "await":      TokenType.AWAIT,
    "didLoad":   TokenType.DID_LOAD,
    "class":      TokenType.CLASS,
    "interface":  TokenType.INTERFACE,
    "extends":    TokenType.EXTENDS,
    "implements": TokenType.IMPLEMENTS,
    "shared":     TokenType.SHARED,
    "private":    TokenType.PRIVATE,
    "protected":  TokenType.PROTECTED,
    "this":       TokenType.THIS,
    "alloc":        TokenType.ALLOC,
    "if":         TokenType.IF,
    "else":       TokenType.ELSE,
    "match":      TokenType.MATCH,
    "case":       TokenType.CASE,
    "default":    TokenType.DEFAULT,
    "when":       TokenType.WHEN,
    "for":        TokenType.FOR,
    "each":       TokenType.EACH,
    "while":      TokenType.WHILE,
    "do":         TokenType.DO,
    "in":         TokenType.IN,
    "break":      TokenType.BREAK,
    "continue":   TokenType.CONTINUE,
    "import":     TokenType.IMPORT,
    "from":       TokenType.FROM,
    "as":         TokenType.AS,
    "ok":         TokenType.OK,
    "error":      TokenType.ERROR,
    "print":      TokenType.PRINT,
    "true":       TokenType.BOOL_LIT,
    "false":      TokenType.BOOL_LIT,
    "null":       TokenType.NULL,
    "int":        TokenType.TYPE_INT,
    "vast":       TokenType.TYPE_VAST,
    "float":      TokenType.TYPE_FLOAT,
    "str":        TokenType.TYPE_STR,
    "bool":       TokenType.TYPE_BOOL,
    "Result":     TokenType.TYPE_RESULT,
    "newLine":    TokenType.NEWLINE_ARG,
    "start":      TokenType.START_ARG,
    "dict":       TokenType.TYPE_DICT,
    "set":        TokenType.TYPE_SET,
    "extend":     TokenType.EXTEND,
    "native":     TokenType.NATIVE,
    "tag":        TokenType.TAG,
    "try":        TokenType.TRY,
    "rescue":     TokenType.RESCUE,
    "fail":       TokenType.FAIL,
    "rethrow":    TokenType.RETHROW,
}

# ============================================================
# TOKEN
# ============================================================

@dataclass
class Token:
    type:    TokenType
    value:   str
    line:    int
    column:  int

    def __repr__(self):
        return (
            f"Token({self.type.name}, "
            f"{repr(self.value)}, "
            f"line={self.line}, col={self.column})"
        )


# ============================================================
# LEXER ERROR
# ============================================================

class MochaLexError(Exception):
    def __init__(self, message, line, column):
        super().__init__(
            f"MochaLexError at line {line}, col {column}: {message}"
        )
        self.line   = line
        self.column = column


# ============================================================
# LEXER
# ============================================================

class Lexer:

    def __init__(self, source: str):
        self.source  = source
        self.pos     = 0           # current char index
        self.line    = 1
        self.column  = 1
        self.tokens  = []

    # --- Character helpers ---

    def current(self) -> Optional[str]:
        if self.pos < len(self.source):
            return self.source[self.pos]
        return None

    def peek(self, offset=1) -> Optional[str]:
        idx = self.pos + offset
        if idx < len(self.source):
            return self.source[idx]
        return None

    def advance(self) -> str:
        ch = self.source[self.pos]
        self.pos    += 1
        self.column += 1
        if ch == "\n":
            self.line  += 1
            self.column = 1
        return ch

    def match_char(self, expected: str) -> bool:
        """ Consume next char if it matches expected """
        if self.current() == expected:
            self.advance()
            return True
        return False

    # --- Token factory ---

    def make_token(self, type: TokenType, value: str,
                   line: int, column: int) -> Token:
        return Token(type, value, line, column)

    # --- Skip whitespace ---

    def skip_whitespace(self):
        while self.current() in (" ", "\t", "\r", "\n"):
            self.advance()

    # --- Skip comments ---

    def skip_comment(self):
        """ // single line comment """
        while self.current() is not None and self.current() != "\n":
            self.advance()
        
    def lex_doc_comment(self, line, col):
        """ ~~ doc comment — captures rest of line as DOC_COMMENT token """
        # skip leading space if present
        if self.current() == " ":
            self.advance()
        start = self.pos
        while self.current() is not None and self.current() != "\n":
            self.advance()
        text = self.source[start:self.pos]
        return self.make_token(TokenType.DOC_COMMENT, text, line, col)

    def skip_multiline_comment(self):
        """ triple-quote multiline comment: \"\"\"..\"\"\" """
        # already consumed first """
        while self.current() is not None:
            if (self.current() == '"'
                    and self.peek(1) == '"'
                    and self.peek(2) == '"'):
                self.advance()
                self.advance()
                self.advance()
                return
            self.advance()
        raise MochaLexError(
            "Unterminated multiline comment", self.line, self.column
        )

    # --- Lex string literal ---

    def lex_string(self, line, col) -> Token:
        """ Consume "..." string literal """
        result = ""
        while self.current() is not None and self.current() != '"':
            if self.current() == "\n":
                raise MochaLexError(
                    "Unterminated string literal", line, col
                )
            # Basic escape sequences
            if self.current() == "\\":
                self.advance()
                esc = self.advance()
                result += {"n": "\n", "t": "\t", '"': '"',
                           "\\": "\\"}.get(esc, "\\" + esc)
            else:
                result += self.advance()

        if self.current() is None:
            raise MochaLexError("Unterminated string literal", line, col)

        self.advance()  # closing "
        return self.make_token(TokenType.STR_LIT, result, line, col)

    # --- Lex number ---

    def lex_number(self, first: str, line, col) -> Token:
        """ Consume int or float literal """
        num = first
        is_float = False

        while self.current() is not None and (self.current().isdigit() or self._is_valid_underscore()):# pyright: ignore[reportOptionalMemberAccess]
            num += self.advance()

        # Check for float: digit.digit (not ..)
        if (self.current() == "."
                and self.peek() is not None
                and self.peek() != "."
                and self.peek().isdigit()): # pyright: ignore[reportOptionalMemberAccess]
            is_float = True
            num += self.advance()   # consume .
            while self.current() is not None and (self.current().isdigit() or self._is_valid_underscore()): # pyright: ignore[reportOptionalMemberAccess]
                num += self.advance()

        # Check for scientific notation: 1.5E10, 2E-3, 3.14E+6
        # Only uppercase E is accepted — Mocha convention
        # Lowercase e — explicit error guiding user to uppercase E
        if self.current() == 'e':
            raise MochaLexError(
                "Mocha enforces uppercase 'E' for scientific notation (e.g. 1.5E10, not 1.5e10)",
                self.line, self.column
            )

        if self.current() == 'E':
            next_ch = self.peek()
            if next_ch is not None and (next_ch.isdigit() or next_ch in ('+', '-')):
                is_float = True
                num += self.advance()  # consume 'E'
                # consume optional sign
                if self.current() in ('+', '-'):
                    num += self.advance()
                # must have at least one digit after E / E+ / E-
                if self.current() is not None and self.current().isdigit(): # pyright: ignore[reportOptionalMemberAccess]
                    while self.current() is not None and self.current().isdigit(): # pyright: ignore[reportOptionalMemberAccess]
                        num += self.advance()
                else:
                    # E with no digits after — not scientific notation, back off
                    num = num[:-1]
                    self.pos -= 1
                    self.column -= 1
                    is_float = False if '.' not in num else True

        # Strip underscores before storing — they're purely for readability
        num = num.replace("_", "")

        token_type = TokenType.FLOAT_LIT if is_float else TokenType.INT_LIT

        # Check for imaginary suffix: 3im or 3.14im
        if self.current() == 'i' and self.peek() == 'm':
            self.advance()  # consume 'i'
            self.advance()  # consume 'm'
            return self.make_token(TokenType.COMPLEX_LIT, num, line, col)

        return self.make_token(token_type, num, line, col)

    def _is_valid_underscore(self) -> bool:
        """ Underscore is valid only if surrounded by digits on both sides
            (no leading/trailing/consecutive underscores) """
        if self.current() != "_":
            return False
        prev = self.source[self.pos - 1] if self.pos > 0 else ""
        nxt  = self.peek()
        return prev.isdigit() and nxt is not None and nxt.isdigit()

    # --- Lex identifier or keyword ---

    def lex_identifier(self, first: str, line, col) -> Token:
        """ Consume identifier, keyword, or SCREAMING_CASE constant """
        word = first
        while (self.current() is not None
               and (self.current().isalnum() or self.current() == "_")): # pyright: ignore[reportOptionalMemberAccess]
            word += self.advance()

        # Check keywords first
        if word in KEYWORDS:
            return self.make_token(KEYWORDS[word], word, line, col)

        # SCREAMING_CASE check: all uppercase letters, digits, underscores
        # and at least one letter
        if (word == word.upper()
                and any(c.isalpha() for c in word)
                and all(c.isalnum() or c == "_" for c in word)):
            return self.make_token(TokenType.CONST_IDENT, word, line, col)

        return self.make_token(TokenType.IDENTIFIER, word, line, col)

    # --- Main Lexer loop ---

    def tokenise(self) -> list[Token]:

        while True:
            self.skip_whitespace()

            if self.current() is None:
                self.tokens.append(
                    self.make_token(TokenType.EOF, "", self.line, self.column)
                )
                break

            line = self.line
            col  = self.column
            ch   = self.advance()

            # === Single line comment ===
            if ch == "/" and self.current() == "/":
                self.advance()
                self.skip_comment()
                continue
                
            # === Doc comment ===
            if ch == "~" and self.current() == "~":
                self.advance()  # consume second ~
                tok = self.lex_doc_comment(line, col)
                self.tokens.append(tok)
                continue

            # === Multiline comment or string ===
            if ch == '"':
                # Check for triple quote """
                if self.current() == '"' and self.peek() == '"':
                    self.advance()
                    self.advance()
                    self.skip_multiline_comment()
                    continue
                # Otherwise normal string
                self.tokens.append(self.lex_string(line, col))
                continue

            # === Char literal — not supported, guide user to strings ===
            if ch == "'":
                raise MochaLexError(
                    "Single-quoted char literals are not supported; use double-quoted strings e.g. \"a\"",
                    line, col
                )

            # === Numbers ===
            if ch.isdigit():
                self.tokens.append(self.lex_number(ch, line, col))
                continue

            # === Identifiers & Keywords ===
            if ch.isalpha() or ch == "_":
                self.tokens.append(self.lex_identifier(ch, line, col))
                continue

            # === Operators & Delimiters ===

            if ch == "+":
                if self.match_char("+"):
                    self.tokens.append(
                        self.make_token(TokenType.PLUS_PLUS, "++", line, col))
                elif self.match_char("="):
                    self.tokens.append(
                        self.make_token(TokenType.PLUS_ASSIGN, "+=", line, col))
                else:
                    self.tokens.append(
                        self.make_token(TokenType.PLUS, "+", line, col))

            elif ch == "-":
                if self.match_char("-"):
                    self.tokens.append(
                        self.make_token(TokenType.MINUS_MINUS, "--", line, col))
                elif self.match_char("="):
                    self.tokens.append(
                        self.make_token(TokenType.MINUS_ASSIGN, "-=", line, col))
                elif self.match_char(">"):
                    self.tokens.append(
                        self.make_token(TokenType.ARROW, "->", line, col))
                else:
                    self.tokens.append(
                        self.make_token(TokenType.MINUS, "-", line, col))

            elif ch == "*":
                if self.match_char("="):
                    self.tokens.append(
                        self.make_token(TokenType.STAR_ASSIGN, "*=", line, col))
                else:
                    self.tokens.append(
                        self.make_token(TokenType.STAR, "*", line, col))

            elif ch == "/":
                if self.match_char("="):
                    self.tokens.append(
                        self.make_token(TokenType.SLASH_ASSIGN, "/=", line, col))
                else:
                    self.tokens.append(
                        self.make_token(TokenType.SLASH, "/", line, col))

            elif ch == "%":
                self.tokens.append(
                    self.make_token(TokenType.PERCENT, "%", line, col))

            elif ch == "=":
                if self.match_char("="):
                    self.tokens.append(
                        self.make_token(TokenType.EQ, "==", line, col))
                else:
                    self.tokens.append(
                        self.make_token(TokenType.ASSIGN, "=", line, col))

            elif ch == "!":
                if self.match_char("="):
                    self.tokens.append(
                        self.make_token(TokenType.NEQ, "!=", line, col))
                else:
                    self.tokens.append(
                        self.make_token(TokenType.NOT, "!", line, col))

            elif ch == "<":
                if self.match_char("<"):
                    self.tokens.append(
                        self.make_token(TokenType.BIT_SHL, "<<", line, col))
                elif self.match_char("="):
                    self.tokens.append(
                        self.make_token(TokenType.LTE, "<=", line, col))
                else:
                    self.tokens.append(
                        self.make_token(TokenType.LT, "<", line, col))

            elif ch == ">":
                if self.match_char(">"):
                    self.tokens.append(
                        self.make_token(TokenType.BIT_SHR, ">>", line, col))
                elif self.match_char("="):
                    self.tokens.append(
                        self.make_token(TokenType.GTE, ">=", line, col))
                else:
                    self.tokens.append(
                        self.make_token(TokenType.GT, ">", line, col))

            elif ch == "&":
                if self.match_char("&"):
                    self.tokens.append(
                        self.make_token(TokenType.AND, "&&", line, col))
                else:
                    self.tokens.append(
                        self.make_token(TokenType.BIT_AND, "&", line, col))

            elif ch == "|":
                if self.match_char("|"):
                    self.tokens.append(
                        self.make_token(TokenType.OR, "||", line, col))
                else:
                    self.tokens.append(
                        self.make_token(TokenType.BIT_OR, "|", line, col))
            
            elif ch == "^":
                self.tokens.append(
                    self.make_token(TokenType.BIT_XOR, "^", line, col))
            
            elif ch == "~":
                self.tokens.append(
                    self.make_token(TokenType.BIT_NOT, "~", line, col))

            elif ch == ".":
                if self.match_char("."):
                    self.tokens.append(
                        self.make_token(TokenType.RANGE, "..", line, col))
                else:
                    self.tokens.append(
                        self.make_token(TokenType.DOT, ".", line, col))

            elif ch == "(":
                self.tokens.append(
                    self.make_token(TokenType.LPAREN, "(", line, col))
            elif ch == ")":
                self.tokens.append(
                    self.make_token(TokenType.RPAREN, ")", line, col))
            elif ch == "{":
                self.tokens.append(
                    self.make_token(TokenType.LBRACE, "{", line, col))
            elif ch == "}":
                self.tokens.append(
                    self.make_token(TokenType.RBRACE, "}", line, col))
            elif ch == "[":
                self.tokens.append(
                    self.make_token(TokenType.LBRACKET, "[", line, col))
            elif ch == "]":
                self.tokens.append(
                    self.make_token(TokenType.RBRACKET, "]", line, col))
            elif ch == ",":
                self.tokens.append(
                    self.make_token(TokenType.COMMA, ",", line, col))
            elif ch == ":":
                self.tokens.append(
                    self.make_token(TokenType.COLON, ":", line, col))
            elif ch == ";":
                self.tokens.append(
                    self.make_token(TokenType.SEMICOLON, ";", line, col))
            elif ch == "#":
                self.tokens.append(
                    self.make_token(TokenType.HASH, "#", line, col))

            else:
                if ord(ch) > 127:
                    continue  # silently skip unicode chars (emojis in comments etc.)
                raise MochaLexError(
                    f"Unexpected character: '{ch}'", line, col
                )

        return self.tokens