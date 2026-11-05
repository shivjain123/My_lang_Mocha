function main(didLoad) -> null {
    var neg: int = -5;
    var negf: float = -2.5;
    var negbig: vast = -9999999999;

    // positional
    var s1: str = "int $0, float $1, vast $2".format(neg, negf, negbig);
    print(s1, newLine=true);

    // positional with literals
    var s2: str = "lit $0 and $1".format(-7, -0.5);
    print(s2, newLine=true);

    // named
    var s3: str = "int $a, float $b, vast $c".format(a=neg, b=negf, c=negbig);
    print(s3, newLine=true);

    // zero and a minus sign next to the placeholder
    var s4: str = "-$0 and $1-".format(neg, 0);
    print(s4, newLine=true);

    print("\n");
};