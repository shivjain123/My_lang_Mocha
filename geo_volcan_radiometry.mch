from "mocha-geo" import *;

function main(didLoad) -> null {

    // ----- Section 5: Volcanology -----

    // volcanic_explosivity_index_estimate(1.0) -> VEI 6
    var s5_1: int = volcanic_explosivity_index_estimate(1.0);
    if (s5_1 == 6) {
        print("PASS: volcanic_explosivity_index_estimate(1.0) == 6", newLine=true);
    } else {
        print("FAIL: volcanic_explosivity_index_estimate", newLine=true);
    };
    print(s5_1, newLine=true);

    // volcanic_explosivity_index_estimate(0.01) -> VEI 4
    var s5_1b: int = volcanic_explosivity_index_estimate(0.01);
    if (s5_1b == 4) {
        print("PASS: volcanic_explosivity_index_estimate(0.01) == 4", newLine=true);
    } else {
        print("FAIL: volcanic_explosivity_index_estimate(0.01)", newLine=true);
    };
    print(s5_1b, newLine=true);

    // eruption_column_height(1.0e7) ~ 13.271255 km
    var s5_2: float = eruption_column_height(10000000.0);
    var diff_s5_2: float = s5_2 - 13.271255;
    var abs_s5_2: float = 0.0;
    if (diff_s5_2 < 0.0) { abs_s5_2 = -diff_s5_2; } else { abs_s5_2 = diff_s5_2; };
    if (abs_s5_2 < 0.001) {
        print("PASS: eruption_column_height ~ 13.271255", newLine=true);
    } else {
        print("FAIL: eruption_column_height", newLine=true);
    };
    print(s5_2, newLine=true);

    // mass_eruption_rate(13.271255) -> roundtrip ~ 1.0e7
    var s5_3: float = mass_eruption_rate(s5_2);
    var diff_s5_3: float = s5_3 - 10000000.0;
    var abs_s5_3: float = 0.0;
    if (diff_s5_3 < 0.0) { abs_s5_3 = -diff_s5_3; } else { abs_s5_3 = diff_s5_3; };
    if (abs_s5_3 < 1.0) {
        print("PASS: mass_eruption_rate roundtrip ~ 1.0e7", newLine=true);
    } else {
        print("FAIL: mass_eruption_rate", newLine=true);
    };
    print(s5_3, newLine=true);

    // magma_ascent_velocity(5.0e6, 2.0, 1.0e4, 3000.0) ~ 0.08333333
    var s5_4: float = magma_ascent_velocity(5000000.0, 2.0, 10000.0, 3000.0);
    var diff_s5_4: float = s5_4 - 0.08333333;
    var abs_s5_4: float = 0.0;
    if (diff_s5_4 < 0.0) { abs_s5_4 = -diff_s5_4; } else { abs_s5_4 = diff_s5_4; };
    if (abs_s5_4 < 0.00001) {
        print("PASS: magma_ascent_velocity ~ 0.08333333", newLine=true);
    } else {
        print("FAIL: magma_ascent_velocity", newLine=true);
    };
    print(s5_4, newLine=true);

    // effusion_rate(0.05, 30.0) ~ 19.290123
    var s5_5: float = effusion_rate(0.05, 30.0);
    var diff_s5_5: float = s5_5 - 19.290123;
    var abs_s5_5: float = 0.0;
    if (diff_s5_5 < 0.0) { abs_s5_5 = -diff_s5_5; } else { abs_s5_5 = diff_s5_5; };
    if (abs_s5_5 < 0.001) {
        print("PASS: effusion_rate ~ 19.290123", newLine=true);
    } else {
        print("FAIL: effusion_rate", newLine=true);
    };
    print(s5_5, newLine=true);

    // lava_volume_from_effusion(19.290123, 2592000.0) -> roundtrip ~ 50000000.0
    var s5_6: float = lava_volume_from_effusion(s5_5, 2592000.0);
    var diff_s5_6: float = s5_6 - 50000000.0;
    var abs_s5_6: float = 0.0;
    if (diff_s5_6 < 0.0) { abs_s5_6 = -diff_s5_6; } else { abs_s5_6 = diff_s5_6; };
    if (abs_s5_6 < 10.0) {
        print("PASS: lava_volume_from_effusion roundtrip ~ 5.0e7", newLine=true);
    } else {
        print("FAIL: lava_volume_from_effusion", newLine=true);
    };
    print(s5_6, newLine=true);

    // magma_viscosity_suspension(1.0e4, 0.3, 0.6) ~ 28284.271247
    var s5_7: float = magma_viscosity_suspension(10000.0, 0.3, 0.6);
    var diff_s5_7: float = s5_7 - 28284.271247;
    var abs_s5_7: float = 0.0;
    if (diff_s5_7 < 0.0) { abs_s5_7 = -diff_s5_7; } else { abs_s5_7 = diff_s5_7; };
    if (abs_s5_7 < 1.0) {
        print("PASS: magma_viscosity_suspension ~ 28284.271247", newLine=true);
    } else {
        print("FAIL: magma_viscosity_suspension", newLine=true);
    };
    print(s5_7, newLine=true);

    // magma_chamber_overpressure(4.0e6, 2700.0, 2400.0, 5000.0) ~ 18709975.0
    var s5_8: float = magma_chamber_overpressure(4000000.0, 2700.0, 2400.0, 5000.0);
    var diff_s5_8: float = s5_8 - 18709975.0;
    var abs_s5_8: float = 0.0;
    if (diff_s5_8 < 0.0) { abs_s5_8 = -diff_s5_8; } else { abs_s5_8 = diff_s5_8; };
    if (abs_s5_8 < 10.0) {
        print("PASS: magma_chamber_overpressure ~ 18709975.0", newLine=true);
    } else {
        print("FAIL: magma_chamber_overpressure", newLine=true);
    };
    print(s5_8, newLine=true);

    // tephra_fallout_thickness(50.0, 0.05, 20.0) ~ 18.393972
    var s5_9: float = tephra_fallout_thickness(50.0, 0.05, 20.0);
    var diff_s5_9: float = s5_9 - 18.393972;
    var abs_s5_9: float = 0.0;
    if (diff_s5_9 < 0.0) { abs_s5_9 = -diff_s5_9; } else { abs_s5_9 = diff_s5_9; };
    if (abs_s5_9 < 0.001) {
        print("PASS: tephra_fallout_thickness ~ 18.393972", newLine=true);
    } else {
        print("FAIL: tephra_fallout_thickness", newLine=true);
    };
    print(s5_9, newLine=true);

    // silica_classification_index(58.0) -> ANDESITE
    var s5_10: RockType = silica_classification_index(58.0);
    if (s5_10 == RockType.ANDESITE) {
        print("PASS: silica_classification_index(58.0) == ANDESITE", newLine=true);
    } else {
        print("FAIL: silica_classification_index", newLine=true);
    };

    // ----- Section 6: Geochronology -----

    // decay_constant_myr(4468.0) ~ 0.0001551359
    var s6_1: float = decay_constant_myr(4468.0);
    var diff_s6_1: float = s6_1 - 0.0001551359;
    var abs_s6_1: float = 0.0;
    if (diff_s6_1 < 0.0) { abs_s6_1 = -diff_s6_1; } else { abs_s6_1 = diff_s6_1; };
    if (abs_s6_1 < 0.0000001) {
        print("PASS: decay_constant_myr ~ 0.0001551359", newLine=true);
    } else {
        print("FAIL: decay_constant_myr", newLine=true);
    };
    print(s6_1, newLine=true);

    // parent_daughter_age(0.00015513, 0.15, 1.0) ~ 900.934328
    var s6_2: float = parent_daughter_age(0.00015513, 0.15, 1.0);
    var diff_s6_2: float = s6_2 - 900.934328;
    var abs_s6_2: float = 0.0;
    if (diff_s6_2 < 0.0) { abs_s6_2 = -diff_s6_2; } else { abs_s6_2 = diff_s6_2; };
    if (abs_s6_2 < 0.5) {
        print("PASS: parent_daughter_age ~ 900.934328", newLine=true);
    } else {
        print("FAIL: parent_daughter_age", newLine=true);
    };
    print(s6_2, newLine=true);

    // u238_pb206_age(0.15, 1.0) ~ 900.900092
    var s6_3: float = u238_pb206_age(0.15, 1.0);
    var diff_s6_3: float = s6_3 - 900.900092;
    var abs_s6_3: float = 0.0;
    if (diff_s6_3 < 0.0) { abs_s6_3 = -diff_s6_3; } else { abs_s6_3 = diff_s6_3; };
    if (abs_s6_3 < 0.5) {
        print("PASS: u238_pb206_age ~ 900.900092", newLine=true);
    } else {
        print("FAIL: u238_pb206_age", newLine=true);
    };
    print(s6_3, newLine=true);

    // u235_pb207_age(0.15, 1.0) ~ 141.909911
    var s6_4: float = u235_pb207_age(0.15, 1.0);
    var diff_s6_4: float = s6_4 - 141.909911;
    var abs_s6_4: float = 0.0;
    if (diff_s6_4 < 0.0) { abs_s6_4 = -diff_s6_4; } else { abs_s6_4 = diff_s6_4; };
    if (abs_s6_4 < 0.5) {
        print("PASS: u235_pb207_age ~ 141.909911", newLine=true);
    } else {
        print("FAIL: u235_pb207_age", newLine=true);
    };
    print(s6_4, newLine=true);

    // rb87_sr87_age(0.02, 1.0) ~ 1394.174627
    var s6_5: float = rb87_sr87_age(0.02, 1.0);
    var diff_s6_5: float = s6_5 - 1394.174627;
    var abs_s6_5: float = 0.0;
    if (diff_s6_5 < 0.0) { abs_s6_5 = -diff_s6_5; } else { abs_s6_5 = diff_s6_5; };
    if (abs_s6_5 < 1.0) {
        print("PASS: rb87_sr87_age ~ 1394.174627", newLine=true);
    } else {
        print("FAIL: rb87_sr87_age", newLine=true);
    };
    print(s6_5, newLine=true);

    // sm147_nd143_age(0.01, 1.0) ~ 1521.661056
    var s6_6: float = sm147_nd143_age(0.01, 1.0);
    var diff_s6_6: float = s6_6 - 1521.661056;
    var abs_s6_6: float = 0.0;
    if (diff_s6_6 < 0.0) { abs_s6_6 = -diff_s6_6; } else { abs_s6_6 = diff_s6_6; };
    if (abs_s6_6 < 1.0) {
        print("PASS: sm147_nd143_age ~ 1521.661056", newLine=true);
    } else {
        print("FAIL: sm147_nd143_age", newLine=true);
    };
    print(s6_6, newLine=true);

    // k40_ar40_age(0.05, 1.0) ~ 703.640903
    var s6_7: float = k40_ar40_age(0.05, 1.0);
    var diff_s6_7: float = s6_7 - 703.640903;
    var abs_s6_7: float = 0.0;
    if (diff_s6_7 < 0.0) { abs_s6_7 = -diff_s6_7; } else { abs_s6_7 = diff_s6_7; };
    if (abs_s6_7 < 0.5) {
        print("PASS: k40_ar40_age ~ 703.640903", newLine=true);
    } else {
        print("FAIL: k40_ar40_age", newLine=true);
    };
    print(s6_7, newLine=true);

    // deposition_rate(5.0, 2.0) = 2.5
    var s6_8: float = deposition_rate(5.0, 2.0);
    if (s6_8 == 2.5) {
        print("PASS: deposition_rate == 2.5", newLine=true);
    } else {
        print("FAIL: deposition_rate", newLine=true);
    };
    print(s6_8, newLine=true);

    // sediment_age_from_depth(10.0, 2.5) = 4.0
    var s6_9: float = sediment_age_from_depth(10.0, 2.5);
    if (s6_9 == 4.0) {
        print("PASS: sediment_age_from_depth == 4.0", newLine=true);
    } else {
        print("FAIL: sediment_age_from_depth", newLine=true);
    };
    print(s6_9, newLine=true);

    // luminescence_age(15.0, 3.0) = 5.0
    var s6_10: float = luminescence_age(15.0, 3.0);
    if (s6_10 == 5.0) {
        print("PASS: luminescence_age == 5.0", newLine=true);
    } else {
        print("FAIL: luminescence_age", newLine=true);
    };
    print(s6_10, newLine=true);

    print("mocha-geo sections 5-6 tests done. mocha-geo COMPLETE!", newLine=true);
};