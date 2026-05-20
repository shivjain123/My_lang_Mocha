// mocha-lib-deps: mocha-string
from "./typechecker.mch" import *;

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

function parse_src(src: str) -> ASTNode {
    var lex: Lexer = Lexer(src);
    var toks: Token[] = lex.tokenise();
    var p: Parser = Parser(toks);
    return p.parse();
};

function run_tc(src: str) -> TypeChecker {
    var ast: ASTNode = parse_src(src);
    var tc: TypeChecker = TypeChecker();
    tc.check(ast);
    return tc;
};

function main(didLoad) -> null {

    // ─── TEST 1: VarDecl int — no errors ────────────────────
    print("--- TEST 1: VarDecl int ---", newLine=true);
    var tc1: TypeChecker = run_tc("function main(didLoad) -> null { var x: int = 42; };");
    check_int("no errors", 0, tc1.errors.length);

    // ─── TEST 2: VarDecl type mismatch ──────────────────────
    print("--- TEST 2: VarDecl type mismatch ---", newLine=true);
    var tc2: TypeChecker = run_tc("function main(didLoad) -> null { var x: int = true; };");
    check_int("1 error", 1, tc2.errors.length);
    check("error msg contains mismatch", "Type", tc2.errors[0].message.substring(0, 3));

    // ─── TEST 3: Undeclared variable ────────────────────────
    print("--- TEST 3: Undeclared variable ---", newLine=true);
    var tc3: TypeChecker = run_tc("function main(didLoad) -> null { var x: int = y; };");
    check_int("1 error", 1, tc3.errors.length);

    // ─── TEST 4: Valid function return type ─────────────────
    print("--- TEST 4: Valid return type ---", newLine=true);
    var tc4: TypeChecker = run_tc("function add(a: int, b: int) -> int { return a + b; }; function main(didLoad) -> null { var x: int = add(1, 2); };");
    check_int("no errors", 0, tc4.errors.length);

    // ─── TEST 5: Return type mismatch ───────────────────────
    print("--- TEST 5: Return type mismatch ---", newLine=true);
    var tc5: TypeChecker = run_tc("function bad(didLoad) -> int { return true; };");
    check_int("1 error", 1, tc5.errors.length);

    // ─── TEST 6: Const reassignment ─────────────────────────
    print("--- TEST 6: Const reassignment ---", newLine=true);
    var tc6: TypeChecker = run_tc("function main(didLoad) -> null { const MAX: int = 10; MAX = 20; };");
    check_int("1 error", 1, tc6.errors.length);

    // ─── TEST 7: Valid class field access ───────────────────
    print("--- TEST 7: Class field access ---", newLine=true);
    var src7: str = "class Dog { var name: str; function constructor() -> null { this.name = \"\"; }; }; function main(didLoad) -> null { var d: Dog = Dog(); var n: str = d.name; };";
    var tc7: TypeChecker = run_tc(src7);
    check_int("no errors", 0, tc7.errors.length);

    // ─── TEST 8: Private field access from outside ──────────
    print("--- TEST 8: Private field access ---", newLine=true);
    var src8: str = "class Cat { private var age: int; function constructor() -> null { this.age = 0; }; }; function main(didLoad) -> null { var c: Cat = Cat(); var a: int = c.age; };";
    var tc8: TypeChecker = run_tc(src8);
    check_int("1 error", 1, tc8.errors.length);

    // ─── TEST 9: If condition not bool ──────────────────────
    print("--- TEST 9: If condition not bool ---", newLine=true);
    var tc9: TypeChecker = run_tc("function main(didLoad) -> null { var x: int = 1; if (x) { var y: int = 2; }; };");
    check_int("1 error", 1, tc9.errors.length);

    // ─── TEST 10: ScopeManager — variable in inner scope ────
    print("--- TEST 10: Inner scope variable ---", newLine=true);
    var tc10: TypeChecker = run_tc("function main(didLoad) -> null { var x: int = 1; if (x == 1) { var y: int = 2; }; };");
    check_int("no errors", 0, tc10.errors.length);

    // ─── TEST 11: Break outside loop ────────────────────────
    print("--- TEST 11: Break outside loop ---", newLine=true);
    var tc11: TypeChecker = run_tc("function main(didLoad) -> null { break; };");
    check_int("1 error", 1, tc11.errors.length);

    // ─── TEST 12: Missing return statement ──────────────────
    print("--- TEST 12: Missing return ---", newLine=true);
    var tc12: TypeChecker = run_tc("function add(a: int, b: int) -> int { var x: int = 1; }; function main(didLoad) -> null { };");
    check_int("1 error", 1, tc12.errors.length);

    // ─── TEST 13: No entry point ────────────────────────────
    print("--- TEST 13: No entry point ---", newLine=true);
    var tc13: TypeChecker = run_tc("function add(a: int, b: int) -> int { return a + b; };");
    check_int("1 error", 1, tc13.errors.length);

    // ─── TEST 14: Binary op type inference ──────────────────
    print("--- TEST 14: BinaryOp type inference ---", newLine=true);
    var tc14: TypeChecker = run_tc("function main(didLoad) -> null { var x: float = 1 + 2.0; };");
    check_int("no errors", 0, tc14.errors.length);

    // ─── TEST 15: ScopeManager lookupType ───────────────────
    print("--- TEST 15: ScopeManager direct ---", newLine=true);
    var sm: ScopeManager = ScopeManager();
    sm.declareSimple("x", "int");
    sm.declareSimple("name", "str");
    check("lookup x", "int", sm.lookupType("x"));
    check("lookup name", "str", sm.lookupType("name"));
    check("lookup missing", "", sm.lookupType("missing"));
    check_bool("isDeclared x", true, sm.isDeclared("x"));
    check_bool("isDeclared missing", false, sm.isDeclared("missing"));
    sm.pushScope();
    sm.declareSimple("y", "float");
    check("inner scope y", "float", sm.lookupType("y"));
    check("outer x visible", "int", sm.lookupType("x"));
    sm.popScope();
    check("y gone after pop", "", sm.lookupType("y"));
    check("x still there", "int", sm.lookupType("x"));

    print("--- ALL TESTS DONE ---", newLine=true);
};