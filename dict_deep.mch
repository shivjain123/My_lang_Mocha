function test_dict_copy(didLoad) -> null {
    print("--- dict copy ---", newLine=true);

    var a: dict = {
        "name": "Shiv",
        "inner": {
            "x": 1,
        },
    };

    var b: dict = a.copy();

    b["inner"]["x"] = 99;
    b["name"] = "Copy";

    print(a["name"], newLine=true);          // Shiv
    print(b["name"], newLine=true);          // Copy
    print(a["inner"]["x"], newLine=true);    // 1  (99 means the inner dict is still shared)
    print(b["inner"]["x"], newLine=true);    // 99
    print(b.jsonify(), newLine=true);

    var d:dict = b.copy();

    d["quote"] = "say \"hi\"";
    d["lines"] = "a\nb";
    d["pi"] = 2.5;
    d["whole"] = 3.0;
    d["ok"] = true;
    print(d.jsonify(), newLine=true);

    d["arr"] = [1, 2, 3];
    print(d.jsonify(), newLine=true);
    print("\n");
    for each i in d.allValues(){
        print(i, newLine=true);
    };
    print(d["inner"], newLine=true);
};