from "mocha-geo" import *;

function main(didLoad) -> null {

    // ----- Section 3: Structural Geology & Plate Tectonics -----

    // plate_velocity(50.0, 10.0) = 0.5 cm/yr
    var s3_1: float = plate_velocity(50.0, 10.0);
    if (s3_1 == 0.5) {
        print("PASS: plate_velocity == 0.5", newLine=true);
    } else {
        print("FAIL: plate_velocity", newLine=true);
    };
    print(s3_1, newLine=true);

    // euler_pole_velocity(0.5, 60.0) ~ 4.814882
    var s3_2: float = euler_pole_velocity(0.5, 60.0);
    var diff_s3_2: float = s3_2 - 4.814882;
    var abs_s3_2: float = 0.0;
    if (diff_s3_2 < 0.0) { abs_s3_2 = -diff_s3_2; } else { abs_s3_2 = diff_s3_2; };
    if (abs_s3_2 < 0.001) {
        print("PASS: euler_pole_velocity ~ 4.814882", newLine=true);
    } else {
        print("FAIL: euler_pole_velocity", newLine=true);
    };
    print(s3_2, newLine=true);

    // relative_plate_motion(3.0, 2.0, 1.0, -1.0) -> (2.0, 3.0)
    var s3_3: (float, 2) = relative_plate_motion(3.0, 2.0, 1.0, -1.0);
    if (s3_3#0 == 2.0 && s3_3#1 == 3.0) {
        print("PASS: relative_plate_motion == (2.0, 3.0)", newLine=true);
    } else {
        print("FAIL: relative_plate_motion", newLine=true);
    };
    print(s3_3#0, newLine=true);
    print(s3_3#1, newLine=true);

    // normal_stress(100.0, 40.0, 30.0) = 85.0
    var s3_4: float = normal_stress(100.0, 40.0, 30.0);
    var diff_s3_4: float = s3_4 - 85.0;
    var abs_s3_4: float = 0.0;
    if (diff_s3_4 < 0.0) { abs_s3_4 = -diff_s3_4; } else { abs_s3_4 = diff_s3_4; };
    if (abs_s3_4 < 0.01) {
        print("PASS: normal_stress ~ 85.0", newLine=true);
    } else {
        print("FAIL: normal_stress", newLine=true);
    };
    print(s3_4, newLine=true);

    // shear_stress(100.0, 40.0, 30.0) ~ 25.980762
    var s3_5: float = shear_stress(100.0, 40.0, 30.0);
    var diff_s3_5: float = s3_5 - 25.980762;
    var abs_s3_5: float = 0.0;
    if (diff_s3_5 < 0.0) { abs_s3_5 = -diff_s3_5; } else { abs_s3_5 = diff_s3_5; };
    if (abs_s3_5 < 0.001) {
        print("PASS: shear_stress ~ 25.980762", newLine=true);
    } else {
        print("FAIL: shear_stress", newLine=true);
    };
    print(s3_5, newLine=true);

    // true_dip(25.0, 40.0) ~ 31.329770
    var s3_6: float = true_dip(25.0, 40.0);
    var diff_s3_6: float = s3_6 - 31.329770;
    var abs_s3_6: float = 0.0;
    if (diff_s3_6 < 0.0) { abs_s3_6 = -diff_s3_6; } else { abs_s3_6 = diff_s3_6; };
    if (abs_s3_6 < 0.001) {
        print("PASS: true_dip ~ 31.329770", newLine=true);
    } else {
        print("FAIL: true_dip", newLine=true);
    };
    print(s3_6, newLine=true);

    // strike_from_dip_direction(135.0) = 45.0
    var s3_7: float = strike_from_dip_direction(135.0);
    if (s3_7 == 45.0) {
        print("PASS: strike_from_dip_direction == 45.0", newLine=true);
    } else {
        print("FAIL: strike_from_dip_direction", newLine=true);
    };
    print(s3_7, newLine=true);

    // airy_isostasy_root(2.0, 2700.0, 3300.0) = 9.0
    var s3_8: float = airy_isostasy_root(2.0, 2700.0, 3300.0);
    if (s3_8 == 9.0) {
        print("PASS: airy_isostasy_root == 9.0", newLine=true);
    } else {
        print("FAIL: airy_isostasy_root", newLine=true);
    };
    print(s3_8, newLine=true);

    // fault_heave_throw(10.0, 60.0) -> (5.0, 8.660254)
    var s3_9: (float, 2) = fault_heave_throw(10.0, 60.0);
    var diff_s3_9_heave: float = s3_9#0 - 5.0;
    var abs_s3_9_heave: float = 0.0;
    if (diff_s3_9_heave < 0.0) { abs_s3_9_heave = -diff_s3_9_heave; } else { abs_s3_9_heave = diff_s3_9_heave; };
    var diff_s3_9_throw: float = s3_9#1 - 8.660254;
    var abs_s3_9_throw: float = 0.0;
    if (diff_s3_9_throw < 0.0) { abs_s3_9_throw = -diff_s3_9_throw; } else { abs_s3_9_throw = diff_s3_9_throw; };
    if (abs_s3_9_heave < 0.001 && abs_s3_9_throw < 0.001) {
        print("PASS: fault_heave_throw ~ (5.0, 8.660254)", newLine=true);
    } else {
        print("FAIL: fault_heave_throw", newLine=true);
    };
    print(s3_9#0, newLine=true);
    print(s3_9#1, newLine=true);

    // strain_ellipse_ratio(0.3, -0.15) ~ 1.529412
    var s3_10: float = strain_ellipse_ratio(0.3, -0.15);
    var diff_s3_10: float = s3_10 - 1.529412;
    var abs_s3_10: float = 0.0;
    if (diff_s3_10 < 0.0) { abs_s3_10 = -diff_s3_10; } else { abs_s3_10 = diff_s3_10; };
    if (abs_s3_10 < 0.001) {
        print("PASS: strain_ellipse_ratio ~ 1.529412", newLine=true);
    } else {
        print("FAIL: strain_ellipse_ratio", newLine=true);
    };
    print(s3_10, newLine=true);

    // ----- Section 4: Hydrology -----

    // hydraulic_gradient(105.0, 98.0, 250.0) = 0.028
    var s4_1: float = hydraulic_gradient(105.0, 98.0, 250.0);
    if (s4_1 == 0.028) {
        print("PASS: hydraulic_gradient == 0.028", newLine=true);
    } else {
        print("FAIL: hydraulic_gradient", newLine=true);
    };
    print(s4_1, newLine=true);

    // darcy_flux(0.0025, 0.028) = 0.00007
    var s4_2: float = darcy_flux(0.0025, 0.028);
    var diff_s4_2: float = s4_2 - 0.00007;
    var abs_s4_2: float = 0.0;
    if (diff_s4_2 < 0.0) { abs_s4_2 = -diff_s4_2; } else { abs_s4_2 = diff_s4_2; };
    if (abs_s4_2 < 0.0000001) {
        print("PASS: darcy_flux ~ 0.00007", newLine=true);
    } else {
        print("FAIL: darcy_flux", newLine=true);
    };
    print(s4_2, newLine=true);

    // darcy_discharge(0.0025, 50.0, 0.028) = 0.0035
    var s4_3: float = darcy_discharge(0.0025, 50.0, 0.028);
    var diff_s4_3: float = s4_3 - 0.0035;
    var abs_s4_3: float = 0.0;
    if (diff_s4_3 < 0.0) { abs_s4_3 = -diff_s4_3; } else { abs_s4_3 = diff_s4_3; };
    if (abs_s4_3 < 0.00001) {
        print("PASS: darcy_discharge ~ 0.0035", newLine=true);
    } else {
        print("FAIL: darcy_discharge", newLine=true);
    };
    print(s4_3, newLine=true);

    // transmissivity(0.0025, 20.0) = 0.05
    var s4_4: float = transmissivity(0.0025, 20.0);
    if (s4_4 == 0.05) {
        print("PASS: transmissivity == 0.05", newLine=true);
    } else {
        print("FAIL: transmissivity", newLine=true);
    };
    print(s4_4, newLine=true);

    // seepage_velocity(0.00007, 0.3) ~ 0.00023333
    var s4_5: float = seepage_velocity(0.00007, 0.3);
    var diff_s4_5: float = s4_5 - 0.00023333;
    var abs_s4_5: float = 0.0;
    if (diff_s4_5 < 0.0) { abs_s4_5 = -diff_s4_5; } else { abs_s4_5 = diff_s4_5; };
    if (abs_s4_5 < 0.000001) {
        print("PASS: seepage_velocity ~ 0.00023333", newLine=true);
    } else {
        print("FAIL: seepage_velocity", newLine=true);
    };
    print(s4_5, newLine=true);

    // porosity(0.35, 1.0) = 0.35
    var s4_6: float = porosity(0.35, 1.0);
    if (s4_6 == 0.35) {
        print("PASS: porosity == 0.35", newLine=true);
    } else {
        print("FAIL: porosity", newLine=true);
    };
    print(s4_6, newLine=true);

    // manning_velocity(0.03, 1.5, 0.001) ~ 1.381252
    var s4_7: float = manning_velocity(0.03, 1.5, 0.001);
    var diff_s4_7: float = s4_7 - 1.381252;
    var abs_s4_7: float = 0.0;
    if (diff_s4_7 < 0.0) { abs_s4_7 = -diff_s4_7; } else { abs_s4_7 = diff_s4_7; };
    if (abs_s4_7 < 0.001) {
        print("PASS: manning_velocity ~ 1.381252", newLine=true);
    } else {
        print("FAIL: manning_velocity", newLine=true);
    };
    print(s4_7, newLine=true);

    // stream_discharge(20.0, 1.381252) ~ 27.625040
    var s4_8: float = stream_discharge(20.0, 1.381252);
    var diff_s4_8: float = s4_8 - 27.625040;
    var abs_s4_8: float = 0.0;
    if (diff_s4_8 < 0.0) { abs_s4_8 = -diff_s4_8; } else { abs_s4_8 = diff_s4_8; };
    if (abs_s4_8 < 0.001) {
        print("PASS: stream_discharge ~ 27.625040", newLine=true);
    } else {
        print("FAIL: stream_discharge", newLine=true);
    };
    print(s4_8, newLine=true);

    // reynolds_number_pipe(2.0, 0.5, 0.000001) = 1000000.0
    var s4_9: float = reynolds_number_pipe(2.0, 0.5, 0.000001);
    var diff_s4_9: float = s4_9 - 1000000.0;
    var abs_s4_9: float = 0.0;
    if (diff_s4_9 < 0.0) { abs_s4_9 = -diff_s4_9; } else { abs_s4_9 = diff_s4_9; };
    if (abs_s4_9 < 1.0) {
        print("PASS: reynolds_number_pipe ~ 1000000.0", newLine=true);
    } else {
        print("FAIL: reynolds_number_pipe", newLine=true);
    };
    print(s4_9, newLine=true);

    // cooper_jacob_drawdown(0.05, 0.05, 86400.0, 100.0, 0.0002) ~ 0.674758
    var s4_10: float = cooper_jacob_drawdown(0.05, 0.05, 86400.0, 100.0, 0.0002);
    var diff_s4_10: float = s4_10 - 0.674758;
    var abs_s4_10: float = 0.0;
    if (diff_s4_10 < 0.0) { abs_s4_10 = -diff_s4_10; } else { abs_s4_10 = diff_s4_10; };
    if (abs_s4_10 < 0.001) {
        print("PASS: cooper_jacob_drawdown ~ 0.674758", newLine=true);
    } else {
        print("FAIL: cooper_jacob_drawdown", newLine=true);
    };
    print(s4_10, newLine=true);

    // time_of_travel(500.0, seepage_velocity(0.00007, 0.3)) ~ 2142857.14
    var s4_11_seep: float = seepage_velocity(0.00007, 0.3);
    var s4_11: float = time_of_travel(500.0, s4_11_seep);
    var diff_s4_11: float = s4_11 - 2142857.14;
    var abs_s4_11: float = 0.0;
    if (diff_s4_11 < 0.0) { abs_s4_11 = -diff_s4_11; } else { abs_s4_11 = diff_s4_11; };
    if (abs_s4_11 < 100.0) {
        print("PASS: time_of_travel ~ 2142857.14", newLine=true);
    } else {
        print("FAIL: time_of_travel", newLine=true);
    };
    print(s4_11, newLine=true);

    print("mocha-geo sections 3-4 tests done.", newLine=true);
};