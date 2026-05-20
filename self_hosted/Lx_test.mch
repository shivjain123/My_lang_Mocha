from "./lexer.mch" import *;

function main(didLoad) -> null {
    var src: str = "var x: int = 42;";
    var lex: Lexer = Lexer(src);
    var toks: Token[] = lex.tokenise();
    print(toks.length, newLine=true); //giving 8 correct

    print("\n");

    var i: int = 0;
    while (i < toks.length) {
        print(toks[i].type.name, newLine=true);
        print(" → ");
        print(toks[i].value);
        i++;
    };
};