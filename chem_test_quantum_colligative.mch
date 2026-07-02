from "mocha-chem" import *;

function main(didLoad) -> null {

    // ----- Section 7: Quantum & Atomic Structure -----

    // bohr_energy: n=1 → -13.6 eV
    var s7_1: float = bohr_energy(1.0);
    if (s7_1 == -13.6) {
        print("PASS: bohr_energy(1) == -13.6 eV", newLine=true);
    } else {
        print("FAIL: bohr_energy(1)", newLine=true);
    };
    print(s7_1, newLine=true);

    // bohr_energy: n=2 → -3.4 eV
    var s7_2: float = bohr_energy(2.0);
    if (s7_2 == -3.4) {
        print("PASS: bohr_energy(2) == -3.4 eV", newLine=true);
    } else {
        print("FAIL: bohr_energy(2)", newLine=true);
    };
    print(s7_2, newLine=true);

    // bohr_radius_n: n=1 → 5.29177e-11 m
    var s7_3: float = bohr_radius_n(1.0);
    var diff_s7_3: float = s7_3 - 0.0000000000529177;
    var abs_s7_3: float = 0.0;
    if (diff_s7_3 < 0.0) { abs_s7_3 = -diff_s7_3; } else { abs_s7_3 = diff_s7_3; };
    if (abs_s7_3 < 0.000000000001) {
        print("PASS: bohr_radius_n(1) ~ 5.292e-11 m", newLine=true);
    } else {
        print("FAIL: bohr_radius_n(1)", newLine=true);
    };
    print(s7_3, newLine=true);

    // rydberg_wavelength: Lyman alpha n1=1, n2=2 → 1.21502e-7 m
    var s7_4: float = rydberg_wavelength(1.0, 2.0);
    var diff_s7_4: float = s7_4 - 0.000000121502;
    var abs_s7_4: float = 0.0;
    if (diff_s7_4 < 0.0) { abs_s7_4 = -diff_s7_4; } else { abs_s7_4 = diff_s7_4; };
    if (abs_s7_4 < 0.000000000001) {
        print("PASS: rydberg_wavelength(1,2) ~ 1.2150e-7 m", newLine=true);
    } else {
        print("FAIL: rydberg_wavelength(1,2)", newLine=true);
    };
    print(s7_4, newLine=true);

    // rydberg_wavelength: Balmer n1=2, n2=3 → 6.56112e-7 m
    var s7_5: float = rydberg_wavelength(2.0, 3.0);
    var diff_s7_5: float = s7_5 - 0.000000656112;
    var abs_s7_5: float = 0.0;
    if (diff_s7_5 < 0.0) { abs_s7_5 = -diff_s7_5; } else { abs_s7_5 = diff_s7_5; };
    if (abs_s7_5 < 0.000000000001) {
        print("PASS: rydberg_wavelength(2,3) ~ 6.5611e-7 m", newLine=true);
    } else {
        print("FAIL: rydberg_wavelength(2,3)", newLine=true);
    };
    print(s7_5, newLine=true);

    // de_broglie_wavelength: electron at 1e6 m/s → 7.2739e-10 m
    var s7_6: float = de_broglie_wavelength(0.000000000000000000000000000000910938, 1000000.0);
    var diff_s7_6: float = s7_6 - 0.000000000727389;
    var abs_s7_6: float = 0.0;
    if (diff_s7_6 < 0.0) { abs_s7_6 = -diff_s7_6; } else { abs_s7_6 = diff_s7_6; };
    if (abs_s7_6 < 0.000000000001) {
        print("PASS: de_broglie_wavelength ~ 7.274e-10 m", newLine=true);
    } else {
        print("FAIL: de_broglie_wavelength", newLine=true);
    };
    print(s7_6, newLine=true);

    // heisenberg_uncertainty_x: delta_p=1e-24 → 5.2729e-11 m
    var s7_7: float = heisenberg_uncertainty_x(0.000000000000000000000001);
    var diff_s7_7: float = s7_7 - 0.0000000000527286;
    var abs_s7_7: float = 0.0;
    if (diff_s7_7 < 0.0) { abs_s7_7 = -diff_s7_7; } else { abs_s7_7 = diff_s7_7; };
    if (abs_s7_7 < 0.000000000001) {
        print("PASS: heisenberg_uncertainty_x ~ 5.273e-11 m", newLine=true);
    } else {
        print("FAIL: heisenberg_uncertainty_x", newLine=true);
    };
    print(s7_7, newLine=true);

    // effective_nuclear_charge: Z=11, sigma=8.8 → 2.2
    var s7_8: float = effective_nuclear_charge(11.0, 8.8);
    var diff_s7_8: float = s7_8 - 2.2;
    var abs_s7_8: float = 0.0;
    if (diff_s7_8 < 0.0) { abs_s7_8 = -diff_s7_8; } else { abs_s7_8 = diff_s7_8; };
    if (abs_s7_8 < 0.0001) {
        print("PASS: effective_nuclear_charge ~ 2.2", newLine=true);
    } else {
        print("FAIL: effective_nuclear_charge", newLine=true);
    };
    print(s7_8, newLine=true);

    // ionization_energy: Z_eff=2.2, n=3 → 7.313778 eV
    var s7_9: float = ionization_energy(2.2, 3.0);
    var diff_s7_9: float = s7_9 - 7.313778;
    var abs_s7_9: float = 0.0;
    if (diff_s7_9 < 0.0) { abs_s7_9 = -diff_s7_9; } else { abs_s7_9 = diff_s7_9; };
    if (abs_s7_9 < 0.0001) {
        print("PASS: ionization_energy ~ 7.3138 eV", newLine=true);
    } else {
        print("FAIL: ionization_energy", newLine=true);
    };
    print(s7_9, newLine=true);

    // ----- Section 8: Solutions & Colligative Properties -----

    // boiling_point_elevation: Kb=0.512, m=1.0, i=1.0 → 0.512
    var s8_1: float = boiling_point_elevation(0.512, 1.0, 1.0);
    if (s8_1 == 0.512) {
        print("PASS: boiling_point_elevation == 0.512", newLine=true);
    } else {
        print("FAIL: boiling_point_elevation", newLine=true);
    };
    print(s8_1, newLine=true);

    // freezing_point_depression: Kf=1.86, m=1.0, i=1.0 → 1.86
    var s8_2: float = freezing_point_depression(1.86, 1.0, 1.0);
    if (s8_2 == 1.86) {
        print("PASS: freezing_point_depression == 1.86", newLine=true);
    } else {
        print("FAIL: freezing_point_depression", newLine=true);
    };
    print(s8_2, newLine=true);

    // osmotic_pressure: M=0.1, T=298, i=1.0 → 2.445299 atm
    var s8_3: float = osmotic_pressure(0.1, 298.0, 1.0);
    var diff_s8_3: float = s8_3 - 2.445299;
    var abs_s8_3: float = 0.0;
    if (diff_s8_3 < 0.0) { abs_s8_3 = -diff_s8_3; } else { abs_s8_3 = diff_s8_3; };
    if (abs_s8_3 < 0.0001) {
        print("PASS: osmotic_pressure ~ 2.4453 atm", newLine=true);
    } else {
        print("FAIL: osmotic_pressure", newLine=true);
    };
    print(s8_3, newLine=true);

    // raoult_law_ideal: x=0.9, P_pure=23.8 → 21.42
    var s8_4: float = raoult_law_ideal(0.9, 23.8);
    var diff_s8_4: float = s8_4 - 21.42;
    var abs_s8_4: float = 0.0;
    if (diff_s8_4 < 0.0) { abs_s8_4 = -diff_s8_4; } else { abs_s8_4 = diff_s8_4; };
    if (abs_s8_4 < 0.0001) {
        print("PASS: raoult_law_ideal ~ 21.42", newLine=true);
    } else {
        print("FAIL: raoult_law_ideal", newLine=true);
    };
    print(s8_4, newLine=true);

    // raoult_law_pressure_lowering: x=0.1, P_pure=23.8 → 2.38
    var s8_5: float = raoult_law_pressure_lowering(0.1, 23.8);
    var diff_s8_5: float = s8_5 - 2.38;
    var abs_s8_5: float = 0.0;
    if (diff_s8_5 < 0.0) { abs_s8_5 = -diff_s8_5; } else { abs_s8_5 = diff_s8_5; };
    if (abs_s8_5 < 0.0001) {
        print("PASS: raoult_law_pressure_lowering ~ 2.38", newLine=true);
    } else {
        print("FAIL: raoult_law_pressure_lowering", newLine=true);
    };
    print(s8_5, newLine=true);

    // henry_law: k_H=0.034, P=1.0 → 0.034
    var s8_6: float = henry_law(0.034, 1.0);
    if (s8_6 == 0.034) {
        print("PASS: henry_law == 0.034", newLine=true);
    } else {
        print("FAIL: henry_law", newLine=true);
    };
    print(s8_6, newLine=true);

    // molarity_to_molality: M=1.0, rho=1050, molar_mass=180 → 1.149425
    var s8_7: float = molarity_to_molality(1.0, 1050.0, 180.0);
    var diff_s8_7: float = s8_7 - 1.149425;
    var abs_s8_7: float = 0.0;
    if (diff_s8_7 < 0.0) { abs_s8_7 = -diff_s8_7; } else { abs_s8_7 = diff_s8_7; };
    if (abs_s8_7 < 0.0001) {
        print("PASS: molarity_to_molality ~ 1.149425", newLine=true);
    } else {
        print("FAIL: molarity_to_molality", newLine=true);
    };
    print(s8_7, newLine=true);

    // mole_fraction_to_molality: x_sol=0.1, x_solv=0.9, M_solv=0.018 → 6.172840
    var s8_8: float = mole_fraction_to_molality(0.1, 0.9, 0.018);
    var diff_s8_8: float = s8_8 - 6.172840;
    var abs_s8_8: float = 0.0;
    if (diff_s8_8 < 0.0) { abs_s8_8 = -diff_s8_8; } else { abs_s8_8 = diff_s8_8; };
    if (abs_s8_8 < 0.0001) {
        print("PASS: mole_fraction_to_molality ~ 6.1728", newLine=true);
    } else {
        print("FAIL: mole_fraction_to_molality", newLine=true);
    };
    print(s8_8, newLine=true);

    // van_t_hoff_factor_apparent: delta_T=3.5, Kf=1.86, m=1.0 → 1.881720
    var s8_9: float = van_t_hoff_factor_apparent(3.5, 1.86, 1.0);
    var diff_s8_9: float = s8_9 - 1.881720;
    var abs_s8_9: float = 0.0;
    if (diff_s8_9 < 0.0) { abs_s8_9 = -diff_s8_9; } else { abs_s8_9 = diff_s8_9; };
    if (abs_s8_9 < 0.0001) {
        print("PASS: van_t_hoff_factor_apparent ~ 1.8817", newLine=true);
    } else {
        print("FAIL: van_t_hoff_factor_apparent", newLine=true);
    };
    print(s8_9, newLine=true);

    // degree_of_dissociation_vant: i=1.8, n=2 → 0.8
    var s8_10: float = degree_of_dissociation_vant(1.8, 2.0);
    if (s8_10 == 0.8) {
        print("PASS: degree_of_dissociation_vant == 0.8", newLine=true);
    } else {
        print("FAIL: degree_of_dissociation_vant", newLine=true);
    };
    print(s8_10, newLine=true);

    print("mocha-chem sections 7-8 tests done.", newLine=true);
};