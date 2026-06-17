function main(didLoad) -> null {
    var a: int = 12;
    var b: int = 10;

    var and_r: int = a & b;
    var or_r: int  = a | b;
    var xor_r: int = a ^ b;
    var not_r: int = ~a;
    var shl_r: int = a << 1;
    var shr_r: int = a >> 1;

    print(and_r, newLine=true);
    print(or_r, newLine=true);
    print(xor_r, newLine=true);
    print(not_r, newLine=true);
    print(shl_r, newLine=true);
    print(shr_r, newLine=true);
    print("\n");
};