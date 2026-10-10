function main(didLoad) -> null {
    var arr: str[] = [];
    var i: int = 0;
    while (i < 2000000) {
        var s: str = "item " + str(i);
        arr.push(s);
        arr.pop();
        i++;
    };
    print("done", newLine=true);
};