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
        print("\n");
    } else {
        print("❌ ", label, newLine=true);
        print("   expected: ", expected, newLine=true);
        print("   actual:   ", actual, newLine=true);
        print("\n");
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

    // ─── TEST 16: try / rescue / fail / rethrow (valid) ─────
    print("--- TEST 16: try rescue valid ---", newLine=true);
    var tc16: TypeChecker = run_tc("function main(didLoad) -> null { try { fail \"boom\"; } rescue, e { var m: str = e; rethrow; }; };");
    check_int("no errors", 0, tc16.errors.length);

    // ─── TEST 17: rethrow outside rescue ────────────────────
    print("--- TEST 17: rethrow outside rescue ---", newLine=true);
    var tc17: TypeChecker = run_tc("function main(didLoad) -> null { rethrow; };");
    check_int("1 error", 1, tc17.errors.length);

    // ─── TEST 18: fail needs a str message ──────────────────
    print("--- TEST 18: fail with non-str ---", newLine=true);
    var tc18: TypeChecker = run_tc("function main(didLoad) -> null { fail 42; };");
    check_int("1 error", 1, tc18.errors.length);

    // ─── TEST 19: unreachable code after return ─────────────
    print("--- TEST 19: unreachable after return ---", newLine=true);
    var tc19: TypeChecker = run_tc("function f() -> int { return 1; var a: int = 2; var b: int = 3; }; function main(didLoad) -> null { };");
    check_int("1 error (reported once)", 1, tc19.errors.length);

    // ─── TEST 20: unreachable code after break ──────────────
    print("--- TEST 20: unreachable after break ---", newLine=true);
    var tc20: TypeChecker = run_tc("function main(didLoad) -> null { while (true) { break; var y: int = 1; }; };");
    check_int("1 error", 1, tc20.errors.length);

    // ─── TEST 21: while(true) with no break needs no return ─
    print("--- TEST 21: while true no break ---", newLine=true);
    var tc21: TypeChecker = run_tc("function f() -> int { while (true) { var a: int = 1; }; }; function main(didLoad) -> null { };");
    check_int("no errors", 0, tc21.errors.length);

    // ─── TEST 22: while(true) WITH a break still needs return ─
    print("--- TEST 22: while true with break ---", newLine=true);
    var tc22: TypeChecker = run_tc("function f() -> int { while (true) { break; }; }; function main(didLoad) -> null { };");
    check_int("1 error", 1, tc22.errors.length);

    // ─── TEST 23: else-if branch that does not return ───────
    print("--- TEST 23: else-if path without return ---", newLine=true);
    var tc23: TypeChecker = run_tc("function f(x: int) -> int { if (x == 1) { return 1; } else if (x == 2) { var a: int = 0; } else { return 3; }; }; function main(didLoad) -> null { };");
    check_int("1 error", 1, tc23.errors.length);

    // ─── TEST 24: float into int is an error ────────────────
    print("--- TEST 24: float into int ---", newLine=true);
    var tc24: TypeChecker = run_tc("function main(didLoad) -> null { var a: int = 2.5; };");
    check_int("1 error", 1, tc24.errors.length);

    // ─── TEST 25: int into float and vast is fine ───────────
    print("--- TEST 25: numeric widening ---", newLine=true);
    var tc25: TypeChecker = run_tc("function main(didLoad) -> null { var f: float = 1; var v: vast = 2; };");
    check_int("no errors", 0, tc25.errors.length);

    // ─── TEST 26: arithmetic on a tag type ──────────────────
    print("--- TEST 26: tag arithmetic ---", newLine=true);
    var tc26: TypeChecker = run_tc("tag Color { RED, GREEN }; function f(c: Color) -> int { return c + 1; }; function main(didLoad) -> null { };");
    check_int("1 error", 1, tc26.errors.length);

    // ─── TEST 27: bitwise needs int or vast ─────────────────
    print("--- TEST 27: bitwise types ---", newLine=true);
    var tc27: TypeChecker = run_tc("function main(didLoad) -> null { var a: int = 6 & 3; var b: int = 1.5 | 2; };");
    check_int("1 error", 1, tc27.errors.length);

    // ─── TEST 28: bitwise NOT ───────────────────────────────
    print("--- TEST 28: unary tilde ---", newLine=true);
    var tc28: TypeChecker = run_tc("function main(didLoad) -> null { var a: int = ~5; var b: bool = ~true; };");
    check_int("1 error", 1, tc28.errors.length);

    // ─── TEST 29: tag access ────────────────────────────────
    print("--- TEST 29: tag access ---", newLine=true);
    var tc29: TypeChecker = run_tc("tag Color { RED, GREEN }; function main(didLoad) -> null { var a: Color = Color.RED; var b: Color = Color.BLUE; };");
    check_int("1 error", 1, tc29.errors.length);

    // ─── TEST 30: nested dict read gives any ────────────────
    print("--- TEST 30: nested dict index ---", newLine=true);
    var tc30: TypeChecker = run_tc("function f(d: dict) -> int { var x: int = d[\"a\"][\"b\"]; return x; }; function main(didLoad) -> null { };");
    check_int("no errors", 0, tc30.errors.length);

    // ─── TEST 31: nested dict write ─────────────────────────
    print("--- TEST 31: nested dict write ---", newLine=true);
    var tc31: TypeChecker = run_tc("function f(d: dict) -> null { d[\"a\"][\"b\"] = 5; }; function main(didLoad) -> null { };");
    check_int("no errors", 0, tc31.errors.length);

    // ─── TEST 32: var declaration rules ─────────────────────
    print("--- TEST 32: 3D, empty 2D, handle arrays ---", newLine=true);
    var tc32: TypeChecker = run_tc("function main(didLoad) -> null { var a: int[][][] = []; var b: int[][] = []; var c: File[] = []; };");
    check_int("3 errors", 3, tc32.errors.length);

    // ─── TEST 33: move-only alias rule ──────────────────────
    print("--- TEST 33: alias class vs tag ---", newLine=true);
    var tc33: TypeChecker = run_tc("tag Color { RED, GREEN }; class Dog { var name: str; function constructor() -> null { this.name = \"\"; }; }; function main(didLoad) -> null { var a: Dog = Dog(); var b: Dog = a; var c: Color = Color.RED; var d: Color = c; };");
    check_int("1 error (class only)", 1, tc33.errors.length);

    // ─── TEST 34: redeclaration vs shadowing ────────────────
    print("--- TEST 34: redeclaration ---", newLine=true);
    var tc34: TypeChecker = run_tc("function main(didLoad) -> null { var x: int = 1; var x: int = 2; if (x == 2) { var x: int = 3; }; };");
    check_int("1 error (inner shadow is fine)", 1, tc34.errors.length);

    // ─── TEST 35: duplicate parameter ───────────────────────
    print("--- TEST 35: duplicate parameter ---", newLine=true);
    var tc35: TypeChecker = run_tc("function f(a: int, a: int) -> int { return a; }; function main(didLoad) -> null { };");
    check_int("1 error", 1, tc35.errors.length);

    // ─── TEST 36: assignment alias rule ─────────────────────
    print("--- TEST 36: alias by assignment ---", newLine=true);
    var tc36: TypeChecker = run_tc("class Dog { var name: str; function constructor() -> null { this.name = \"\"; }; }; function main(didLoad) -> null { var a: Dog = Dog(); var b: Dog = Dog(); b = a; a = a; };");
    check_int("1 error (a = a is fine)", 1, tc36.errors.length);

    // ─── TEST 37: Complex is immutable ──────────────────────
    print("--- TEST 37: Complex immutable ---", newLine=true);
    var tc37: TypeChecker = run_tc("function main(didLoad) -> null { var c: Complex = Complex(1, 2); var r: float = c.real; c.real = 9; c.imag += 5; };");
    check_int("2 errors (reading is fine)", 2, tc37.errors.length);

    // ─── TEST 38: handle stored into a field ────────────────
    print("--- TEST 38: handle into field ---", newLine=true);
    var tc38: TypeChecker = run_tc("class Box { var sb: StringBuilder; function constructor() -> null { this.sb = StringBuilder(); }; }; function main(didLoad) -> null { var s: StringBuilder = StringBuilder(); var b: Box = Box(); b.sb = s; b.sb = StringBuilder(); };");
    check_int("1 error (new handle is fine)", 1, tc38.errors.length);

    // ─── TEST 39: null and mismatch on fields ───────────────
    print("--- TEST 39: field null and mismatch ---", newLine=true);
    var tc39: TypeChecker = run_tc("class Box { var n: int; var s: str; function constructor() -> null { this.n = 0; this.s = \"\"; }; }; function main(didLoad) -> null { var b: Box = Box(); b.n = null; b.s = 5; b.n = 7; };");
    check_int("2 errors (b.n = 7 is fine)", 2, tc39.errors.length);

    // ─── TEST 40: dict inside itself ────────────────────────
    print("--- TEST 40: dict inside itself ---", newLine=true);
    var tc40: TypeChecker = run_tc("function f(d: dict) -> null { d[\"me\"] = d; d[\"x\"] = 5; }; function main(didLoad) -> null { };");
    check_int("1 error (d[x] = 5 is fine)", 1, tc40.errors.length);

    // ─── TEST 41: local body checked, native body skipped ───
    print("--- TEST 41: local vs native function ---", newLine=true);
    var tc41: TypeChecker = run_tc("local function f() -> int { var x: int = true; return 1; }; function ext(a: int) -> int native c_ext; function main(didLoad) -> null { };");
    check_int("1 error (local body checked, native has no body)", 1, tc41.errors.length);

    print("--- ALL TESTS DONE ---", newLine=true);
};