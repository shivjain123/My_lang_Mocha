function main(didLoad) -> null {
    var a: int[] = [];
    a.push(1);
    a.push(2);
    a.push(1);
    a.push(3);
    var total: int = 0;
    var i: int = 0;
    while (i < 2000000) {
        total = total + a.occs(1);
        i++;
    };
    print(total, newLine=true);
};