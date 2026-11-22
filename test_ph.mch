from "mocha-stats" import *;

function main(didLoad) -> null {
    var big: float[] = [5.1, 4.9, 4.7, 4.6, 5.0, 5.4, 4.6, 5.0, 4.4, 4.9, 5.4, 4.8, 4.8, 4.3, 5.8, 5.7, 5.4, 5.1, 5.7, 5.1, 5.4, 5.1, 4.6, 5.1, 4.8, 5.0, 5.0, 5.2, 5.2, 4.7, 4.8, 5.4, 5.2, 5.5, 4.9, 5.0, 5.5, 4.9, 4.4, 5.1];
    var small: float[] = [5.1, 4.9, 4.7, 4.6, 5.0, 5.4, 4.6, 5.0];

    // big (n = 40): z_score twice (no warning), then t_score once (warns)
    print(big.z_score(6.0), newLine=true);
    print(big.z_score(4.5), newLine=true);
    print(big.t_score(5.0), newLine=true);

    // small (n = 8): z_score once (warns), then t_score twice (no warning)
    print(small.z_score(5.5), newLine=true);
    print(small.t_score(5.0), newLine=true);
    print(small.t_score(4.8), newLine=true);
};