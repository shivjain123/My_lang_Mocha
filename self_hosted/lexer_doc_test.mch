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
    // Basic doc comment with leading space
    var lex1: Lexer = Lexer("~~ hello world\nvar x: int = 1;");
    var toks1: Token[] = lex1.tokenise();
    check("tok0 type", "DOC_COMMENT", toks1[0].type.name());
    check("tok0 value", "hello world", toks1[0].value);
    check("tok1 type", "VAR", toks1[1].type.name());

    // Doc comment with no leading space
    var lex2: Lexer = Lexer("~~nospace");
    var toks2: Token[] = lex2.tokenise();
    check("nospace value", "nospace", toks2[0].value);

    // Empty doc comment
    var lex3: Lexer = Lexer("~~\nvar y: int = 2;");
    var toks3: Token[] = lex3.tokenise();
    check("empty value", "", toks3[0].value);
    check("empty next type", "VAR", toks3[1].type.name());

    // Lone ~ should still be BIT_NOT, not confused with doc comments
    var lex4: Lexer = Lexer("~x");
    var toks4: Token[] = lex4.tokenise();
    check("lone tilde type", "BIT_NOT", toks4[0].type.name());
    check("lone tilde value", "~", toks4[0].value);

    print("--- DONE ---", newLine=true);
};