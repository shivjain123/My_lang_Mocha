from "mocha-stats" import *;

function main(didLoad) -> null {
    var means: float[] = [0.0, 3.0, 8.0];
    var stds: float[] = [1.0, 0.5, 2.0];
    var weights: float[] = [0.5, 0.3, 0.2];
    var g: GaussianMixture = GaussianMixture(means, stds, weights);

    // pdf(-1, 0, 2.5, 3, 6, 12, 30)
    print(g.pdf(-1.0), newLine=true);
    print(g.pdf(0.0), newLine=true);
    print(g.pdf(2.5), newLine=true);
    print(g.pdf(3.0), newLine=true);
    print(g.pdf(6.0), newLine=true);
    print(g.pdf(12.0), newLine=true);
    print(g.pdf(30.0), newLine=true);

    // cdf(-6, -2, 1, 3, 6, 10, 40)
    print(g.cdf(-6.0), newLine=true);
    print(g.cdf(-2.0), newLine=true);
    print(g.cdf(1.0), newLine=true);
    print(g.cdf(3.0), newLine=true);
    print(g.cdf(6.0), newLine=true);
    print(g.cdf(10.0), newLine=true);
    print(g.cdf(40.0), newLine=true);

    // mean, variance, dominant component
    print(g.mean(), newLine=true);
    print(g.variance(), newLine=true);
    print(g.dominant_component(), newLine=true);

    // responsibility(x, k)
    print(g.responsibility(2.5, 0), newLine=true);
    print(g.responsibility(2.5, 1), newLine=true);
    print(g.responsibility(2.5, 2), newLine=true);
    print(g.responsibility(12.0, 2), newLine=true);
    print(g.responsibility(12.0, 0), newLine=true);
    print(g.responsibility(7.0, 2), newLine=true);
};