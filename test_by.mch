function main(didLoad) -> null {
    var a: dict = {"a": 1};
    var b: dict = {"b": 2};
    var m: dict = a.merge(b);
    var c: dict = m.copy();
    var x: int = c["a"];
    var y: int = c["b"];
    print(x + y, newLine=true);
};