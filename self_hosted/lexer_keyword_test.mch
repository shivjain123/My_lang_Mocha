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
    var src: str = "local try rescue fail rethrow";
    var lex: Lexer = Lexer(src);
    var toks: Token[] = lex.tokenise();

    check("tok0", "LOCAL", toks[0].type.name());
    check("tok1", "TRY", toks[1].type.name());
    check("tok2", "RESCUE", toks[2].type.name());
    check("tok3", "FAIL", toks[3].type.name());
    check("tok4", "RETHROW", toks[4].type.name());

    print("--- DONE ---", newLine=true);
};