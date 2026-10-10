function main(didLoad) -> null {
    var i: int = 0;
    while (i < 2000000) {
        var arr: str[] = [];
        var s: str = "item " + str(i);
        arr.push(s);
        arr.push("abc");
        i++;
    };
    print("done", newLine=true);
};