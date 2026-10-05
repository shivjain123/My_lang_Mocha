class Named {
    var label: str;
    var n: int;
    function constructor(l: str, v: int) -> null {
        this.label = l;
        this.n = v;
    };
};

function main(didLoad) -> null {
    var i: int = 0;
    while (i < 2000000) {
        var obj: Named = Named("fixed text", i);
        i++;
    };
    print("done", newLine=true);
};