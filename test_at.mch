function main(didLoad) -> null {
    var i: int = 0;
    while (i < 2000000) {
        var arr: str[] = [];
        arr.push("item " + str(i));
        i++;
    };
    print("done", newLine=true);
};