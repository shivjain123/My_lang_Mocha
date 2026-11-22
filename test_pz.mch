from "mocha-forge" import *;

function main(didLoad) -> null {
    var x: float[][] = [[1.0, 1.2], [1.4, 0.8], [0.7, 1.1], [1.2, 1.5], [0.9, 0.6], [1.5, 1.3], [8.0, 8.2], [8.4, 7.8], [7.7, 8.1], [8.2, 8.5], [7.9, 7.6], [8.5, 8.3], [1.1, 8.2], [1.5, 7.8], [0.8, 8.1], [1.3, 8.6], [0.9, 7.7], [1.6, 8.3]];

    var km: KMeans = KMeans(3);
    km.fit(x);
    var labels: int[] = km.get_labels();

    // 1 if every blob got one label and the three blobs got three different labels
    var ok: int = 1;
    var i: int = 1;
    while (i < 6) {
        if (labels[i] != labels[0]) { ok = 0; };
        i++;
    };
    i = 7;
    while (i < 12) {
        if (labels[i] != labels[6]) { ok = 0; };
        i++;
    };
    i = 13;
    while (i < 18) {
        if (labels[i] != labels[12]) { ok = 0; };
        i++;
    };
    if (labels[0] == labels[6] || labels[0] == labels[12] || labels[6] == labels[12]) { ok = 0; };
    print(ok, newLine=true);

    // inertia
    print(km.inertia(x), newLine=true);

    // centroid of blob A's cluster, blob B's cluster, blob C's cluster
    var c: float[][] = km.get_centroids();
    print(c[labels[0]][0], newLine=true);
    print(c[labels[0]][1], newLine=true);
    print(c[labels[6]][0], newLine=true);
    print(c[labels[6]][1], newLine=true);
    print(c[labels[12]][0], newLine=true);
    print(c[labels[12]][1], newLine=true);
};