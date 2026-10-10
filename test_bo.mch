function main(didLoad) -> null {
    var t: (int, 2) = (1, 2);
    var i: int = 0;
    while (i < 2000000) {
        t = (i, 2);
        i++;
    };
    print("done", newLine=true);
};