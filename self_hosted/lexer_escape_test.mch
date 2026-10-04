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
    // Known escapes still work
    var lex1: Lexer = Lexer("\"a\\nb\\tc\\\"d\\\\e\"");
    var toks1: Token[] = lex1.tokenise();
    check("known escapes", "a\nb\tc\"d\\e", toks1[0].value);

    // Unknown escape — preserved as literal backslash + char
    var lex2: Lexer = Lexer("\"hello\\xworld\"");
    var toks2: Token[] = lex2.tokenise();
    check("unknown escape", "hello\\xworld", toks2[0].value);

    print("--- DONE ---", newLine=true);
};