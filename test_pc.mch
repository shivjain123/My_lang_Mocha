from "mocha-stats" import *;

function main(didLoad) -> null {
    var d: BinomialDist = BinomialDist(40, 0.3);

    // choose(0, 5, 12, 20)
    print(d.choose(0), newLine=true);
    print(d.choose(5), newLine=true);
    print(d.choose(12), newLine=true);
    print(d.choose(20), newLine=true);

    // pmf(0, 5, 12, 20, 30, 38)
    print(d.pmf(0), newLine=true);
    print(d.pmf(5), newLine=true);
    print(d.pmf(12), newLine=true);
    print(d.pmf(20), newLine=true);
    print(d.pmf(30), newLine=true);
    print(d.pmf(38), newLine=true);

    // cdf(0, 5, 12, 20, 30)
    print(d.cdf(0), newLine=true);
    print(d.cdf(5), newLine=true);
    print(d.cdf(12), newLine=true);
    print(d.cdf(20), newLine=true);
    print(d.cdf(30), newLine=true);

    // survival(5, 12, 20, 25, 30, 35)
    print(d.survival(5), newLine=true);
    print(d.survival(12), newLine=true);
    print(d.survival(20), newLine=true);
    print(d.survival(25), newLine=true);
    print(d.survival(30), newLine=true);
    print(d.survival(35), newLine=true);

    // mean and variance
    print(d.mean(), newLine=true);
    print(d.variance(), newLine=true);
};