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
    // Emoji between two identifiers should be silently skipped —
    // only "a", "b", and EOF should remain as tokens
    var lex1: Lexer = Lexer("a🙂b");
    var toks1: Token[] = lex1.tokenise();
    check("emoji count", "3", str(toks1.length));
    check("emoji tok0 type", "IDENTIFIER", toks1[0].type.name());
    check("emoji tok0 value", "a", toks1[0].value);
    check("emoji tok1 type", "IDENTIFIER", toks1[1].type.name());
    check("emoji tok1 value", "b", toks1[1].value);

    // A genuinely unknown low-ASCII character (backtick `) should
    // still emit UNKNOWN, not be silently skipped
    var lex2: Lexer = Lexer("`");
    var toks2: Token[] = lex2.tokenise();
    check("backtick count", "2", str(toks2.length));
    check("backtick type", "UNKNOWN", toks2[0].type.name());
    check("backtick value", "`", toks2[0].value);

    print("--- DONE ---", newLine=true);
};