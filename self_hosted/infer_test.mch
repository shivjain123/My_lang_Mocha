from "mocha-matvec" import *;

class Bag {
    var items: int[];
    var names: str[];
    function constructor() -> null {
        this.items = [3, 4];
        this.names = ["a"];
    };
    function first() -> int {
        return this.items[0];
    };
    function firstName() -> str {
        return this.names[0];
    };
};

function infer_tests(didLoad) -> null {
    var b: Bag = Bag();
    print(str(b.first()), newLine=true);
};
