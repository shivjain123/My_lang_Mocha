from "mocha-astro" import *;

function main(didLoad) -> null {

    // ----- Section 1: Ayanamsa & Sidereal Foundations -----

    // julian_day_number(2000,1,1,12.0) = 2451545.0 (J2000.0 reference)
    var s1_1: float = julian_day_number(2000, 1, 1, 12.0);
    if (s1_1 == 2451545.0) {
        print("PASS: julian_day_number(J2000.0) == 2451545.0", newLine=true);
    } else {
        print("FAIL: julian_day_number(J2000.0)", newLine=true);
    };
    print(s1_1, newLine=true);

    // julian_day_number(1900,1,1,0.0) = 2415020.5
    var s1_2: float = julian_day_number(1900, 1, 1, 0.0);
    if (s1_2 == 2415020.5) {
        print("PASS: julian_day_number(1900) == 2415020.5", newLine=true);
    } else {
        print("FAIL: julian_day_number(1900)", newLine=true);
    };
    print(s1_2, newLine=true);

    // fractional_year(2024,7,4) ~ 2024.505464
    var s1_3: float = fractional_year(2024, 7, 4);
    var diff_s1_3: float = s1_3 - 2024.505464;
    var abs_s1_3: float = 0.0;
    if (diff_s1_3 < 0.0) { abs_s1_3 = -diff_s1_3; } else { abs_s1_3 = diff_s1_3; };
    if (abs_s1_3 < 0.001) {
        print("PASS: fractional_year(2024,7,4) ~ 2024.505464", newLine=true);
    } else {
        print("FAIL: fractional_year(2024,7,4)", newLine=true);
    };
    print(s1_3, newLine=true);

    // fractional_year(2000,1,1) = 2000.0
    var s1_4: float = fractional_year(2000, 1, 1);
    if (s1_4 == 2000.0) {
        print("PASS: fractional_year(2000,1,1) == 2000.0", newLine=true);
    } else {
        print("FAIL: fractional_year(2000,1,1)", newLine=true);
    };
    print(s1_4, newLine=true);

    // normalize_degrees(370.0) = 10.0
    var s1_5: float = normalize_degrees(370.0);
    if (s1_5 == 10.0) {
        print("PASS: normalize_degrees(370.0) == 10.0", newLine=true);
    } else {
        print("FAIL: normalize_degrees(370.0)", newLine=true);
    };
    print(s1_5, newLine=true);

    // normalize_degrees(-30.0) = 330.0
    var s1_6: float = normalize_degrees(-30.0);
    if (s1_6 == 330.0) {
        print("PASS: normalize_degrees(-30.0) == 330.0", newLine=true);
    } else {
        print("FAIL: normalize_degrees(-30.0)", newLine=true);
    };
    print(s1_6, newLine=true);

    // normalize_degrees(720.5) = 0.5
    var s1_7: float = normalize_degrees(720.5);
    if (s1_7 == 0.5) {
        print("PASS: normalize_degrees(720.5) == 0.5", newLine=true);
    } else {
        print("FAIL: normalize_degrees(720.5)", newLine=true);
    };
    print(s1_7, newLine=true);

    // lahiri_ayanamsa(2000.0) ~ 23.856750
    var s1_8: float = lahiri_ayanamsa(2000.0);
    var diff_s1_8: float = s1_8 - 23.856750;
    var abs_s1_8: float = 0.0;
    if (diff_s1_8 < 0.0) { abs_s1_8 = -diff_s1_8; } else { abs_s1_8 = diff_s1_8; };
    if (abs_s1_8 < 0.0001) {
        print("PASS: lahiri_ayanamsa(2000.0) ~ 23.856750", newLine=true);
    } else {
        print("FAIL: lahiri_ayanamsa(2000.0)", newLine=true);
    };
    print(s1_8, newLine=true);

    // lahiri_ayanamsa(2024.5) ~ 24.198653
    var s1_9: float = lahiri_ayanamsa(2024.5);
    var diff_s1_9: float = s1_9 - 24.198653;
    var abs_s1_9: float = 0.0;
    if (diff_s1_9 < 0.0) { abs_s1_9 = -diff_s1_9; } else { abs_s1_9 = diff_s1_9; };
    if (abs_s1_9 < 0.0001) {
        print("PASS: lahiri_ayanamsa(2024.5) ~ 24.198653", newLine=true);
    } else {
        print("FAIL: lahiri_ayanamsa(2024.5)", newLine=true);
    };
    print(s1_9, newLine=true);

    // raman_ayanamsa(2000.0) ~ 23.240050
    var s1_10: float = raman_ayanamsa(2000.0);
    var diff_s1_10: float = s1_10 - 23.240050;
    var abs_s1_10: float = 0.0;
    if (diff_s1_10 < 0.0) { abs_s1_10 = -diff_s1_10; } else { abs_s1_10 = diff_s1_10; };
    if (abs_s1_10 < 0.0001) {
        print("PASS: raman_ayanamsa(2000.0) ~ 23.240050", newLine=true);
    } else {
        print("FAIL: raman_ayanamsa(2000.0)", newLine=true);
    };
    print(s1_10, newLine=true);

    // kp_ayanamsa(2000.0) ~ 23.717990
    var s1_11: float = kp_ayanamsa(2000.0);
    var diff_s1_11: float = s1_11 - 23.717990;
    var abs_s1_11: float = 0.0;
    if (diff_s1_11 < 0.0) { abs_s1_11 = -diff_s1_11; } else { abs_s1_11 = diff_s1_11; };
    if (abs_s1_11 < 0.0001) {
        print("PASS: kp_ayanamsa(2000.0) ~ 23.717990", newLine=true);
    } else {
        print("FAIL: kp_ayanamsa(2000.0)", newLine=true);
    };
    print(s1_11, newLine=true);

    // fagan_bradley_ayanamsa(2000.0) ~ 24.739662
    var s1_12: float = fagan_bradley_ayanamsa(2000.0);
    var diff_s1_12: float = s1_12 - 24.739662;
    var abs_s1_12: float = 0.0;
    if (diff_s1_12 < 0.0) { abs_s1_12 = -diff_s1_12; } else { abs_s1_12 = diff_s1_12; };
    if (abs_s1_12 < 0.0001) {
        print("PASS: fagan_bradley_ayanamsa(2000.0) ~ 24.739662", newLine=true);
    } else {
        print("FAIL: fagan_bradley_ayanamsa(2000.0)", newLine=true);
    };
    print(s1_12, newLine=true);

    // tropical_to_sidereal(285.34, 24.198653) ~ 261.141347
    var s1_13: float = tropical_to_sidereal(285.34, 24.198653);
    var diff_s1_13: float = s1_13 - 261.141347;
    var abs_s1_13: float = 0.0;
    if (diff_s1_13 < 0.0) { abs_s1_13 = -diff_s1_13; } else { abs_s1_13 = diff_s1_13; };
    if (abs_s1_13 < 0.0001) {
        print("PASS: tropical_to_sidereal ~ 261.141347", newLine=true);
    } else {
        print("FAIL: tropical_to_sidereal", newLine=true);
    };
    print(s1_13, newLine=true);

    // sidereal_to_tropical roundtrip -> 285.34
    var s1_14: float = sidereal_to_tropical(s1_13, 24.198653);
    var diff_s1_14: float = s1_14 - 285.34;
    var abs_s1_14: float = 0.0;
    if (diff_s1_14 < 0.0) { abs_s1_14 = -diff_s1_14; } else { abs_s1_14 = diff_s1_14; };
    if (abs_s1_14 < 0.0001) {
        print("PASS: sidereal_to_tropical roundtrip ~ 285.34", newLine=true);
    } else {
        print("FAIL: sidereal_to_tropical roundtrip", newLine=true);
    };
    print(s1_14, newLine=true);

    // ----- Section 2: Planetary Positions (Ephemerides) -----

    // centuries_since_j2000(2448908.5) ~ -0.072183436 (Meeus example)
    var s2_1: float = centuries_since_j2000(2448908.5);
    var diff_s2_1: float = s2_1 - (-0.072183436);
    var abs_s2_1: float = 0.0;
    if (diff_s2_1 < 0.0) { abs_s2_1 = -diff_s2_1; } else { abs_s2_1 = diff_s2_1; };
    if (abs_s2_1 < 0.000001) {
        print("PASS: centuries_since_j2000 ~ -0.072183436", newLine=true);
    } else {
        print("FAIL: centuries_since_j2000", newLine=true);
    };
    print(s2_1, newLine=true);

    // atan2_degrees checks (all 4 quadrants) — tolerance-based, trig-derived
    var s2_2: float = atan2_degrees(1.0, 1.0);
    var diff_s2_2: float = s2_2 - 45.0;
    var abs_s2_2: float = 0.0;
    if (diff_s2_2 < 0.0) { abs_s2_2 = -diff_s2_2; } else { abs_s2_2 = diff_s2_2; };
    if (abs_s2_2 < 0.0001) {
        print("PASS: atan2_degrees(1,1) ~ 45.0", newLine=true);
    } else {
        print("FAIL: atan2_degrees(1,1)", newLine=true);
    };
    print(s2_2, newLine=true);

    var s2_3: float = atan2_degrees(1.0, -1.0);
    var diff_s2_3: float = s2_3 - 135.0;
    var abs_s2_3: float = 0.0;
    if (diff_s2_3 < 0.0) { abs_s2_3 = -diff_s2_3; } else { abs_s2_3 = diff_s2_3; };
    if (abs_s2_3 < 0.0001) {
        print("PASS: atan2_degrees(1,-1) ~ 135.0", newLine=true);
    } else {
        print("FAIL: atan2_degrees(1,-1)", newLine=true);
    };
    print(s2_3, newLine=true);

    var s2_4: float = atan2_degrees(-1.0, -1.0);
    var diff_s2_4: float = s2_4 - 225.0;
    var abs_s2_4: float = 0.0;
    if (diff_s2_4 < 0.0) { abs_s2_4 = -diff_s2_4; } else { abs_s2_4 = diff_s2_4; };
    if (abs_s2_4 < 0.0001) {
        print("PASS: atan2_degrees(-1,-1) ~ 225.0", newLine=true);
    } else {
        print("FAIL: atan2_degrees(-1,-1)", newLine=true);
    };
    print(s2_4, newLine=true);

    var s2_5: float = atan2_degrees(-1.0, 1.0);
    var diff_s2_5: float = s2_5 - 315.0;
    var abs_s2_5: float = 0.0;
    if (diff_s2_5 < 0.0) { abs_s2_5 = -diff_s2_5; } else { abs_s2_5 = diff_s2_5; };
    if (abs_s2_5 < 0.0001) {
        print("PASS: atan2_degrees(-1,1) ~ 315.0", newLine=true);
    } else {
        print("FAIL: atan2_degrees(-1,1)", newLine=true);
    };
    print(s2_5, newLine=true);

    // solve_kepler_equation(100.0, 0.205630) ~ 110.999249
    var s2_6: float = solve_kepler_equation(100.0, 0.205630);
    var diff_s2_6: float = s2_6 - 110.999249;
    var abs_s2_6: float = 0.0;
    if (diff_s2_6 < 0.0) { abs_s2_6 = -diff_s2_6; } else { abs_s2_6 = diff_s2_6; };
    if (abs_s2_6 < 0.0001) {
        print("PASS: solve_kepler_equation ~ 110.999249", newLine=true);
    } else {
        print("FAIL: solve_kepler_equation", newLine=true);
    };
    print(s2_6, newLine=true);

    // sun_ecliptic_longitude(-0.072183436) ~ 199.909873 (Meeus worked example)
    var s2_7: float = sun_ecliptic_longitude(-0.072183436);
    var diff_s2_7: float = s2_7 - 199.909873;
    var abs_s2_7: float = 0.0;
    if (diff_s2_7 < 0.0) { abs_s2_7 = -diff_s2_7; } else { abs_s2_7 = diff_s2_7; };
    if (abs_s2_7 < 0.001) {
        print("PASS: sun_ecliptic_longitude(Meeus example) ~ 199.909873", newLine=true);
    } else {
        print("FAIL: sun_ecliptic_longitude(Meeus example)", newLine=true);
    };
    print(s2_7, newLine=true);

    // sun_ecliptic_longitude(0.0) ~ 280.382159 (J2000.0)
    var s2_8: float = sun_ecliptic_longitude(0.0);
    var diff_s2_8: float = s2_8 - 280.382159;
    var abs_s2_8: float = 0.0;
    if (diff_s2_8 < 0.0) { abs_s2_8 = -diff_s2_8; } else { abs_s2_8 = diff_s2_8; };
    if (abs_s2_8 < 0.001) {
        print("PASS: sun_ecliptic_longitude(J2000.0) ~ 280.382159", newLine=true);
    } else {
        print("FAIL: sun_ecliptic_longitude(J2000.0)", newLine=true);
    };
    print(s2_8, newLine=true);

    // mercury_ecliptic_longitude(0.0) ~ 271.951928
    var s2_9: float = mercury_ecliptic_longitude(0.0);
    var diff_s2_9: float = s2_9 - 271.951928;
    var abs_s2_9: float = 0.0;
    if (diff_s2_9 < 0.0) { abs_s2_9 = -diff_s2_9; } else { abs_s2_9 = diff_s2_9; };
    if (abs_s2_9 < 0.001) {
        print("PASS: mercury_ecliptic_longitude(J2000.0) ~ 271.951928", newLine=true);
    } else {
        print("FAIL: mercury_ecliptic_longitude(J2000.0)", newLine=true);
    };
    print(s2_9, newLine=true);

    // venus_ecliptic_longitude(0.0) ~ 241.520522
    var s2_10: float = venus_ecliptic_longitude(0.0);
    var diff_s2_10: float = s2_10 - 241.520522;
    var abs_s2_10: float = 0.0;
    if (diff_s2_10 < 0.0) { abs_s2_10 = -diff_s2_10; } else { abs_s2_10 = diff_s2_10; };
    if (abs_s2_10 < 0.001) {
        print("PASS: venus_ecliptic_longitude(J2000.0) ~ 241.520522", newLine=true);
    } else {
        print("FAIL: venus_ecliptic_longitude(J2000.0)", newLine=true);
    };
    print(s2_10, newLine=true);

    // mars_ecliptic_longitude(0.0) ~ 327.965438
    var s2_11: float = mars_ecliptic_longitude(0.0);
    var diff_s2_11: float = s2_11 - 327.965438;
    var abs_s2_11: float = 0.0;
    if (diff_s2_11 < 0.0) { abs_s2_11 = -diff_s2_11; } else { abs_s2_11 = diff_s2_11; };
    if (abs_s2_11 < 0.001) {
        print("PASS: mars_ecliptic_longitude(J2000.0) ~ 327.965438", newLine=true);
    } else {
        print("FAIL: mars_ecliptic_longitude(J2000.0)", newLine=true);
    };
    print(s2_11, newLine=true);

    // jupiter_ecliptic_longitude(0.0) ~ 25.352661
    var s2_12: float = jupiter_ecliptic_longitude(0.0);
    var diff_s2_12: float = s2_12 - 25.352661;
    var abs_s2_12: float = 0.0;
    if (diff_s2_12 < 0.0) { abs_s2_12 = -diff_s2_12; } else { abs_s2_12 = diff_s2_12; };
    if (abs_s2_12 < 0.001) {
        print("PASS: jupiter_ecliptic_longitude(J2000.0) ~ 25.352661", newLine=true);
    } else {
        print("FAIL: jupiter_ecliptic_longitude(J2000.0)", newLine=true);
    };
    print(s2_12, newLine=true);

    // saturn_ecliptic_longitude(0.0) ~ 40.214144
    var s2_13: float = saturn_ecliptic_longitude(0.0);
    var diff_s2_13: float = s2_13 - 40.214144;
    var abs_s2_13: float = 0.0;
    if (diff_s2_13 < 0.0) { abs_s2_13 = -diff_s2_13; } else { abs_s2_13 = diff_s2_13; };
    if (abs_s2_13 < 0.001) {
        print("PASS: saturn_ecliptic_longitude(J2000.0) ~ 40.214144", newLine=true);
    } else {
        print("FAIL: saturn_ecliptic_longitude(J2000.0)", newLine=true);
    };
    print(s2_13, newLine=true);

    // uranus_ecliptic_longitude(0.0) ~ 315.668015
    var s2_14: float = uranus_ecliptic_longitude(0.0);
    var diff_s2_14: float = s2_14 - 315.668015;
    var abs_s2_14: float = 0.0;
    if (diff_s2_14 < 0.0) { abs_s2_14 = -diff_s2_14; } else { abs_s2_14 = diff_s2_14; };
    if (abs_s2_14 < 0.001) {
        print("PASS: uranus_ecliptic_longitude(J2000.0) ~ 315.668015", newLine=true);
    } else {
        print("FAIL: uranus_ecliptic_longitude(J2000.0)", newLine=true);
    };
    print(s2_14, newLine=true);

    // neptune_ecliptic_longitude(0.0) ~ 302.551133
    var s2_15: float = neptune_ecliptic_longitude(0.0);
    var diff_s2_15: float = s2_15 - 302.551133;
    var abs_s2_15: float = 0.0;
    if (diff_s2_15 < 0.0) { abs_s2_15 = -diff_s2_15; } else { abs_s2_15 = diff_s2_15; };
    if (abs_s2_15 < 0.001) {
        print("PASS: neptune_ecliptic_longitude(J2000.0) ~ 302.551133", newLine=true);
    } else {
        print("FAIL: neptune_ecliptic_longitude(J2000.0)", newLine=true);
    };
    print(s2_15, newLine=true);

    // pluto_ecliptic_longitude(0.0) ~ 250.186433
    var s2_16: float = pluto_ecliptic_longitude(0.0);
    var diff_s2_16: float = s2_16 - 250.186433;
    var abs_s2_16: float = 0.0;
    if (diff_s2_16 < 0.0) { abs_s2_16 = -diff_s2_16; } else { abs_s2_16 = diff_s2_16; };
    if (abs_s2_16 < 0.01) {
        print("PASS: pluto_ecliptic_longitude(J2000.0) ~ 250.186433", newLine=true);
    } else {
        print("FAIL: pluto_ecliptic_longitude(J2000.0)", newLine=true);
    };
    print(s2_16, newLine=true);

    // moon_ecliptic_longitude(0.0) ~ 223.281403
    var s2_17: float = moon_ecliptic_longitude(0.0);
    var diff_s2_17: float = s2_17 - 223.281403;
    var abs_s2_17: float = 0.0;
    if (diff_s2_17 < 0.0) { abs_s2_17 = -diff_s2_17; } else { abs_s2_17 = diff_s2_17; };
    if (abs_s2_17 < 0.001) {
        print("PASS: moon_ecliptic_longitude(J2000.0) ~ 223.281403", newLine=true);
    } else {
        print("FAIL: moon_ecliptic_longitude(J2000.0)", newLine=true);
    };
    print(s2_17, newLine=true);

    // moon_ecliptic_longitude(-0.077221081) ~ 133.248923 (Meeus example, truncated series)
    var s2_18: float = moon_ecliptic_longitude(-0.077221081);
    var diff_s2_18: float = s2_18 - 133.248923;
    var abs_s2_18: float = 0.0;
    if (diff_s2_18 < 0.0) { abs_s2_18 = -diff_s2_18; } else { abs_s2_18 = diff_s2_18; };
    if (abs_s2_18 < 0.001) {
        print("PASS: moon_ecliptic_longitude(Meeus example) ~ 133.248923", newLine=true);
    } else {
        print("FAIL: moon_ecliptic_longitude(Meeus example)", newLine=true);
    };
    print(s2_18, newLine=true);

    // rahu_longitude(0.0) ~ 125.044520
    var s2_19: float = rahu_longitude(0.0);
    var diff_s2_19: float = s2_19 - 125.044520;
    var abs_s2_19: float = 0.0;
    if (diff_s2_19 < 0.0) { abs_s2_19 = -diff_s2_19; } else { abs_s2_19 = diff_s2_19; };
    if (abs_s2_19 < 0.0001) {
        print("PASS: rahu_longitude(J2000.0) ~ 125.044520", newLine=true);
    } else {
        print("FAIL: rahu_longitude(J2000.0)", newLine=true);
    };
    print(s2_19, newLine=true);

    // ketu_longitude(125.044520) = 305.044520
    var s2_20: float = ketu_longitude(s2_19);
    var diff_s2_20: float = s2_20 - 305.044520;
    var abs_s2_20: float = 0.0;
    if (diff_s2_20 < 0.0) { abs_s2_20 = -diff_s2_20; } else { abs_s2_20 = diff_s2_20; };
    if (abs_s2_20 < 0.0001) {
        print("PASS: ketu_longitude ~ 305.044520", newLine=true);
    } else {
        print("FAIL: ketu_longitude", newLine=true);
    };
    print(s2_20, newLine=true);

    print("mocha-astro sections 1-2 tests done.", newLine=true);
};