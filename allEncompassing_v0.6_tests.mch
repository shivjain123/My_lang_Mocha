"""
    Mocha v0.6 — Consolidated Tests

    Entry point: runAllTests(didLoad)
    All sections are normal functions called from inside.
    Commented-out blocks preserved for reference.

    Sections:
     1.  Array Return + str-to-int cast
     2.  Break
     4.  Continue
     5.  Diamond Virtual Inheritance
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
    19.  alloc int[n]
    20.  Sort with closure
    21.  ctype FFI
    22.  File I/O FFI
    23.  Filter lambda (inline)
    24.  Reduce lambda
    25.  mocha-SymCha — full
    26.  vast (int64)
    27.  mocha-processing
    28.  Binary ops                  ← NEW v0.6
    29.  2D array alloc + slices     ← NEW v0.6
    30.  Object array (alloc Point)  ← NEW v0.6
    31.  Default field values        ← NEW v0.6
    32.  Constructor inheritance     ← NEW v0.6
    33.  vast edge cases             ← NEW v0.6
    34.  mocha-matvec v1             ← NEW v0.6
    35.  mocha-matvec v2             ← NEW v0.6
    36.  sym_equal + simplify        ← NEW v0.6 (now does not work in v0.9)
"""


// ============================================================
// IMPORTS
// ============================================================

import mochaString from "mocha-string";
from "mocha-SymCha" import *;
import mochaProcessing from "mocha-processing";
from "mocha-matvec" import *;


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

// Section 30 — Object array
class Point {
    var x: int;
    var y: int;
    function constructor(x: int, y: int) -> null {
        this.x = x;
        this.y = y;
    };
};

// Section 31 — Default field values
class DefaultAnimal {
    var name: str = "unknown";
    var age: int = 0;
};

// Section 32 — Constructor inheritance
class BaseAnimal {
    var name: str;
    function constructor(n: str) -> null {
        this.name = n;
    };
    function speak() -> null {
        print(this.name, newLine=true);
    };
};

class Hippo extends BaseAnimal {
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
        "age": "19",
        "gpa": "9.8",
        "active": "true",
    };

    print(d["name"], newLine=true);   // Shiv
    print(d["age"], newLine=true);    // 19

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
            "age": "19",
        },
    };
    print(nest["person"]["name"], newLine=true);  // Shiv
    print(nest["person"]["age"], newLine=true);   // 19

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
    puts(str(fast_pow(2.0, 0)));   // 1
    puts(str(fast_pow(2.0, 10)));  // 1024
    puts(str(fast_pow(2.0, -1)));  // 0.5
    puts(str(fast_pow(-3.0, 3)));  // -27

    puts("--- sin / cos ---");
    puts(str((0.0).sin(mes=RAD)));     // 0
    puts(str((90.0).sin(mes=DEG)));    // 1
    puts(str((0.0).cos(mes=RAD)));     // 1
    puts(str((90.0).cos(mes=DEG)));    // ~0 

    puts("--- inv_sin / inv_cos / inv_tan ---");
    puts((1.0).inv_sin().toString());   // ~1.5707
    puts((1.0).inv_cos().toString());   // 0
    puts(str((1.0).inv_tan()));     // ~0.7853

    puts("--- tan ---");
    puts(str((0.0).tan(mes=RAD)));
    puts(str((45.0).tan(mes=DEG)));
    puts(str((90.0).tan(mes=DEG)));

    puts("--- sqrt ---");
    puts((4.0).sqrt().toString());    // 2
    puts((2.0).sqrt().toString());    // 1.41421
    puts((0.0).sqrt().toString());    // 0
    puts((-1.0).sqrt().toString());

    puts("--- cubrot ---");
    puts(str((27.0).cubrot()));   // 3
    puts(str((8.0).cubrot()));    // 2
    puts(str((-27.0).cubrot())); // -3

    puts("--- log / log2 / log10 ---");
    puts((2.71828182845904).log().toString());  // ~1
    puts((1.0).log().toString());              // 0
    puts((0.0).log().toString());              
    puts((-1.0).log().toString());             
    puts((8.0).log2().toString());             // 3
    puts((0.0).log2().toString());             
    puts((100.0).log10().toString());          // 2
    puts((0.0).log10().toString());           

    puts("--- INF detection ---");
    var neg: float = -1.0;
    var sqr: Complex = neg.sqrt();
    var t90: float = (90.0).tan(mes=DEG);
    puts(sqr.toString());
    puts(str(t90));

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
    print(ripped.substring(6, 10), newLine=true);   // World

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
    print(10 % 3, newLine=true);     // 1
    print(15 % 5, newLine=true);     // 0
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
    print(grid.occs(1, col=0), newLine=true);      // 2 (wait: col 0 is 1,1,2 → 2 ones)
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

    var sa: set<int> = <1, 2, 3, 4, 5>;
    var sb: set<int> = <4, 5, 6, 7>;
    var u: set<int> = sa.union(sb);
    print(u.size, newLine=true);           // 7
    var inter: set<int> = sa.intersect(sb);
    print(inter.size, newLine=true);       // 2
    var d: set<int> = sa.xor(sb);
    print(d.size, newLine=true);
    var rd: set<int> = sa.rel_diff(sb);
    print(rd.size, newLine=true);

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
// SECTION 19 — alloc int[n]
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
// SECTION 20 — Sort with closure capture
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
// SECTION 21 — ctype FFI
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
// SECTION 22 — File I/O FFI
// ============================================================

function section_fileIO() -> null {
    puts("--- 22. File I/O FFI ---");
    var f: File = open("mocha_test_output.txt", "write");
    f.write("Hello from Mocha file I/O!");
    f.close();
    puts("File written: mocha_test_output.txt");
};


// ============================================================
// SECTION 23 — Filter lambda (inline)
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
// SECTION 24 — Reduce lambda
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
// SECTION 25 — mocha-SymCha — full
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
    print(sym_eval(s, "x", 0.0), newLine=true);                               // 0.0
    print(sym_eval(sym_simplify(sym_diff(s, "x")), "x", 0.0), newLine=true);  // 1.0

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
// SECTION 26 — vast (int64)
// ============================================================

function section_vast() -> null {
    print("--- 26. vast ---", newLine=true);

    var n: vast = 12586269025;
    print(n, newLine=true);           // 12586269025

    var m: vast = n + 1;
    print(m, newLine=true);           // 12586269026

    print(str(n), newLine=true);      // "12586269025"

    var v: vast = 9999999999;
    var i: int = 1;
    var result: vast = v + i;         // vast + int → vast
    print(result, newLine=true);      // 10000000000

    var fib50: vast = 12586269025;
    print(fib50, newLine=true);       // fib(50) correct value
};


// ============================================================
// SECTION 27 — mocha-processing
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
    print(mappedS[0], newLine=true);

    var sum: int = reduce(nums, lambda (a: int, b: int) -> int: a + b, 0);
    print(sum, newLine=true);              // 15

    var total: float = reduceFloat(prices, lambda (a: float, b: float) -> float: a + b, 0.0);
    print(total, newLine=true);            // 12.0

    var joined: str = reduceStr(words, lambda (a: str, b: str) -> str: a + "," + b, "");
    print(joined, newLine=true);           // apple,banana,cherry,date
};


// ============================================================
// SECTION 28 — Binary ops          ← NEW v0.6
// ============================================================

function section_binaryOps() -> null {
    print("--- 28. Binary ops ---", newLine=true);

    // Arithmetic
    print(1 + 2, newLine=true);        // 3  int_add
    print(5 - 6, newLine=true);        // -1 int_sub
    print(3 * 4, newLine=true);        // 12 int_mul
    print(10 / 2, newLine=true);       // 5  int_div
    print(10 % 3, newLine=true);       // 1  int_mod

    print(1 + 2.0, newLine=true);      // 3.0  float_add
    print(3 * 2.5, newLine=true);      // 7.5  float_mul
    print(10.0 / 4, newLine=true);     // 2.5  float_div

    var vbig: vast = 1234567890123 + 1;
    print(vbig, newLine=true);         // 1234567890124  vast_add

    // Strings
    print("ab" + "cd", newLine=true);          // abcd
    print("hello" == "hello", newLine=true);   // true  str_eq
    print("foo" != "bar", newLine=true);       // true  str_ne

    // Numeric comparisons
    print(1 == 1, newLine=true);       // true   int_eq
    print(2 != 3, newLine=true);       // true   int_ne
    print(3 < 4, newLine=true);        // true   int_<
    print(5 >= 5, newLine=true);       // true   int_>=
    print(2.0 < 3.5, newLine=true);    // true   float_<
    print(1.0 == 1, newLine=true);     // true   float_eq (promotion)
    print(1234567890123 > 1000, newLine=true); // true  vast_>

    // Logical
    print(true && false, newLine=true);  // false  bool_and
    print(true || false, newLine=true);  // true   bool_or

    // Mixed numeric promotion
    print(2.5 + 3, newLine=true);    // 5.5  float + int → float
};


// ============================================================
// SECTION 29 — 2D array alloc + slices  ← NEW v0.6
// ============================================================

function section_2dArray() -> null {
    print("--- 29. 2D array alloc + slices ---", newLine=true);

    // alloc int[n][m]
    var rows: int = 3;
    var cols: int = 3;
    var grid: int[][] = alloc int[rows][cols];

    // fill
    var r: int = 0;
    while (r < rows) {
        var c: int = 0;
        while (c < cols) {
            grid[r][c] = (r * cols) + c; //915
            c++;
        };
        r++;
    };

    // get/set
    print(grid[0][0], newLine=true);  // 0
    print(grid[0][2], newLine=true);  // 2
    print(grid[1][1], newLine=true);  // 4
    print(grid[2][2], newLine=true);  // 8

    // literal 2D
    var mat: int[][] = [[1, 2, 3], [4, 5, 6], [7, 8, 9]];

    // row slice: mat[1][] → entire row 1
    var row1: int[] = mat[1][];
    print(row1[0], newLine=true);  // 4
    print(row1[1], newLine=true);  // 5
    print(row1[2], newLine=true);  // 6

    // col slice: mat[][2] → entire col 2
    var col2: int[] = mat[][2];
    print(col2[0], newLine=true);  // 3
    print(col2[1], newLine=true);  // 6
    print(col2[2], newLine=true);  // 9

    // rows and cols properties
    print(mat.rows, newLine=true);  // 3
    print(mat.cols, newLine=true);  // 3

    // occs on 2D without specifier — whole matrix search ← NEW v0.6
    var grid2: int[][] = [[1, 2, 1], [1, 3, 4], [2, 2, 1]];
    print(grid2.occs(1), newLine=true);  // 4 (whole matrix)
    print(grid2.occs(2), newLine=true);  // 3
    print(grid2.occs(9), newLine=true);  // 0
};


// ============================================================
// SECTION 30 — Object array (alloc Point[])  ← NEW v0.6
// ============================================================

function section_objectArray() -> null {
    print("--- 30. Object array ---", newLine=true);

    var points: Point[] = [];

    var p1: Point = Point(1, 2);
    var p2: Point = Point(3, 4);
    var p3: Point = Point(5, 6);

    points.push(p1);
    points.push(p2);
    points.push(p3);

    print(points.length, newLine=true);   // 3
    print(points[0].x, newLine=true);     // 1
    print(points[0].y, newLine=true);     // 2
    print(points[1].x, newLine=true);     // 3
    print(points[2].y, newLine=true);     // 6
};


// ============================================================
// SECTION 31 — Default field values  ← NEW v0.6
// ============================================================

function section_defaultFields() -> null {
    print("--- 31. Default field values ---", newLine=true);

    var a: DefaultAnimal = DefaultAnimal();
    print(a.name, newLine=true);  // unknown
    print(a.age, newLine=true);   // 0

    a.name = "Rex";
    a.age = 3;
    print(a.name, newLine=true);  // Rex
    print(a.age, newLine=true);   // 3
};


// ============================================================
// SECTION 32 — Constructor inheritance  ← NEW v0.6
// ============================================================

function section_constructorInheritance() -> null {
    print("--- 32. Constructor inheritance ---", newLine=true);

    // Hippo has no constructor — delegates to BaseAnimal(n: str)
    var h: Hippo = Hippo("Rex");
    h.speak();  // Rex

    var h2: Hippo = Hippo("Titan");
    h2.speak(); // Titan
};


// ============================================================
// SECTION 33 — vast edge cases  ← NEW v0.6
// ============================================================

function section_vastEdge() -> null {
    print("--- 33. vast edge cases ---", newLine=true);

    // increment / decrement
    var v: vast = 12586269025;
    v++;
    print(v, newLine=true);   // 12586269026
    v--;
    print(v, newLine=true);   // 12586269025

    // vast as for loop counter
    var sum: vast = 0;
    for (var j: vast = 0; j < 5; j++) {
        sum = sum + j;
    };
    print(sum, newLine=true);  // 10

    // vast[] array
    var arr: vast[] = [12586269025, 12586269026, 12586269027];
    print(arr[0], newLine=true);   // 12586269025
    print(arr[1], newLine=true);   // 12586269026
    arr.push(99999999999);
    print(arr[3], newLine=true);   // 99999999999
    print(arr.length, newLine=true); // 4

    // vast arithmetic
    var a: vast = 9999999999;
    var b: vast = 9999999999;
    print(a + b, newLine=true);   // 19999999998
    print(a * 2, newLine=true);   // 19999999998
    print(a + 1, newLine=true);   // 10000000000  vast + int → vast

    // vast str conversion
    var ns: str = str(a);
    print(ns, newLine=true);   // 9999999999

    // vast in set
    var s: set<vast> = <12586269025, 12586269026>;
    print(s.size, newLine=true);              // 2
    print(s.has(12586269025), newLine=true);  // true
    print(s.has(99), newLine=true);           // false
};


// ============================================================
// SECTION 34 — mocha-matvec v1 (unchanged ops, no breaking changes)
// ============================================================

function section_matvecV1() -> null {
    print("--- 34. mocha-matvec v1 ---", newLine=true);

    // int[] ops
    var a: int[] = [1, 2, 3, 4];
    var b: int[] = [2, 3, 4, 5];

    var sc: int[] = a.scalar(3);
    print(sc[0], newLine=true);   // 3
    print(sc[3], newLine=true);   // 12

    print(a.vector(b), newLine=true);  // 40

    var h: int[] = a.hadamard(b);
    print(h[0], newLine=true);   // 2
    print(h[3], newLine=true);   // 20

    var ad: int[] = a.add(b);
    print(ad[0], newLine=true);  // 3
    print(ad[3], newLine=true);  // 9

    var sb: int[] = a.sub(b);
    print(sb[0], newLine=true);  // -1
    print(sb[3], newLine=true);  // -1

    print(a.magn(), newLine=true);  // ~5.47723

    var norm: float[] = a.unit_vector();
    print(norm[0], newLine=true);   // ~0.182574
    print(norm[3], newLine=true);   // ~0.730297

    // float[] ops
    var fa: float[] = [1.0, 2.0, 3.0];
    var fb: float[] = [4.0, 5.0, 6.0];

    print(fa.vector(fb), newLine=true);  // 32.0
    print(fa.magn(), newLine=true);      // ~3.74166

    // int[][] ops
    var ma: int[][] = [[1, 2], [3, 4]];
    var mb: int[][] = [[5, 6], [7, 8]];

    var mv: int[][] = ma.vector(mb);
    print(mv[0][0], newLine=true);  // 19
    print(mv[0][1], newLine=true);  // 22
    print(mv[1][0], newLine=true);  // 43
    print(mv[1][1], newLine=true);  // 50

    var mt: int[][] = ma.transpose();
    print(mt[0][0], newLine=true);  // 1
    print(mt[0][1], newLine=true);  // 3
    print(mt[1][0], newLine=true);  // 2
    print(mt[1][1], newLine=true);  // 4

    print(ma.trace(), newLine=true);  // 5
    print(ma.det(), newLine=true);    // -2.0
    print(ma.rank(), newLine=true);   // 2

    var sing: int[][] = [[1, 2], [2, 4]];
    print(sing.rank(), newLine=true); // 1

    // float[][] ops
    var fma: float[][] = [[1.0, 2.0], [3.0, 4.0]];
    print(fma.det(), newLine=true);   // -2.0
    print(fma.trace(), newLine=true); // 5.0

    var m3: float[][] = [[1.0,2.0,3.0],[4.0,5.0,6.0],[7.0,8.0,9.0]];
    print(m3.det(), newLine=true);    // 0.0
    print(m3.rank(), newLine=true);   // 2
};


// ============================================================
// SECTION 35 — mocha-matvec v3 (breaking changes: Complex types)
// ============================================================

function section_matvecV3() -> null {
    print("--- 35. mocha-matvec v3 ---", newLine=true);

    // minor — unchanged, still int[][]
    var m: int[][] = [[1, 2, 3], [4, 5, 6], [7, 8, 9]];
    var mn: int[][] = m.minor(0, 0);
    print(mn[0][0], newLine=true);  // 5
    print(mn[0][1], newLine=true);  // 6
    print(mn[1][0], newLine=true);  // 8
    print(mn[1][1], newLine=true);  // 9

    // cofactor — unchanged, float[][]
    var c2: float[][] = [[1.0, 2.0], [3.0, 4.0]];
    var cof: float[][] = c2.cofactor();
    print(cof[0][0], newLine=true);   // 4.0
    print(cof[0][1], newLine=true);   // -3.0
    print(cof[1][0], newLine=true);   // -2.0
    print(cof[1][1], newLine=true);   // 1.0

    // inverse — unchanged return type, but singular now errors+exits
    // so we only test the invertible case here
    var inv: float[][] = c2.inverse();
    print(inv[0][0], newLine=true);   // -2.0
    print(inv[0][1], newLine=true);   // 1.0
    print(inv[1][0], newLine=true);   // 1.5
    print(inv[1][1], newLine=true);   // -0.5

    var identity: float[][] = c2.vector(inv);
    print(identity[0][0], newLine=true);  // ~1.0
    print(identity[0][1], newLine=true);  // ~0.0
    print(identity[1][0], newLine=true);  // ~0.0
    print(identity[1][1], newLine=true);  // ~1.0

    // NOTE: singular inverse test removed — now calls c_exit(2) loudly
    // test it separately if needed: sing.inverse() should print error and exit

    // ----------------------------------------------------------
    // eigenvalues — now returns Complex[]
    // Real eigenvalues have .imag == 0.0
    // ----------------------------------------------------------

    // Case 1: symmetric matrix — two distinct real eigenvalues
    var e2: float[][] = [[2.0, 1.0], [1.0, 2.0]];
    var evals: Complex[] = e2.eigenvalues();
    print(evals[0].real, newLine=true);  // 3.0
    print(evals[0].imag, newLine=true);  // 0.0
    print(evals[1].real, newLine=true);  // 1.0
    print(evals[1].imag, newLine=true);  // 0.0

    // Case 2: rotation matrix — complex conjugate pair
    // [[0,-1],[1,0]] has eigenvalues +i and -i
    var rot: float[][] = [[0.0, -1.0], [1.0, 0.0]];
    var rot_evals: Complex[] = rot.eigenvalues();
    print(rot_evals[0].real, newLine=true);  // 0.0
    print(rot_evals[0].imag, newLine=true);  // 1.0  (+i)
    print(rot_evals[1].real, newLine=true);  // 0.0
    print(rot_evals[1].imag, newLine=true);  // -1.0 (-i)

    // Case 3: one zero eigenvalue (det=0) — only ONE zero, not all
    // [[2,0],[0,0]] has eigenvalues 2.0 and 0.0
    var sing2: float[][] = [[2.0, 0.0], [0.0, 0.0]];
    var sing_evals: Complex[] = sing2.eigenvalues();
    print(sing_evals[0].real, newLine=true);  // 2.0
    print(sing_evals[1].real, newLine=true);  // 0.0

    // ----------------------------------------------------------
    // eigenvectors — now returns Complex[][]
    // Each COLUMN is one eigenvector
    // For real symmetric, imag parts should be ~0.0
    // ----------------------------------------------------------

    var evecs: Complex[][] = e2.eigenvectors();

    // Column 0 corresponds to λ=3: eigenvector is [1/√2, 1/√2]
    // Check .real parts, .imag should be ~0.0
    var v0_re0: float = evecs[0][0].real;
    var v0_re1: float = evecs[1][0].real;
    // Unit vector check via real parts (imag ~0 for real symmetric)
    var v0mag: float = (v0_re0 * v0_re0) + (v0_re1 * v0_re1);
    print(v0mag, newLine=true);  // ~1.0

    // Column 1 corresponds to λ=1: eigenvector is [-1/√2, 1/√2]
    var v1_re0: float = evecs[0][1].real;
    var v1_re1: float = evecs[1][1].real;
    var v1mag: float = (v1_re0 * v1_re0) + (v1_re1 * v1_re1);
    print(v1mag, newLine=true);  // ~1.0

    // Imaginary parts should be ~0 for real symmetric matrix
    print(evecs[0][0].imag, newLine=true);  // ~0.0
    print(evecs[1][0].imag, newLine=true);  // ~0.0

    // ----------------------------------------------------------
    // diagonalise — now returns Complex[][]
    // For real eigenvalues, .imag == 0.0 on diagonal
    // ----------------------------------------------------------

    var d2: Complex[][] = e2.diagonalise();
    print(d2[0][0].real, newLine=true);  // 3.0
    print(d2[0][0].imag, newLine=true);  // 0.0
    print(d2[0][1].real, newLine=true);  // 0.0  (off-diagonal)
    print(d2[1][0].real, newLine=true);  // 0.0  (off-diagonal)
    print(d2[1][1].real, newLine=true);  // 1.0
    print(d2[1][1].imag, newLine=true);  // 0.0

    // diagonalise on rotation matrix — complex diagonal
    var rot_d: Complex[][] = rot.diagonalise();
    print(rot_d[0][0].real, newLine=true);  // 0.0
    print(rot_d[0][0].imag, newLine=true);  // 1.0  (+i on diagonal)
    print(rot_d[1][1].real, newLine=true);  // 0.0
    print(rot_d[1][1].imag, newLine=true);  // -1.0 (-i on diagonal)

    // ----------------------------------------------------------
    // SVD — still float[][], unchanged
    // AᵀA is symmetric so eigenvalues always real
    // ----------------------------------------------------------

    var s2: float[][] = [[1.0, 0.0], [0.0, 2.0]];
    var svd_result: (float[][], 3) = s2.svd();
    var u: float[][] = svd_result#0;
    var sigma: float[][] = svd_result#1;
    var vt_mat: float[][] = svd_result#2;

    // singular values on diagonal
    print(sigma[0][0], newLine=true);  // 1.0 or 2.0
    print(sigma[1][1], newLine=true);  // 2.0 or 1.0

    // U orthogonal check: U*Uᵀ = I
    var ut: float[][] = u.transpose();
    var uut: float[][] = u.vector(ut);
    print(uut[0][0], newLine=true);  // ~1.0
    print(uut[1][1], newLine=true);  // ~1.0
    print(uut[0][1], newLine=true);  // ~0.0

    // reconstruct A = U * Σ * Vᵀ
    var recon: float[][] = u.vector(sigma.vector(vt_mat));
    print(recon[0][0], newLine=true);  // ~1.0
    print(recon[0][1], newLine=true);  // ~0.0
    print(recon[1][0], newLine=true);  // ~0.0
    print(recon[1][1], newLine=true);  // ~2.0

    // ----------------------------------------------------------
    // Defective matrix test — should error+exit loudly
    // [[3,1],[0,3]] has λ=3 repeated, geometric multiplicity 1
    // Uncomment to test error path:
    // var defect: float[][] = [[3.0, 1.0], [0.0, 3.0]];
    // var _: Complex[][] = defect.eigenvectors();
    // ----------------------------------------------------------
};


// ============================================================
// SECTION 36 — sym_equal + simplify  ← NEW v0.6
// ============================================================

function section_symEqual() -> null {
    print("--- 36. sym_equal + simplify ---", newLine=true);

    var x: Expr = var_e("x");

    // f/f → 1 (structural equality)
    var expr1: Expr = div_e(var_e("x"), var_e("x"));
    var simp1: Expr = sym_simplify(expr1);
    print(sym_print(simp1), newLine=true);  // 1

    // (x*2)/(2*x) → 1 (commutative equality: x*2 == 2*x)
    var expr2: Expr = div_e(mul(x, num(2.0)), mul(num(2.0), x));
    var simp2: Expr = sym_simplify(expr2);
    print(sym_print(simp2), newLine=true);  // 1

    // d/dx(x/x) → 0 (simplify before diff)
    var expr3: Expr = div_e(var_e("x"), var_e("x"));
    var d3: Expr = sym_simplify(sym_diff(expr3, "x"));
    print(sym_print(d3), newLine=true);  // 0

    // a+b == b+a (commutative ADD)
    var ab: Expr = add(var_e("x"), num(1.0));
    var ba: Expr = add(num(1.0), var_e("x"));
    var diff_ab: Expr = sym_simplify(sym_diff(ab, "x"));
    var diff_ba: Expr = sym_simplify(sym_diff(ba, "x"));
    print(sym_print(diff_ab), newLine=true);  // 1
    print(sym_print(diff_ba), newLine=true);  // 1
};


// ============================================================
// ENTRY POINT
// ============================================================

function runAllTests(didLoad) -> null {
    print("Mocha v0.6 — All Tests", newLine=true);
    print("==========================", newLine=true);

    section_arrayCast();
    section_break();
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
    section_binaryOps();
    section_2dArray();
    section_objectArray();
    section_defaultFields();
    section_constructorInheritance();
    section_vastEdge();
    section_matvecV1();
    section_matvecV3();
    //section_symEqual(); (DOES NOT WORK IN V0.9 NOW)

    print("==========================", newLine=true);
    print("All Tests Complete!", newLine=true);
};
