from "mocha-stats" import *;

function main(didLoad) -> null {
    var d: FDist = FDist(5.0, 20.0);

    // pdf(0.2, 1, 3, 10)
    print(d.pdf(0.2), newLine=true);
    print(d.pdf(1.0), newLine=true);
    print(d.pdf(3.0), newLine=true);
    print(d.pdf(10.0), newLine=true);

    // cdf(0.01, 0.2, 1, 3, 10, 50)
    print(d.cdf(0.01), newLine=true);
    print(d.cdf(0.2), newLine=true);
    print(d.cdf(1.0), newLine=true);
    print(d.cdf(3.0), newLine=true);
    print(d.cdf(10.0), newLine=true);
    print(d.cdf(50.0), newLine=true);

    // survival(0.2, 1, 3, 10, 50, 200)
    print(d.survival(0.2), newLine=true);
    print(d.survival(1.0), newLine=true);
    print(d.survival(3.0), newLine=true);
    print(d.survival(10.0), newLine=true);
    print(d.survival(50.0), newLine=true);
    print(d.survival(200.0), newLine=true);

    // mean and variance
    print(d.mean(), newLine=true);
    print(d.variance(), newLine=true);
};