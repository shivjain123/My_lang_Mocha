from "mocha-processing" import *;

function test_pca_real(didLoad) -> null {
    print("=== PCAReducer — Real Data Test ===", newLine=true);
    print("", newLine=true);

    // ──────────────────────────────────────────────
    // 1. 2D Gaussian blob (isotropic)
    //    Equal variance in all directions.
    //    PCA should give ~equal explained variance.
    // ──────────────────────────────────────────────

    var n: int = 200;
    var data_blob: float[][] = alloc float[n][2];

    // Fill with Gaussian noise (mean=0, std=2)
    var i: int = 0;
    while (i < n) {
        var x: float = rand_float(0.0, 1.0) * 2.0;
        var y: float = rand_float(0.0, 1.0) * 2.0;
        // Convert to Gaussian-ish via Box-Muller (or just uniform for a quick test)
        data_blob[i][0] = x;
        data_blob[i][1] = y;
        i++;
    };

    var pca_blob: PCAReducer = PCAReducer(2);
    pca_blob.fit(data_blob);
    var ratio_blob: float[] = pca_blob.explained_variance_ratio();

    print("--- 2D Isotropic Blob ---", newLine=true);
    print("Explained variance ratio:", newLine=true);
    print("  PC1: " + str(ratio_blob[0]), newLine=true);
    print("  PC2: " + str(ratio_blob[1]), newLine=true);
    print("Components for 95%: " + str(pca_blob.n_components_for_variance(0.95)), newLine=true);
    print("", newLine=true);

    // ──────────────────────────────────────────────
    // 2. Elongated 2D Gaussian (variance along one axis)
    //    PCA should capture ~100% in first component.
    // ──────────────────────────────────────────────

    var data_elong: float[][] = alloc float[n][2];

    // Strong correlation: y = x + noise
    i = 0;
    while (i < n) {
        var x: float = rand_float(-5.0, 5.0);
        var noise: float = rand_float(-0.5, 0.5);
        data_elong[i][0] = x;
        data_elong[i][1] = x + noise;
        i++;
    };

    var pca_elong: PCAReducer = PCAReducer(2);
    pca_elong.fit(data_elong);
    var ratio_elong: float[] = pca_elong.explained_variance_ratio();

    print("--- 2D Elongated Blob ---", newLine=true);
    print("Explained variance ratio:", newLine=true);
    print("  PC1: " + str(ratio_elong[0]), newLine=true);
    print("  PC2: " + str(ratio_elong[1]), newLine=true);
    print("Components for 95%: " + str(pca_elong.n_components_for_variance(0.95)), newLine=true);
    print("", newLine=true);

    // ──────────────────────────────────────────────
    // 3. 4D → 2D latent structure
    //    Data is generated from 2 hidden variables + noise.
    //    PCA should recover 2 meaningful components.
    // ──────────────────────────────────────────────

    var n4: int = 100;
    var data4: float[][] = alloc float[n4][4];

    i = 0;
    while (i < n4) {
        var t1: float = rand_float(-3.0, 3.0);
        var t2: float = rand_float(-3.0, 3.0);

        // 4D observations = linear combination of t1, t2 + noise
        data4[i][0] = 2.0 * t1 + 1.0 * t2 + rand_float(-0.3, 0.3);
        data4[i][1] = 1.0 * t1 + 2.0 * t2 + rand_float(-0.3, 0.3);
        data4[i][2] = 1.0 * t1 - 1.0 * t2 + rand_float(-0.3, 0.3);
        data4[i][3] = 0.5 * t1 + 1.5 * t2 + rand_float(-0.3, 0.3);
        i++;
    };

    var pca4: PCAReducer = PCAReducer(4);
    pca4.fit(data4);
    var ratio4: float[] = pca4.explained_variance_ratio();

    print("--- 4D Latent Structure (2 hidden vars) ---", newLine=true);
    print("Explained variance ratio:", newLine=true);
    print("  PC1: " + str(ratio4[0]), newLine=true);
    print("  PC2: " + str(ratio4[1]), newLine=true);
    print("  PC3: " + str(ratio4[2]), newLine=true);
    print("  PC4: " + str(ratio4[3]), newLine=true);
    print("Components for 95%: " + str(pca4.n_components_for_variance(0.95)), newLine=true);
    print("", newLine=true);

    // ──────────────────────────────────────────────
    // 4. Inverse transform reconstruction error
    // ──────────────────────────────────────────────

    print("--- Reconstruction Error (2D → 4D) ---", newLine=true);
    var pca_recon: PCAReducer = PCAReducer(2);
    pca_recon.fit(data4);
    var reduced4: float[][] = pca_recon.transform(data4);
    var reconstructed: float[][] = pca_recon.inverse_transform(reduced4);

    var mse_total: float = 0.0;
    var sample_idx: int = 0;
    while (sample_idx < n4) {
        var mse_sample: float = 0.0;
        var dim: int = 0;
        while (dim < 4) {
            var diff: float = data4[sample_idx][dim] - reconstructed[sample_idx][dim];
            mse_sample = mse_sample + diff * diff;
            dim++;
        };
        mse_total = mse_total + mse_sample / 4.0;
        sample_idx++;
    };
    var mse_avg: float = mse_total / float(n4);

    print("Average reconstruction MSE: " + str(mse_avg), newLine=true);
    print("", newLine=true);

    print("=== PCAReducer Test Done ===", newLine=true);
};