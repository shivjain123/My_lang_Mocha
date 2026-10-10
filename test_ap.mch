function main(didLoad) -> null {
    var s: set<int> = <1, 2, 3, 4>;
    var hits: int = 0;
    var i: int = 0;
    while (i < 2000000) {
        if (s.has(i)) {
            hits++;
        };
        var t: set<int> = <99>;
        t.delete(99);
        i++;
    };
    print(hits, newLine=true);
};