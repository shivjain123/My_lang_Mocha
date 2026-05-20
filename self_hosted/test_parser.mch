from "./parser.mch" import *;

function main(didLoad) -> null {
    var src: str = "var x: int = 42;";
    
    // Lex
    var lex: Lexer = Lexer(src);
    var toks: Token[] = lex.tokenise();
    
    // Parse
    var parser: Parser = Parser(toks);
    var ast: ASTNode = parser.parse();
    
    // Print top level
    print("Root kind: ", newLine=true);
    print(ast.kind, newLine=true);              // Program
    print("Children count: ", newLine=true);
    print(ast.children.length, newLine=true);   // 1

    // First statement — VarDecl
    var stmt: ASTNode = ast.children[0];
    print("Stmt kind: ", newLine=true);
    print(stmt.kind, newLine=true);             // VarDecl
    print("Var name: ", newLine=true);
    print(stmt.value, newLine=true);            // x
    print("Var type: ", newLine=true);
    print(stmt.type_str, newLine=true);         // int

    // Value — IntLiteral
    print("Value kind: ", newLine=true);
    print(stmt.left.kind, newLine=true);        // IntLiteral
    print("Value: ", newLine=true);
    print(stmt.left.int_val, newLine=true);     // 42
};