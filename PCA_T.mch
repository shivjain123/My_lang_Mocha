function puts(s: str) -> int native puts;
from "mocha-processing" import *;
function test_pca(didLoad) -> null {
    puts("=== PCAReducer Test ===");

    // ── Simple 2D dataset — obvious structure along one axis ──
    // Points roughly along y = x line — first PC should capture most variance
    var data: float[][] = alloc float[6][2];
    data[0][0] = 1.0; data[0][1] = 1.0;
    data[1][0] = 2.0; data[1][1] = 2.0;
    data[2][0] = 3.0; data[2][1] = 3.0;
    data[3][0] = 4.0; data[3][1] = 4.0;
    data[4][0] = 5.0; data[4][1] = 5.0;
    data[5][0] = 6.0; data[5][1] = 6.0;

    var pca: PCAReducer = PCAReducer(2);
    pca.fit(data);

    // explained variance ratio — first component should be ~1.0, second ~0.0
    var ratio: float[] = pca.explained_variance_ratio();
    puts("Explained variance ratio:");
    puts(str(ratio[0]));   // ~1.0
    puts(str(ratio[1]));   // ~0.0

    // n_components_for_variance — should need only 1 component for 95%
    var needed: int = pca.n_components_for_variance(0.95);
    puts("Components needed for 95% variance:");
    puts(str(needed));     // 1

    // ── transform ──
    var reduced: float[][] = pca.fit_transform(data);
    puts("Reduced shape (should be 6x2):");
    puts(str(reduced.length));      // 6
    puts(str(reduced.cols));        // 2

    // ── 4D dataset — reduce to 2D ──
    puts("--- 4D → 2D ---");
    var data4: float[][] = alloc float[5][4];
    data4[0][0] = 1.0; data4[0][1] = 2.0; data4[0][2] = 3.0; data4[0][3] = 4.0;
    data4[1][0] = 2.0; data4[1][1] = 3.0; data4[1][2] = 4.0; data4[1][3] = 5.0;
    data4[2][0] = 3.0; data4[2][1] = 4.0; data4[2][2] = 5.0; data4[2][3] = 6.0;
    data4[3][0] = 4.0; data4[3][1] = 5.0; data4[3][2] = 6.0; data4[3][3] = 7.0;
    data4[4][0] = 5.0; data4[4][1] = 6.0; data4[4][2] = 7.0; data4[4][3] = 8.0;

    var pca2: PCAReducer = PCAReducer(2);
    var reduced4: float[][] = pca2.fit_transform(data4);
    puts("Reduced shape (should be 5x2):");
    puts(str(reduced4.length));   // 5
    puts(str(reduced4.cols));     // 2

    var ratio4: float[] = pca2.explained_variance_ratio();
    puts("Explained variance ratio (4D→2D):");
    puts(str(ratio4[0]));   // ~1.0 (all variance in first component, perfectly linear data)
    puts(str(ratio4[1]));   // ~0.0

    var needed4: int = pca2.n_components_for_variance(0.95);
    puts("Components needed for 95% (should be 1):");
    puts(str(needed4));     // 1

    // ── inverse_transform — reconstruct and check closeness ──
    puts("--- inverse_transform ---");
    var pca3: PCAReducer = PCAReducer(2);
    pca3.fit(data);
    var reduced3: float[][] = pca3.transform(data);
    var reconstructed: float[][] = pca3.inverse_transform(reduced3);

    // first point should reconstruct close to [1.0, 1.0]
    puts("Reconstructed[0][0] (expect ~1.0):");
    puts(str(reconstructed[0][0]));
    puts("Reconstructed[0][1] (expect ~1.0):");
    puts(str(reconstructed[0][1]));

    // last point should reconstruct close to [6.0, 6.0]
    puts("Reconstructed[5][0] (expect ~6.0):");
    puts(str(reconstructed[5][0]));
    puts("Reconstructed[5][1] (expect ~6.0):");
    puts(str(reconstructed[5][1]));

    puts("=== PCAReducer Test Done ===");
};