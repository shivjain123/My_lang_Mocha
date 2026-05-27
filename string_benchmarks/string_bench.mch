import mochaString from "mocha-string";
//This Benchmark is unstable since time is longer or shorter than is measures.
//Since, strings overflow buffer. Fix strings or use StringBuilder

"""function test(didLoad) -> null {
    // Benchmark 1: String concatenation loop (10000 iterations)
    var result: str = "";
    var i: int = 0;
    while (i < 10000) {
        result = result + "a";
        i++;
    };
    print(result.length, newLine=true);

    // Benchmark 2: String contains (repeated search)
    var haystack: str = "the quick brown fox jumps over the lazy dog";
    var found: int = 0;
    var j: int = 0;
    while (j < 10000) {
        if (haystack.contains("fox")) {
            found = found + 1;
        };
        j++;
    };
    print(found, newLine=true);

    // Benchmark 3: String reverse (repeated)
    var s: str = "Hello Mocha World";
    var k: int = 0;
    while (k < 10000) {
        var r: str = s.reverse();
        k++;
    };
    print(s.reverse(), newLine=true);

    // Benchmark 4: Split and join simulation
    var csv: str = "one,two,three,four,five";
    var count: int = 0;
    var l: int = 0;
    while (l < 10000) {
        var parts: str[] = csv.split(",");
        count = count + parts.length;
        l++;
    };
    print(count, newLine=true);
};"""

function test(didLoad) -> null {
    // Benchmark 1: String concatenation via StringBuilder
    var sb1: StringBuilder = StringBuilder();
    var i: int = 0;
    while (i < 10000) {
        sb1.append("a");
        i++;
    };
    print(sb1.toString().length, newLine=true);

    // Benchmark 2: String contains (same as before — no StringBuilder needed)
    var haystack: str = "the quick brown fox jumps over the lazy dog";
    var found: int = 0;
    var j: int = 0;
    while (j < 10000) {
        if (haystack.contains("fox")) {
            found = found + 1;
        };
        j++;
    };
    print(found, newLine=true);

    // Benchmark 3: String reverse via StringBuilder
    var s: str = "Hello Mocha World";
    var k: int = 0;
    while (k < 10000) {
        var sb3: StringBuilder = StringBuilder();
        sb3.append(s);
        var r: str = sb3.reverse();
        k++;
    };
    var sb_final: StringBuilder = StringBuilder();
    sb_final.append(s);
    print(sb_final.reverse(), newLine=true);

    // Benchmark 4: Split (same as before)
    var csv: str = "one,two,three,four,five";
    var count: int = 0;
    var l: int = 0;
    while (l < 10000) {
        var parts: str[] = csv.split(",");
        count = count + parts.length;
        l++;
    };
    print(count, newLine=true);
};

"""
from "mocha-stopwatch" import *;

function test(didLoad) -> null {
    var sw: Stopwatch = Stopwatch();

    // Benchmark 1: StringBuilder concat
    sw.begin();
    var sb1: StringBuilder = StringBuilder();
    var i: int = 0;
    while (i < 10000) {
        sb1.append("a");
        i++;
    };
    print(sb1.toString().length, newLine=true);
    sw.end();
    print("B1 StringBuilder concat: " + str(sw.elapsed_ms()) + "ms", newLine=true);

    // Benchmark 2: Contains
    sw.reset();
    sw.begin();
    var haystack: str = "the quick brown fox jumps over the lazy dog";
    var found: int = 0;
    var j: int = 0;
    while (j < 10000) {
        if (haystack.contains("fox")) {
            found = found + 1;
        };
        j++;
    };
    print(found, newLine=true);
    sw.end();
    print("B2 contains: " + str(sw.elapsed_ms()) + "ms", newLine=true);

    // Benchmark 3: Reverse
    sw.reset();
    sw.begin();
    var s: str = "Hello Mocha World";
    var k: int = 0;
    while (k < 10000) {
        var sb3: StringBuilder = StringBuilder();
        sb3.append(s);
        var r: str = sb3.reverse();
        k++;
    };
    var sb_final: StringBuilder = StringBuilder();
    sb_final.append(s);
    print(sb_final.reverse(), newLine=true);
    sw.end();
    print("B3 reverse: " + str(sw.elapsed_ms()) + "ms", newLine=true);

    // Benchmark 4: Split
    sw.reset();
    sw.begin();
    var csv: str = "one,two,three,four,five";
    var count: int = 0;
    var l: int = 0;
    while (l < 10000) {
        var parts: str[] = csv.split(",");
        count = count + parts.length;
        l++;
    };
    print(count, newLine=true);
    sw.end();
    print("B4 split: " + str(sw.elapsed_ms()) + "ms", newLine=true);
};"""