class Holder {
    var s: set<str>;

    function constructor() -> null {
        this.s = <"pear", "apple", "fig">;
    };

    function lowest() -> str {
        return this.s.min();
    };
};

function main(didLoad) -> null {
    var h: Holder = Holder();
    print(h.lowest(), newLine=true);
    var ints: set<int> = <5, 2, 9>;
    print(ints.max(), newLine=true);
    print("\n");
};