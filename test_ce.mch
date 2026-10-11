function main(didLoad) -> null {
    var g: str[][] = alloc str[2][2];
    g[1][0] = "hi " + str(5);
    g[1][1] = g[1][0];
    var s: str = g[1][1];
    print(s, newLine=true);
};