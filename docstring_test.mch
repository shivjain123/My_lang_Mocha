// test_docstrings.mch

// ============================================================
// PHASE 1 — basic single-line docstrings
// ============================================================

~~ adds two numbers
function add(a: int, b: int) -> int {
    return a + b;
};

// Expected: FunctionDecl { name: "add", doc: ["adds two numbers"] }

function noDoc(x: int) -> int {
    return x;
};

// Expected: FunctionDecl { name: "noDoc", doc: None }

~~ fetches a url and returns the response body
function fetchPage(url: str, timeout: int) -> str {
    return url;
};

// Expected: FunctionDecl { name: "fetchPage", doc: ["fetches a url and returns the response body"] }

// ============================================================
// PHASE 2 — multiline docstrings
// ============================================================

~~ computes the nth fibonacci number
~~ uses iterative approach for efficiency
function fib(n: int) -> int {
    var a: int = 0;
    var b: int = 1;
    var i: int = 0;
    while (i < n) {
        var tmp: int = b;
        b = a + b;
        a = tmp;
        i = i + 1;
    };
    return a;
};

// Expected: doc: ["computes the nth fibonacci number", "uses iterative approach for efficiency"]

~~ first line of doc
~~ second line of doc
~~ third line of doc
function threeLines() -> null {
    return null;
};

// Expected: doc: ["first line of doc", "second line of doc", "third line of doc"]

// ============================================================
// PHASE 3 — class and method docstrings
// ============================================================

~~ represents a 2D point in cartesian space
class Point {
    var x: float;
    var y: float;

    function constructor(x: float, y: float) {
        this.x = x;
        this.y = y;
    };

    ~~ returns the distance to another point
    function distanceTo(other: Point) -> float {
        return this.x - other.x;
    };

    // Expected: MethodDecl { name: "distanceTo", doc: ["returns the distance to another point"], visibility: "public" }

    ~~ string representation of this point
    private function toString() -> str {
        return "point";
    };

    // Expected: MethodDecl { name: "toString", doc: ["string representation of this point"], visibility: "private" }

    ~~ creates a Point at the origin
    shared function origin() -> Point {
        return Point(0.0, 0.0);
    };

    // Expected: MethodDecl { name: "origin", doc: ["creates a Point at the origin"], is_shared: true }

    function undocumented() -> null {
        return null;
    };

    // Expected: MethodDecl { name: "undocumented", doc: None }
};

// Expected: ClassDecl { name: "Point", doc: ["represents a 2D point in cartesian space"] }

// ============================================================
// PHASE 4 — tagged lines (@param / @return)
// ============================================================

~~ computes base raised to the power of exp
~~ @param base the base value
~~ @param exp the exponent, must be non-negative
~~ @return base ^ exp as a float
function power(base: float, exp: int) -> float {
    return base;
};

// Expected: doc: ["computes base raised to the power of exp", "@param base the base value", "@param exp the exponent, must be non-negative", "@return base ^ exp as a float"]

~~ @param items the list to sort in place
~~ @return sorted list of integers
function sortInts(items: int[]) -> int[] {
    return items;
};

// Expected: doc: ["@param items the list to sort in place", "@return sorted list of integers"]

// ============================================================
// PHASE 5 — edge cases
// ============================================================

~~
function emptyDoc() -> null {
    return null;
};

// Expected: doc: [""]

// this comment belongs to nobody — blank line below separates it from afterGap

function afterGap() -> null {
    return null;
};

// Expected: doc: None

~~ native function with a docstring
function sin(x: float) -> float native mocha_math_sin;

// Expected: FunctionDecl { name: "sin", doc: ["native function with a docstring"], is_native: true }

function main(didLoad) -> null {
    var p1: Point = Point(1.0, 2.0);
    var p2: Point = Point(4.0, 6.0);
    var d: float = p1.distanceTo(p2);
    var origin: Point = Point.origin();
    var n: int = fib(10);
    var pw: float = power(2.0, 8);
    var sorted: int[] = sortInts([3, 1, 4, 1, 5]);
};