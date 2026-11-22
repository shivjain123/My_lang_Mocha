from "mocha-stats" import *;

function main(didLoad) -> null {
    var d: BetaDist = BetaDist(2.5, 4.0);

    // beta_func
    print(d.beta_func(), newLine=true);

    // pdf(0.1, 0.3, 0.6, 0.95, 0.999)
    print(d.pdf(0.1), newLine=true);
    print(d.pdf(0.3), newLine=true);
    print(d.pdf(0.6), newLine=true);
    print(d.pdf(0.95), newLine=true);
    print(d.pdf(0.999), newLine=true);

    // mean, variance, mode, skewness
    print(d.mean(), newLine=true);
    print(d.variance(), newLine=true);
    print(d.mode(), newLine=true);
    print(d.skewness(), newLine=true);

    // Beta(8, 20): beta_func and pdf(0.05, 0.3, 0.9, 0.99)
    var g: BetaDist = BetaDist(8.0, 20.0);
    print(g.beta_func(), newLine=true);
    print(g.pdf(0.05), newLine=true);
    print(g.pdf(0.3), newLine=true);
    print(g.pdf(0.9), newLine=true);
    print(g.pdf(0.99), newLine=true);

    // update(3, 5) gives Beta(5.5, 9.0): mean, variance, skewness, mode
    var u: BetaDist = d.update(3, 5);
    print(u.mean(), newLine=true);
    print(u.variance(), newLine=true);
    print(u.skewness(), newLine=true);
    print(u.mode(), newLine=true);

    // is_uniform and is_symmetric
    var one: BetaDist = BetaDist(1.0, 1.0);
    var sym: BetaDist = BetaDist(3.0, 3.0);
    print(one.is_uniform(), newLine=true);
    print(d.is_uniform(), newLine=true);
    print(sym.is_symmetric(), newLine=true);
    print(d.is_symmetric(), newLine=true);
};