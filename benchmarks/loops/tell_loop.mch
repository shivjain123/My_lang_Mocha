function main(didLoad) -> null {
    var n: int = 100000000;
    var secret: int = n + 0;  //force no const folding
    var total: int = 0;
    for (var i: int = 0; i < secret; i++) {
        total = total + i;
    };
    print(total);
};