function main(didLoad) -> null {
    var arr: str[] = alloc str[2];
    var i: int = 0;
    while (i < 2000000) {
        var s: str = "item " + str(i);
        arr[0] = s;
        arr[1] = arr[0];
        i++;
    };
    print("done", newLine=true);
};