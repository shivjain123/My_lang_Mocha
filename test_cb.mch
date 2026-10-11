function main(didLoad) -> null {
    var g: str[][] = alloc str[2][2];
    var i: int = 0;
    while (i < 2000000) {
        g[0][0] = "item " + str(i);
        var s: str = g[0][0];
        i++;
    };
    print("done", newLine=true);
};