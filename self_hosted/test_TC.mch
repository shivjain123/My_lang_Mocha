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

    // ─── TEST 42: duplicate function shows both signatures ──
    print("--- TEST 42: function overloading ---", newLine=true);
    var tc42: TypeChecker = run_tc("function f(a: int) -> int { return a; }; function f(a: int, b: str) -> null { }; function main(didLoad) -> null { };");
    check_int("1 error", 1, tc42.errors.length);
    check("message starts right", "Illegal redefinition", tc42.errors[0].message.substring(0, 19));

    // ─── TEST 43: members from ALL parents ──────────────────
    print("--- TEST 43: multiple parents ---", newLine=true);
    var tc43: TypeChecker = run_tc("class A { var x: int; function constructor() -> null { this.x = 0; }; }; class B { var y: int; function constructor() -> null { this.y = 0; }; }; class C extends A, B { function constructor() -> null { this.x = 0; }; }; function main(didLoad) -> null { var c: C = C(); var a: int = c.x; var s: str = c.y; };");
    check_int("1 error (c.y is int, from the SECOND parent)", 1, tc43.errors.length);
    var tc43b: TypeChecker = run_tc("class A { var x: int; function constructor() -> null { this.x = 0; }; }; class B { protected var y: int; function constructor() -> null { this.y = 0; }; }; class C extends A, B { function constructor() -> null { this.x = 0; }; function getY() -> int { return this.y; }; }; function main(didLoad) -> null { };");
    check_int("no errors (protected y reachable from a subclass)", 0, tc43b.errors.length);

    // ─── TEST 44: member access on unknown, dict members ────
    print("--- TEST 44: member access basics ---", newLine=true);
    var tc44: TypeChecker = run_tc("function f(d: dict) -> null { var a: int = zzz.foo; var s: str = d.jsonify; var c: dict = d.copy; var b: int = d.bogus; }; function main(didLoad) -> null { };");
    check_int("2 errors (zzz undeclared once, d.bogus)", 2, tc44.errors.length);

    // ─── TEST 45: set methods, tag .name, unknown member ────
    print("--- TEST 45: member access rest ---", newLine=true);
    var tc45: TypeChecker = run_tc("tag Color { RED, GREEN }; class Dog { var name: str; function constructor() -> null { this.name = \"\"; }; }; function f(c: Color, s: set<int>, b: set<bool>, d: Dog) -> null { var n: str = c.name; var x: int = c.bogus; var m: int = s.min; var j: float = s.jaccard; var q: bool = b.min; var z: int = d.nothing; }; function main(didLoad) -> null { };");
    check_int("3 errors (c.bogus, b.min, d.nothing)", 3, tc45.errors.length);
    check("set<bool> min message", "min()/max() not defined", tc45.errors[1].message.substring(0, 22));

    // ─── TEST 46: too many arguments ────────────────────────
    print("--- TEST 46: too many arguments ---", newLine=true);
    var tc46: TypeChecker = run_tc("class Dog { function constructor(n: int) -> null { }; function bark(a: int) -> null { }; }; function g(a: int) -> int { return a; }; function main(didLoad) -> null { var x: int = g(1, 2); var d: Dog = Dog(1, 2); d.bark(1, 2); var y: int = g(1); var d2: Dog = Dog(1); d2.bark(1); };");
    check_int("3 errors (function, constructor, method)", 3, tc46.errors.length);
    var tc46b: TypeChecker = run_tc("class Dog { function constructor(n: int) -> null { }; }; class Puppy extends Dog { var age: int; }; function main(didLoad) -> null { var p: Puppy = Puppy(1, 2); };");
    check_int("1 error (inherited constructor)", 1, tc46b.errors.length);

    // ─── TEST 47: Complex(a, b) arguments ───────────────────
    print("--- TEST 47: Complex arguments ---", newLine=true);
    var tc47: TypeChecker = run_tc("function main(didLoad) -> null { var a: Complex = Complex(1, 2); var b: Complex = Complex(1, 2, 3); var c: Complex = Complex(\"x\", 2.5); };");
    check_int("2 errors (3 arguments, str argument)", 2, tc47.errors.length);

    // ─── TEST 48: dict merge / jsonify / copy calls ─────────
    print("--- TEST 48: dict method calls ---", newLine=true);
    var tc48: TypeChecker = run_tc("function f(d: dict, e: dict) -> null { d.merge(e); d.merge(e, override=true); var j: str = d.jsonify(); var c: dict = d.copy(); d.merge(5); d.merge(e, override=1); d.merge(e, force=true); d.bogus(); }; function main(didLoad) -> null { };");
    check_int("4 errors", 4, tc48.errors.length);

    // ─── TEST 49: 2D occs/push, set retype/subset, tag call ─
    print("--- TEST 49: more method calls ---", newLine=true);
    var tc49: TypeChecker = run_tc("tag Color { RED, GREEN }; function f(m: int[][], r: int[], s: set<int>, t: set<str>, c: Color) -> null { var a: int = m.occs(1, row=0); var b: int = m.occs(1); m.push(r); m.push(r, col=true); m.push(r, r); s.retype(float); s.retype(foo); var x: bool = s.subset(s); var y: bool = s.subset(t); var n: str = c.name(); var z: str = c.nope(); }; function main(didLoad) -> null { };");
    check_int("5 errors", 5, tc49.errors.length);

    // ─── TEST 50: array copy and str dictify ────────────────
    print("--- TEST 50: array copy, str dictify ---", newLine=true);
    var tc50: TypeChecker = run_tc("function f(a: int[], s: str) -> null { var b: int[] = a.copy(); var d: dict = s.dictify(); var c: str[] = a.copy(); }; function main(didLoad) -> null { };");
    check_int("1 error (a.copy() is int[], not str[])", 1, tc50.errors.length);

    // ─── TEST 51: private/protected method calls ────────────
    print("--- TEST 51: method visibility ---", newLine=true);
    var tc51: TypeChecker = run_tc("class Dog { private function secret() -> int { return 1; }; protected function guarded() -> int { return 2; }; function open() -> int { return this.secret() + this.guarded(); }; }; class Puppy extends Dog { function fine() -> int { return this.guarded(); }; }; function main(didLoad) -> null { var d: Dog = Dog(); var a: int = d.open(); var b: int = d.secret(); var c: int = d.guarded(); };");
    check_int("2 errors (secret and guarded from outside; calls inside classes are fine)", 2, tc51.errors.length);

    // ─── TEST 52: set jaccard / dice / overlap ──────────────
    print("--- TEST 52: set similarity calls ---", newLine=true);
    var tc52: TypeChecker = run_tc("function f(s: set<int>, t: set<str>) -> null { var a: float = s.jaccard(s); var b: float = s.overlap(t); var c: int = s.dice(s); }; function main(didLoad) -> null { };");
    check_int("2 errors (overlap with set<str>, dice returns float not int)", 2, tc52.errors.length);

    // ─── TEST 53: interface registry ────────────────────────
    print("--- TEST 53: interface implements ---", newLine=true);
    var tc53: TypeChecker = run_tc("interface Shape { function area() -> int; }; class Sq implements Shape { function constructor() -> null { }; function area() -> int { return 1; }; }; class Bad implements Shape { function constructor() -> null { }; }; function main(didLoad) -> null { };");
    check_int("1 error (Bad is missing area; Sq is fine)", 1, tc53.errors.length);

    // ─── TEST 54: interface signatures ──────────────────────
    print("--- TEST 54: interface conformance ---", newLine=true);
    var tc54: TypeChecker = run_tc("interface Shape { function area(a: int) -> int; function label(a: int) -> str; function size(a: int, b: int) -> int; }; class Bad implements Shape { function constructor() -> null { }; function area(a: str) -> int { return 1; }; function label(a: int) -> int { return 1; }; function size(a: int) -> int { return 1; }; }; class Good implements Shape { function constructor() -> null { }; function area(a: int) -> int { return 1; }; function label(a: int) -> str { return \"\"; }; function size(a: int, b: int) -> int { return 1; }; }; function main(didLoad) -> null { };");
    check_int("3 errors (Bad: param type, return type, param count; Good is fine)", 3, tc54.errors.length);

    // ─── TEST 55: diamond fields ────────────────────────────
    print("--- TEST 55: diamond problem ---", newLine=true);
    var tc55: TypeChecker = run_tc("class A { var x: int; function hi() -> int { return 1; }; function constructor() -> null { this.x = 0; }; }; class B { var x: int; function hi() -> int { return 2; }; function constructor() -> null { this.x = 0; }; }; class C extends A, B { function constructor() -> null { }; }; function main(didLoad) -> null { };");
    check_int("1 error (field x from A and B; the shared method hi is only recorded)", 1, tc55.errors.length);

    // ─── TEST 56: diamond method call ───────────────────────
    print("--- TEST 56: diamond call site ---", newLine=true);
    var tc56: TypeChecker = run_tc("class A { function hi() -> int { return 1; }; function constructor() -> null { }; }; class B { function hi() -> int { return 2; }; function only() -> int { return 3; }; function constructor() -> null { }; }; class C extends A, B { function constructor() -> null { }; }; function main(didLoad) -> null { var c: C = C(); var a: int = c.hi(); var b: int = c.only(); };");
    check_int("1 error (c.hi() is ambiguous; c.only() is fine)", 1, tc56.errors.length);

    // ─── TEST 57: didLoad not allowed on a method ───────────
    print("--- TEST 57: didLoad on a method ---", newLine=true);
    var tc57: TypeChecker = run_tc("class App { function constructor() -> null { }; function runApp(didLoad) -> null { }; }; function main(didLoad) -> null { };");
    check_int("1 error (didLoad on App.runApp; main is the only entry point)", 1, tc57.errors.length);

    // ─── TEST 58: shared field ──────────────────────────────
    print("--- TEST 58: shared field ---", newLine=true);
    var tc58: TypeChecker = run_tc("class A { shared var x: int; var y: int; function constructor() -> null { this.y = 0; }; }; function main(didLoad) -> null { };");
    check_int("1 error (shared var x; plain var y is fine)", 1, tc58.errors.length);

    // ─── TEST 59: weak field parses ─────────────────────────
    print("--- TEST 59: weak field ---", newLine=true);
    var tc59: TypeChecker = run_tc("class Node { weak var parent: Node; var v: int; function constructor() -> null { this.v = 0; }; }; function main(didLoad) -> null { };");
    check_int("no errors (weak var parses; the checker rule comes next)", 0, tc59.errors.length);

    // ─── TEST 60: weak field types ──────────────────────────
    print("--- TEST 60: weak field rule ---", newLine=true);
    var tc60: TypeChecker = run_tc("class Node { weak var parent: Node; weak var n: int; weak var kids: Node[]; function constructor() -> null { }; }; function main(didLoad) -> null { };");
    check_int("2 errors (weak int, weak Node[]; weak Node is fine)", 2, tc60.errors.length);

    // ─── TEST 61: dict literal parses ───────────────────────
    print("--- TEST 61: dict literal ---", newLine=true);
    var tc61: TypeChecker = run_tc("function main(didLoad) -> null { var a: dict = {}; var b: dict = {\"x\": 1, \"y\": 2,}; };");
    check_int("no errors (parses; the checker rule comes next)", 0, tc61.errors.length);

    // ─── TEST 62: dict literal rules ────────────────────────
    print("--- TEST 62: dict literal check ---", newLine=true);
    var tc62: TypeChecker = run_tc("function main(didLoad) -> null { var a: dict = {\"x\": 1, \"y\": 2}; var b: dict = {1: 2}; var c: int = {\"k\": 1}; var d: dict = {\"k\": zzz}; };");
    check_int("3 errors (int key, dict into int, undeclared zzz)", 3, tc62.errors.length);

    // ─── TEST 63: set literal parses ────────────────────────
    print("--- TEST 63: set literal ---", newLine=true);
    var tc63: TypeChecker = run_tc("function main(didLoad) -> null { var a: set<int> = <1, 2, 3>; var b: set<str> = <\"x\", \"y\",>; };");
    check_int("no errors (parses; the checker rule comes next)", 0, tc63.errors.length);

    // ─── TEST 64: set literal rules ─────────────────────────
    print("--- TEST 64: set literal check ---", newLine=true);
    var tc64: TypeChecker = run_tc("function main(didLoad) -> null { var a: set<int> = <1, 2, 3>; var b: set<int> = <1, \"x\">; var c: set<str> = <1, 2>; };");
    check_int("2 errors (mixed elements; set<int> into set<str>)", 2, tc64.errors.length);

    // ─── TEST 65: for each over a set ───────────────────────
    print("--- TEST 65: for each in <set> ---", newLine=true);
    var tc65: TypeChecker = run_tc("function f(s: set<int>, n: int) -> null { for each x in <s> { var y: int = x; var z: str = x; }; for each q in <n> { }; }; function main(didLoad) -> null { };");
    check_int("2 errors (x is int, not str; <n> is not a set)", 2, tc65.errors.length);

    // ─── TEST 66: library qualified call ────────────────────
    print("--- TEST 66: lib qualified call ---", newLine=true);
    var tc66: TypeChecker = run_tc("function main(didLoad) -> null { var a: float = \"mocha-math\".sin(45.0); var s: str = \"hello\"; var b: float = \"mocha-math\".cos(zzz); };");
    check_int("1 error (zzz undeclared; plain string and known call are fine)", 1, tc66.errors.length);

    // ─── TEST 67: range ends ────────────────────────────────
    print("--- TEST 67: range ends ---", newLine=true);
    var tc67: TypeChecker = run_tc("function main(didLoad) -> null { var n: int = 5; match (n) { case 1..9: var a: int = 1; case 1..\"z\": var b: int = 2; default: var c: int = 3; }; };");
    check_int("1 error (1..\"z\" mixes int and str; 1..9 is fine)", 1, tc67.errors.length);

    print("--- ALL TESTS DONE ---", newLine=true);
};