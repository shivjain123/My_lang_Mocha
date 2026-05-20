"""
    Mocha v0.5 — Consolidated Tests
    
    Entry point: runAllTests(didLoad)
    All sections are normal functions called from inside.
    Commented-out blocks preserved for reference.
    
    Sections:
     1.  Array Return + str-to-int cast
     2.  Break
     4.  Continue
     5.  Diamond Virtual Inheritance
     6.  Dictionary
     7.  Do-While
     8.  extend str
     9.  extends + implements
    10.  for each
    11.  from import wildcard
    12.  Inline bool return
    13.  MochaMath — full (rounding, trig, roots, logs, calculus, cubrot)
    14.  MochaString — full
    15.  Modulo / Division
    16.  Array occs (1D + 2D)
    17.  Sets
    18.  this pointer
    19.  alloc int[n]           ← NEW v0.5
    20.  Sort with closure      ← NEW v0.5
    21.  ctype FFI              ← NEW v0.5
    22.  File I/O FFI           ← NEW v0.5
    23.  Filter lambda (inline) ← NEW v0.5
    24.  Reduce lambda          ← NEW v0.5
    25.  mocha-SymCha — full    ← NEW v0.5
    26.  vast (int64)           ← NEW v0.5
    27.  mocha-processing       ← NEW v0.4
"""


// ============================================================
// IMPORTS
// ============================================================

import mochaString from "mocha-string";
from "mocha-SymCha" import *;
import mochaProcessing from "mocha-processing";
from "mocha-math" import *;


// ============================================================
// FFI DECLARATIONS
// ============================================================

function puts(s: str) -> int native puts;
function isalpha(c: int) -> int native mocha_wrap_isalpha;
function isdigit(c: int) -> int native mocha_wrap_isdigit;
function toupper(c: int) -> int native mocha_wrap_toupper;
function tolower(c: int) -> int native mocha_wrap_tolower;
function hypot(x: float, y: float) -> float native mocha_wrap_hypot;
function fmod(x: float, y: float) -> float native mocha_wrap_fmod;
function clock_now() -> int native mocha_wrap_clock;
function fopen(path: str, mode: str) -> null native fopen;
function fclose(file: null) -> int native fclose;
function fputs(s: str, file: null) -> int native fputs;


// ============================================================
// CLASSES & INTERFACES
// ============================================================

interface Speakable {
    function speak() -> null;
};

class Animal {
    function speak() -> null {
        print("...", newLine=true);
    };
    function breathe() -> null {
        print("Animal breathes", newLine=true);
    };
};

class Bird extends Animal {
    function breathe() -> null {
        print("Bird breathes", newLine=true);
    };
};

class Horse extends Animal {
    function breathe() -> null {
        print("Horse breathes", newLine=true);
    };
};

class Pegasus extends Bird, Horse {};

class Duck extends Animal implements Speakable {
    function speak() -> null {
        print("Quack!", newLine=true);
    };
};

class Counter {
    var count: int = 0;

    function increment() -> null {
        this.count = this.count + 1;
    };

    function getCount() -> int {
        return this.count;
    };
};


// ============================================================
// HELPER FUNCTIONS (inline lambda tests)
// ============================================================

function isZero(n: int) -> bool {
    return n == 0;
};

function filter_inline(arr: int[], pred: lambda) -> int[] {
    var result: int[] = [];
    for each x in arr {
        if (pred(x)) {
            result.push(x);
        };
    };
    return result;
};

function reduce_inline(arr: int[], combiner: lambda, init: int) -> int {
    var acc: int = init;
    for each x in arr {
        acc = combiner(acc, x);
    };
    return acc;
};


// ============================================================
// SECTION 1 — Array Return + str-to-int cast
// ============================================================

function section_arrayCast() -> null {
    print("--- 1. str-to-int cast ---", newLine=true);
    var s: str = "42";
    var n: int = s.toInt();
    print(n, newLine=true);  // 42
};


// ============================================================
// SECTION 2 — Break
// ============================================================

function section_break() -> null {
    print("--- 2. Break ---", newLine=true);
    var i: int = 0;
    while (i < 10) {
        if (i == 5) {
            break;
        };
        print(i, newLine=true);
        i = i + 1;
    };
};


"""// ============================================================
// SECTION 3 — char
// ============================================================

function section_char() -> null {
    print("--- 3. char ---", newLine=true);

    var s: str = "hello";
    var c: char = s.charAt(0);
    print(c, newLine=true);          // h

    var cs: str = str(c);
    print(cs, newLine=true);         // h

    const LOWER: char[] = ['a','b','c','d','e','f','g','h','i','j','k','l','m',
                            'n','o','p','q','r','s','t','u','v','w','x','y','z'];
    print(LOWER[0], newLine=true);   // a
    print(LOWER[25], newLine=true);  // z
    var r: bool = c == LOWER[7];    // h is index 7
    print(r, newLine=true);          // true
};"""


// ============================================================
// SECTION 4 — Continue
// ============================================================

function section_continue() -> null {
    print("--- 4. Continue ---", newLine=true);
    var i: int = 0;
    while (i < 10) {
        i = i + 1;
        if (i == 5) {
            continue;
        };
        print(i, newLine=true);
    };
};


// ============================================================
// SECTION 5 — Diamond Virtual Inheritance
// ============================================================

function section_diamond() -> null {
    print("--- 5. Diamond Virtual Inheritance ---", newLine=true);
    var p: Pegasus = Pegasus();
    Bird.p.breathe();
    Horse.p.breathe();
};


// ============================================================
// SECTION 6 — Dictionary
// ============================================================

function section_dict() -> null {
    print("--- 6. Dictionary ---", newLine=true);

    var d: dict = {
        "name": "Shiv",
        "age": 16,
        "gpa": 9.8,
        "active": true,
    };

    print(d["name"], newLine=true);   // Shiv
    print(d["age"], newLine=true);    // 16

    d["name"] = "Mocha";
    print(d["name"], newLine=true);   // Mocha

    d["lang"] = "Mocha Lang";
    print(d["lang"], newLine=true);   // Mocha Lang

    print(d.has("name"), newLine=true);    // true
    print(d.has("missing"), newLine=true); // false
    print(d.length, newLine=true);         // 5

    var keys: str[] = d.allKeys();
    for each k in keys {
        print(k, newLine=true);
    };

    var vals: str[] = d.allValues();
    for each v in vals {
        print(v, newLine=true);
    };

    d.remove("age");
    print(d.length, newLine=true);    // 4

    var nest: dict = {
        "person": {
            "name": "Shiv",
            "age": 16,
        },
    };
    print(nest["person"]["name"], newLine=true);  // Shiv
    print(nest["person"]["age"], newLine=true);   // 16

    // fatal error tests — uncomment to test error messages
    """
    d.clean();
    print(d["naem"], newLine=true);  // MochaRuntimeError: did you mean 'name'?
    """
};


// ============================================================
// SECTION 7 — Do-While
// ============================================================

function section_doWhile() -> null {
    print("--- 7. Do-While ---", newLine=true);
    var i: int = 0;
    do {
        print(i, newLine=true);
        i = i + 1;
    } while (i < 5);
};


// ============================================================
// SECTION 8 — extend str (contains)
// ============================================================

function section_extend() -> null {
    print("--- 8. extend str ---", newLine=true);
    var s: str = "hello world";
    print(s.contains("world"), newLine=true);  // true
    print(s.contains("xyz"), newLine=true);    // false
};


// ============================================================
// SECTION 9 — extends + implements
// ============================================================

function section_extendsImplements() -> null {
    print("--- 9. extends + implements ---", newLine=true);
    var a: Animal = Animal();
    var d: Duck = Duck();
    a.speak();   // ...
    d.speak();   // Quack!
};


// ============================================================
// SECTION 10 — for each
// ============================================================

function section_forEach() -> null {
    print("--- 10. for each ---", newLine=true);

    var nums: int[] = [1, 2, 3, 4, 5];
    for each n in nums {
        print(n, newLine=true);
    };

    var names: str[] = ["Shiv", "Mocha", "Lang"];
    for each name in names {
        print(name, newLine=true);
    };

    var floats: float[] = [1.1, 2.2, 3.3];
    for each f in floats {
        print(f, newLine=true);
    };
};


// ============================================================
// SECTION 11 — from import wildcard
// ============================================================

function section_fromImportWildcard() -> null {
    print("--- 11. from import wildcard ---", newLine=true);
    print(PI, newLine=true);
    print(E, newLine=true);
    print(TAU, newLine=true);
    print(PHI, newLine=true);
};


// ============================================================
// SECTION 12 — Inline bool return
// ============================================================

function section_inlineReturn() -> null {
    print("--- 12. Inline bool return ---", newLine=true);
    print(isZero(0), newLine=true);  // true
    print(isZero(5), newLine=true);  // false
};


// ============================================================
// SECTION 13 — MochaMath — full
// ============================================================

function section_mathFull() -> null {
    print("--- 13. MochaMath ---", newLine=true);

    puts("--- abs ---");
    puts(str(abs(3.5)));    // 3.5
    puts(str(abs(-3.5)));   // 3.5
    puts(str(abs(0.0)));    // 0

    puts("--- round / rdown / rup ---");
    puts(str(round(2.5)));  // 3
    puts(str(round(-2.5))); // -2
    puts(str(rdown(3.9)));  // 3
    puts(str(rdown(-3.1))); // -4
    puts(str(rup(3.1)));    // 4
    puts(str(rup(-3.9)));   // -3

    puts("--- pow ---");
    puts(str(fast_pow(2.0, 0)));    // 1
    puts(str(fast_pow(2.0, 10)));   // 1024
    puts(str(fast_pow(2.0, -1)));   // 0.5
    puts(str(fast_pow(-3.0, 3)));   // -27
    puts(str(c_pow(2.0, 0.5)));     // 1.41421
    puts(str(c_pow(10.0, 3.0)));    // 1000

    puts("--- sin / cos ---");
    puts(str((0.0).sin(mes=RAD)));     // 0
    puts(str((90.0).sin(mes=DEG)));    // 1
    puts(str((0.0).cos(mes=RAD)));     // 1
    puts(str((90.0).cos(mes=DEG)));    // ~0

    puts("--- inv_sin / inv_cos / inv_tan ---");
    puts((1.0).inv_sin().toString());    // 1.5707+0im
    puts((1.0).inv_cos().toString());    // 0+0im
    puts(str((1.0).inv_tan()));          // ~0.7853

    puts("--- inv_sin / inv_cos outside [-1, 1] ---");
    puts((2.0).inv_sin().toString());    // complex result
    puts((2.0).inv_cos().toString());    // complex result

    puts("--- tan ---");
    puts(str((0.0).tan(mes=RAD)));     // 0
    puts(str((45.0).tan(mes=DEG)));    // 1
    puts(str((90.0).tan(mes=DEG)));    // inf

    puts("--- sqrt ---");
    puts((4.0).sqrt().toString());     // 2+0im
    puts((2.0).sqrt().toString());     // 1.41421+0im
    puts((0.0).sqrt().toString());     // 0+0im
    puts((-1.0).sqrt().toString());    // 0+1im

    puts("--- cubrot ---");
    puts(str((27.0).cubrot()));    // 3
    puts(str((8.0).cubrot()));     // 2
    puts(str((-27.0).cubrot()));   // -3

    puts("--- log / log2 / log10 ---");
    puts((2.71828182845904).log().toString());   // ~1+0im
    puts((1.0).log().toString());               // 0+0im
    puts((0.0).log().toString());               // -inf+0im
    puts((-1.0).log().toString());              // 0+3.14159im
    puts((8.0).log2().toString());              // 3+0im
    puts((0.0).log2().toString());              // -inf+0im
    puts((100.0).log10().toString());           // 2+0im
    puts((0.0).log10().toString());             // -inf+0im

    puts("--- complex pow ---");
    var ci: Complex = 0.0 + 1.0im;
    puts(complex_pow(ci, 2.0).toString());      // -1+0im  (i² = -1)
    puts(complex_pow(ci, 0.5).toString());      // complex result

    puts("--- INF detection ---");
    var t90: float = (90.0).tan(mes=DEG);
    puts(str(t90));   // inf

    puts("--- calculus ---");
    var d1: float = (2.0).derivative(lambda (x: float) -> float: x * x);
    puts(str(d1));   // ~4.0

    var d2: float = (1.0).derivative(lambda (x: float) -> float: x * x * x);
    puts(str(d2));   // ~3.0

    var i1: float = integral(lambda (x: float) -> float: x * x, 0.0, 3.0);
    puts(str(i1));   // ~9.0

    var i2: float = integral(lambda (x: float) -> float: 1.0, 0.0, 5.0);
    puts(str(i2));   // 5.0

    var l1: float = (2.0).limit(lambda (x: float) -> float: x * x);
    puts(str(l1));   // ~4.0

    var li: float = limit_inf(lambda (x: float) -> float: 1.0 / x);
    puts(str(li));   // ~0.0
};


// ============================================================
// SECTION 14 — MochaString — full
// ============================================================

function section_mochaString() -> null {
    print("--- 14. MochaString ---", newLine=true);

    var s: str = "  Hello World  ";
    var ripped: str = s.rip();
    print(ripped, newLine=true);                    // Hello World
    print(ripped.toUpper(), newLine=true);          // HELLO WORLD
    print(ripped.toLower(), newLine=true);          // hello world
    print(ripped.contains("World"), newLine=true);  // true
    print(ripped.startsWith("Hello"), newLine=true);// true
    print(ripped.endsWith("World"), newLine=true);  // true
    print(ripped.indexOf("World"), newLine=true);   // 6
    print(ripped.reverse(), newLine=true);          // dlroW olleH
    print(ripped.isPalindrome(), newLine=true);     // false
    print(ripped.occurs("l"), newLine=true);        // 3
    print(ripped.substring(6, 11), newLine=true);   // World

    var parts: str[] = ripped.split(" ");
    print(parts[0], newLine=true);  // Hello
    print(parts[1], newLine=true);  // World

    var s2: str = "hello world world";
    print(s2.replace("world", "Mocha", 1), newLine=true);
    print(s2.replaceAll("world", "Mocha"), newLine=true);

    var s3: str = "42";
    var s4: str = "3.14";
    print(s3.toInt(), newLine=true);
    print(s4.toFloat(), newLine=true);
};


// ============================================================
// SECTION 15 — Modulo / Division
// ============================================================

function section_modDiv() -> null {
    print("--- 15. Modulo ---", newLine=true);
    print(10 % 3, newLine=true);    // 1
    print(15 % 5, newLine=true);    // 0
    print(10.5 % 3.0, newLine=true); // 1.5
};


// ============================================================
// SECTION 16 — Array occs (1D + 2D)
// ============================================================

function section_occs() -> null {
    print("--- 16. Array occs ---", newLine=true);

    var arr: int[] = [1, 2, 3, 1, 4, 1, 2];
    print(arr.occs(1), newLine=true);  // 3
    print(arr.occs(2), newLine=true);  // 2
    print(arr.occs(9), newLine=true);  // 0

    var grid: int[][] = [[1, 2, 1], [1, 3, 4], [2, 2, 1]];
    print(grid.occs(1, row=0), newLine=true);      // 2
    print(grid.occs(1, col=0), newLine=true);      // 2
    print(grid.occs(1, row=[0, 2]), newLine=true); // 4
    print(grid.occs(1, col=[0, 2]), newLine=true); // 4
};


// ============================================================
// SECTION 17 — Sets
// ============================================================

function section_sets() -> null {
    print("--- 17. Sets ---", newLine=true);

    var s1: set<int> = <1, 2, 3, 4, 5>;
    for each x in <s1> {
        print(x, newLine=true);
    };

    var s2: set<float> = <1.1, 2.2, 3.3>;
    for each f in <s2> {
        print(f, newLine=true);
    };

    var s3: set<str> = <"hello", "world", "mocha">;
    for each w in <s3> {
        print(w, newLine=true);
    };

    var s4: set<int> = <10, 20, 30>;
    s4.insert(40);
    for each n in <s4> {
        print(n, newLine=true);
    };

    // set operations
    var sa: set<int> = <1, 2, 3, 4, 5>;
    var sb: set<int> = <4, 5, 6, 7>;
    var u: set<int> = sa.union(sb);
    print(u.size, newLine=true);           // 7
    var inter: set<int> = sa.intersect(sb);
    print(inter.size, newLine=true);       // 2
    var d: set<int> = sa.diff(sb);
    print(d.size, newLine=true);           // 5

    var sn: set<int> = <1, 2, 3>;
    sn.negate();
    print(sn.has(-1), newLine=true);       // true
    sn.clean();
    print(sn.size, newLine=true);          // 0
};


// ============================================================
// SECTION 18 — this pointer
// ============================================================

function section_this() -> null {
    print("--- 18. this pointer ---", newLine=true);
    var c: Counter = Counter();
    c.increment();
    c.increment();
    print(c.getCount(), newLine=true);  // 2
};


// ============================================================
// SECTION 19 — alloc int[n]   ← NEW v0.5
// ============================================================

function section_alloc() -> null {
    print("--- 19. alloc int[n] ---", newLine=true);
    var n: int = 5;
    var arr: int[] = alloc int[n];
    arr.push(1);
    arr.push(2);
    arr.push(3);
    print(arr.length, newLine=true);  // 3
    print(arr[0], newLine=true);      // 1
    print(arr[2], newLine=true);      // 3
};


// ============================================================
// SECTION 20 — Sort with closure capture   ← NEW v0.5
// ============================================================

function section_sortClosure() -> null {
    print("--- 20. Sort with closure ---", newLine=true);

    var nums: int[] = [5, 2, 8, 1, 9, 3];
    var multiplier: int = 2;
    sort(nums, lambda (a: int, b: int) -> bool: a * multiplier > b * multiplier);
    print(nums[0], newLine=true);   // 9 (descending)
    print(nums[5], newLine=true);   // 1

    var offset: int = 10;
    sort(nums, lambda (a: int, b: int) -> bool: a + offset < b + offset);
    print(nums[0], newLine=true);   // 1 (ascending)

    var prices: float[] = [3.5, 1.2, 8.9, 2.1, 5.5];
    var scale: float = 2.0;
    sort(prices, lambda (a: float, b: float) -> bool: a * scale > b * scale);
    print(prices[0], newLine=true);   // 8.9
    print(prices[4], newLine=true);   // 1.2

    var words: str[] = ["banana", "apple", "cherry", "date"];
    sort(words, lambda (a: str, b: str) -> bool: a > b);
    for each g in words {
        print(g, newLine=true);  // descending alphabetical
    };
};


// ============================================================
// SECTION 21 — ctype FFI   ← NEW v0.5
// ============================================================

function section_ctypeFFI() -> null {
    puts("--- 21. ctype FFI ---");
    puts(str(isalpha(65)));   // 1 (A is alpha)
    puts(str(isdigit(51)));   // 1 (3 is digit)
    puts(str(toupper(97)));   // 65 (a → A)
    puts(str(tolower(65)));   // 97 (A → a)

    var h: float = hypot(3.0, 4.0);
    puts(str(h));             // 5.0

    var m: float = fmod(10.0, 3.0);
    puts(str(m));             // 1.0

    puts(str(clock_now()));   // ticks since program start
};


// ============================================================
// SECTION 22 — File I/O FFI   ← NEW v0.5
// ============================================================

function section_fileIO() -> null {
    puts("--- 22. File I/O FFI ---");
    var f: null = fopen("mocha_test_output.txt", "w");
    fputs("Hello from Mocha file I/O!", f);
    fclose(f);
    puts("File written: mocha_test_output.txt");
};


// ============================================================
// SECTION 23 — Filter lambda (inline)   ← NEW v0.5
// ============================================================

function section_filterInline() -> null {
    print("--- 23. Filter lambda ---", newLine=true);
    var nums: int[] = [5, 2, 8, 1, 9, 3];
    var threshold: int = 4;
    var filtered: int[] = filter_inline(nums, lambda (x: int) -> bool: x > threshold);
    print(filtered.length, newLine=true);  // 3 (5, 8, 9)
    print(filtered[0], newLine=true);      // 5
};


// ============================================================
// SECTION 24 — Reduce lambda   ← NEW v0.5
// ============================================================

function section_reduceInline() -> null {
    print("--- 24. Reduce lambda ---", newLine=true);
    var nums: int[] = [1, 2, 3, 4, 5];

    var sum: int = reduce_inline(nums, lambda (a: int, b: int) -> int: a + b, 0);
    print(sum, newLine=true);      // 15

    var product: int = reduce_inline(nums, lambda (a: int, b: int) -> int: a * b, 1);
    print(product, newLine=true);  // 120
};


// ============================================================
// SECTION 25 — mocha-SymCha — full   ← NEW v0.5
// ============================================================

function section_symcha() -> null {
    print("--- 25. mocha-SymCha ---", newLine=true);

    var x: Expr = var_e("x");

    // Expression: x² + 3x + 1
    var expr: Expr = add(add(pow_e(x, num(2.0)), mul(num(3.0), x)), num(1.0));
    print(sym_print(expr), newLine=true);  // x² + 3x + 1

    // d/dx → 2x + 3
    var deriv: Expr = sym_simplify(sym_diff(expr, "x"));
    print(sym_print(deriv), newLine=true);  // 2x + 3

    // f(2) = 11
    print(sym_eval(expr, "x", 2.0), newLine=true);   // 11.0

    // f'(2) = 7
    print(sym_eval(deriv, "x", 2.0), newLine=true);  // 7.0

    // critical point: 2x + 3 = 0 → x = -1.5
    print(sym_eval(deriv, "x", -1.5), newLine=true); // 0.0

    // sin(x) and d/dx(sin(x)) at x=0
    var s: Expr = sin_e(x);
    print(sym_eval(s, "x", 0.0), newLine=true);                          // 0.0
    print(sym_eval(sym_simplify(sym_diff(s, "x")), "x", 0.0), newLine=true); // 1.0

    // Integration
    print(sym_print(sym_simplify(sym_antidv(pow_e(x, num(2.0)), "x"))) + " + C", newLine=true);  // x³/3 + C
    print(sym_print(sym_simplify(sym_antidv(sin_e(x), "x"))) + " + C", newLine=true);            // -cos(x) + C
    print(sym_print(sym_simplify(sym_antidv(cos_e(x), "x"))) + " + C", newLine=true);            // sin(x) + C
    print(sym_print(sym_simplify(sym_antidv(exp_e(x), "x"))) + " + C", newLine=true);            // exp(x) + C

    // Definite — symbolic
    print(sym_integral(pow_e(x, num(2.0)), "x", 0.0, 3.0), newLine=true);  // 9.0

    // Definite — numerical fallback
    print(sym_integral(mul(x, sin_e(x)), "x", 0.0, PI), newLine=true);     // ~3.14159

    // Logarithmic differentiation
    print(sym_print(sym_simplify(sym_diff(pow_e(x, x), "x"))), newLine=true);           // x^x·ln(x) + 1
    print(sym_print(sym_simplify(sym_diff(pow_e(num(2.0), x), "x"))), newLine=true);    // 2^x·ln(2)
    print(sym_print(sym_simplify(sym_diff(pow_e(x, num(2.0)), "x"))), newLine=true);    // 2x
};


// ============================================================
// SECTION 26 — vast (int64)   ← NEW v0.5
// ============================================================

function section_vast() -> null {
    print("--- 26. vast ---", newLine=true);

    var n: vast = 12586269025;
    print(n, newLine=true);           // 12586269025

    var m: vast = n + 1;
    print(m, newLine=true);           // 12586269026

    print(str(n), newLine=true);      // "12586269025"

    // Arithmetic promotion
    var v: vast = 9999999999;
    var i: int = 1;
    var result: vast = v + i;         // vast + int → vast
    print(result, newLine=true);      // 10000000000

    var fib50: vast = 12586269025;
    print(fib50, newLine=true);       // fib(50) correct value
};


// ============================================================
// SECTION 27 — mocha-processing   ← NEW v0.4
// ============================================================

function section_processing() -> null {
    print("--- 27. mocha-processing ---", newLine=true);

    var nums: int[] = [1, 2, 3, 4, 5];
    var prices: float[] = [1.5, 2.5, 3.5, 4.5];
    var words: str[] = ["apple", "banana", "cherry", "date"];
    var threshold: int = 3;
    var minPrice: float = 2.0;

    var filtered: int[] = filter(nums, lambda (x: int) -> bool: x > threshold);
    print(filtered.length, newLine=true);   // 2 (4, 5)

    var filteredF: float[] = filterFloat(prices, lambda (x: float) -> bool: x > minPrice);
    print(filteredF.length, newLine=true);  // 2 (3.5, 4.5)

    var doubled: int[] = map(nums, lambda (x: int) -> int: x * 2);
    print(doubled[4], newLine=true);        // 10

    var mappedF: float[] = mapFloat(prices, lambda (x: float) -> float: x * 2.0);
    print(mappedF[0], newLine=true);
    print(mappedF[1], newLine=true);
    print(mappedF[2], newLine=true);
    print(mappedF[3], newLine=true);

    var mappedS: str[] = mapStr(words, lambda (x: str) -> str: x.toUpper());
    print(mappedS[0], newLine=true);        // APPLE

    var sum: int = reduce(nums, lambda (a: int, b: int) -> int: a + b, 0);
    print(sum, newLine=true);              // 15

    var total: float = reduceFloat(prices, lambda (a: float, b: float) -> float: a + b, 0.0);
    print(total, newLine=true);            // 12.0

    var joined: str = reduceStr(words, lambda (a: str, b: str) -> str: a + "," + b, "");
    print(joined, newLine=true);           // apple,banana,cherry,date
};


// ============================================================
// ENTRY POINT
// ============================================================

function runAllTests(didLoad) -> null {
    print("Mocha v0.5 — All Tests", newLine=true);
    print("==========================", newLine=true);

    section_arrayCast();
    section_break();
    //section_char(); #Does not work anymore. Has been decomissioned
    section_continue();
    section_diamond();
    section_dict();
    section_doWhile();
    section_extend();
    section_extendsImplements();
    section_forEach();
    section_fromImportWildcard();
    section_inlineReturn();
    section_mathFull();
    section_mochaString();
    section_modDiv();
    section_occs();
    section_sets();
    section_this();
    section_alloc();
    section_sortClosure();
    section_ctypeFFI();
    section_fileIO();
    section_filterInline();
    section_reduceInline();
    section_symcha();
    section_vast();
    section_processing();

    print("==========================", newLine=true);
    print("All Tests Complete!", newLine=true);
};