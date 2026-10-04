from "./lexer.mch" import *;

function check(label: str, expected: str, actual: str) -> null {
    if (expected == actual) {
        print("✅ ", label, newLine=true);
    } else {
        print("❌ ", label, newLine=true);
        print("   expected: ", expected, newLine=true);
        print("   actual:   ", actual, newLine=true);
    };
};

function main(didLoad) -> null {
    // Basic scientific notation
    var lex1: Lexer = Lexer("1.5E10");
    var toks1: Token[] = lex1.tokenise();
    check("1.5E10 type", "FLOAT_LIT", toks1[0].type.name());
    check("1.5E10 value", "1.5E10", toks1[0].value);

    // Negative exponent
    var lex2: Lexer = Lexer("2E-3");
    var toks2: Token[] = lex2.tokenise();
    check("2E-3 type", "FLOAT_LIT", toks2[0].type.name());
    check("2E-3 value", "2E-3", toks2[0].value);

    // Positive sign exponent
    var lex3: Lexer = Lexer("3.14E+6");
    var toks3: Token[] = lex3.tokenise();
    check("3.14E+6 type", "FLOAT_LIT", toks3[0].type.name());
    check("3.14E+6 value", "3.14E+6", toks3[0].value);

    // E with no digits after — should back off, NOT be treated as scientific
    var lex4: Lexer = Lexer("1E");
    var toks4: Token[] = lex4.tokenise();
    check("1E backoff count", "3", str(toks4.length));
    check("1E tok0 type", "INT_LIT", toks4[0].type.name());
    check("1E tok0 value", "1", toks4[0].value);
    check("1E tok1 type", "CONST_IDENT", toks4[1].type.name());
    check("1E tok1 value", "E", toks4[1].value);

    print("--- DONE ---", newLine=true);
};