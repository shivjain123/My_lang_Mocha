function main(didLoad) -> null {
    var a: dict = {"a": 1};
    var b: dict = {"b": 2};
    var i: int = 0;
    while (i < 2000000) {
        var m: dict = a.merge(b);
        i++;
    };
    print("done", newLine=true);
};