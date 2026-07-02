from "mocha-chem" import *;

function main(didLoad) -> null {

    // ----- Section 9: Inorganic / Solid State -----

    // born_lande_lattice_energy: NaCl → -753365.6589 J/mol
    var s9_1: float = born_lande_lattice_energy(1.74756, 1.0, 1.0, 0.000000000282, 8.0);
    var diff_s9_1: float = s9_1 - (-753365.6589);
    var abs_s9_1: float = 0.0;
    if (diff_s9_1 < 0.0) { abs_s9_1 = -diff_s9_1; } else { abs_s9_1 = diff_s9_1; };
    if (abs_s9_1 < 1.0) {
    print("PASS: born_lande_lattice_energy ~ -753365.66", newLine=true);
    } else {
        print("FAIL: born_lande_lattice_energy", newLine=true);
    };
    print(s9_1, newLine=true);

    // born_haber_lattice_energy: NaCl → -787.0 kJ/mol
    var s9_2: float = born_haber_lattice_energy(-411.0, 108.0, 121.0, 496.0, -349.0);
    if (s9_2 == -787.0) {
        print("PASS: born_haber_lattice_energy == -787.0", newLine=true);
    } else {
        print("FAIL: born_haber_lattice_energy", newLine=true);
    };
    print(s9_2, newLine=true);

    // kapustinskii_lattice_energy: NaCl → 851.7935 kJ/mol
    var s9_3: float = kapustinskii_lattice_energy(2.0, 1.0, 1.0, 282.0);
    var diff_s9_3: float = s9_3 - 851.7935;
    var abs_s9_3: float = 0.0;
    if (diff_s9_3 < 0.0) { abs_s9_3 = -diff_s9_3; } else { abs_s9_3 = diff_s9_3; };
    if (abs_s9_3 < 0.001) {
        print("PASS: kapustinskii_lattice_energy ~ 851.7935", newLine=true);
    } else {
        print("FAIL: kapustinskii_lattice_energy", newLine=true);
    };
    print(s9_3, newLine=true);

    // crystal_field_stabilization_energy: d6 low spin → -48000 cm^-1
    var s9_4: float = crystal_field_stabilization_energy(6.0, 0.0, 20000.0);
    if (s9_4 == -48000.0) {
        print("PASS: crystal_field_stabilization_energy == -48000.0", newLine=true);
    } else {
        print("FAIL: crystal_field_stabilization_energy", newLine=true);
    };
    print(s9_4, newLine=true);

    // ionic_radius_ratio: Na+/Cl- → 0.524862
    var s9_5: float = ionic_radius_ratio(0.95, 1.81);
    var diff_s9_5: float = s9_5 - 0.524862;
    var abs_s9_5: float = 0.0;
    if (diff_s9_5 < 0.0) { abs_s9_5 = -diff_s9_5; } else { abs_s9_5 = diff_s9_5; };
    if (abs_s9_5 < 0.0001) {
        print("PASS: ionic_radius_ratio ~ 0.5249", newLine=true);
    } else {
        print("FAIL: ionic_radius_ratio", newLine=true);
    };
    print(s9_5, newLine=true);

    // pauling_ionic_character: delta_chi=2.23 → 71.154754 %
    var s9_6: float = pauling_ionic_character(2.23);
    var diff_s9_6: float = s9_6 - 71.154754;
    var abs_s9_6: float = 0.0;
    if (diff_s9_6 < 0.0) { abs_s9_6 = -diff_s9_6; } else { abs_s9_6 = diff_s9_6; };
    if (abs_s9_6 < 0.001) {
        print("PASS: pauling_ionic_character ~ 71.1548 %", newLine=true);
    } else {
        print("FAIL: pauling_ionic_character", newLine=true);
    };
    print(s9_6, newLine=true);

    // ----- Section 10: Organic-Adjacent Calculations -----

    // degree_of_unsaturation: C6H6 → 4.0
    var s10_1: float = degree_of_unsaturation(6.0, 6.0, 0.0);
    if (s10_1 == 4.0) {
        print("PASS: degree_of_unsaturation(C6H6) == 4.0", newLine=true);
    } else {
        print("FAIL: degree_of_unsaturation(C6H6)", newLine=true);
    };
    print(s10_1, newLine=true);

    // degree_of_unsaturation: glucose C6H12O6 → 1.0
    var s10_2: float = degree_of_unsaturation(6.0, 12.0, 0.0);
    if (s10_2 == 1.0) {
        print("PASS: degree_of_unsaturation(glucose) == 1.0", newLine=true);
    } else {
        print("FAIL: degree_of_unsaturation(glucose)", newLine=true);
    };
    print(s10_2, newLine=true);

    // molecular_formula_multiplier: glucose → 6.0
    var s10_3: float = molecular_formula_multiplier(180.156, 30.026);
    var diff_s10_3: float = s10_3 - 6.0;
    var abs_s10_3: float = 0.0;
    if (diff_s10_3 < 0.0) { abs_s10_3 = -diff_s10_3; } else { abs_s10_3 = diff_s10_3; };
    if (abs_s10_3 < 0.0001) {
        print("PASS: molecular_formula_multiplier ~ 6.0", newLine=true);
    } else {
        print("FAIL: molecular_formula_multiplier", newLine=true);
    };
    print(s10_3, newLine=true);

    // moles_from_combustion_co2: 17.6 g CO2 → 0.399909 mol
    var s10_4: float = moles_from_combustion_co2(17.6);
    var diff_s10_4: float = s10_4 - 0.399909;
    var abs_s10_4: float = 0.0;
    if (diff_s10_4 < 0.0) { abs_s10_4 = -diff_s10_4; } else { abs_s10_4 = diff_s10_4; };
    if (abs_s10_4 < 0.0001) {
        print("PASS: moles_from_combustion_co2 ~ 0.3999", newLine=true);
    } else {
        print("FAIL: moles_from_combustion_co2", newLine=true);
    };
    print(s10_4, newLine=true);

    // moles_from_combustion_h2o: 7.2 g H2O → 0.799334 mol
    var s10_5: float = moles_from_combustion_h2o(7.2);
    var diff_s10_5: float = s10_5 - 0.799334;
    var abs_s10_5: float = 0.0;
    if (diff_s10_5 < 0.0) { abs_s10_5 = -diff_s10_5; } else { abs_s10_5 = diff_s10_5; };
    if (abs_s10_5 < 0.0001) {
        print("PASS: moles_from_combustion_h2o ~ 0.7993", newLine=true);
    } else {
        print("FAIL: moles_from_combustion_h2o", newLine=true);
    };
    print(s10_5, newLine=true);

    // mass_oxygen_by_difference: 10g sample, 4.803308g C, 0.805729g H → 4.390963 g
    var s10_6: float = mass_oxygen_by_difference(10.0, 4.803308, 0.805729);
    var diff_s10_6: float = s10_6 - 4.390963;
    var abs_s10_6: float = 0.0;
    if (diff_s10_6 < 0.0) { abs_s10_6 = -diff_s10_6; } else { abs_s10_6 = diff_s10_6; };
    if (abs_s10_6 < 0.0001) {
        print("PASS: mass_oxygen_by_difference ~ 4.391", newLine=true);
    } else {
        print("FAIL: mass_oxygen_by_difference", newLine=true);
    };
    print(s10_6, newLine=true);

    // ----- Section 11: Spectroscopy -----

    // beer_lambert_absorbance: epsilon=15000, c=0.001, l=1 → 15.0
    var s11_1: float = beer_lambert_absorbance(15000.0, 0.001, 1.0);
    if (s11_1 == 15.0) {
        print("PASS: beer_lambert_absorbance == 15.0", newLine=true);
    } else {
        print("FAIL: beer_lambert_absorbance", newLine=true);
    };
    print(s11_1, newLine=true);

    // beer_lambert_concentration: A=0.5, epsilon=15000, l=1 → 0.00003333
    var s11_2: float = beer_lambert_concentration(0.5, 15000.0, 1.0);
    var diff_s11_2: float = s11_2 - 0.00003333;
    var abs_s11_2: float = 0.0;
    if (diff_s11_2 < 0.0) { abs_s11_2 = -diff_s11_2; } else { abs_s11_2 = diff_s11_2; };
    if (abs_s11_2 < 0.0000001) {
        print("PASS: beer_lambert_concentration ~ 3.333e-5", newLine=true);
    } else {
        print("FAIL: beer_lambert_concentration", newLine=true);
    };
    print(s11_2, newLine=true);

    // transmittance_from_absorbance: A=0.5 → 0.316228
    var s11_3: float = transmittance_from_absorbance(0.5);
    var diff_s11_3: float = s11_3 - 0.316228;
    var abs_s11_3: float = 0.0;
    if (diff_s11_3 < 0.0) { abs_s11_3 = -diff_s11_3; } else { abs_s11_3 = diff_s11_3; };
    if (abs_s11_3 < 0.0001) {
        print("PASS: transmittance_from_absorbance ~ 0.3162", newLine=true);
    } else {
        print("FAIL: transmittance_from_absorbance", newLine=true);
    };
    print(s11_3, newLine=true);

    // absorbance_from_transmittance: T=0.316 → 0.500313
    var s11_4: float = absorbance_from_transmittance(0.316);
    var diff_s11_4: float = s11_4 - 0.500313;
    var abs_s11_4: float = 0.0;
    if (diff_s11_4 < 0.0) { abs_s11_4 = -diff_s11_4; } else { abs_s11_4 = diff_s11_4; };
    if (abs_s11_4 < 0.0001) {
        print("PASS: absorbance_from_transmittance ~ 0.5003", newLine=true);
    } else {
        print("FAIL: absorbance_from_transmittance", newLine=true);
    };
    print(s11_4, newLine=true);

    // wavelength_to_frequency: 500nm → 5.995849e14 Hz
    var s11_5: float = wavelength_to_frequency(0.0000005);
    var diff_s11_5: float = s11_5 - 599584900000000.0;
    var abs_s11_5: float = 0.0;
    if (diff_s11_5 < 0.0) { abs_s11_5 = -diff_s11_5; } else { abs_s11_5 = diff_s11_5; };
    if (abs_s11_5 < 1000000000.0) {
        print("PASS: wavelength_to_frequency ~ 5.9958e14 Hz", newLine=true);
    } else {
        print("FAIL: wavelength_to_frequency", newLine=true);
    };
    print(s11_5, newLine=true);

    // frequency_to_wavelength: 6e14 Hz → 4.996541e-7 m
    var s11_6: float = frequency_to_wavelength(600000000000000.0);
    var diff_s11_6: float = s11_6 - 0.0000004996541;
    var abs_s11_6: float = 0.0;
    if (diff_s11_6 < 0.0) { abs_s11_6 = -diff_s11_6; } else { abs_s11_6 = diff_s11_6; };
    if (abs_s11_6 < 0.00000000001) {
        print("PASS: frequency_to_wavelength ~ 4.9965e-7 m", newLine=true);
    } else {
        print("FAIL: frequency_to_wavelength", newLine=true);
    };
    print(s11_6, newLine=true);

    // wavenumber_to_wavelength: 1500 cm^-1 → 6.66667e-4 cm
    var s11_7: float = wavenumber_to_wavelength(1500.0);
    var diff_s11_7: float = s11_7 - 0.000666667;
    var abs_s11_7: float = 0.0;
    if (diff_s11_7 < 0.0) { abs_s11_7 = -diff_s11_7; } else { abs_s11_7 = diff_s11_7; };
    if (abs_s11_7 < 0.000001) {
        print("PASS: wavenumber_to_wavelength ~ 6.6667e-4 cm", newLine=true);
    } else {
        print("FAIL: wavenumber_to_wavelength", newLine=true);
    };
    print(s11_7, newLine=true);

    // wavelength_to_wavenumber: 0.000667 cm → 1499.250375 cm^-1
    var s11_8: float = wavelength_to_wavenumber(0.000667);
    var diff_s11_8: float = s11_8 - 1499.250375;
    var abs_s11_8: float = 0.0;
    if (diff_s11_8 < 0.0) { abs_s11_8 = -diff_s11_8; } else { abs_s11_8 = diff_s11_8; };
    if (abs_s11_8 < 0.001) {
        print("PASS: wavelength_to_wavenumber ~ 1499.25", newLine=true);
    } else {
        print("FAIL: wavelength_to_wavenumber", newLine=true);
    };
    print(s11_8, newLine=true);

    // energy_per_mole_photons: 6e14 Hz → 239418.727139 J/mol
    var s11_9: float = energy_per_mole_photons(600000000000000.0);
    var diff_s11_9: float = s11_9 - 239418.727139;
    var abs_s11_9: float = 0.0;
    if (diff_s11_9 < 0.0) { abs_s11_9 = -diff_s11_9; } else { abs_s11_9 = diff_s11_9; };
    if (abs_s11_9 < 1.0) {
        print("PASS: energy_per_mole_photons ~ 239418.73", newLine=true);
    } else {
        print("FAIL: energy_per_mole_photons", newLine=true);
    };
    print(s11_9, newLine=true);

    print("mocha-chem sections 9-11 tests done.", newLine=true);
};