from "mocha-bio" import *;

function main(didLoad) -> null {

    // ----- Exponential Growth -----
    // N(t) = 100 * e^(0.1 * 10) = 100 * e^1 ≈ 271.828
    var eg1: float = exponential_growth(100.0, 0.1, 10.0);
    if (eg1 > 271.0 && eg1 < 273.0) {
        print("PASS: exponential_growth(100, 0.1, 10) ~271.8", newLine=true);
    } else {
        print("FAIL: exponential_growth(100, 0.1, 10) ~271.8", newLine=true);
    };
    print("exponential growth = ", newLine=false);
    print(eg1, newLine=true);

    // N(0) should always equal N0
    var eg2: float = exponential_growth(500.0, 0.5, 0.0);
    if (eg2 == 500.0) {
        print("PASS: exponential_growth at t=0 == N0", newLine=true);
    } else {
        print("FAIL: exponential_growth at t=0 == N0", newLine=true);
    };

    // ----- Logistic Growth -----
    // At t=0, N should equal N0
    var lg1: float = logistic_growth(50.0, 0.5, 1000.0, 0.0);
    if (lg1 == 50.0) {
        print("PASS: logistic_growth at t=0 == N0", newLine=true);
    } else {
        print("FAIL: logistic_growth at t=0 == N0", newLine=true);
    };

    // At large t, N should approach K
    var lg2: float = logistic_growth(50.0, 0.5, 1000.0, 100.0);
    if (lg2 > 999.0 && lg2 <= 1000.0) {
        print("PASS: logistic_growth at large t approaches K", newLine=true);
    } else {
        print("FAIL: logistic_growth at large t approaches K", newLine=true);
    };
    print("logistic growth (t=100) = ", newLine=false);
    print(lg2, newLine=true);

    // ----- Doubling Time -----
    // r=0.693147 → doubling time = ln(2)/ln(2) = 1.0
    var dt1: float = doubling_time(0.6931471805599453);
    if (dt1 > 0.99 && dt1 < 1.01) {
        print("PASS: doubling_time(ln2) ~1.0", newLine=true);
    } else {
        print("FAIL: doubling_time(ln2) ~1.0", newLine=true);
    };

    // r=0.1 → doubling time ~6.931
    var dt2: float = doubling_time(0.1);
    if (dt2 > 6.9 && dt2 < 7.0) {
        print("PASS: doubling_time(0.1) ~6.93", newLine=true);
    } else {
        print("FAIL: doubling_time(0.1) ~6.93", newLine=true);
    };
    print("doubling time = ", newLine=false);
    print(dt2, newLine=true);

    // ----- Carrying Capacity Usage -----
    var cu1: float = carrying_capacity_usage(500.0, 1000.0);
    if (cu1 == 50.0) {
        print("PASS: carrying_capacity_usage(500, 1000) == 50%", newLine=true);
    } else {
        print("FAIL: carrying_capacity_usage(500, 1000) == 50%", newLine=true);
    };

    // ----- Population Density -----
    var pd1: float = population_density(1000.0, 25.0);
    if (pd1 == 40.0) {
        print("PASS: population_density(1000, 25) == 40", newLine=true);
    } else {
        print("FAIL: population_density(1000, 25) == 40", newLine=true);
    };

    // ----- Lotka-Volterra -----
    // prey=100, predator=10, alpha=0.1, beta=0.01, delta=0.01, gamma=0.1, dt=1
    var lv1: (float, 2) = lotka_volterra(100.0, 10.0, 0.1, 0.01, 0.01, 0.1, 1.0);
    if (lv1#0 > 0.0 && lv1#1 > 0.0) {
        print("PASS: lotka_volterra returns positive populations", newLine=true);
    } else {
        print("FAIL: lotka_volterra returns positive populations", newLine=true);
    };
    print("prey next = ", newLine=false);
    print(lv1#0, newLine=true);
    print("predator next = ", newLine=false);
    print(lv1#1, newLine=true);

    // ----- Michaelis-Menten -----
    // At [S] = Km, v = Vmax/2
    var mm1: float = michaelis_menten(100.0, 10.0, 10.0);
    if (mm1 == 50.0) {
        print("PASS: michaelis_menten at S=Km == Vmax/2", newLine=true);
    } else {
        print("FAIL: michaelis_menten at S=Km == Vmax/2", newLine=true);
    };
    print("michaelis-menten = ", newLine=false);
    print(mm1, newLine=true);

    // At [S] >> Km, v approaches Vmax
    var mm2: float = michaelis_menten(100.0, 1.0, 1000.0);
    if (mm2 > 99.0 && mm2 <= 100.0) {
        print("PASS: michaelis_menten at high S approaches Vmax", newLine=true);
    } else {
        print("FAIL: michaelis_menten at high S approaches Vmax", newLine=true);
    };

    // velocity fraction at S=Km should be 0.5
    var vf1: float = velocity_fraction(10.0, 10.0);
    if (vf1 == 0.5) {
        print("PASS: velocity_fraction at S=Km == 0.5", newLine=true);
    } else {
        print("FAIL: velocity_fraction at S=Km == 0.5", newLine=true);
    };

    // ----- Beer-Lambert -----
    // A = 1000 * 1.0 * 0.001 = 1.0
    var bl1: float = absorbance(1000.0, 1.0, 0.001);
    if (bl1 == 1.0) {
        print("PASS: absorbance(1000, 1.0, 0.001) == 1.0", newLine=true);
    } else {
        print("FAIL: absorbance(1000, 1.0, 0.001) == 1.0", newLine=true);
    };

    // Reverse: concentration from absorbance
    var bl2: float = concentration_from_absorbance(1.0, 1000.0, 1.0);
    if (bl2 == 0.001) {
        print("PASS: concentration_from_absorbance == 0.001", newLine=true);
    } else {
        print("FAIL: concentration_from_absorbance == 0.001", newLine=true);
    };
    print("concentration = ", newLine=false);
    print(bl2, newLine=true);

    // ----- Henderson-Hasselbalch -----
    // At equal concentrations, pH = pKa
    var hh1: float = henderson_hasselbalch(7.4, 1.0, 1.0);
    if (hh1 > 7.39 && hh1 < 7.41) {
        print("PASS: henderson_hasselbalch equal conc == pKa", newLine=true);
    } else {
        print("FAIL: henderson_hasselbalch equal conc == pKa", newLine=true);
    };
    print("pH = ", newLine=false);
    print(hh1, newLine=true);

    // ----- Q10 -----
    // Q10 = 2.0 means rate doubles per 10°C
    var q1: float = q10(1.0, 2.0, 20.0, 30.0);
    if (q1 > 1.99 && q1 < 2.01) {
        print("PASS: q10(1.0, 2.0, 20, 30) == 2.0", newLine=true);
    } else {
        print("FAIL: q10(1.0, 2.0, 20, 30) == 2.0", newLine=true);
    };
    print("Q10 = ", newLine=false);
    print(q1, newLine=true);

    // Rate at new temperature
    var rt1: float = rate_at_temperature(1.0, 2.0, 20.0, 30.0);
    if (rt1 > 1.99 && rt1 < 2.01) {
        print("PASS: rate_at_temperature(1.0, Q10=2, +10C) == 2.0", newLine=true);
    } else {
        print("FAIL: rate_at_temperature(1.0, Q10=2, +10C) == 2.0", newLine=true);
    };

    // ----- Hardy-Weinberg -----
    // p=0.6, q=0.4 → p²=0.36, 2pq=0.48, q²=0.16
    var hw1: (float, 3) = hardy_weinberg(0.6);
    if (hw1#0 > 0.359 && hw1#0 < 0.361) {
        print("PASS: hardy_weinberg p² == 0.36", newLine=true);
    } else {
        print("FAIL: hardy_weinberg p² == 0.36", newLine=true);
    };
    if (hw1#1 > 0.479 && hw1#1 < 0.481) {
        print("PASS: hardy_weinberg 2pq == 0.48", newLine=true);
    } else {
        print("FAIL: hardy_weinberg 2pq == 0.48", newLine=true);
    };
    if (hw1#2 > 0.159 && hw1#2 < 0.161) {
        print("PASS: hardy_weinberg q² == 0.16", newLine=true);
    } else {
        print("FAIL: hardy_weinberg q² == 0.16", newLine=true);
    };
    print("p2=", newLine=false); print(hw1#0, newLine=false);
    print(" 2pq=", newLine=false); print(hw1#1, newLine=false);
    print(" q2=", newLine=false); print(hw1#2, newLine=true);

    // Equilibrium check — should sum to 1
    var hwc: bool = hardy_weinberg_check(0.36, 0.48, 0.16);
    if (hwc) {
        print("PASS: hardy_weinberg_check(0.36, 0.48, 0.16) == true", newLine=true);
    } else {
        print("FAIL: hardy_weinberg_check(0.36, 0.48, 0.16) == true", newLine=true);
    };

    // ----- Allele Frequency After Mutation -----
    // p=0.9, mu_forward=0.01, mu_reverse=0.001
    // p_next = 0.9*(1-0.01) + 0.1*0.001 = 0.891 + 0.0001 = 0.8911
    var am1: float = allele_freq_after_mutation(0.9, 0.01, 0.001);
    if (am1 > 0.890 && am1 < 0.892) {
        print("PASS: allele_freq_after_mutation ~0.8911", newLine=true);
    } else {
        print("FAIL: allele_freq_after_mutation ~0.8911", newLine=true);
    };
    print("allele freq after mutation = ", newLine=false);
    print(am1, newLine=true);

    // ----- Allele Frequency After Selection -----
    // neutral selection s=0, p should stay same
    var as1: float = allele_freq_after_selection(0.6, 0.0);
    if (as1 > 0.59 && as1 < 0.61) {
        print("PASS: allele_freq_after_selection neutral s=0 preserves p", newLine=true);
    } else {
        print("FAIL: allele_freq_after_selection neutral s=0 preserves p", newLine=true);
    };

    // strong selection s=1 against recessive — p should increase
    var as2: float = allele_freq_after_selection(0.6, 1.0);
    if (as2 > 0.6) {
        print("PASS: allele_freq_after_selection s=1 increases p", newLine=true);
    } else {
        print("FAIL: allele_freq_after_selection s=1 increases p", newLine=true);
    };
    print("allele freq after selection = ", newLine=false);
    print(as2, newLine=true);

    // ----- Effective Population Size -----
    // Equal sex ratio: Ne = 4*50*50/(50+50) = 10000/100 = 100
    var ep1: float = effective_population_size(50.0, 50.0);
    if (ep1 == 100.0) {
        print("PASS: effective_population_size(50, 50) == 100", newLine=true);
    } else {
        print("FAIL: effective_population_size(50, 50) == 100", newLine=true);
    };

    // Skewed sex ratio reduces Ne
    var ep2: float = effective_population_size(90.0, 10.0);
    if (ep2 < 100.0) {
        print("PASS: effective_population_size skewed < equal sex ratio", newLine=true);
    } else {
        print("FAIL: effective_population_size skewed < equal sex ratio", newLine=true);
    };
    print("effective pop size (skewed) = ", newLine=false);
    print(ep2, newLine=true);

    print("Non-medical biology tests done.", newLine=true);
};