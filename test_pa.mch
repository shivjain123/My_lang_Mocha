from "mocha-stats" import *;

function main(didLoad) -> null {
    var d: PoissonDist = PoissonDist(4.5);

    // pmf at k = 0, 2, 4, 10
    print(d.pmf(0), newLine=true);
    print(d.pmf(2), newLine=true);
    print(d.pmf(4), newLine=true);
    print(d.pmf(10), newLine=true);

    // cdf at k = 0, 2, 4, 10
    print(d.cdf(0), newLine=true);
    print(d.cdf(2), newLine=true);
    print(d.cdf(4), newLine=true);
    print(d.cdf(10), newLine=true);

    // survival at k = 2, 10, 15, 20, 25
    print(d.survival(2), newLine=true);
    print(d.survival(10), newLine=true);
    print(d.survival(15), newLine=true);
    print(d.survival(20), newLine=true);
    print(d.survival(25), newLine=true);

    // mean and variance
    print(d.mean(), newLine=true);
    print(d.variance(), newLine=true);
};