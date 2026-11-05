function main(didLoad) -> null {
    // control: a separate dict inside another one
    var inner: dict = {"x": 1};
    var outer: dict = {"name": "Shiv"};
    outer["a"] = inner;
    print("control ok", newLine=true);

    // the case in question: a dict inside itself
    var d: dict = {"name": "Shiv"};
    d["a"] = d;
    print("self insert accepted", newLine=true);
    print(d);

    print("\n");
};