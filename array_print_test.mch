function main(didLoad) -> null {
    var a: int[] = [1, 2, 3];
    var b: str[] = ["apple", "banana"];
    var c: float[] = [1.5, 2.0, 3.25];
    var d: bool[] = [];
    d.push(true);
    d.push(false);
    d.push(true);
    var e: int[] = [];

    print("int:", newLine=true);
    print(a, newLine=true);
    print("str:", newLine=true);
    print(b, newLine=true);
    print("float:", newLine=true);
    print(c, newLine=true);
    print("bool:", newLine=true);
    print(d, newLine=true);
    print("empty:", newLine=true);
    print(e, newLine=true);
    print("\n");

    var f: vast[] = [10, 20, 30];
    print("vast:", newLine=true);
    print(f, newLine=true);
};