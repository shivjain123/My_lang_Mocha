// ============================================================
// token.mch — Token types and Token class
// Foundation of Mocha's self-hosted compiler
// ============================================================


// ============================================================
// TOKEN TYPES
// ============================================================

tag TokenType {

    // --- Literals ---
    INT_LIT,
    FLOAT_LIT,
    STR_LIT,
    BOOL_LIT,
    COMPLEX_LIT,
    NULL,

    // --- Identifiers ---
    IDENTIFIER,
    CONST_IDENT,

    // --- Variable / Constant ---
    VAR,
    CONST,

    // --- Types ---
    TYPE_INT,
    TYPE_VAST,
    TYPE_FLOAT,
    TYPE_STR,
    TYPE_BOOL,
    TYPE_RESULT,
    TYPE_DICT,
    TYPE_SET,

    // --- Functions ---
    FUNCTION,
    RETURN,
    LAMBDA,
    ASYNC,
    AWAIT,
    DID_LOAD,
    ARROW,
    NATIVE,

    // --- Classes ---
    CLASS,
    INTERFACE,
    EXTENDS,
    IMPLEMENTS,
    SHARED,
    PRIVATE,
    PROTECTED,
    THIS,
    ALLOC,

    // --- Control Flow ---
    IF,
    ELSE,
    MATCH,
    CASE,
    DEFAULT,
    WHEN,

    // --- Loops ---
    FOR,
    EACH,
    WHILE,
    DO,
    IN,
    BREAK,
    CONTINUE,

    // --- Imports ---
    IMPORT,
    FROM,
    AS,

    // --- Result ---
    OK,
    ERROR,

    // --- Print ---
    PRINT,
    NEWLINE_ARG,
    START_ARG,

    // --- Tags ---
    TAG,

    // --- Extend ---
    EXTEND,

    // --- Operators ---
    PLUS,
    MINUS,
    STAR,
    SLASH,
    PERCENT,
    ASSIGN,
    EQ,
    NEQ,
    LT,
    GT,
    LTE,
    GTE,
    AND,
    OR,
    NOT,
    RANGE,

    // --- Increment / Decrement ---
    PLUS_PLUS,
    MINUS_MINUS,

    // --- Compound Assignment ---
    PLUS_ASSIGN,
    MINUS_ASSIGN,
    STAR_ASSIGN,
    SLASH_ASSIGN,

    // --- Delimiters ---
    LPAREN,
    RPAREN,
    LBRACE,
    RBRACE,
    LBRACKET,
    RBRACKET,
    COMMA,
    COLON,
    SEMICOLON,
    DOT,
    HASH,
    
    // --- Angle Brackets (for set<T>) ---
    LANGLE,
    RANGLE,

    // --- Special ---
    EOF,
    UNKNOWN,
};


// ============================================================
// TOKEN CLASS
// ============================================================

class Token {
    var type:   TokenType;
    var value:  str;
    var line:   int;
    var col:    int;

    function init(t: TokenType, v: str, l: int, c: int) -> null {
        this.type  = t;
        this.value = v;
        this.line  = l;
        this.col   = c;
    };
};