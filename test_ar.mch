function main(didLoad) -> null {
    var i: int = 0;
    while (i < 2000000) {
        var t: set<int> = <99>;
        t.delete(99);
        i++;
    };
    print("done", newLine=true);
};