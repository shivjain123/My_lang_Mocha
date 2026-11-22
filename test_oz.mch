from "mocha-stats" import *;

function main(didLoad) -> null {
    var d: NormalDist = NormalDist(100.0, 15.0);

    // pdf: 5 values
    print(d.pdf(100.0), newLine=true);
    print(d.pdf(115.0), newLine=true);
    print(d.pdf(70.0), newLine=true);
    print(d.pdf(130.0), newLine=true);
    print(d.pdf(55.0), newLine=true);

    // cdf: 5 values
    print(d.cdf(100.0), newLine=true);
    print(d.cdf(115.0), newLine=true);
    print(d.cdf(70.0), newLine=true);
    print(d.cdf(130.0), newLine=true);
    print(d.cdf(55.0), newLine=true);

    // survival: 115, 160, 175, then the deep tail 190, 205, 220
    print(d.survival(115.0), newLine=true);
    print(d.survival(160.0), newLine=true);
    print(d.survival(175.0), newLine=true);
    print(d.survival(190.0), newLine=true);
    print(d.survival(205.0), newLine=true);
    print(d.survival(220.0), newLine=true);

    // contains(x, 0.95): 5 values
    print(d.contains(115.0, 0.95), newLine=true);
    print(d.contains(125.0, 0.95), newLine=true);
    print(d.contains(135.0, 0.95), newLine=true);
    print(d.contains(70.0, 0.95), newLine=true);
    print(d.contains(60.0, 0.95), newLine=true);
};