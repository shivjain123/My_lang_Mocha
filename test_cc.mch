function main(didLoad) -> null {
    var d: dict = {"person": {"name": "Shiv"}};
    var i: int = 0;
    while (i < 2000000) {
        var s: dict = d["person"]["name"];
        i++;
    };
    print("done", newLine=true);
};