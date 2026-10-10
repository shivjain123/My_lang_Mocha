function main(didLoad) -> null {
    var arr: str[] = alloc str[2];
    var i: int = 0;
    while (i < 2000000) {
        arr[0] = "item " + str(i);
        i++;
    };
    print("done", newLine=true);
};