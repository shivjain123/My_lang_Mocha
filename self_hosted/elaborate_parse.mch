from "./parser.mch" import *;

function check(label: str, expected: str, actual: str) -> null {
    if (expected == actual) {
        print("✅ ", label, newLine=true);
    } else {
        print("❌ ", label, newLine=true);
        print("   expected: ", expected, newLine=true);
        print("   actual:   ", actual, newLine=true);
    };
};

function check_int(label: str, expected: int, actual: int) -> null {
    if (expected == actual) {
        print("✅ ", label, newLine=true);
    } else {
        print("❌ ", label, newLine=true);
        print("   expected: ", expected, newLine=true);
        print("   actual:   ", actual, newLine=true);
    };
};

function check_bool(label: str, expected: bool, actual: bool) -> null {
    if (expected == actual) {
        print("✅ ", label, newLine=true);
    } else {
        print("❌ ", label, newLine=true);
    };
};

function main(didLoad) -> null {

    // ─── TEST 1: VarDecl with int literal ───────────────────
    print("--- TEST 1: VarDecl int ---", newLine=true);
    var src1: str = "var x: int = 42;";
    var lex1: Lexer = Lexer(src1);
    var toks1: Token[] = lex1.tokenise();
    var p1: Parser = Parser(toks1);
    var ast1: ASTNode = p1.parse();
    var s1: ASTNode = ast1.children[0];
    check("kind", "VarDecl", s1.kind);
    check("name", "x", s1.value);
    check("type", "int", s1.type_str);
    check("val kind", "IntLiteral", s1.left.kind);
    check_int("val", 42, s1.left.int_val);

    // ─── TEST 2: VarDecl with string literal ────────────────
    print("--- TEST 2: VarDecl str ---", newLine=true);
    var src2: str = "var name: str = \"mocha\";";
    print(src2, newLine=true);
    var lex2: Lexer = Lexer(src2);
    var toks2: Token[] = lex2.tokenise();
    var p2: Parser = Parser(toks2);
    var ast2: ASTNode = p2.parse();
    var s2: ASTNode = ast2.children[0];
    check("kind", "VarDecl", s2.kind);
    check("name", "name", s2.value);
    check("type", "str", s2.type_str);
    check("val kind", "StrLiteral", s2.left.kind);
    check("val", "mocha", s2.left.value);

    // ─── TEST 3: If statement ────────────────────────────────
    print("--- TEST 3: IfStmt ---", newLine=true);
    var src3: str = "if (x == 1) { var y: int = 2; };";
    var lex3: Lexer = Lexer(src3);
    var toks3: Token[] = lex3.tokenise();
    var p3: Parser = Parser(toks3);
    var ast3: ASTNode = p3.parse();
    var s3: ASTNode = ast3.children[0];
    check("kind", "IfStmt", s3.kind);
    check("cond kind", "BinaryOp", s3.condition.kind);
    check("cond op", "==", s3.condition.value);
    check_int("body count", 1, s3.body.length);
    check("body[0] kind", "VarDecl", s3.body[0].kind);

    // ─── TEST 4: While loop ──────────────────────────────────
    print("--- TEST 4: WhileLoop ---", newLine=true);
    var src4: str = "while (i < 10) { i = i + 1; };";
    var lex4: Lexer = Lexer(src4);
    var toks4: Token[] = lex4.tokenise();
    var p4: Parser = Parser(toks4);
    var ast4: ASTNode = p4.parse();
    var s4: ASTNode = ast4.children[0];
    check("kind", "WhileLoop", s4.kind);
    check("cond kind", "BinaryOp", s4.condition.kind);
    check("cond op", "<", s4.condition.value);
    check_int("body count", 1, s4.body.length);

    // ─── TEST 5: Function declaration ───────────────────────
    print("--- TEST 5: FunctionDecl ---", newLine=true);
    var src5: str = "function add(a: int, b: int) -> int { return a + b; };";
    var lex5: Lexer = Lexer(src5);
    var toks5: Token[] = lex5.tokenise();
    var p5: Parser = Parser(toks5);
    var ast5: ASTNode = p5.parse();
    var s5: ASTNode = ast5.children[0];
    check("kind", "FunctionDecl", s5.kind);
    check("name", "add", s5.value);
    check("return type", "int", s5.type_str);
    check_int("param count", 2, s5.params.length);
    check("param0 name", "a", s5.params[0].value);
    check("param0 type", "int", s5.params[0].type_str);
    check("param1 name", "b", s5.params[1].value);
    check_int("body count", 1, s5.body.length);
    check("return kind", "ReturnStmt", s5.body[0].kind);

    // ─── TEST 6: For each loop ───────────────────────────────
    print("--- TEST 6: ForEachLoop ---", newLine=true);
    var src6: str = "for each x in arr { print(x, newLine=true); };";
    var lex6: Lexer = Lexer(src6);
    var toks6: Token[] = lex6.tokenise();
    var p6: Parser = Parser(toks6);
    var ast6: ASTNode = p6.parse();
    var s6: ASTNode = ast6.children[0];
    check("kind", "ForEachLoop", s6.kind);
    check("var", "x", s6.value);
    check("iter kind", "Identifier", s6.left.kind);
    check("iter name", "arr", s6.left.value);

    // ─── TEST 7: Match statement ─────────────────────────────
    print("--- TEST 7: MatchStmt ---", newLine=true);
    var src7: str = "match (x) { case 1: var a: int = 1; default: var b: int = 0; };";
    var lex7: Lexer = Lexer(src7);
    var toks7: Token[] = lex7.tokenise();
    var p7: Parser = Parser(toks7);
    var ast7: ASTNode = p7.parse();
    var s7: ASTNode = ast7.children[0];
    check("kind", "MatchStmt", s7.kind);
    check_int("case count", 2, s7.cases.length);
    check("case0 kind", "CaseNode", s7.cases[0].kind);
    check_bool("case0 is_default", false, s7.cases[0].flag1);
    check_bool("case1 is_default", true, s7.cases[1].flag1);

    // ─── TEST 8: Binary expressions ─────────────────────────
    print("--- TEST 8: BinaryOp chain ---", newLine=true);
    var src8: str = "var z: bool = a > 1 && b < 10;";
    var lex8: Lexer = Lexer(src8);
    var toks8: Token[] = lex8.tokenise();
    var p8: Parser = Parser(toks8);
    var ast8: ASTNode = p8.parse();
    var s8: ASTNode = ast8.children[0];
    check("kind", "VarDecl", s8.kind);
    check("val kind", "BinaryOp", s8.left.kind);
    check("top op", "&&", s8.left.value);
    check("left op", ">", s8.left.left.value);
    check("right op", "<", s8.left.right.value);

    // ─── TEST 9: Class declaration ───────────────────────────
    print("--- TEST 9: ClassDecl ---", newLine=true);
    var src9: str = "class Dog { var name: str; function constructor(n: str) -> null { this.name = n; }; };";
    var lex9: Lexer = Lexer(src9);
    var toks9: Token[] = lex9.tokenise();
    var p9: Parser = Parser(toks9);
    var ast9: ASTNode = p9.parse();
    var s9: ASTNode = ast9.children[0];
    check("kind", "ClassDecl", s9.kind);
    check("name", "Dog", s9.value);
    check_int("body count", 2, s9.body.length);
    check("field kind", "FieldDecl", s9.body[0].kind);
    check("field name", "name", s9.body[0].value);
    check("method kind", "MethodDecl", s9.body[1].kind);
    check("method name", "constructor", s9.body[1].value);

    // ─── TEST 10: Lambda ─────────────────────────────────────
    print("--- TEST 10: Lambda ---", newLine=true);
    var src10: str = "var f: lambda = lambda(x: int) -> int: x + 1;";
    var lex10: Lexer = Lexer(src10);
    var toks10: Token[] = lex10.tokenise();
    var p10: Parser = Parser(toks10);
    var ast10: ASTNode = p10.parse();
    var s10: ASTNode = ast10.children[0];
    check("kind", "VarDecl", s10.kind);
    check("val kind", "LambdaExpr", s10.left.kind);
    check_int("param count", 1, s10.left.params.length);
    check("param name", "x", s10.left.params[0].value);
    check("return type", "int", s10.left.type_str);

    print("--- ALL TESTS DONE ---", newLine=true);
};