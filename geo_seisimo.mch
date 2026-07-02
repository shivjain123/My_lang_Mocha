from "mocha-geo" import *;

function main(didLoad) -> null {

    // ----- Section 1: Seismology -----

    // richter_magnitude(1.0, 100.0) = 0.319
    var s1_1: float = richter_magnitude(1.0, 100.0);
    var diff_s1_1: float = s1_1 - 0.319;
    var abs_s1_1: float = 0.0;
    if (diff_s1_1 < 0.0) { abs_s1_1 = -diff_s1_1; } else { abs_s1_1 = diff_s1_1; };
    if (abs_s1_1 < 0.001) {
        print("PASS: richter_magnitude ~ 0.319", newLine=true);
    } else {
        print("FAIL: richter_magnitude", newLine=true);
    };
    print(s1_1, newLine=true);

    // moment_magnitude(1000000.0) = -2.07
    var s1_2: float = moment_magnitude(1000000.0);
    var diff_s1_2: float = s1_2 - (-2.07);
    var abs_s1_2: float = 0.0;
    if (diff_s1_2 < 0.0) { abs_s1_2 = -diff_s1_2; } else { abs_s1_2 = diff_s1_2; };
    if (abs_s1_2 < 0.001) {
        print("PASS: moment_magnitude ~ -2.07", newLine=true);
    } else {
        print("FAIL: moment_magnitude", newLine=true);
    };
    print(s1_2, newLine=true);

    // seismic_moment(100.0, 10.0, 1.0) = 1000.0
    var s1_3: float = seismic_moment(100.0, 10.0, 1.0);
    var diff_s1_3: float = s1_3 - 1000.0;
    var abs_s1_3: float = 0.0;
    if (diff_s1_3 < 0.0) { abs_s1_3 = -diff_s1_3; } else { abs_s1_3 = diff_s1_3; };
    if (abs_s1_3 < 0.01) {
        print("PASS: seismic_moment ~ 1000.0", newLine=true);
    } else {
        print("FAIL: seismic_moment", newLine=true);
    };
    print(s1_3, newLine=true);

    // energy_release(5.0) = 1995262314968.88 — relative error check
    var s1_4: float = energy_release(5.0);
    var diff_s1_4: float = float(unsafe_div(s1_4 - 1995262314968.88, 1995262314968.88));
    var abs_s1_4: float = 0.0;
    if (diff_s1_4 < 0.0) { abs_s1_4 = -diff_s1_4; } else { abs_s1_4 = diff_s1_4; };
    if (abs_s1_4 < 0.0001) {
        print("PASS: energy_release ~ 1.9953e12", newLine=true);
    } else {
        print("FAIL: energy_release", newLine=true);
    };
    print(s1_4, newLine=true);

    // p_wave_travel_time(100.0, 6.0) = 16.6667
    var s1_5: float = p_wave_travel_time(100.0, 6.0);
    var diff_s1_5: float = s1_5 - 16.6667;
    var abs_s1_5: float = 0.0;
    if (diff_s1_5 < 0.0) { abs_s1_5 = -diff_s1_5; } else { abs_s1_5 = diff_s1_5; };
    if (abs_s1_5 < 0.001) {
        print("PASS: p_wave_travel_time ~ 16.6667", newLine=true);
    } else {
        print("FAIL: p_wave_travel_time", newLine=true);
    };
    print(s1_5, newLine=true);

    // s_wave_travel_time(100.0, 3.5) = 28.5714
    var s1_6: float = s_wave_travel_time(100.0, 3.5);
    var diff_s1_6: float = s1_6 - 28.5714;
    var abs_s1_6: float = 0.0;
    if (diff_s1_6 < 0.0) { abs_s1_6 = -diff_s1_6; } else { abs_s1_6 = diff_s1_6; };
    if (abs_s1_6 < 0.001) {
        print("PASS: s_wave_travel_time ~ 28.5714", newLine=true);
    } else {
        print("FAIL: s_wave_travel_time", newLine=true);
    };
    print(s1_6, newLine=true);

    // sp_time_interval_distance(10.0, 6.0, 3.5) = 84.0
    var s1_7: float = sp_time_interval_distance(10.0, 6.0, 3.5);
    var diff_s1_7: float = s1_7 - 84.0;
    var abs_s1_7: float = 0.0;
    if (diff_s1_7 < 0.0) { abs_s1_7 = -diff_s1_7; } else { abs_s1_7 = diff_s1_7; };
    if (abs_s1_7 < 0.01) {
        print("PASS: sp_time_interval_distance ~ 84.0", newLine=true);
    } else {
        print("FAIL: sp_time_interval_distance", newLine=true);
    };
    print(s1_7, newLine=true);

    // epicenter_triangulation → (0.5, 0.5)
    var s1_8: (float, 2) = epicenter_triangulation(
        78.7151, 78.7151, 78.7151,
        0.0, 0.0,
        0.0, 1.0,
        1.0, 0.0
    );
    var diff_s1_8_lat: float = s1_8#0 - 0.5;
    var abs_s1_8_lat: float = 0.0;
    if (diff_s1_8_lat < 0.0) { abs_s1_8_lat = -diff_s1_8_lat; } else { abs_s1_8_lat = diff_s1_8_lat; };
    var diff_s1_8_lon: float = s1_8#1 - 0.5;
    var abs_s1_8_lon: float = 0.0;
    if (diff_s1_8_lon < 0.0) { abs_s1_8_lon = -diff_s1_8_lon; } else { abs_s1_8_lon = diff_s1_8_lon; };
    if (abs_s1_8_lat < 0.001 && abs_s1_8_lon < 0.001) {
        print("PASS: epicenter_triangulation ~ (0.5, 0.5)", newLine=true);
    } else {
        print("FAIL: epicenter_triangulation", newLine=true);
    };
    print(s1_8#0, newLine=true);
    print(s1_8#1, newLine=true);

    // peak_ground_acceleration(6.5, 50.0) = 0.059024
    var s1_9: float = peak_ground_acceleration(6.5, 50.0);
    var diff_s1_9: float = s1_9 - 0.059024;
    var abs_s1_9: float = 0.0;
    if (diff_s1_9 < 0.0) { abs_s1_9 = -diff_s1_9; } else { abs_s1_9 = diff_s1_9; };
    if (abs_s1_9 < 0.0001) {
        print("PASS: peak_ground_acceleration ~ 0.059024", newLine=true);
    } else {
        print("FAIL: peak_ground_acceleration", newLine=true);
    };
    print(s1_9, newLine=true);

    // mercalli_intensity_estimate(0.059024) = 4.789
    var s1_10: float = mercalli_intensity_estimate(0.059024);
    var diff_s1_10: float = s1_10 - 4.789;
    var abs_s1_10: float = 0.0;
    if (diff_s1_10 < 0.0) { abs_s1_10 = -diff_s1_10; } else { abs_s1_10 = diff_s1_10; };
    if (abs_s1_10 < 0.001) {
        print("PASS: mercalli_intensity_estimate ~ 4.789", newLine=true);
    } else {
        print("FAIL: mercalli_intensity_estimate", newLine=true);
    };
    print(s1_10, newLine=true);

    // ----- Section 2: Mineralogy & Crystallography -----

    // specific_gravity(2650.0) = 2.65
    var s2_1: float = specific_gravity(2650.0);
    var diff_s2_1: float = s2_1 - 2.65;
    var abs_s2_1: float = 0.0;
    if (diff_s2_1 < 0.0) { abs_s2_1 = -diff_s2_1; } else { abs_s2_1 = diff_s2_1; };
    if (abs_s2_1 < 0.001) {
        print("PASS: specific_gravity ~ 2.65", newLine=true);
    } else {
        print("FAIL: specific_gravity", newLine=true);
    };
    print(s2_1, newLine=true);

    // unit_cell_volume(5,5,5,90,90,90) = 125.0
    var s2_2: float = unit_cell_volume(5.0, 5.0, 5.0, 90.0, 90.0, 90.0);
    var diff_s2_2: float = s2_2 - 125.0;
    var abs_s2_2: float = 0.0;
    if (diff_s2_2 < 0.0) { abs_s2_2 = -diff_s2_2; } else { abs_s2_2 = diff_s2_2; };
    if (abs_s2_2 < 0.01) {
        print("PASS: unit_cell_volume ~ 125.0", newLine=true);
    } else {
        print("FAIL: unit_cell_volume", newLine=true);
    };
    print(s2_2, newLine=true);

    // theoretical_density(58.44, 4.0, 179.0) = 2.1685
    var s2_3: float = theoretical_density(58.44, 4.0, 179.0);
    var diff_s2_3: float = s2_3 - 2.1685;
    var abs_s2_3: float = 0.0;
    if (diff_s2_3 < 0.0) { abs_s2_3 = -diff_s2_3; } else { abs_s2_3 = diff_s2_3; };
    if (abs_s2_3 < 0.001) {
        print("PASS: theoretical_density ~ 2.1685", newLine=true);
    } else {
        print("FAIL: theoretical_density", newLine=true);
    };
    print(s2_3, newLine=true);

    // bragg_angle(1.5406, 2.0, 1) = 22.653
    var s2_4: float = bragg_angle(1.5406, 2.0, 1);
    var diff_s2_4: float = s2_4 - 22.653;
    var abs_s2_4: float = 0.0;
    if (diff_s2_4 < 0.0) { abs_s2_4 = -diff_s2_4; } else { abs_s2_4 = diff_s2_4; };
    if (abs_s2_4 < 0.001) {
        print("PASS: bragg_angle ~ 22.653", newLine=true);
    } else {
        print("FAIL: bragg_angle", newLine=true);
    };
    print(s2_4, newLine=true);

    // d_spacing_cubic(5.6402, 1, 1, 1) = 3.2564
    var s2_5: float = d_spacing_cubic(5.6402, 1, 1, 1);
    var diff_s2_5: float = s2_5 - 3.2564;
    var abs_s2_5: float = 0.0;
    if (diff_s2_5 < 0.0) { abs_s2_5 = -diff_s2_5; } else { abs_s2_5 = diff_s2_5; };
    if (abs_s2_5 < 0.001) {
        print("PASS: d_spacing_cubic ~ 3.2564", newLine=true);
    } else {
        print("FAIL: d_spacing_cubic", newLine=true);
    };
    print(s2_5, newLine=true);

    // d_spacing_hexagonal(4.9135, 5.4052, 1, 0, 0) = 4.2552
    var s2_6: float = d_spacing_hexagonal(4.9135, 5.4052, 1, 0, 0);
    var diff_s2_6: float = s2_6 - 4.2552;
    var abs_s2_6: float = 0.0;
    if (diff_s2_6 < 0.0) { abs_s2_6 = -diff_s2_6; } else { abs_s2_6 = diff_s2_6; };
    if (abs_s2_6 < 0.001) {
        print("PASS: d_spacing_hexagonal ~ 4.2552", newLine=true);
    } else {
        print("FAIL: d_spacing_hexagonal", newLine=true);
    };
    print(s2_6, newLine=true);

    // mohs_to_vickers_estimate(7.0) = 15848.93
    var s2_7: float = mohs_to_vickers_estimate(7.0);
    var diff_s2_7: float = s2_7 - 15848.93;
    var abs_s2_7: float = 0.0;
    if (diff_s2_7 < 0.0) { abs_s2_7 = -diff_s2_7; } else { abs_s2_7 = diff_s2_7; };
    if (abs_s2_7 < 1.0) {
        print("PASS: mohs_to_vickers_estimate ~ 15848.93", newLine=true);
    } else {
        print("FAIL: mohs_to_vickers_estimate", newLine=true);
    };
    print(s2_7, newLine=true);

    // packing_efficiency(FCC) = 0.7405
    var s2_8: float = packing_efficiency(CrystalStructure.FCC);
    var diff_s2_8: float = s2_8 - 0.7405;
    var abs_s2_8: float = 0.0;
    if (diff_s2_8 < 0.0) { abs_s2_8 = -diff_s2_8; } else { abs_s2_8 = diff_s2_8; };
    if (abs_s2_8 < 0.0001) {
        print("PASS: packing_efficiency FCC ~ 0.7405", newLine=true);
    } else {
        print("FAIL: packing_efficiency", newLine=true);
    };
    print(s2_8, newLine=true);

    // coordination_number_estimate(0.72, 1.40) = 6
    var s2_9: int = coordination_number_estimate(0.72, 1.40);
    if (s2_9 == 6) {
        print("PASS: coordination_number_estimate == 6", newLine=true);
    } else {
        print("FAIL: coordination_number_estimate", newLine=true);
    };
    print(s2_9, newLine=true);

    // madelung_constant_estimate(6) = 1.7476
    var s2_10: float = madelung_constant_estimate(19);
    var diff_s2_10: float = s2_10 - 1.7476;
    var abs_s2_10: float = 0.0;
    if (diff_s2_10 < 0.0) { abs_s2_10 = -diff_s2_10; } else { abs_s2_10 = diff_s2_10; };
    if (abs_s2_10 < 0.0001) {
        print("PASS: madelung_constant_estimate ~ 1.7476", newLine=true);
    } else {
        print("FAIL: madelung_constant_estimate", newLine=true);
    };
    print(s2_10, newLine=true);

    print("mocha-geo sections 1+2 tests done.", newLine=true);
};