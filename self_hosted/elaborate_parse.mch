from "./parser.mch" import *;

function check(label: str, expected: str, actual: str) -> null {
    if (expected == actual) {
        print(label, " ✅", newLine=true);
    } else {
        print("❌ ", label, newLine=true);
        print("   expected: ", expected, newLine=true);
        print("   actual:   ", actual, newLine=true);
    };
};

function check_int(label: str, expected: int, actual: int) -> null {
    if (expected == actual) {
        print(label, " ✅", newLine=true);
    } else {
        print("❌ ", label, newLine=true);
        print("   expected: ", expected, newLine=true);
        print("   actual:   ", actual, newLine=true);
    };
};

function check_bool(label: str, expected: bool, actual: bool) -> null {
    if (expected == actual) {
        print(label, " ✅", newLine=true);
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

    // ─── TEST 11: Match with range, when, and member-access cases ───
    print("--- TEST 11: Match case patterns ---", newLine=true);
    var src11: str = "match (x) { case 90..99: var a: int = 1; case y when y < 60: var b: int = 2; case TokenType.INT_LIT: var c: int = 3; default: var d: int = 0; };";
    var lex11: Lexer = Lexer(src11);
    var toks11: Token[] = lex11.tokenise();
    var p11: Parser = Parser(toks11);
    var ast11: ASTNode = p11.parse();
    var s11: ASTNode = ast11.children[0];
    check("kind", "MatchStmt", s11.kind);
    check_int("case count", 4, s11.cases.length);
    check("case0 pattern kind", "RangeNode", s11.cases[0].left.kind);
    check_int("case0 range start", 90, s11.cases[0].left.left.int_val);
    check_int("case0 range end", 99, s11.cases[0].left.right.int_val);
    check("case1 pattern kind", "Identifier", s11.cases[1].left.kind);
    check("case1 pattern name", "y", s11.cases[1].left.value);
    check("case1 when kind", "BinaryOp", s11.cases[1].condition.kind);
    check("case2 pattern kind", "MemberAccess", s11.cases[2].left.kind);
    check("case2 member", "INT_LIT", s11.cases[2].left.value);
    check("case2 object", "TokenType", s11.cases[2].left.left.value);
    check_bool("case3 is_default", true, s11.cases[3].flag1);

    // ─── TEST 12: Bitwise precedence chain ───
    print("--- TEST 12: Bitwise precedence ---", newLine=true);
    var src12: str = "var z: int = 1 | 2 ^ 3 & 4 << 5;";
    var lex12: Lexer = Lexer(src12);
    var toks12: Token[] = lex12.tokenise();
    var p12: Parser = Parser(toks12);
    var ast12: ASTNode = p12.parse();
    var s12: ASTNode = ast12.children[0];
    check("kind", "VarDecl", s12.kind);
    check("top op", "|", s12.left.value);
    check_int("top left", 1, s12.left.left.int_val);
    check("second op", "^", s12.left.right.value);
    check_int("second left", 2, s12.left.right.left.int_val);
    check("third op", "&", s12.left.right.right.value);
    check_int("third left", 3, s12.left.right.right.left.int_val);
    check("fourth op", "<<", s12.left.right.right.right.value);
    check_int("fourth left", 4, s12.left.right.right.right.left.int_val);
    check_int("fourth right", 5, s12.left.right.right.right.right.int_val);

    // ─── TEST 13: Bitwise NOT ───
    print("--- TEST 13: Bitwise NOT ---", newLine=true);
    var src13: str = "var a: int = ~5; var b: int = ~x & 3;";
    var lex13: Lexer = Lexer(src13);
    var toks13: Token[] = lex13.tokenise();
    var p13: Parser = Parser(toks13);
    var ast13: ASTNode = p13.parse();
    var s13a: ASTNode = ast13.children[0];
    var s13b: ASTNode = ast13.children[1];
    check("a val kind", "UnaryOp", s13a.left.kind);
    check("a op", "~", s13a.left.value);
    check_int("a operand", 5, s13a.left.right.int_val);
    check("b top op", "&", s13b.left.value);
    check("b left kind", "UnaryOp", s13b.left.left.kind);
    check("b left op", "~", s13b.left.left.value);
    check("b left operand", "x", s13b.left.left.right.value);
    check_int("b right", 3, s13b.left.right.int_val);

    // ─── TEST 14: Qualified method call ───
    print("--- TEST 14: QualifiedMethodCall ---", newLine=true);
    var src14: str = "class Bird { function breathe() -> null { }; }; var r: int = Bird.p.breathe(7, step=2);";
    var lex14: Lexer = Lexer(src14);
    var toks14: Token[] = lex14.tokenise();
    var p14: Parser = Parser(toks14);
    var ast14: ASTNode = p14.parse();
    var s14: ASTNode = ast14.children[1];
    check("kind", "VarDecl", s14.kind);
    check("call kind", "QualifiedMethodCall", s14.left.kind);
    check("parent class", "Bird", s14.left.value);
    check("object", "p", s14.left.extra);
    check("method", "breathe", s14.left.type_str);
    check_int("arg count", 2, s14.left.args.length);
    check_int("arg0 value", 7, s14.left.args[0].int_val);
    check("arg1 kind", "NamedArg", s14.left.args[1].kind);
    check("arg1 name", "step", s14.left.args[1].value);

    // ─── TEST 15: TagAccess ───
    print("--- TEST 15: TagAccess ---", newLine=true);
    var src15: str = "tag DSKind { INT, FLOAT, STR, BOOL }; var a: DSKind = DSKind.INT; var m: str = a.name();";
    var lex15: Lexer = Lexer(src15);
    var toks15: Token[] = lex15.tokenise();
    var p15: Parser = Parser(toks15);
    var ast15: ASTNode = p15.parse();
    var s15a: ASTNode = ast15.children[1];
    var s15m: ASTNode = ast15.children[2];
    check("a kind", "VarDecl", s15a.kind);
    check("a val kind", "TagAccess", s15a.left.kind);
    check("a tag name", "DSKind", s15a.left.value);
    check("a member", "INT", s15a.left.extra);
    check("m val kind", "FunctionCall", s15m.left.kind);
    check("m callee kind", "MemberAccess", s15m.left.left.kind);
    check("m callee name", "name", s15m.left.left.value);
    check("m callee obj", "a", s15m.left.left.left.value);

    // ─── TEST 16: SCREAMING_CASE class, extends, implements ───
    print("--- TEST 16: CONST_IDENT class names ---", newLine=true);
    var src16: str = "class BASE_CLASS { }; class MY_CLASS extends BASE_CLASS implements IFACE_ONE { };";
    var lex16: Lexer = Lexer(src16);
    var toks16: Token[] = lex16.tokenise();
    var p16: Parser = Parser(toks16);
    var ast16: ASTNode = p16.parse();
    var s16a: ASTNode = ast16.children[0];
    var s16b: ASTNode = ast16.children[1];
    check("a kind", "ClassDecl", s16a.kind);
    check("a name", "BASE_CLASS", s16a.value);
    check("b kind", "ClassDecl", s16b.kind);
    check("b name", "MY_CLASS", s16b.value);
    check_int("b parent count", 1, s16b.children.length);
    check("b parent kind", "Parent", s16b.children[0].kind);
    check("b parent name", "BASE_CLASS", s16b.children[0].value);
    check_int("b interface count", 1, s16b.else_ifs.length);
    check("b interface name", "IFACE_ONE", s16b.else_ifs[0].value);

    // ─── TEST 17: alloc with primitive, CONST_IDENT class, and 2D ───
    print("--- TEST 17: alloc ---", newLine=true);
    var src17: str = "var a: int[] = alloc int[5]; var b: MY_CLASS[] = alloc MY_CLASS[3]; var c: int[][] = alloc int[2][4];";
    var lex17: Lexer = Lexer(src17);
    var toks17: Token[] = lex17.tokenise();
    var p17: Parser = Parser(toks17);
    var ast17: ASTNode = p17.parse();
    var s17a: ASTNode = ast17.children[0];
    var s17b: ASTNode = ast17.children[1];
    var s17c: ASTNode = ast17.children[2];
    check("a type", "int[]", s17a.type_str);
    check("a val kind", "AllocArray", s17a.left.kind);
    check("a elem", "int", s17a.left.value);
    check_int("a size", 5, s17a.left.left.int_val);
    check("b type", "MY_CLASS[]", s17b.type_str);
    check("b val kind", "AllocArray", s17b.left.kind);
    check("b elem", "MY_CLASS", s17b.left.value);
    check_int("b size", 3, s17b.left.left.int_val);
    check("c type", "int[][]", s17c.type_str);
    check("c elem", "int", s17c.left.value);
    check_int("c size1", 2, s17c.left.left.int_val);
    check_int("c size2", 4, s17c.left.right.int_val);

    // ─── TEST 18: do-while ───
    print("--- TEST 18: DoWhileLoop ---", newLine=true);
    var src18: str = "do { i = i + 1; var y: int = 2; } while (i < 10);";
    var lex18: Lexer = Lexer(src18);
    var toks18: Token[] = lex18.tokenise();
    var p18: Parser = Parser(toks18);
    var ast18: ASTNode = p18.parse();
    var s18: ASTNode = ast18.children[0];
    check("kind", "DoWhileLoop", s18.kind);
    check("cond kind", "BinaryOp", s18.condition.kind);
    check("cond op", "<", s18.condition.value);
    check_int("body count", 2, s18.body.length);
    check("body[1] kind", "VarDecl", s18.body[1].kind);

    // ─── TEST 19: try/rescue, fail, rethrow ───
    print("--- TEST 19: try/rescue/fail/rethrow ---", newLine=true);
    var src19: str = "try { fail \"boom\"; } rescue, e { rethrow; }; try { var a: int = 1; } rescue { var b: int = 2; };";
    var lex19: Lexer = Lexer(src19);
    var toks19: Token[] = lex19.tokenise();
    var p19: Parser = Parser(toks19);
    var ast19: ASTNode = p19.parse();
    var s19a: ASTNode = ast19.children[0];
    var s19b: ASTNode = ast19.children[1];
    check("a kind", "TryRescue", s19a.kind);
    check("a binding", "e", s19a.value);
    check_int("a try count", 1, s19a.body.length);
    check("a try[0] kind", "FailStmt", s19a.body[0].kind);
    check("a fail msg", "boom", s19a.body[0].left.value);
    check_int("a rescue count", 1, s19a.else_body.length);
    check("a rescue[0] kind", "RethrowStmt", s19a.else_body[0].kind);
    check("b kind", "TryRescue", s19b.kind);
    check("b binding", "", s19b.value);
    check("b try[0] kind", "VarDecl", s19b.body[0].kind);
    check("b rescue[0] kind", "VarDecl", s19b.else_body[0].kind);

    // ─── TEST 20: local functions and extend ───
    print("--- TEST 20: local and extend ---", newLine=true);
    var src20: str = "local function helper() -> int { return 1; }; extend int { local function twice() -> int { return 2; }; function thrice() -> int { return 3; }; };";
    var lex20: Lexer = Lexer(src20);
    var toks20: Token[] = lex20.tokenise();
    var p20: Parser = Parser(toks20);
    var ast20: ASTNode = p20.parse();
    var s20a: ASTNode = ast20.children[0];
    var s20b: ASTNode = ast20.children[1];
    check("a kind", "FunctionDecl", s20a.kind);
    check("a name", "helper", s20a.value);
    check_bool("a is_local", true, s20a.flag2);
    check("b kind", "ExtendDecl", s20b.kind);
    check("b type", "int", s20b.value);
    check_int("b body count", 2, s20b.body.length);
    check("b m0 kind", "ExtendMethod", s20b.body[0].kind);
    check("b m0 name", "twice", s20b.body[0].value);
    check_bool("b m0 is_local", true, s20b.body[0].flag2);
    check("b m1 name", "thrice", s20b.body[1].value);
    check_bool("b m1 is_local", false, s20b.body[1].flag2);

     // ─── TEST 21: doc comments ───
    print("--- TEST 21: doc comments ---", newLine=true);
    var src21: str = "~~ adds things\nfunction add() -> int { return 1; };\n~~ a box\nclass Box {\n~~ opens it\nfunction open() -> null { };\nfunction shut() -> null { };\n};";
    var lex21: Lexer = Lexer(src21);
    var toks21: Token[] = lex21.tokenise();
    var p21: Parser = Parser(toks21);
    var ast21: ASTNode = p21.parse();
    var s21f: ASTNode = ast21.children[0];
    var s21c: ASTNode = ast21.children[1];
    check("f kind", "FunctionDecl", s21f.kind);
    check_bool("f has doc", true, s21f.doc_text != "");
    check("c kind", "ClassDecl", s21c.kind);
    check_bool("c has doc", true, s21c.doc_text != "");
    check_int("c body count", 2, s21c.body.length);
    check_bool("open has doc", true, s21c.body[0].doc_text != "");
    check_bool("shut has no doc", true, s21c.body[1].doc_text == "");

    // ─── TEST 22: doc comments in extend ───
    print("--- TEST 22: extend docs ---", newLine=true);
    var src22: str = "extend int {\n~~ doubles it\nfunction double() -> int { return 2; };\nfunction plain() -> int { return 1; };\n};";
    var lex22: Lexer = Lexer(src22);
    var toks22: Token[] = lex22.tokenise();
    var p22: Parser = Parser(toks22);
    var ast22: ASTNode = p22.parse();
    var s22: ASTNode = ast22.children[0];
    check("kind", "ExtendDecl", s22.kind);
    check_int("body count", 2, s22.body.length);
    check("m0 name", "double", s22.body[0].value);
    check_bool("m0 has doc", true, s22.body[0].doc_text != "");
    check("m1 name", "plain", s22.body[1].value);
    check_bool("m1 has no doc", true, s22.body[1].doc_text == "");

    // ─── TEST 23: async function and await ───
    print("--- TEST 23: async and await ---", newLine=true);
    var src23: str = "async function fetch() -> int { var r: int = await work(); return r; }; function plain() -> int { return 1; };";
    var lex23: Lexer = Lexer(src23);
    var toks23: Token[] = lex23.tokenise();
    var p23: Parser = Parser(toks23);
    var ast23: ASTNode = p23.parse();
    var s23a: ASTNode = ast23.children[0];
    var s23b: ASTNode = ast23.children[1];
    check("a kind", "FunctionDecl", s23a.kind);
    check("a name", "fetch", s23a.value);
    check_bool("a is_async", true, s23a.is_async);
    check("a await kind", "AwaitExpr", s23a.body[0].left.kind);
    check("a await operand", "FunctionCall", s23a.body[0].left.left.kind);
    check("b name", "plain", s23b.value);
    check_bool("b is_async", false, s23b.is_async);

    // ─── TEST 24: async and shared methods in a class ───
    print("--- TEST 24: async methods ---", newLine=true);
    var src24: str = "class Job { async function run() -> int { return 1; }; shared function make() -> null { }; private shared async function both() -> null { }; };";
    var lex24: Lexer = Lexer(src24);
    var toks24: Token[] = lex24.tokenise();
    var p24: Parser = Parser(toks24);
    var ast24: ASTNode = p24.parse();
    var s24: ASTNode = ast24.children[0];
    check_int("body count", 3, s24.body.length);
    check("m0 kind", "MethodDecl", s24.body[0].kind);
    check_bool("m0 is_async", true, s24.body[0].is_async);
    check_bool("m0 is_shared", false, s24.body[0].flag1);
    check_bool("m1 is_async", false, s24.body[1].is_async);
    check_bool("m1 is_shared", true, s24.body[1].flag1);
    check_bool("m2 is_async", true, s24.body[2].is_async);
    check_bool("m2 is_shared", true, s24.body[2].flag1);
    check("m2 visibility", "private", s24.body[2].extra);

    print("--- ALL TESTS DONE ---", newLine=true);
};