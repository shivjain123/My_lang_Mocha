function main(didLoad) -> null {
    // Stage 4: d["key"] read — exercises the rc_retain-on-get fix (Step 49)
    var d4: dict = {"name": "Shiv"};
    var got: str = "";
    var m: int = 0;
    while (m < 200000) {
        got = d4["name"];
        m++;
    };
    print("stage 4 done", newLine=true);

    // Stage 7: merge() and copy() with a FRESH dict argument
    var base: dict = {"x": "1"};
    var merged: dict = {};
    var copied: dict = {};
    var q: int = 0;
    while (q < 200000) {
        merged = base.merge({"y": "2"}, override=true);
        copied = base.copy();
        q++;
    };
    print("stage 7 done", newLine=true);

    print("all stages done", newLine=true);
};