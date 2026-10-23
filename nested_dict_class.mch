class DictHolder {
    var d: dict;

    function setup() -> null {
        this.d = {
            "inner": {
                "x": 1,
            },
        };
    };

    function bump() -> null {
        this.d["inner"]["x"] = 99;
    };

    function show() -> null {
        var n: int = this.d["inner"]["x"];
        print(this.d["inner"]["x"], newLine=true);
    };
};

function test_this_dict(didLoad) -> null {
    print("--- this.d nested write ---", newLine=true);
    var h: DictHolder = DictHolder();
    h.setup();
    h.show();   // 1
    h.bump();
    h.show();   // 99
};