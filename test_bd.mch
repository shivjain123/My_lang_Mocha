function main(didLoad) -> null {
    var d: dict = {"k": "start"};
    var i: int = 0;
    while (i < 2000000) {
        d["k"] = "item " + str(i);
        var x: str = d["k"];
        i++;
    };
    print("done", newLine=true);
};