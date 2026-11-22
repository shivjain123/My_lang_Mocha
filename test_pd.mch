from "mocha-stats" import *;

function main(didLoad) -> null {
    var d: ExponentialDist = ExponentialDist(0.5);

    // pdf(0, 1, 4, 10)
    print(d.pdf(0.0), newLine=true);
    print(d.pdf(1.0), newLine=true);
    print(d.pdf(4.0), newLine=true);
    print(d.pdf(10.0), newLine=true);

    // cdf(1E-7, 0.1, 1, 4, 10, 50)
    print(d.cdf(1E-7), newLine=true);
    print(d.cdf(0.1), newLine=true);
    print(d.cdf(1.0), newLine=true);
    print(d.cdf(4.0), newLine=true);
    print(d.cdf(10.0), newLine=true);
    print(d.cdf(50.0), newLine=true);

    // survival(1, 10, 40, 80)
    print(d.survival(1.0), newLine=true);
    print(d.survival(10.0), newLine=true);
    print(d.survival(40.0), newLine=true);
    print(d.survival(80.0), newLine=true);

    // mean, variance, median
    print(d.mean(), newLine=true);
    print(d.variance(), newLine=true);
    print(d.median(), newLine=true);

    // memoryless(3, 2) and memoryless(20, 30)
    print(d.memoryless(3.0, 2.0), newLine=true);
    print(d.memoryless(20.0, 30.0), newLine=true);
};