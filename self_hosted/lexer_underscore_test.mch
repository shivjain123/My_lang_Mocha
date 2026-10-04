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
    // Basic underscore grouping
    var lex1: Lexer = Lexer("1_000_000");
    var toks1: Token[] = lex1.tokenise();
    check("1_000_000 type", "INT_LIT", toks1[0].type.name());
    check("1_000_000 value", "1000000", toks1[0].value);

    // Underscore in float
    var lex2: Lexer = Lexer("1_234.5_6");
    var toks2: Token[] = lex2.tokenise();
    check("1_234.5_6 type", "FLOAT_LIT", toks2[0].type.name());
    check("1_234.5_6 value", "1234.56", toks2[0].value);

    // Leading underscore — NOT valid in a number; "_1" should lex as
    // identifier "_1" entirely, number lexing never even starts
    var lex3: Lexer = Lexer("_1");
    var toks3: Token[] = lex3.tokenise();
    check("_1 type", "IDENTIFIER", toks3[0].type.name());
    check("_1 value", "_1", toks3[0].value);

    // Trailing underscore — "1_" : underscore is invalid here since
    // nothing digit follows, so it should stop the number at "1"
    // and "_" should then lex as its own identifier token
    var lex4: Lexer = Lexer("1_");
    var toks4: Token[] = lex4.tokenise();
    check("1_ count", "3", str(toks4.length));
    check("1_ tok0 type", "INT_LIT", toks4[0].type.name());
    check("1_ tok0 value", "1", toks4[0].value);
    check("1_ tok1 type", "IDENTIFIER", toks4[1].type.name());
    check("1_ tok1 value", "_", toks4[1].value);

    // Consecutive underscores — "1__2" : first underscore fails
    // (next char is "_" not a digit), so number stops at "1",
    // then "__2" lexes as one identifier
    var lex5: Lexer = Lexer("1__2");
    var toks5: Token[] = lex5.tokenise();
    check("1__2 count", "3", str(toks5.length));
    check("1__2 tok0 value", "1", toks5[0].value);
    check("1__2 tok1 type", "IDENTIFIER", toks5[1].type.name());
    check("1__2 tok1 value", "__2", toks5[1].value);

    print("--- DONE ---", newLine=true);
};