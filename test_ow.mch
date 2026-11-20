from "mocha-stats" import *;

function main(didLoad) -> null {
    var x: float[] = [5.1, 4.9, 4.7, 4.6, 5.0, 5.4, 4.6, 5.0, 4.4, 4.9, 5.4, 4.8, 4.8, 4.3, 5.8, 5.7, 5.4, 5.1, 5.7, 5.1, 5.4, 5.1, 4.6, 5.1, 4.8, 5.0, 5.0, 5.2, 5.2, 4.7, 4.8, 5.4, 5.2, 5.5, 4.9, 5.0, 5.5, 4.9, 4.4, 5.1, 5.0, 4.5, 4.4, 5.0, 5.1, 4.8, 5.1, 4.6, 5.3, 5.0, 7.0, 6.4, 6.9, 5.5, 6.5, 5.7, 6.3, 4.9, 6.6, 5.2, 5.0, 5.9, 6.0, 6.1, 5.6, 6.7, 5.6, 5.8, 6.2, 5.6, 5.9, 6.1, 6.3, 6.1, 6.4, 6.6, 6.8, 6.7, 6.0, 5.7, 5.5, 5.5, 5.8, 6.0, 5.4, 6.0, 6.7, 6.3, 5.6, 5.5, 5.5, 6.1, 5.8, 5.0, 5.6, 5.7, 5.7, 6.2, 5.1, 5.7, 6.3, 5.8, 7.1, 6.3, 6.5, 7.6, 4.9, 7.3, 6.7, 7.2, 6.5, 6.4, 6.8, 5.7, 5.8, 6.4, 6.5, 7.7, 7.7, 6.0, 6.9, 5.6, 7.7, 6.3, 6.7, 7.2, 6.2, 6.1, 6.4, 7.2, 7.4, 7.9, 6.4, 6.3, 6.1, 7.7, 6.3, 6.4, 6.0, 6.9, 6.7, 6.9, 5.8, 6.8, 6.7, 6.7, 6.3, 6.5, 6.2, 5.9];
    print(x.length, newLine=true);
    print(x.mean(), newLine=true);
    print(x.median(), newLine=true);
    var modes: float[] = x.mode();
    print(modes.length, newLine=true);
    print(modes[0], newLine=true);
    print(x.var_popu(), newLine=true);
    print(x.var_sample(), newLine=true);
    print(x.std_popu(), newLine=true);
    print(x.std_sample(), newLine=true);
    print(x.first_quart(), newLine=true);
    print(x.third_quart(), newLine=true);
    print(x.range_of_quart(), newLine=true);
    var b: float[] = x.outlier_bounds();
    print(b[0], newLine=true);
    print(b[1], newLine=true);
    print(x.skewness(), newLine=true);
    print(x.skewness_sample(), newLine=true);
    print(x.kurtosis(), newLine=true);
    print(x.kurtosis_sample(), newLine=true);
};