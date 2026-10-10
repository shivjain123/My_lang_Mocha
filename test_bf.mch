function main(didLoad) -> null {
    var arr: str[] = alloc str[1];
    var s: str = "start";
    var i: int = 0;
    while (i < 2000000) {
        arr[0] = "item " + str(i);
        s = arr[0];
        i++;
    };
    print("done", newLine=true);
};