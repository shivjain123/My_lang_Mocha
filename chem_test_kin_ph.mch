from "mocha-chem" import *;

function main(didLoad) -> null {

    // ----- Section 3: Chemical Kinetics -----

    // conc_zero_order: [A]0=1.0, k=0.1, t=3.0 → 0.7
    var s3_1: float = conc_zero_order(1.0, 0.1, 3.0);
    if (s3_1 == 0.7) {
        print("PASS: conc_zero_order == 0.7", newLine=true);
    } else {
        print("FAIL: conc_zero_order", newLine=true);
    };
    print(s3_1, newLine=true);

    // conc_first_order: expected 0.367879
    var s3_2: float = conc_first_order(1.0, 0.5, 2.0);
    var diff_s3_2: float = s3_2 - 0.367879;
    var abs_s3_2: float = 0.0;
    if (diff_s3_2 < 0.0) { abs_s3_2 = -diff_s3_2; } else { abs_s3_2 = diff_s3_2; };
    if (abs_s3_2 < 0.0001) {
        print("PASS: conc_first_order ~ 0.367879", newLine=true);
    } else {
        print("FAIL: conc_first_order", newLine=true);
    };
    print(s3_2, newLine=true);

    // conc_second_order: expected 0.5
    var s3_3: float = conc_second_order(1.0, 0.5, 2.0);
    if (s3_3 == 0.5) {
        print("PASS: conc_second_order == 0.5", newLine=true);
    } else {
        print("FAIL: conc_second_order", newLine=true);
    };
    print(s3_3, newLine=true);

    // half_life_zero_order: expected 5.0
    var s3_4: float = half_life_zero_order(1.0, 0.1);
    if (s3_4 == 5.0) {
        print("PASS: half_life_zero_order == 5.0", newLine=true);
    } else {
        print("FAIL: half_life_zero_order", newLine=true);
    };
    print(s3_4, newLine=true);

    // half_life_first_order: expected 1.386294
    var s3_5: float = half_life_first_order(0.5);
    var diff_s3_5: float = s3_5 - 1.386294;
    var abs_s3_5: float = 0.0;
    if (diff_s3_5 < 0.0) { abs_s3_5 = -diff_s3_5; } else { abs_s3_5 = diff_s3_5; };
    if (abs_s3_5 < 0.0001) {
        print("PASS: half_life_first_order ~ 1.386294", newLine=true);
    } else {
        print("FAIL: half_life_first_order", newLine=true);
    };
    print(s3_5, newLine=true);

    // half_life_second_order: expected 2.0
    var s3_6: float = half_life_second_order(1.0, 0.5);
    if (s3_6 == 2.0) {
        print("PASS: half_life_second_order == 2.0", newLine=true);
    } else {
        print("FAIL: half_life_second_order", newLine=true);
    };
    print(s3_6, newLine=true);

    // arrhenius_k: A=1e13, Ea=75000, T=500 → ~1.4606e5
    var s3_7: float = arrhenius_k(10000000000000.0, 75000.0, 500.0);
    var diff_s3_7: float = s3_7 - 146056.5;
    var abs_s3_7: float = 0.0;
    if (diff_s3_7 < 0.0) { abs_s3_7 = -diff_s3_7; } else { abs_s3_7 = diff_s3_7; };
    if (abs_s3_7 < 1.0) {
        print("PASS: arrhenius_k ~ 1.4606e5", newLine=true);
    } else {
        print("FAIL: arrhenius_k", newLine=true);
    };
    print(s3_7, newLine=true);

    // activation_energy_two_point: k1=0.0112, k2=0.0894, T1=500, T2=600 → 51809.6946
    var s3_8: float = activation_energy_two_point(0.0112, 0.0894, 500.0, 600.0);
    var diff_s3_8: float = s3_8 - 51809.6946;
    var abs_s3_8: float = 0.0;
    if (diff_s3_8 < 0.0) { abs_s3_8 = -diff_s3_8; } else { abs_s3_8 = diff_s3_8; };
    if (abs_s3_8 < 0.1) {
        print("PASS: activation_energy_two_point ~ 51809.69", newLine=true);
    } else {
        print("FAIL: activation_energy_two_point", newLine=true);
    };
    print(s3_8, newLine=true);

    // rate_law: k=0.5, [A]=2.0, m=2, [B]=3.0, n=1 → 6.0
    var s3_9: float = rate_law(0.5, 2.0, 2.0, 3.0, 1.0);
    if (s3_9 == 6.0) {
        print("PASS: rate_law == 6.0", newLine=true);
    } else {
        print("FAIL: rate_law", newLine=true);
    };
    print(s3_9, newLine=true);

    // time_to_conc_first_order: [A]0=1.0, [A]t=0.25, k=0.5 → 2.772589
    var s3_10: float = time_to_conc_first_order(1.0, 0.25, 0.5);
    var diff_s3_10: float = s3_10 - 2.772589;
    var abs_s3_10: float = 0.0;
    if (diff_s3_10 < 0.0) { abs_s3_10 = -diff_s3_10; } else { abs_s3_10 = diff_s3_10; };
    if (abs_s3_10 < 0.0001) {
        print("PASS: time_to_conc_first_order ~ 2.772589", newLine=true);
    } else {
        print("FAIL: time_to_conc_first_order", newLine=true);
    };
    print(s3_10, newLine=true);

    // time_to_conc_second_order: expected 6.0
    var s3_11: float = time_to_conc_second_order(1.0, 0.25, 0.5);
    if (s3_11 == 6.0) {
        print("PASS: time_to_conc_second_order == 6.0", newLine=true);
    } else {
        print("FAIL: time_to_conc_second_order", newLine=true);
    };
    print(s3_11, newLine=true);

    // arrhenius_ratio: Ea=75000, T1=500, T2=600 → 20.226147
    var s3_12: float = arrhenius_ratio(75000.0, 500.0, 600.0);
    var diff_s3_12: float = s3_12 - 20.226147;
    var abs_s3_12: float = 0.0;
    if (diff_s3_12 < 0.0) { abs_s3_12 = -diff_s3_12; } else { abs_s3_12 = diff_s3_12; };
    if (abs_s3_12 < 0.001) {
        print("PASS: arrhenius_ratio ~ 20.2261", newLine=true);
    } else {
        print("FAIL: arrhenius_ratio", newLine=true);
    };
    print(s3_12, newLine=true);

    // ----- Section 4: Equilibrium & Acid-Base -----

    // kc_from_kp: Kp=1.5, T=500, delta_n=-1 → 61.542750
    var s4_1: float = kc_from_kp(1.5, 500.0, -1.0);
    var diff_s4_1: float = s4_1 - 61.542750;
    var abs_s4_1: float = 0.0;
    if (diff_s4_1 < 0.0) { abs_s4_1 = -diff_s4_1; } else { abs_s4_1 = diff_s4_1; };
    if (abs_s4_1 < 0.001) {
        print("PASS: kc_from_kp ~ 61.5428", newLine=true);
    } else {
        print("FAIL: kc_from_kp", newLine=true);
    };
    print(s4_1, newLine=true);

    // kp_from_kc: roundtrip → 1.5
    var s4_2: float = kp_from_kc(61.542750, 500.0, -1.0);
    var diff_s4_2: float = s4_2 - 1.5;
    var abs_s4_2: float = 0.0;
    if (diff_s4_2 < 0.0) { abs_s4_2 = -diff_s4_2; } else { abs_s4_2 = diff_s4_2; };
    if (abs_s4_2 < 0.0001) {
        print("PASS: kp_from_kc ~ 1.5", newLine=true);
    } else {
        print("FAIL: kp_from_kc", newLine=true);
    };
    print(s4_2, newLine=true);

    // reaction_quotient: 0.5/2.0 = 0.25
    var s4_3: float = reaction_quotient(0.5, 2.0);
    if (s4_3 == 0.25) {
        print("PASS: reaction_quotient == 0.25", newLine=true);
    } else {
        print("FAIL: reaction_quotient", newLine=true);
    };
    print(s4_3, newLine=true);

    // solubility_from_ksp_1_1: sqrt(1.8e-10) → 1.341641e-5
    var s4_4: float = solubility_from_ksp_1_1(0.00000000018);
    var diff_s4_4: float = s4_4 - 0.00001341641;
    var abs_s4_4: float = 0.0;
    if (diff_s4_4 < 0.0) { abs_s4_4 = -diff_s4_4; } else { abs_s4_4 = diff_s4_4; };
    if (abs_s4_4 < 0.000000001) {
        print("PASS: solubility_from_ksp_1_1 ~ 1.3416e-5", newLine=true);
    } else {
        print("FAIL: solubility_from_ksp_1_1", newLine=true);
    };
    print(s4_4, newLine=true);

    // common_ion_solubility: Ksp=1.8e-10, c_ion=0.1 → ~1.8e-9
    var s4_5: float = common_ion_solubility(0.00000000018, 0.1);
    var diff_s4_5: float = s4_5 - 0.0000000018;
    var abs_s4_5: float = 0.0;
    if (diff_s4_5 < 0.0) { abs_s4_5 = -diff_s4_5; } else { abs_s4_5 = diff_s4_5; };
    if (abs_s4_5 < 0.0000000001) {
        print("PASS: common_ion_solubility ~ 1.8e-9", newLine=true);
    } else {
        print("FAIL: common_ion_solubility", newLine=true);
    };
    print(s4_5, newLine=true);

    // ph_from_h_conc: [H+]=1e-7 → 7.0
    var s4_6: float = ph_from_h_conc(0.0000001);
    var diff_s4_6: float = s4_6 - 7.0;
    var abs_s4_6: float = 0.0;
    if (diff_s4_6 < 0.0) { abs_s4_6 = -diff_s4_6; } else { abs_s4_6 = diff_s4_6; };
    if (abs_s4_6 < 0.0001) {
        print("PASS: ph_from_h_conc(1e-7) ~ 7.0", newLine=true);
    } else {
        print("FAIL: ph_from_h_conc(1e-7)", newLine=true);
    };
    print(s4_6, newLine=true);

    // ph_from_h_conc: [H+]=0.01 → 2.0
    var s4_7: float = ph_from_h_conc(0.01);
    var diff_s4_7: float = s4_7 - 2.0;
    var abs_s4_7: float = 0.0;
    if (diff_s4_7 < 0.0) { abs_s4_7 = -diff_s4_7; } else { abs_s4_7 = diff_s4_7; };
    if (abs_s4_7 < 0.0001) {
        print("PASS: ph_from_h_conc(0.01) ~ 2.0", newLine=true);
    } else {
        print("FAIL: ph_from_h_conc(0.01)", newLine=true);
    };
    print(s4_7, newLine=true);

    // ph_from_poh: 14 - 7 = 7.0
    var s4_8: float = ph_from_poh(7.0);
    if (s4_8 == 7.0) {
        print("PASS: ph_from_poh == 7.0", newLine=true);
    } else {
        print("FAIL: ph_from_poh", newLine=true);
    };
    print(s4_8, newLine=true);

    // henderson_hasselbalch: pKa=4.74, equal conc → 4.74
    var s4_9: float = henderson_hasselbalch(4.74, 0.5, 0.5);
    var diff_s4_9: float = s4_9 - 4.74;
    var abs_s4_9: float = 0.0;
    if (diff_s4_9 < 0.0) { abs_s4_9 = -diff_s4_9; } else { abs_s4_9 = diff_s4_9; };
    if (abs_s4_9 < 0.0001) {
        print("PASS: henderson_hasselbalch(equal) ~ 4.74", newLine=true);
    } else {
        print("FAIL: henderson_hasselbalch(equal)", newLine=true);
    };
    print(s4_9, newLine=true);

    // henderson_hasselbalch: pKa=4.74, [A-]=1.0, [HA]=0.5 → 5.041030
    var s4_10: float = henderson_hasselbalch(4.74, 1.0, 0.5);
    var diff_s4_10: float = s4_10 - 5.041030;
    var abs_s4_10: float = 0.0;
    if (diff_s4_10 < 0.0) { abs_s4_10 = -diff_s4_10; } else { abs_s4_10 = diff_s4_10; };
    if (abs_s4_10 < 0.0001) {
        print("PASS: henderson_hasselbalch(2:1) ~ 5.0410", newLine=true);
    } else {
        print("FAIL: henderson_hasselbalch(2:1)", newLine=true);
    };
    print(s4_10, newLine=true);

    // ph_weak_acid: Ka=1.8e-5, Ca=0.1 → 2.872364
    var s4_11: float = ph_weak_acid(0.000018, 0.1);
    var diff_s4_11: float = s4_11 - 2.872364;
    var abs_s4_11: float = 0.0;
    if (diff_s4_11 < 0.0) { abs_s4_11 = -diff_s4_11; } else { abs_s4_11 = diff_s4_11; };
    if (abs_s4_11 < 0.0001) {
        print("PASS: ph_weak_acid ~ 2.872364", newLine=true);
    } else {
        print("FAIL: ph_weak_acid", newLine=true);
    };
    print(s4_11, newLine=true);

    // ph_weak_base: Kb=1.8e-5, Cb=0.1 → 11.127636
    var s4_12: float = ph_weak_base(0.000018, 0.1);
    var diff_s4_12: float = s4_12 - 11.127636;
    var abs_s4_12: float = 0.0;
    if (diff_s4_12 < 0.0) { abs_s4_12 = -diff_s4_12; } else { abs_s4_12 = diff_s4_12; };
    if (abs_s4_12 < 0.0001) {
        print("PASS: ph_weak_base ~ 11.127636", newLine=true);
    } else {
        print("FAIL: ph_weak_base", newLine=true);
    };
    print(s4_12, newLine=true);

    // buffer_capacity: C=1.0, Ka=1.8e-5, pH=4.74 → 0.575733
    var s4_13: float = buffer_capacity(1.0, 0.000018, 4.74);
    var diff_s4_13: float = s4_13 - 0.575733;
    var abs_s4_13: float = 0.0;
    if (diff_s4_13 < 0.0) { abs_s4_13 = -diff_s4_13; } else { abs_s4_13 = diff_s4_13; };
    if (abs_s4_13 < 0.001) {
        print("PASS: buffer_capacity ~ 0.575733", newLine=true);
    } else {
        print("FAIL: buffer_capacity", newLine=true);
    };
    print(s4_13, newLine=true);

    // degree_of_dissociation: Ka=1.8e-5, Ca=0.1 → 0.013416
    var s4_14: float = degree_of_dissociation(0.000018, 0.1);
    var diff_s4_14: float = s4_14 - 0.013416;
    var abs_s4_14: float = 0.0;
    if (diff_s4_14 < 0.0) { abs_s4_14 = -diff_s4_14; } else { abs_s4_14 = diff_s4_14; };
    if (abs_s4_14 < 0.0001) {
        print("PASS: degree_of_dissociation ~ 0.013416", newLine=true);
    } else {
        print("FAIL: degree_of_dissociation", newLine=true);
    };
    print(s4_14, newLine=true);

    // pka_from_ka: Ka=1.8e-5 → 4.744727
    var s4_15: float = pka_from_ka(0.000018);
    var diff_s4_15: float = s4_15 - 4.744727;
    var abs_s4_15: float = 0.0;
    if (diff_s4_15 < 0.0) { abs_s4_15 = -diff_s4_15; } else { abs_s4_15 = diff_s4_15; };
    if (abs_s4_15 < 0.0001) {
        print("PASS: pka_from_ka ~ 4.744727", newLine=true);
    } else {
        print("FAIL: pka_from_ka", newLine=true);
    };
    print(s4_15, newLine=true);

    print("mocha-chem sections 3-4 tests done.", newLine=true);
};