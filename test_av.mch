function main(didLoad) -> null {
    var arr: str[] = [];
    var i: int = 0;
    while (i < 2000000) {
        arr.push("item " + str(i));
        arr.pop();
        i++;
    };
    print("done", newLine=true);
};