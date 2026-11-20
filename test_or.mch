function main(didLoad) -> null {
    var a: float = 5.0E-6;
    var b: float = a + 1.0E-13;
    print(b - a, newLine=true);
    var c: float = 3.0E-6;
    var d: float = c * 1.00001;
    print(d - c, newLine=true);
    var e: float = 5.0E-13;
    print(e, newLine=true);
    print(e * 1000.0, newLine=true);
};