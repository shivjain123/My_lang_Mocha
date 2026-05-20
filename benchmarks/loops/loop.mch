function main(didLoad) -> null {
    var total: int = 0;
    for (var i: int = 0; i < 100000000; i++) {
        total = total + i;
    };
    print(total);
};