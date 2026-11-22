from "mocha-processing" import *;

function main(didLoad) -> null {
    var data: float[][] = [[5.1, 3.5, 1.4, 0.2], [4.9, 3.0, 1.4, 0.2], [4.7, 3.2, 1.3, 0.2], [4.6, 3.1, 1.5, 0.2], [5.0, 3.6, 1.4, 0.2], [5.4, 3.9, 1.7, 0.4], [4.6, 3.4, 1.4, 0.3], [5.0, 3.4, 1.5, 0.2], [4.4, 2.9, 1.4, 0.2], [4.9, 3.1, 1.5, 0.1], [5.4, 3.7, 1.5, 0.2], [4.8, 3.4, 1.6, 0.2], [4.8, 3.0, 1.4, 0.1], [4.3, 3.0, 1.1, 0.1], [5.8, 4.0, 1.2, 0.2], [5.7, 4.4, 1.5, 0.4], [5.4, 3.9, 1.3, 0.4], [5.1, 3.5, 1.4, 0.3], [5.7, 3.8, 1.7, 0.3], [5.1, 3.8, 1.5, 0.3]];

    // 4 components kept: the full ratio list
    var full: PCAReducer = PCAReducer(4);
    full.fit(data);
    var r: float[] = full.explained_variance_ratio();
    print(r[0], newLine=true);
    print(r[1], newLine=true);
    print(r[2], newLine=true);
    print(r[3], newLine=true);
    print(full.n_components_for_variance(0.8), newLine=true);
    print(full.n_components_for_variance(0.9), newLine=true);
    print(full.n_components_for_variance(0.99), newLine=true);
    print(full.n_components_for_variance(1.0), newLine=true);

    // 2 components kept
    var two: PCAReducer = PCAReducer(2);
    two.fit(data);
    print(two.n_components_for_variance(0.8), newLine=true);
    print(two.n_components_for_variance(0.9), newLine=true);

    // must stop here with a loud error: 2 components cannot reach 99 percent
    print(two.n_components_for_variance(0.99), newLine=true);
    print("this line must NOT print", newLine=true);
};