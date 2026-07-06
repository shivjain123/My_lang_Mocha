from "mocha-astro" import *;

function main(didLoad) -> null {

    // ----- Section 5: Vimshottari Dasha System -----

    var s5_1: float = dasha_years(DashaLord.KETU);
    if (s5_1 == 7.0) { print("PASS: dasha_years(KETU) == 7.0", newLine=true); } else { print("FAIL: dasha_years(KETU)", newLine=true); };
    print(s5_1, newLine=true);

    var s5_2: float = dasha_years(DashaLord.VENUS);
    if (s5_2 == 20.0) { print("PASS: dasha_years(VENUS) == 20.0", newLine=true); } else { print("FAIL: dasha_years(VENUS)", newLine=true); };
    print(s5_2, newLine=true);

    var s5_3: int = index_from_dasha_lord(DashaLord.MOON);
    if (s5_3 == 3) { print("PASS: index_from_dasha_lord(MOON) == 3", newLine=true); } else { print("FAIL: index_from_dasha_lord(MOON)", newLine=true); };
    print(s5_3, newLine=true);

    var s5_4: DashaLord = dasha_lord_from_index(3);
    if (s5_4 == DashaLord.MOON) { print("PASS: dasha_lord_from_index(3) == MOON", newLine=true); } else { print("FAIL: dasha_lord_from_index(3)", newLine=true); };

    var s5_5: DashaLord = next_dasha_lord(DashaLord.MOON);
    if (s5_5 == DashaLord.MARS) { print("PASS: next_dasha_lord(MOON) == MARS", newLine=true); } else { print("FAIL: next_dasha_lord(MOON)", newLine=true); };

    // wraparound check: Mercury (last, idx8) -> should wrap to Ketu (idx0)
    var s5_6: DashaLord = next_dasha_lord(DashaLord.MERCURY);
    if (s5_6 == DashaLord.KETU) { print("PASS: next_dasha_lord(MERCURY) wraps to KETU", newLine=true); } else { print("FAIL: next_dasha_lord(MERCURY) wraparound", newLine=true); };

    // nakshatra_index(123.45) = 9
    var s5_7: int = nakshatra_index(123.45);
    if (s5_7 == 9) { print("PASS: nakshatra_index(123.45) == 9", newLine=true); } else { print("FAIL: nakshatra_index(123.45)", newLine=true); };
    print(s5_7, newLine=true);

    // dasha_lord_at_birth(123.45) -> KETU (nak_idx 9 % 9 = 0 -> KETU)
    var s5_8: DashaLord = dasha_lord_at_birth(123.45);
    if (s5_8 == DashaLord.KETU) { print("PASS: dasha_lord_at_birth(123.45) == KETU", newLine=true); } else { print("FAIL: dasha_lord_at_birth(123.45)", newLine=true); };

    // dasha_balance_years(123.45) ~ 5.188750
    var s5_9: float = dasha_balance_years(123.45);
    var diff_s5_9: float = s5_9 - 5.188750;
    var abs_s5_9: float = 0.0;
    if (diff_s5_9 < 0.0) { abs_s5_9 = -diff_s5_9; } else { abs_s5_9 = diff_s5_9; };
    if (abs_s5_9 < 0.001) {
        print("PASS: dasha_balance_years(123.45) ~ 5.188750", newLine=true);
    } else {
        print("FAIL: dasha_balance_years(123.45)", newLine=true);
    };
    print(s5_9, newLine=true);

    // antardasha_duration(MARS, 10.0) ~ 0.583333
    var s5_10: float = antardasha_duration(DashaLord.MARS, 10.0);
    var diff_s5_10: float = s5_10 - 0.583333;
    var abs_s5_10: float = 0.0;
    if (diff_s5_10 < 0.0) { abs_s5_10 = -diff_s5_10; } else { abs_s5_10 = diff_s5_10; };
    if (abs_s5_10 < 0.001) {
        print("PASS: antardasha_duration(MARS, 10yr) ~ 0.583333", newLine=true);
    } else {
        print("FAIL: antardasha_duration(MARS, 10yr)", newLine=true);
    };
    print(s5_10, newLine=true);

    // antardasha_duration(VENUS, 10.0) ~ 1.666667
    var s5_11: float = antardasha_duration(DashaLord.VENUS, 10.0);
    var diff_s5_11: float = s5_11 - 1.666667;
    var abs_s5_11: float = 0.0;
    if (diff_s5_11 < 0.0) { abs_s5_11 = -diff_s5_11; } else { abs_s5_11 = diff_s5_11; };
    if (abs_s5_11 < 0.001) {
        print("PASS: antardasha_duration(VENUS, 10yr) ~ 1.666667", newLine=true);
    } else {
        print("FAIL: antardasha_duration(VENUS, 10yr)", newLine=true);
    };
    print(s5_11, newLine=true);

    // ----- Section 6: Divisional Charts (Varga) D1-D16 -----

    // Test longitude 249.5 deg (Sagittarius, sign_index=8, dual)
    var sign_idx: int = zodiac_sign_index(249.5);
    if (sign_idx == 8) { print("PASS: sign_idx(249.5) == 8 (Sagittarius)", newLine=true); } else { print("FAIL: sign_idx(249.5)", newLine=true); };

    var s6_1: int = sign_modality(8);
    if (s6_1 == 2) { print("PASS: sign_modality(Sagittarius) == 2 (dual)", newLine=true); } else { print("FAIL: sign_modality(8)", newLine=true); };
    print(s6_1, newLine=true);

    var s6_2: bool = is_odd_sign(0);
    if (s6_2 == true) { print("PASS: is_odd_sign(Aries) == true", newLine=true); } else { print("FAIL: is_odd_sign(0)", newLine=true); };

    var s6_3: bool = is_odd_sign(1);
    if (s6_3 == false) { print("PASS: is_odd_sign(Taurus) == false", newLine=true); } else { print("FAIL: is_odd_sign(1)", newLine=true); };

    // Cross-checks against known classical facts
    var s6_4: int = navamsa_sign_d9(0, 0);
    if (s6_4 == 0) { print("PASS: navamsa_sign_d9(Aries,0) == Aries (movable starts from itself)", newLine=true); } else { print("FAIL: navamsa_sign_d9(0,0)", newLine=true); };
    print(s6_4, newLine=true);

    var s6_5: int = navamsa_sign_d9(1, 0);
    if (s6_5 == 9) { print("PASS: navamsa_sign_d9(Taurus,0) == Capricorn (fixed starts from 9th)", newLine=true); } else { print("FAIL: navamsa_sign_d9(1,0)", newLine=true); };
    print(s6_5, newLine=true);

    var s6_6: int = navamsa_sign_d9(2, 0);
    if (s6_6 == 6) { print("PASS: navamsa_sign_d9(Gemini,0) == Libra (dual starts from 5th)", newLine=true); } else { print("FAIL: navamsa_sign_d9(2,0)", newLine=true); };
    print(s6_6, newLine=true);

    var s6_7: int = drekkana_sign_d3(0, 1);
    if (s6_7 == 4) { print("PASS: drekkana_sign_d3(Aries,part1) == Leo", newLine=true); } else { print("FAIL: drekkana_sign_d3(0,1)", newLine=true); };
    print(s6_7, newLine=true);

    var s6_8: int = drekkana_sign_d3(0, 2);
    if (s6_8 == 8) { print("PASS: drekkana_sign_d3(Aries,part2) == Sagittarius", newLine=true); } else { print("FAIL: drekkana_sign_d3(0,2)", newLine=true); };
    print(s6_8, newLine=true);

    var s6_9: int = chaturthamsa_sign_d4(0, 2);
    if (s6_9 == 6) { print("PASS: chaturthamsa_sign_d4(Aries,part2) == Libra", newLine=true); } else { print("FAIL: chaturthamsa_sign_d4(0,2)", newLine=true); };
    print(s6_9, newLine=true);

    var s6_10: int = saptamsa_sign_d7(1, 0);
    if (s6_10 == 7) { print("PASS: saptamsa_sign_d7(Taurus,0) == Scorpio (even starts 7th)", newLine=true); } else { print("FAIL: saptamsa_sign_d7(1,0)", newLine=true); };
    print(s6_10, newLine=true);

    var s6_11: int = dasamsa_sign_d10(1, 0);
    if (s6_11 == 9) { print("PASS: dasamsa_sign_d10(Taurus,0) == Capricorn (even starts 9th)", newLine=true); } else { print("FAIL: dasamsa_sign_d10(1,0)", newLine=true); };
    print(s6_11, newLine=true);

    var s6_12: int = shodasamsa_sign_d16(1, 0);
    if (s6_12 == 4) { print("PASS: shodasamsa_sign_d16(Taurus/fixed,0) == Leo", newLine=true); } else { print("FAIL: shodasamsa_sign_d16(1,0)", newLine=true); };
    print(s6_12, newLine=true);

    var s6_13: int = hora_sign_d2(0, 0);
    var s6_14: int = hora_sign_d2(0, 1);
    if (s6_13 == 4 && s6_14 == 3) { print("PASS: hora_sign_d2(Aries) -> Leo, Cancer", newLine=true); } else { print("FAIL: hora_sign_d2(Aries)", newLine=true); };

    var s6_15: int = hora_sign_d2(1, 0);
    var s6_16: int = hora_sign_d2(1, 1);
    if (s6_15 == 3 && s6_16 == 4) { print("PASS: hora_sign_d2(Taurus) -> Cancer, Leo", newLine=true); } else { print("FAIL: hora_sign_d2(Taurus)", newLine=true); };

    // Full worked example at longitude 249.5 (Sagittarius)
    var p_d9: int = varga_part_index(249.5, 9);
    if (p_d9 == 2) { print("PASS: varga_part_index(249.5, D9) == 2", newLine=true); } else { print("FAIL: varga_part_index D9", newLine=true); };
    print(p_d9, newLine=true);

    var s6_17: int = navamsa_sign_d9(8, p_d9);
    if (s6_17 == 2) { print("PASS: navamsa_sign_d9(249.5 full pipeline) == Gemini", newLine=true); } else { print("FAIL: navamsa_sign_d9(249.5 full pipeline)", newLine=true); };
    print(s6_17, newLine=true);

    var s6_18: int = dwadasamsa_sign_d12(8, 3);
    if (s6_18 == 11) { print("PASS: dwadasamsa_sign_d12(Sagittarius,part3) == Pisces", newLine=true); } else { print("FAIL: dwadasamsa_sign_d12(8,3)", newLine=true); };
    print(s6_18, newLine=true);

    print("mocha-astro sections 5-6 tests done.", newLine=true);
};