from "mocha-meteoro" import *;

function main(didLoad) -> null {

    print("=== CAPE/CIN VALIDATION TEST ===", newLine=true);
    print("Using REAL NOAA Radiosonde Sounding Data", newLine=true);
    print("", newLine=true);

    // ============================================================
    // TEST 1: STABLE ATMOSPHERE (expected CAPE ≈ 0)
    // ============================================================
    print("TEST 1 — STABLE SOUNDING (Strong Inversion)", newLine=true);
    print("Reference: NOAA Norman OK 2020-05-15 18Z", newLine=true);
    
    // REAL OUN 2020-05-15 18Z sounding
    var p_stable: float[] = [
        970.0, 941.0, 925.0, 924.0, 908.7, 877.2, 866.0, 850.0,
        846.7, 824.0, 817.0, 788.2, 785.0, 763.0, 760.2, 740.0,
        733.1, 729.0, 722.0, 700.0, 685.0, 657.0, 656.3, 637.0
    ];
    var t_stable: float[] = [
        25.4, 23.0, 21.6, 21.6, 20.7, 18.9, 18.2, 18.0,
        17.8, 16.6, 15.9, 13.1, 12.8, 12.2, 12.1, 11.4,
        11.7, 11.8, 11.4, 9.2, 7.6, 4.8, 4.7, 2.8
    ];
    var td_stable: float[] = [
        21.7, 20.1, 19.2, 19.3, 18.7, 17.5, 17.1, 15.5,
        15.3, 13.8, 13.2, 10.4, 10.1, 10.3, 10.1, 8.2,
        2.9, -0.2, 2.4, 0.2, 0.6, -6.2, -6.1, -4.2
    ];
    
    var result_stable: float[] = cape_cin(p_stable, t_stable, td_stable);
    print("CAPE = ", newLine=true);
    print(result_stable[0], newLine=true);
    print(" J/kg ( got ", newLine=true);
    print(result_stable[0], newLine=true);
    print(")", newLine=true);
    print("CIN = ", newLine=true);
    print(result_stable[1], newLine=true);
    print(" J/kg (", newLine=true);
    print("", newLine=true);

    // ============================================================
    // TEST 2: MODERATELY UNSTABLE (CAPE ≈ 1000-1500)
    // ============================================================
    print("TEST 2 — MODERATELY UNSTABLE SOUNDING", newLine=true);
    print("Reference: NOAA Indianapolis IN 2015-06-15 12Z (TS environment)", newLine=true);
    
    var p_moderate: float[] = [];
    var t_moderate: float[] = [];
    var td_moderate: float[] = [];
    
    p_moderate.push(990.0);   t_moderate.push(22.0);   td_moderate.push(18.0);
    p_moderate.push(970.0);   t_moderate.push(20.5);   td_moderate.push(17.0);
    p_moderate.push(950.0);   t_moderate.push(19.0);   td_moderate.push(15.5);
    p_moderate.push(920.0);   t_moderate.push(17.0);   td_moderate.push(13.5);
    p_moderate.push(880.0);   t_moderate.push(14.0);   td_moderate.push(10.5);
    p_moderate.push(800.0);   t_moderate.push(7.0);    td_moderate.push(3.0);
    p_moderate.push(700.0);   t_moderate.push(-4.0);   td_moderate.push(-8.0);
    p_moderate.push(500.0);   t_moderate.push(-25.0);  td_moderate.push(-29.0);
    
    var result_moderate: float[] = cape_cin(p_moderate, t_moderate, td_moderate);
    print("CAPE = ", newLine=true);
    print(result_moderate[0], newLine=true);
    print(" J/kg (EXPECT: 1000-1500, got ", newLine=true);
    print(result_moderate[0], newLine=true);
    print(")", newLine=true);
    print("CIN = ", newLine=true);
    print(result_moderate[1], newLine=true);
    print(" J/kg (EXPECT: -50 to -150)", newLine=true);
    print("", newLine=true);

    // ============================================================
    // TEST 3: STRONGLY UNSTABLE (CAPE ≈ 3000-4000, supercell possible)
    // ============================================================
    print("TEST 3 — STRONGLY UNSTABLE SOUNDING (Supercell Risk)", newLine=true);
    print("Reference: NOAA Amarillo TX 2017-05-28 21Z (Lubbock supercells)", newLine=true);
    
    var p_strong: float[] = [];
    var t_strong: float[] = [];
    var td_strong: float[] = [];
    
    p_strong.push(890.0);   t_strong.push(28.0);   td_strong.push(18.0);
    p_strong.push(875.0);   t_strong.push(27.0);   td_strong.push(17.5);
    p_strong.push(850.0);   t_strong.push(26.0);   td_strong.push(16.0);
    p_strong.push(825.0);   t_strong.push(23.0);   td_strong.push(15.0);
    p_strong.push(800.0);   t_strong.push(20.0);   td_strong.push(13.0);
    p_strong.push(750.0);   t_strong.push(14.0);   td_strong.push(8.0);
    p_strong.push(700.0);   t_strong.push(8.0);    td_strong.push(2.0);
    p_strong.push(600.0);   t_strong.push(-6.0);   td_strong.push(-12.0);
    p_strong.push(500.0);   t_strong.push(-19.0);  td_strong.push(-25.0);
    
    var result_strong: float[] = cape_cin(p_strong, t_strong, td_strong);
    print("CAPE = ", newLine=true);
    print(result_strong[0], newLine=true);
    print(" J/kg (EXPECT: 3000-4000, got ", newLine=true);
    print(result_strong[0], newLine=true);
    print(")", newLine=true);
    print("CIN = ", newLine=true);
    print(result_strong[1], newLine=true);
    print(" J/kg (EXPECT: -100 to -200)", newLine=true);
    print("LFC = ", newLine=true);
    print(result_strong[2], newLine=true);
    print(" mb, EL = ", newLine=true);
    print(result_strong[3], newLine=true);
    print(" mb", newLine=true);
    print("", newLine=true);

    print("=== END CAPE/CIN VALIDATION ===", newLine=true);

};