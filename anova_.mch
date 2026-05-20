from "mocha-stats" import *;
function puts(s: str) -> int native puts;

function test_fdist_anova(didLoad) -> null {
    puts("=== FDist + ANOVA Test ===");

    // ─────────────────────────────────────────
    // FDist basic sanity checks
    // ─────────────────────────────────────────
    puts("--- FDist ---");

    var fd: FDist = FDist(5.0, 10.0);

    // CDF at 0 should be 0
    puts("cdf(0):");
    puts(str(fd.cdf(0.0)));

    // CDF at large value should approach 1
    puts("cdf(100):");
    puts(str(fd.cdf(100.0)));

    // CDF at mean should be ~0.5 (rough check)
    var m: float = fd.mean();
    puts("mean:");
    puts(str(m));

    // survival + cdf should sum to 1
    var cdf_val: float = fd.cdf(2.0);
    var surv_val: float = fd.survival(2.0);
    var total: float = cdf_val + surv_val;
    puts("cdf(2) + survival(2):");
    puts(str(total));

    // Known value: F(5,10).cdf(3.0) ≈ 0.9343 (check with scipy)
    puts("cdf(3.0) with d1=5 d2=10:");
    puts(str(fd.cdf(3.0)));

    // variance
    puts("variance d1=5 d2=10:");
    puts(str(fd.variance()));

    // ─────────────────────────────────────────
    // one_way_anova: clearly separated groups
    // scipy: f_oneway([2,3,4,3,2],[8,9,8,7,9],[4,5,4,5,4])
    // expected: F~40+, p~0.00001
    // ─────────────────────────────────────────
    puts("--- ANOVA: clearly separated groups ---");

    var groups: float[][] = alloc float[3][5];
    groups[0][0] = 2.0; groups[0][1] = 3.0; groups[0][2] = 4.0; groups[0][3] = 3.0; groups[0][4] = 2.0;
    groups[1][0] = 8.0; groups[1][1] = 9.0; groups[1][2] = 8.0; groups[1][3] = 7.0; groups[1][4] = 9.0;
    groups[2][0] = 4.0; groups[2][1] = 5.0; groups[2][2] = 4.0; groups[2][3] = 5.0; groups[2][4] = 4.0;

    var r1: (float, 4) = one_way_anova(groups);
    puts("F-statistic:");
    puts(str(r1#0));
    puts("p-value:");
    puts(str(r1#1));
    puts("df_between:");
    puts(str(r1#2));
    puts("df_within:");
    puts(str(r1#3));

    // ─────────────────────────────────────────
    // one_way_anova: overlapping groups — high p-value
    // scipy: f_oneway([1,2,3,4,5],[2,3,4,5,6],[1,3,5,7,9])
    // expected: F~0.5, p~0.6
    // ─────────────────────────────────────────
    puts("--- ANOVA: overlapping groups ---");

    var groups2: float[][] = alloc float[3][5];
    groups2[0][0] = 1.0; groups2[0][1] = 2.0; groups2[0][2] = 3.0; groups2[0][3] = 4.0; groups2[0][4] = 5.0;
    groups2[1][0] = 2.0; groups2[1][1] = 3.0; groups2[1][2] = 4.0; groups2[1][3] = 5.0; groups2[1][4] = 6.0;
    groups2[2][0] = 1.0; groups2[2][1] = 3.0; groups2[2][2] = 5.0; groups2[2][3] = 7.0; groups2[2][4] = 9.0;

    var r2: (float, 4) = one_way_anova(groups2);
    puts("F-statistic:");
    puts(str(r2#0));
    puts("p-value:");
    puts(str(r2#1));
    puts("df_between:");
    puts(str(r2#2));
    puts("df_within:");
    puts(str(r2#3));

    // ─────────────────────────────────────────
    // one_way_anova_unequal: unequal group sizes
    // group0: [1,2,3] n=3
    // group1: [10,11,12,13] n=4
    // group2: [5,6] n=2
    // scipy: f_oneway([1,2,3],[10,11,12,13],[5,6])
    // expected: F~60+, p very small
    // ─────────────────────────────────────────
    puts("--- ANOVA unequal group sizes ---");

    var groups3: float[][] = alloc float[3][4];
    groups3[0][0] = 1.0; groups3[0][1] = 2.0; groups3[0][2] = 3.0; groups3[0][3] = 0.0;
    groups3[1][0] = 10.0; groups3[1][1] = 11.0; groups3[1][2] = 12.0; groups3[1][3] = 13.0;
    groups3[2][0] = 5.0; groups3[2][1] = 6.0; groups3[2][2] = 0.0; groups3[2][3] = 0.0;

    var sizes: int[] = [3, 4, 2];

    var r3: (float, 4) = one_way_anova_unequal(groups3, sizes);
    puts("F-statistic:");
    puts(str(r3#0));
    puts("p-value:");
    puts(str(r3#1));
    puts("df_between:");
    puts(str(r3#2));
    puts("df_within:");
    puts(str(r3#3));

    puts("=== FDist + ANOVA Test Done ===");
};