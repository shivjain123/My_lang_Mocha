from "mocha-processing" import *;

function main(didLoad) -> null {
    var data: float[][] = [[5.1, 3.5, 1.4, 0.2], [4.9, 3.0, 1.4, 0.2], [4.7, 3.2, 1.3, 0.2], [4.6, 3.1, 1.5, 0.2], [5.0, 3.6, 1.4, 0.2], [5.4, 3.9, 1.7, 0.4], [4.6, 3.4, 1.4, 0.3], [5.0, 3.4, 1.5, 0.2], [4.4, 2.9, 1.4, 0.2], [4.9, 3.1, 1.5, 0.1], [5.4, 3.7, 1.5, 0.2], [4.8, 3.4, 1.6, 0.2], [4.8, 3.0, 1.4, 0.1], [4.3, 3.0, 1.1, 0.1], [5.8, 4.0, 1.2, 0.2], [5.7, 4.4, 1.5, 0.4], [5.4, 3.9, 1.3, 0.4], [5.1, 3.5, 1.4, 0.3], [5.7, 3.8, 1.7, 0.3], [5.1, 3.8, 1.5, 0.3]];

    var pca: PCAReducer = PCAReducer(2);
    var t: float[][] = pca.fit_transform(data);

    // explained variance (2 values)
    print(pca.explained_variance[0], newLine=true);
    print(pca.explained_variance[1], newLine=true);

    // explained variance ratio (2 values)
    var ratio: float[] = pca.explained_variance_ratio();
    print(ratio[0], newLine=true);
    print(ratio[1], newLine=true);

    // components needed for 90 percent
    print(pca.n_components_for_variance(0.9), newLine=true);

    // absolute projections of rows 0, 1, 19 (signs can differ)
    print(abs(t[0][0]), newLine=true);
    print(abs(t[0][1]), newLine=true);
    print(abs(t[1][0]), newLine=true);
    print(abs(t[1][1]), newLine=true);
    print(abs(t[19][0]), newLine=true);
    print(abs(t[19][1]), newLine=true);

    // reconstruction of rows 0 and 19 from the 2 components
    var back: float[][] = pca.inverse_transform(t);
    print(back[0][0], newLine=true);
    print(back[0][1], newLine=true);
    print(back[0][2], newLine=true);
    print(back[0][3], newLine=true);
    print(back[19][0], newLine=true);
    print(back[19][1], newLine=true);
    print(back[19][2], newLine=true);
    print(back[19][3], newLine=true);
};