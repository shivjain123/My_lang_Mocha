function main(didLoad) -> null {
    var src: str[] = alloc str[1];
    var i: int = 0;
    while (i < 2000000) {
        src[0] = "item " + str(i);
        var dst: str[] = [];
        dst.push(src[0]);
        i++;
    };
    print("done", newLine=true);
};