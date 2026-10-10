function main(didLoad) -> null {
    var arr: int[] = [];
    var i: int = 0;
    while (i < 2000000) {
        arr.push(i);
        arr.pop();
        i++;
    };
    print("done", newLine=true);
};