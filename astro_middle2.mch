from "mocha-astro" import *;

function main(didLoad) -> null {

    // ----- Section 3: House Systems -----

    // local_sidereal_time(2446895.5, 0.0) ~ 197.693195 (Meeus example 12.a, GMST)
    var s3_1: float = local_sidereal_time(2446895.5, 0.0);
    var diff_s3_1: float = s3_1 - 197.693195;
    var abs_s3_1: float = 0.0;
    if (diff_s3_1 < 0.0) { abs_s3_1 = -diff_s3_1; } else { abs_s3_1 = diff_s3_1; };
    if (abs_s3_1 < 0.001) {
        print("PASS: local_sidereal_time(Meeus GMST example) ~ 197.693195", newLine=true);
    } else {
        print("FAIL: local_sidereal_time", newLine=true);
    };
    print(s3_1, newLine=true);

    // midheaven_longitude(100.0, 23.4393) ~ 99.189513
    var s3_2: float = midheaven_longitude(100.0, 23.4393);
    var diff_s3_2: float = s3_2 - 99.189513;
    var abs_s3_2: float = 0.0;
    if (diff_s3_2 < 0.0) { abs_s3_2 = -diff_s3_2; } else { abs_s3_2 = diff_s3_2; };
    if (abs_s3_2 < 0.001) {
        print("PASS: midheaven_longitude ~ 99.189513", newLine=true);
    } else {
        print("FAIL: midheaven_longitude", newLine=true);
    };
    print(s3_2, newLine=true);

    // ascendant_longitude(100.0, 51.5, 23.4393) ~ 7.052496
    var s3_3: float = ascendant_longitude(100.0, 51.5, 23.4393);
    var diff_s3_3: float = s3_3 - 7.052496;
    var abs_s3_3: float = 0.0;
    if (diff_s3_3 < 0.0) { abs_s3_3 = -diff_s3_3; } else { abs_s3_3 = diff_s3_3; };
    if (abs_s3_3 < 0.001) {
        print("PASS: ascendant_longitude ~ 7.052496", newLine=true);
    } else {
        print("FAIL: ascendant_longitude", newLine=true);
    };
    print(s3_3, newLine=true);

    // opposite_point(7.052496) ~ 187.052496
    var s3_4: float = opposite_point(s3_3);
    var diff_s3_4: float = s3_4 - 187.052496;
    var abs_s3_4: float = 0.0;
    if (diff_s3_4 < 0.0) { abs_s3_4 = -diff_s3_4; } else { abs_s3_4 = diff_s3_4; };
    if (abs_s3_4 < 0.001) {
        print("PASS: opposite_point ~ 187.052496", newLine=true);
    } else {
        print("FAIL: opposite_point", newLine=true);
    };
    print(s3_4, newLine=true);

    // equal_house_cusp(7.052496, 5) ~ 127.052496
    var s3_5: float = equal_house_cusp(s3_3, 5);
    var diff_s3_5: float = s3_5 - 127.052496;
    var abs_s3_5: float = 0.0;
    if (diff_s3_5 < 0.0) { abs_s3_5 = -diff_s3_5; } else { abs_s3_5 = diff_s3_5; };
    if (abs_s3_5 < 0.001) {
        print("PASS: equal_house_cusp(house 5) ~ 127.052496", newLine=true);
    } else {
        print("FAIL: equal_house_cusp", newLine=true);
    };
    print(s3_5, newLine=true);

    // whole_sign_cusp(7.052496, 1) = 0.0 (Aries start)
    var s3_6: float = whole_sign_cusp(s3_3, 1);
    if (s3_6 == 0.0) {
        print("PASS: whole_sign_cusp(house 1) == 0.0", newLine=true);
    } else {
        print("FAIL: whole_sign_cusp(house 1)", newLine=true);
    };
    print(s3_6, newLine=true);

    // whole_sign_cusp(7.052496, 5) = 120.0
    var s3_7: float = whole_sign_cusp(s3_3, 5);
    if (s3_7 == 120.0) {
        print("PASS: whole_sign_cusp(house 5) == 120.0", newLine=true);
    } else {
        print("FAIL: whole_sign_cusp(house 5)", newLine=true);
    };
    print(s3_7, newLine=true);

    // semi_diurnal_arc(0.0, 51.5) = 90.0
    var s3_8: float = semi_diurnal_arc(0.0, 51.5);
    var diff_s3_8: float = s3_8 - 90.0;
    var abs_s3_8: float = 0.0;
    if (diff_s3_8 < 0.0) { abs_s3_8 = -diff_s3_8; } else { abs_s3_8 = diff_s3_8; };
    if (abs_s3_8 < 0.001) {
        print("PASS: semi_diurnal_arc(0 decl) ~ 90.0", newLine=true);
    } else {
        print("FAIL: semi_diurnal_arc(0 decl)", newLine=true);
    };
    print(s3_8, newLine=true);

    // semi_diurnal_arc(15.0, 51.5) ~ 109.685580
    var s3_9: float = semi_diurnal_arc(15.0, 51.5);
    var diff_s3_9: float = s3_9 - 109.685580;
    var abs_s3_9: float = 0.0;
    if (diff_s3_9 < 0.0) { abs_s3_9 = -diff_s3_9; } else { abs_s3_9 = diff_s3_9; };
    if (abs_s3_9 < 0.001) {
        print("PASS: semi_diurnal_arc(15 decl) ~ 109.685580", newLine=true);
    } else {
        print("FAIL: semi_diurnal_arc(15 decl)", newLine=true);
    };
    print(s3_9, newLine=true);

    // Full Placidus cusp set at RAMC=100.0, lat=51.5, obliquity=23.4393
    var s3_10: float = placidus_cusp_11(100.0, 51.5, 23.4393);
    var diff_s3_10: float = s3_10 - 62.6189;
    var abs_s3_10: float = 0.0;
    if (diff_s3_10 < 0.0) { abs_s3_10 = -diff_s3_10; } else { abs_s3_10 = diff_s3_10; };
    if (abs_s3_10 < 0.001) {
        print("PASS: placidus_cusp_11 ~ 62.6189", newLine=true);
    } else {
        print("FAIL: placidus_cusp_11", newLine=true);
    };
    print(s3_10, newLine=true);

    var s3_11: float = placidus_cusp_12(100.0, 51.5, 23.4393);
    var diff_s3_11: float = s3_11 - 31.7552;
    var abs_s3_11: float = 0.0;
    if (diff_s3_11 < 0.0) { abs_s3_11 = -diff_s3_11; } else { abs_s3_11 = diff_s3_11; };
    if (abs_s3_11 < 0.001) {
        print("PASS: placidus_cusp_12 ~ 31.7552", newLine=true);
    } else {
        print("FAIL: placidus_cusp_12", newLine=true);
    };
    print(s3_11, newLine=true);

    var s3_12: float = placidus_cusp_9(100.0, 51.5, 23.4393);
    var diff_s3_12: float = s3_12 - 134.7747;
    var abs_s3_12: float = 0.0;
    if (diff_s3_12 < 0.0) { abs_s3_12 = -diff_s3_12; } else { abs_s3_12 = diff_s3_12; };
    if (abs_s3_12 < 0.001) {
        print("PASS: placidus_cusp_9 ~ 134.7747", newLine=true);
    } else {
        print("FAIL: placidus_cusp_9", newLine=true);
    };
    print(s3_12, newLine=true);

    var s3_13: float = placidus_cusp_8(100.0, 51.5, 23.4393);
    var diff_s3_13: float = s3_13 - 164.0427;
    var abs_s3_13: float = 0.0;
    if (diff_s3_13 < 0.0) { abs_s3_13 = -diff_s3_13; } else { abs_s3_13 = diff_s3_13; };
    if (abs_s3_13 < 0.001) {
        print("PASS: placidus_cusp_8 ~ 164.0427", newLine=true);
    } else {
        print("FAIL: placidus_cusp_8", newLine=true);
    };
    print(s3_13, newLine=true);

    var s3_14: float = placidus_cusp_2(100.0, 51.5, 23.4393);
    var diff_s3_14: float = s3_14 - 344.0427;
    var abs_s3_14: float = 0.0;
    if (diff_s3_14 < 0.0) { abs_s3_14 = -diff_s3_14; } else { abs_s3_14 = diff_s3_14; };
    if (abs_s3_14 < 0.001) {
        print("PASS: placidus_cusp_2 ~ 344.0427", newLine=true);
    } else {
        print("FAIL: placidus_cusp_2", newLine=true);
    };
    print(s3_14, newLine=true);

    var s3_15: float = placidus_cusp_3(100.0, 51.5, 23.4393);
    var diff_s3_15: float = s3_15 - 314.7747;
    var abs_s3_15: float = 0.0;
    if (diff_s3_15 < 0.0) { abs_s3_15 = -diff_s3_15; } else { abs_s3_15 = diff_s3_15; };
    if (abs_s3_15 < 0.001) {
        print("PASS: placidus_cusp_3 ~ 314.7747", newLine=true);
    } else {
        print("FAIL: placidus_cusp_3", newLine=true);
    };
    print(s3_15, newLine=true);

    var s3_16: float = placidus_cusp_5(100.0, 51.5, 23.4393);
    var diff_s3_16: float = s3_16 - 242.6189;
    var abs_s3_16: float = 0.0;
    if (diff_s3_16 < 0.0) { abs_s3_16 = -diff_s3_16; } else { abs_s3_16 = diff_s3_16; };
    if (abs_s3_16 < 0.001) {
        print("PASS: placidus_cusp_5 ~ 242.6189", newLine=true);
    } else {
        print("FAIL: placidus_cusp_5", newLine=true);
    };
    print(s3_16, newLine=true);

    var s3_17: float = placidus_cusp_6(100.0, 51.5, 23.4393);
    var diff_s3_17: float = s3_17 - 211.7552;
    var abs_s3_17: float = 0.0;
    if (diff_s3_17 < 0.0) { abs_s3_17 = -diff_s3_17; } else { abs_s3_17 = diff_s3_17; };
    if (abs_s3_17 < 0.001) {
        print("PASS: placidus_cusp_6 ~ 211.7552", newLine=true);
    } else {
        print("FAIL: placidus_cusp_6", newLine=true);
    };
    print(s3_17, newLine=true);

    // ----- Section 4: Vedic Aspects & Planetary Relationships -----

    var s4_1: int = zodiac_sign_index(15.0);
    if (s4_1 == 0) { print("PASS: zodiac_sign_index(15.0) == 0", newLine=true); } else { print("FAIL: zodiac_sign_index(15.0)", newLine=true); };
    print(s4_1, newLine=true);

    var s4_2: int = zodiac_sign_index(95.0);
    if (s4_2 == 3) { print("PASS: zodiac_sign_index(95.0) == 3", newLine=true); } else { print("FAIL: zodiac_sign_index(95.0)", newLine=true); };
    print(s4_2, newLine=true);

    var s4_3: int = zodiac_sign_index(359.9);
    if (s4_3 == 11) { print("PASS: zodiac_sign_index(359.9) == 11", newLine=true); } else { print("FAIL: zodiac_sign_index(359.9)", newLine=true); };
    print(s4_3, newLine=true);

    var s4_4: int = house_position(0, 6);
    if (s4_4 == 7) { print("PASS: house_position(0,6) == 7", newLine=true); } else { print("FAIL: house_position(0,6)", newLine=true); };
    print(s4_4, newLine=true);

    var s4_5: int = house_position(0, 3);
    if (s4_5 == 4) { print("PASS: house_position(0,3) == 4", newLine=true); } else { print("FAIL: house_position(0,3)", newLine=true); };
    print(s4_5, newLine=true);

    var s4_6: int = house_position(0, 0);
    if (s4_6 == 1) { print("PASS: house_position(0,0) == 1", newLine=true); } else { print("FAIL: house_position(0,0)", newLine=true); };
    print(s4_6, newLine=true);

    var s4_7: int = house_position(9, 2);
    if (s4_7 == 6) { print("PASS: house_position(9,2) == 6 (negative-diff case)", newLine=true); } else { print("FAIL: house_position(9,2)", newLine=true); };
    print(s4_7, newLine=true);

    var s4_8: bool = has_seventh_aspect(7);
    if (s4_8 == true) { print("PASS: has_seventh_aspect(7) == true", newLine=true); } else { print("FAIL: has_seventh_aspect(7)", newLine=true); };

    var s4_9: bool = has_seventh_aspect(5);
    if (s4_9 == false) { print("PASS: has_seventh_aspect(5) == false", newLine=true); } else { print("FAIL: has_seventh_aspect(5)", newLine=true); };

    var s4_10: bool = has_mars_special_aspect(4);
    var s4_11: bool = has_mars_special_aspect(8);
    var s4_12: bool = has_mars_special_aspect(5);
    if (s4_10 == true && s4_11 == true && s4_12 == false) {
        print("PASS: has_mars_special_aspect(4,8 true / 5 false)", newLine=true);
    } else {
        print("FAIL: has_mars_special_aspect", newLine=true);
    };

    var s4_13: bool = has_jupiter_special_aspect(5);
    var s4_14: bool = has_jupiter_special_aspect(9);
    var s4_15: bool = has_jupiter_special_aspect(3);
    if (s4_13 == true && s4_14 == true && s4_15 == false) {
        print("PASS: has_jupiter_special_aspect(5,9 true / 3 false)", newLine=true);
    } else {
        print("FAIL: has_jupiter_special_aspect", newLine=true);
    };

    var s4_16: bool = has_saturn_special_aspect(3);
    var s4_17: bool = has_saturn_special_aspect(10);
    var s4_18: bool = has_saturn_special_aspect(1);
    if (s4_16 == true && s4_17 == true && s4_18 == false) {
        print("PASS: has_saturn_special_aspect(3,10 true / 1 false)", newLine=true);
    } else {
        print("FAIL: has_saturn_special_aspect", newLine=true);
    };

    var s4_19: bool = has_rahu_ketu_special_aspect(3);
    if (s4_19 == true) { print("PASS: has_rahu_ketu_special_aspect(3) == true", newLine=true); } else { print("FAIL: has_rahu_ketu_special_aspect", newLine=true); };

    var s4_20: float = angular_separation(10.0, 350.0);
    if (s4_20 == 20.0) { print("PASS: angular_separation(10,350) == 20.0", newLine=true); } else { print("FAIL: angular_separation(10,350)", newLine=true); };
    print(s4_20, newLine=true);

    var s4_21: float = angular_separation(100.0, 260.0);
    if (s4_21 == 160.0) { print("PASS: angular_separation(100,260) == 160.0", newLine=true); } else { print("FAIL: angular_separation(100,260)", newLine=true); };
    print(s4_21, newLine=true);

    var s4_22: bool = is_combust(100.0, 105.0, 8.0);
    if (s4_22 == true) { print("PASS: is_combust(sep=5, orb=8) == true", newLine=true); } else { print("FAIL: is_combust true case", newLine=true); };

    var s4_23: bool = is_combust(100.0, 120.0, 8.0);
    if (s4_23 == false) { print("PASS: is_combust(sep=20, orb=8) == false", newLine=true); } else { print("FAIL: is_combust false case", newLine=true); };

    print("mocha-astro sections 3-4 tests done.", newLine=true);
};