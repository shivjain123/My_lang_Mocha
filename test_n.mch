class Named {
    var label: str;
    function constructor(l: str) -> null {
        this.label = l;
    };
    function get() -> str {
        return this.label;
    };
};

function main(didLoad) -> null {
    var o: Named = Named("hello");
    var i: int = 0;
    while (i < 1000) {
        var s: str = o.get();
        i++;
    };
    print("done", newLine=true);
};