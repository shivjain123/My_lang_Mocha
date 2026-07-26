from "mocha-stopwatch" import *;
from "mocha-math" import *;

// ============================================================
// 1. FAST INTEGER SQUARE ROOT
// ============================================================
function is_square(n: int) -> bool {
    var f: float = float(n);
    var r: float = f.sqrt().real;
    var root: int = int(r);
    if (root * root < n) {
        while ((root + 1) * (root + 1) <= n) {
            root = root + 1;
        };
    };
    if (root * root > n) {
        while (root * root > n) {
            root = root - 1;
        };
    };
    return root * root == n;
};

// ============================================================
// 2. GCD HELPER
// ============================================================
function gcd(a: int, b: int) -> int {
    var x: int = a;
    var y: int = b;
    while (y != 0) {
        var t: int = y;
        y = x % y;
        x = t;
    };
    return x;
};

// ============================================================
// 3. SEARCH 4D EULER BRICKS
// ============================================================
function search_4d(limit: int) -> int[][] {
    var results: int[][] = [];
    var a: int = 1;
    while (a <= limit) {
        var b: int = a;
        while (b <= limit) {
            if (!is_square(a*a + b*b)) { b++; continue; };
            var c: int = b;
            while (c <= limit) {
                if (!is_square(a*a + c*c)) { c++; continue; };
                if (!is_square(b*b + c*c)) { c++; continue; };
                if (!is_square(a*a + b*b + c*c)) { c++; continue; };
                var d: int = c;
                while (d <= limit) {
                    if (!is_square(a*a + d*d)) { d++; continue; };
                    if (!is_square(b*b + d*d)) { d++; continue; };
                    if (!is_square(c*c + d*d)) { d++; continue; };
                    if (!is_square(a*a + b*b + d*d)) { d++; continue; };
                    if (!is_square(a*a + c*c + d*d)) { d++; continue; };
                    if (!is_square(b*b + c*c + d*d)) { d++; continue; };
                    if (!is_square(a*a + b*b + c*c + d*d)) { d++; continue; };
                    if (gcd(gcd(gcd(a, b), c), d) == 1) {
                        var brick: int[] = [a, b, c, d];
                        results.push(brick);
                    };
                    d++;
                };
                c++;
            };
            b++;
        };
        a++;
    };
    return results;
};

// ============================================================
// 4. MAIN
// ============================================================
function main(didLoad) -> null {
    var sw: Stopwatch = Stopwatch();
    sw.begin();

    const LIMIT: int = 80000;
    print("========================================", newLine=true);
    print("4D EULER BRICK SEARCH (MOCHA)", newLine=true);
    print("limit = ", LIMIT, newLine=true);
    print("========================================\n", newLine=true);

    var results: int[][] = search_4d(LIMIT);

    sw.end();
    var elapsed: float = sw.elapsed_ms();

    print("\n========================================", newLine=true);
    print("RESULTS", newLine=true);
    print("========================================", newLine=true);
    print("Found ", results.length, " 4D bricks in ", elapsed, "ms", newLine=true);

    if (results.length > 0) {
        var i: int = 0;
        while (i < results.length) {
            var brick: int[] = results[i];
            print("  (", brick[0], ", ", brick[1], ", ", brick[2], ", ", brick[3], ")", newLine=true);
            i++;
        };
    } else {
        print("  ❌ No 4D bricks found in this range.", newLine=true);
    };
};