function main(didLoad) -> null {
    var i: int = 0;
    while (i < 2000000) {
        var d: dict = {
            "seed": 1,
        };
        d["k"] = "v";
        i++;
    };
    print("done", newLine=true);
};