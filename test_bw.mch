function main(didLoad) -> null {
    var d: dict = {"a": 1, "b": 2};
    var i: int = 0;
    while (i < 2000000) {
        var c: dict = d.copy();
        i++;
    };
    print("done", newLine=true);
};