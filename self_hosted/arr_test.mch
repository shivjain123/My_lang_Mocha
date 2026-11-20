function main(didLoad) -> null {
    var a: str[] = [];
    var i: int = 0;
    while (i < 400) {
        a.push("declare void @x()");
        a.push("");
        i += 1;
    };
    print(a.length, newLine=true);
};