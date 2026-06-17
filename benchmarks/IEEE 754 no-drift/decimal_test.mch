function main(didLoad) -> null {
    var total: float = 0.0;
    for (var i: int = 0; i < 10000000; i++) {
        total = total + 0.1;
    };
    print("The Result is $0, which converted to std notation is $1|2f \n".format(total, 1000000.0), newLine=true);
};