from "mocha-society" import *;

function main(didLoad) -> null {

    // ----- Section 7: Socio-Economic Development -----

    // life_expectancy_index(72.5, 20.0, 85.0) ~ 0.807692
    var s7_1: float = life_expectancy_index(72.5, 20.0, 85.0);
    var diff_s7_1: float = s7_1 - 0.807692;
    var abs_s7_1: float = 0.0;
    if (diff_s7_1 < 0.0) { abs_s7_1 = -diff_s7_1; } else { abs_s7_1 = diff_s7_1; };
    if (abs_s7_1 < 0.001) {
        print("PASS: life_expectancy_index ~ 0.807692", newLine=true);
    } else {
        print("FAIL: life_expectancy_index", newLine=true);
    };
    print(s7_1, newLine=true);

    // schooling_index(8.5, 0.0, 15.0) ~ 0.566667
    var s7_2: float = schooling_index(8.5, 0.0, 15.0);
    var diff_s7_2: float = s7_2 - 0.566667;
    var abs_s7_2: float = 0.0;
    if (diff_s7_2 < 0.0) { abs_s7_2 = -diff_s7_2; } else { abs_s7_2 = diff_s7_2; };
    if (abs_s7_2 < 0.001) {
        print("PASS: schooling_index(mean years) ~ 0.566667", newLine=true);
    } else {
        print("FAIL: schooling_index(mean years)", newLine=true);
    };
    print(s7_2, newLine=true);

    // schooling_index(13.0, 0.0, 18.0) ~ 0.722222
    var s7_3: float = schooling_index(13.0, 0.0, 18.0);
    var diff_s7_3: float = s7_3 - 0.722222;
    var abs_s7_3: float = 0.0;
    if (diff_s7_3 < 0.0) { abs_s7_3 = -diff_s7_3; } else { abs_s7_3 = diff_s7_3; };
    if (abs_s7_3 < 0.001) {
        print("PASS: schooling_index(expected years) ~ 0.722222", newLine=true);
    } else {
        print("FAIL: schooling_index(expected years)", newLine=true);
    };
    print(s7_3, newLine=true);

    // education_index(0.566667, 0.722222) ~ 0.644444
    var s7_4: float = education_index(s7_2, s7_3);
    var diff_s7_4: float = s7_4 - 0.644444;
    var abs_s7_4: float = 0.0;
    if (diff_s7_4 < 0.0) { abs_s7_4 = -diff_s7_4; } else { abs_s7_4 = diff_s7_4; };
    if (abs_s7_4 < 0.001) {
        print("PASS: education_index ~ 0.644444", newLine=true);
    } else {
        print("FAIL: education_index", newLine=true);
    };
    print(s7_4, newLine=true);

    // income_index(12000.0, 100.0, 75000.0) ~ 0.723178
    var s7_5: float = income_index(12000.0, 100.0, 75000.0);
    var diff_s7_5: float = s7_5 - 0.723178;
    var abs_s7_5: float = 0.0;
    if (diff_s7_5 < 0.0) { abs_s7_5 = -diff_s7_5; } else { abs_s7_5 = diff_s7_5; };
    if (abs_s7_5 < 0.001) {
        print("PASS: income_index ~ 0.723178", newLine=true);
    } else {
        print("FAIL: income_index", newLine=true);
    };
    print(s7_5, newLine=true);

    // human_development_index(0.807692, 0.644444, 0.723178) ~ 0.722036
    var s7_6: float = human_development_index(s7_1, s7_4, s7_5);
    var diff_s7_6: float = s7_6 - 0.722036;
    var abs_s7_6: float = 0.0;
    if (diff_s7_6 < 0.0) { abs_s7_6 = -diff_s7_6; } else { abs_s7_6 = diff_s7_6; };
    if (abs_s7_6 < 0.001) {
        print("PASS: human_development_index ~ 0.722036", newLine=true);
    } else {
        print("FAIL: human_development_index", newLine=true);
    };
    print(s7_6, newLine=true);

    // gdp_per_capita_growth_rate(45000.0, 48000.0, 3.0) ~ 0.021513
    var s7_7: float = gdp_per_capita_growth_rate(45000.0, 48000.0, 3.0);
    var diff_s7_7: float = s7_7 - 0.021513;
    var abs_s7_7: float = 0.0;
    if (diff_s7_7 < 0.0) { abs_s7_7 = -diff_s7_7; } else { abs_s7_7 = diff_s7_7; };
    if (abs_s7_7 < 0.0001) {
        print("PASS: gdp_per_capita_growth_rate ~ 0.021513", newLine=true);
    } else {
        print("FAIL: gdp_per_capita_growth_rate", newLine=true);
    };
    print(s7_7, newLine=true);

    // income_elasticity_of_demand(15.0, 10.0) = 1.5
    var s7_8: float = income_elasticity_of_demand(15.0, 10.0);
    if (s7_8 == 1.5) {
        print("PASS: income_elasticity_of_demand == 1.5", newLine=true);
    } else {
        print("FAIL: income_elasticity_of_demand", newLine=true);
    };
    print(s7_8, newLine=true);

    // engels_coefficient(4500.0, 18000.0) = 25.0
    var s7_9: float = engels_coefficient(4500.0, 18000.0);
    if (s7_9 == 25.0) {
        print("PASS: engels_coefficient == 25.0", newLine=true);
    } else {
        print("FAIL: engels_coefficient", newLine=true);
    };
    print(s7_9, newLine=true);

    // unemployment_rate(1200000.0, 25000000.0) = 4.8
    var s7_10: float = unemployment_rate(1200000.0, 25000000.0);
    if (s7_10 == 4.8) {
        print("PASS: unemployment_rate == 4.8", newLine=true);
    } else {
        print("FAIL: unemployment_rate", newLine=true);
    };
    print(s7_10, newLine=true);

    // labor_force_participation_rate(25000000.0, 40000000.0) = 62.5
    var s7_11: float = labor_force_participation_rate(25000000.0, 40000000.0);
    if (s7_11 == 62.5) {
        print("PASS: labor_force_participation_rate == 62.5", newLine=true);
    } else {
        print("FAIL: labor_force_participation_rate", newLine=true);
    };
    print(s7_11, newLine=true);

    // purchasing_power_parity_adjustment(50000.0, 0.65) ~ 76923.076923
    var s7_12: float = purchasing_power_parity_adjustment(50000.0, 0.65);
    var diff_s7_12: float = s7_12 - 76923.076923;
    var abs_s7_12: float = 0.0;
    if (diff_s7_12 < 0.0) { abs_s7_12 = -diff_s7_12; } else { abs_s7_12 = diff_s7_12; };
    if (abs_s7_12 < 0.5) {
        print("PASS: purchasing_power_parity_adjustment ~ 76923.076923", newLine=true);
    } else {
        print("FAIL: purchasing_power_parity_adjustment", newLine=true);
    };
    print(s7_12, newLine=true);

    // misery_index(6.5, 4.8) = 11.3
    var s7_13: float = misery_index(6.5, 4.8);
    if (s7_13 == 11.3) {
        print("PASS: misery_index == 11.3", newLine=true);
    } else {
        print("FAIL: misery_index", newLine=true);
    };
    print(s7_13, newLine=true);

    print("mocha-society section 7 tests done. mocha-society COMPLETE!", newLine=true);
};