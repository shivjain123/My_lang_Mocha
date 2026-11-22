from "mocha-stats" import *;

function main(didLoad) -> null {
    var d: GammaDist = GammaDist(3.5, 0.8);

    // pdf(0.5, 2, 5, 20, 60)
    print(d.pdf(0.5), newLine=true);
    print(d.pdf(2.0), newLine=true);
    print(d.pdf(5.0), newLine=true);
    print(d.pdf(20.0), newLine=true);
    print(d.pdf(60.0), newLine=true);

    // mean, variance, mode
    print(d.mean(), newLine=true);
    print(d.variance(), newLine=true);
    print(d.mode(), newLine=true);

    // a bigger alpha: GammaDist(30, 4), pdf(3, 7.5, 20)
    var g: GammaDist = GammaDist(30.0, 4.0);
    print(g.pdf(3.0), newLine=true);
    print(g.pdf(7.5), newLine=true);
    print(g.pdf(20.0), newLine=true);

    // the is_* checks
    var e: GammaDist = GammaDist(1.0, 0.5);
    print(e.is_exponential(), newLine=true);
    print(d.is_exponential(), newLine=true);
    var c: GammaDist = GammaDist(2.5, 0.5);
    print(c.is_chi_squared(5), newLine=true);
    print(c.is_chi_squared(4), newLine=true);
};