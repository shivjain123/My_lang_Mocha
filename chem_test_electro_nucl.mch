from "mocha-chem" import *;

function main(didLoad) -> null {

    // ----- Section 5: Electrochemistry -----

    // cell_potential_standard: 0.34 - (-0.76) = 1.10
    var s5_1: float = cell_potential_standard(0.34, -0.76);
    if (s5_1 == 1.1) {
        print("PASS: cell_potential_standard == 1.10", newLine=true);
    } else {
        print("FAIL: cell_potential_standard", newLine=true);
    };
    print(s5_1, newLine=true);

    // nernst_equation: E=1.10, n=2, Q=0.01, T=298 → 1.159127
    var s5_2: float = nernst_equation(1.10, 2.0, 0.01, 298.0);
    var diff_s5_2: float = s5_2 - 1.159127;
    var abs_s5_2: float = 0.0;
    if (diff_s5_2 < 0.0) { abs_s5_2 = -diff_s5_2; } else { abs_s5_2 = diff_s5_2; };
    if (abs_s5_2 < 0.0001) {
        print("PASS: nernst_equation ~ 1.159127", newLine=true);
    } else {
        print("FAIL: nernst_equation", newLine=true);
    };
    print(s5_2, newLine=true);

    // nernst_at_25c: E=1.10, n=2, Q=0.01 → 1.159160
    var s5_3: float = nernst_at_25c(1.10, 2.0, 0.01);
    var diff_s5_3: float = s5_3 - 1.159160;
    var abs_s5_3: float = 0.0;
    if (diff_s5_3 < 0.0) { abs_s5_3 = -diff_s5_3; } else { abs_s5_3 = diff_s5_3; };
    if (abs_s5_3 < 0.0001) {
        print("PASS: nernst_at_25c ~ 1.159160", newLine=true);
    } else {
        print("FAIL: nernst_at_25c", newLine=true);
    };
    print(s5_3, newLine=true);

    // gibbs_from_emf: n=2, E=1.10 → -212267.0
    var s5_4: float = gibbs_from_emf(2.0, 1.10);
    var diff_s5_4: float = s5_4 - (-212267.0);
    var abs_s5_4: float = 0.0;
    if (diff_s5_4 < 0.0) { abs_s5_4 = -diff_s5_4; } else { abs_s5_4 = diff_s5_4; };
    if (abs_s5_4 < 1.0) {
        print("PASS: gibbs_from_emf ~ -212267.0", newLine=true);
    } else {
        print("FAIL: gibbs_from_emf", newLine=true);
    };
    print(s5_4, newLine=true);

    // keq_from_emf: n=2, E=1.10, T=298 → ~1.6157e37
    var s5_5: float = keq_from_emf(2.0, 1.10, 298.0);
    var diff_s5_5: float = s5_5 - 16156910000000000000000000000000000000.0;
    var abs_s5_5: float = 0.0;
    if (diff_s5_5 < 0.0) { abs_s5_5 = -diff_s5_5; } else { abs_s5_5 = diff_s5_5; };
    if (abs_s5_5 < 1.0E33) {
        print("PASS: keq_from_emf ~ 1.6157e37", newLine=true);
    } else {
        print("FAIL: keq_from_emf", newLine=true);
    };
    print(s5_5, newLine=true);

    // emf_from_keq: roundtrip → 1.10
    var s5_6: float = emf_from_keq(2.0, s5_5, 298.0);
    var diff_s5_6: float = s5_6 - 1.10;
    var abs_s5_6: float = 0.0;
    if (diff_s5_6 < 0.0) { abs_s5_6 = -diff_s5_6; } else { abs_s5_6 = diff_s5_6; };
    if (abs_s5_6 < 0.001) {
        print("PASS: emf_from_keq roundtrip ~ 1.10", newLine=true);
    } else {
        print("FAIL: emf_from_keq", newLine=true);
    };
    print(s5_6, newLine=true);

    // electrolysis_mass: Cu, I=2A, t=3600s, n=2 → 2.370997 g
    var s5_7: float = electrolysis_mass(63.546, 2.0, 3600.0, 2.0);
    var diff_s5_7: float = s5_7 - 2.370997;
    var abs_s5_7: float = 0.0;
    if (diff_s5_7 < 0.0) { abs_s5_7 = -diff_s5_7; } else { abs_s5_7 = diff_s5_7; };
    if (abs_s5_7 < 0.001) {
        print("PASS: electrolysis_mass ~ 2.370997 g", newLine=true);
    } else {
        print("FAIL: electrolysis_mass", newLine=true);
    };
    print(s5_7, newLine=true);

    // electrolysis_time: roundtrip → 3600 s
    var s5_8: float = electrolysis_time(63.546, s5_7, 2.0, 2.0);
    var diff_s5_8: float = s5_8 - 3600.0;
    var abs_s5_8: float = 0.0;
    if (diff_s5_8 < 0.0) { abs_s5_8 = -diff_s5_8; } else { abs_s5_8 = diff_s5_8; };
    if (abs_s5_8 < 0.01) {
        print("PASS: electrolysis_time roundtrip ~ 3600 s", newLine=true);
    } else {
        print("FAIL: electrolysis_time", newLine=true);
    };
    print(s5_8, newLine=true);

    // molar_conductivity: 0.1/100 = 0.001
    var s5_9: float = molar_conductivity(0.1, 100.0);
    if (s5_9 == 0.001) {
        print("PASS: molar_conductivity == 0.001", newLine=true);
    } else {
        print("FAIL: molar_conductivity", newLine=true);
    };
    print(s5_9, newLine=true);

    // kohlrausch_conductivity → 0.004420
    var s5_10: float = kohlrausch_conductivity(0.01265, 0.000823, 100.0);
    var diff_s5_10: float = s5_10 - 0.004420;
    var abs_s5_10: float = 0.0;
    if (diff_s5_10 < 0.0) { abs_s5_10 = -diff_s5_10; } else { abs_s5_10 = diff_s5_10; };
    if (abs_s5_10 < 0.0001) {
        print("PASS: kohlrausch_conductivity ~ 0.004420", newLine=true);
    } else {
        print("FAIL: kohlrausch_conductivity", newLine=true);
    };
    print(s5_10, newLine=true);

    // ----- Section 6: Nuclear Chemistry -----

    // decay_constant: C-14, t_half=5730 → 1.20968e-4
    var s6_1: float = decay_constant(5730.0);
    var diff_s6_1: float = s6_1 - 0.000120968;
    var abs_s6_1: float = 0.0;
    if (diff_s6_1 < 0.0) { abs_s6_1 = -diff_s6_1; } else { abs_s6_1 = diff_s6_1; };
    if (abs_s6_1 < 0.000000001) {
        print("PASS: decay_constant ~ 1.20968e-4", newLine=true);
    } else {
        print("FAIL: decay_constant", newLine=true);
    };
    print(s6_1, newLine=true);

    // nuclei_remaining: one half-life → N0/2
    var s6_2: float = nuclei_remaining(100000000000000000000.0, s6_1, 5730.0);
    var diff_s6_2: float = s6_2 - 50000000000000000000.0;
    var abs_s6_2: float = 0.0;
    if (diff_s6_2 < 0.0) { abs_s6_2 = -diff_s6_2; } else { abs_s6_2 = diff_s6_2; };
    if (abs_s6_2 < 100000000000000.0) {
        print("PASS: nuclei_remaining ~ 5e19", newLine=true);
    } else {
        print("FAIL: nuclei_remaining", newLine=true);
    };
    print(s6_2, newLine=true);

    // activity_remaining: one half-life → A0/2
    var s6_3: float = activity_remaining(10000000000.0, s6_1, 5730.0);
    var diff_s6_3: float = s6_3 - 5000000000.0;
    var abs_s6_3: float = 0.0;
    if (diff_s6_3 < 0.0) { abs_s6_3 = -diff_s6_3; } else { abs_s6_3 = diff_s6_3; };
    if (abs_s6_3 < 1000.0) {
        print("PASS: activity_remaining ~ 5e9", newLine=true);
    } else {
        print("FAIL: activity_remaining", newLine=true);
    };
    print(s6_3, newLine=true);

    // radiometric_age: two half-lives → 11460 years
    var s6_4: float = radiometric_age(100000000000000000000.0, 25000000000000000000.0, s6_1);
    var diff_s6_4: float = s6_4 - 11460.0;
    var abs_s6_4: float = 0.0;
    if (diff_s6_4 < 0.0) { abs_s6_4 = -diff_s6_4; } else { abs_s6_4 = diff_s6_4; };
    if (abs_s6_4 < 0.01) {
        print("PASS: radiometric_age ~ 11460 years", newLine=true);
    } else {
        print("FAIL: radiometric_age", newLine=true);
    };
    print(s6_4, newLine=true);

    // carbon14_age: half activity → ~5730 years
    var s6_5: float = carbon14_age(0.227, 0.1135);
    var diff_s6_5: float = s6_5 - 5730.0;
    var abs_s6_5: float = 0.0;
    if (diff_s6_5 < 0.0) { abs_s6_5 = -diff_s6_5; } else { abs_s6_5 = diff_s6_5; };
    if (abs_s6_5 < 0.1) {
        print("PASS: carbon14_age ~ 5730 years", newLine=true);
    } else {
        print("FAIL: carbon14_age", newLine=true);
    };
    print(s6_5, newLine=true);

    // mass_defect: He-4 → 0.029280 u
    var s6_6: float = mass_defect(2.0, 2.0, 1.007276, 1.008665, 4.002602);
    var diff_s6_6: float = s6_6 - 0.029280;
    var abs_s6_6: float = 0.0;
    if (diff_s6_6 < 0.0) { abs_s6_6 = -diff_s6_6; } else { abs_s6_6 = diff_s6_6; };
    if (abs_s6_6 < 0.000001) {
        print("PASS: mass_defect ~ 0.029280 u", newLine=true);
    } else {
        print("FAIL: mass_defect", newLine=true);
    };
    print(s6_6, newLine=true);

    // binding_energy: He-4 → 27.274144 MeV
    var s6_7: float = binding_energy(s6_6);
    var diff_s6_7: float = s6_7 - 27.274144;
    var abs_s6_7: float = 0.0;
    if (diff_s6_7 < 0.0) { abs_s6_7 = -diff_s6_7; } else { abs_s6_7 = diff_s6_7; };
    if (abs_s6_7 < 0.001) {
        print("PASS: binding_energy ~ 27.274 MeV", newLine=true);
    } else {
        print("FAIL: binding_energy", newLine=true);
    };
    print(s6_7, newLine=true);

    // binding_energy_per_nucleon: He-4, A=4 → 6.818536
    var s6_8: float = binding_energy_per_nucleon(s6_7, 4.0);
    var diff_s6_8: float = s6_8 - 6.818536;
    var abs_s6_8: float = 0.0;
    if (diff_s6_8 < 0.0) { abs_s6_8 = -diff_s6_8; } else { abs_s6_8 = diff_s6_8; };
    if (abs_s6_8 < 0.001) {
        print("PASS: binding_energy_per_nucleon ~ 6.8185 MeV", newLine=true);
    } else {
        print("FAIL: binding_energy_per_nucleon", newLine=true);
    };
    print(s6_8, newLine=true);

    // q_value_decay: Ra-226 alpha → 4.871714 MeV
    var s6_9: float = q_value_decay(226.025410, 222.017578, 4.002602);
    var diff_s6_9: float = s6_9 - 4.871714;
    var abs_s6_9: float = 0.0;
    if (diff_s6_9 < 0.0) { abs_s6_9 = -diff_s6_9; } else { abs_s6_9 = diff_s6_9; };
    if (abs_s6_9 < 0.001) {
        print("PASS: q_value_decay ~ 4.871714 MeV", newLine=true);
    } else {
        print("FAIL: q_value_decay", newLine=true);
    };
    print(s6_9, newLine=true);

    // becquerel_to_curie: 3.7e10 Bq → 1.0 Ci
    var s6_10: float = becquerel_to_curie(37000000000.0);
    if (s6_10 == 1.0) {
        print("PASS: becquerel_to_curie == 1.0 Ci", newLine=true);
    } else {
        print("FAIL: becquerel_to_curie", newLine=true);
    };
    print(s6_10, newLine=true);

    // curie_to_becquerel: 1.0 Ci → 3.7e10 Bq
    var s6_11: float = curie_to_becquerel(1.0);
    if (s6_11 == 37000000000.0) {
        print("PASS: curie_to_becquerel == 3.7e10 Bq", newLine=true);
    } else {
        print("FAIL: curie_to_becquerel", newLine=true);
    };
    print(s6_11, newLine=true);

    print("mocha-chem sections 5-6 tests done.", newLine=true);
};