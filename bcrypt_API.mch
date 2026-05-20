//from "mocha-math" import rand_int(), rand_seed(), bcrypt_rand_int(), bcrypt_rand_float(), bcrypt_rand_unit(), bcrypt_rand_ints(), bcrypt_rand_bool(), bcrypt_rand_seed();
from "mocha-string" import *;

function rand_int(min: int, max: int) -> int native mocha_rand_int;
function rand_seed(seed: int) -> null native mocha_rand_seed;
function bcrypt_rand_int(min: int, max: int) -> int native mocha_bcrypt_rand_int;
function bcrypt_rand_float(min: float, max: float) -> float native mocha_bcrypt_rand_float;
function bcrypt_rand_unit() -> float native mocha_bcrypt_rand_unit;
function bcrypt_rand_ints(min: int, max: int, count: int) -> str native mocha_bcrypt_rand_ints;
function bcrypt_rand_bool() -> bool native mocha_bcrypt_rand_bool;
function bcrypt_rand_seed() -> int native mocha_bcrypt_rand_seed;

function main(didLoad) -> null {
    print("=== BCrypt RNG Tests ===", newLine=true);

    // ── Section 1: Basic randomness ──
    print("--- 1. bcrypt_rand_int ---", newLine=true);
    var i: int = 0;
    while (i < 10) {
        print(str(bcrypt_rand_int(1, 100)) + " ", newLine=false);
        i++;
    };
    print("", newLine=true);

    // ── Section 2: Float range ──
    print("--- 2. bcrypt_rand_float ---", newLine=true);
    var j: int = 0;
    while (j < 5) {
        print(str(bcrypt_rand_float(0.0, 1.0)) + " ", newLine=false);
        j++;
    };
    print("", newLine=true);

    // ── Section 3: Unit float ──
    print("--- 3. bcrypt_rand_unit ---", newLine=true);
    var k: int = 0;
    while (k < 5) {
        print(str(bcrypt_rand_unit()) + " ", newLine=false);
        k++;
    };
    print("", newLine=true);

    // ── Section 4: Bool coin flip ──
    print("--- 4. bcrypt_rand_bool ---", newLine=true);
    var heads: int = 0;
    var tails: int = 0;
    var f: int = 0;
    while (f < 1000) {
        var b: bool = bcrypt_rand_bool();
        if (b) { heads++; };
        if (!b) { tails++; };
        f++;
    };
    print("heads: " + str(heads) + " tails: " + str(tails), newLine=true);
    // should be roughly 500/500

    // ── Section 5: Seed ──
    print("--- 5. bcrypt_rand_seed ---", newLine=true);
    var seed: int = bcrypt_rand_seed();
    print("seed: " + str(seed), newLine=true);
    rand_seed(seed);
    var s: int = 0;
    while (s < 5) {
        print(str(rand_int(1, 100)) + " ", newLine=false);
        s++;
    };
    print("", newLine=true);

    // ── Section 6: Bulk ints ──
    print("--- 6. bcrypt_rand_ints ---", newLine=true);
    var bulk: str = bcrypt_rand_ints(1, 10, 20);
    print("raw: " + bulk, newLine=true);
    var arr: str[] = bulk.split("|");
    print("count: " + str(arr.length), newLine=true);  // 20
    // find min and max
    var mn: int = 999;
    var mx: int = 0;
    var ai: int = 0;
    while (ai < arr.length) {
        var v: int = arr[ai].toInt();
        if (v < mn) { mn = v; };
        if (v > mx) { mx = v; };
        ai++;
    };
    print("min: " + str(mn) + " max: " + str(mx), newLine=true);
    // both should be between 1 and 10

    // ── Section 7: ML use case — weight init ──
    print("--- 7. ML weight init (Xavier) ---", newLine=true);
    var n_in: int = 4;
    var n_out: int = 4;
    var limit: float = bcrypt_rand_unit() * 2.0 - 1.0;  // [-1, 1]
    var wi: int = 0;
    while (wi < n_in) {
        var wj: int = 0;
        while (wj < n_out) {
            var w: float = bcrypt_rand_float(0.0 - limit, limit);
            print(str(w) + " ", newLine=false);
            wj++;
        };
        print("", newLine=true);
        wi++;
    };

    // ── Section 8: Distribution check ──
    print("--- 8. Distribution (1-5, 1000 samples) ---", newLine=true);
    var counts: int[] = alloc int[5];
    var di: int = 0;
    while (di < 5) { counts[di] = 0; di++; };
    var si: int = 0;
    while (si < 1000) {
        var v: int = bcrypt_rand_int(1, 5);
        var idx: int = v - 1;
        counts[idx] = counts[idx] + 1;
        si++;
    };
    var ci: int = 0;
    while (ci < 5) {
        print(str(ci + 1) + ": " + str(counts[ci]), newLine=true);
        ci++;
    };
    // should be roughly 200 each

    print("=== BCrypt RNG Done ===", newLine=true);
};