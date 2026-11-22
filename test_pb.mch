from "mocha-stats" import *;

function main(didLoad) -> null {
    var d: PoissonDist = PoissonDist(4.5);
    print(d.pmf(16), newLine=true);
    print(d.pmf(21), newLine=true);
    print(d.pmf(26), newLine=true);
    print(d.pmf(30), newLine=true);
    print(d.pmf(40), newLine=true);
};