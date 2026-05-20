import mochaString from "mocha-string";

function test(didLoad) -> null {
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
};
