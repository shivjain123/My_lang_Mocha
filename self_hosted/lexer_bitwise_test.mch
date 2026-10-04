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
    var src: str = "& | ^ ~ << >> && ||";
    var lex: Lexer = Lexer(src);
    var toks: Token[] = lex.tokenise();

    check("count", "9", str(toks.length));

    check("tok0 type", "BIT_AND", toks[0].type.name());
    check("tok0 value", "&", toks[0].value);

    check("tok1 type", "BIT_OR", toks[1].type.name());
    check("tok1 value", "|", toks[1].value);

    check("tok2 type", "BIT_XOR", toks[2].type.name());
    check("tok2 value", "^", toks[2].value);

    check("tok3 type", "BIT_NOT", toks[3].type.name());
    check("tok3 value", "~", toks[3].value);

    check("tok4 type", "BIT_SHL", toks[4].type.name());
    check("tok4 value", "<<", toks[4].value);

    check("tok5 type", "BIT_SHR", toks[5].type.name());
    check("tok5 value", ">>", toks[5].value);

    check("tok6 type", "AND", toks[6].type.name());
    check("tok6 value", "&&", toks[6].value);

    check("tok7 type", "OR", toks[7].type.name());
    check("tok7 value", "||", toks[7].value);

    print("--- DONE ---", newLine=true);
};