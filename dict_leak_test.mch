function run(didLoad){
    var d: dict = {
        "name": "Shiv",
        "inner": {
            "x": 1,
        },
    };
    d["quote"] = "say \"hi\"";
    d["lines"] = "a\nb";
    d["pi"] = 2.5;
    d["whole"] = 3.0;
    d["ok"] = true;
    d["arr"] = [1, 2, 3];
    var i: int = 0;
    while (i < 100000) {
        print(d.copy(), newLine=true);
        i++;
    };
};