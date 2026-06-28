from "mocha-chem" import *;

function main(didLoad) -> null {

    // ----- Section 1: Stoichiometry & Real Gases -----

    var r1: float = moles_from_mass(18.015, 18.015);
    if (r1 == 1.0) {
        print("PASS: moles_from_mass(18.015, 18.015) == 1.0", newLine=true);
    } else {
        print("FAIL: moles_from_mass(18.015, 18.015)", newLine=true);
    };
    print(r1, newLine=true);

    var r2: float = mass_from_moles(2.0, 18.015);
    if (r2 == 36.03) {
        print("PASS: mass_from_moles(2.0, 18.015) == 36.03", newLine=true);
    } else {
        print("FAIL: mass_from_moles(2.0, 18.015)", newLine=true);
    };
    print(r2, newLine=true);

    var r3: float = stoich_moles(6.0, 3.0, 2.0);
    var diff3: float = r3 - 4.0;
    var abs3: float = 0.0;
    if (diff3 < 0.0) {
        abs3 = -diff3;
    } else {
        abs3 = diff3;
    };
    if (abs3 < 0.0001) {
        print("PASS: stoich_moles ~ 4.0", newLine=true);
    } else {
        print("FAIL: stoich_moles", newLine=true);
    };
    print(r3, newLine=true);

    var r4: float = percent_yield(8.5, 10.0);
    if (r4 == 85.0) {
        print("PASS: percent_yield(8.5, 10.0) == 85.0", newLine=true);
    } else {
        print("FAIL: percent_yield(8.5, 10.0)", newLine=true);
    };
    print(r4, newLine=true);

    var r5: float = molarity(0.5, 0.25);
    if (r5 == 2.0) {
        print("PASS: molarity(0.5, 0.25) == 2.0", newLine=true);
    } else {
        print("FAIL: molarity(0.5, 0.25)", newLine=true);
    };
    print(r5, newLine=true);

    var r6: float = dilution_final_volume(2.0, 0.5, 0.1);
    if (r6 == 10.0) {
        print("PASS: dilution_final_volume(2.0, 0.5, 0.1) == 10.0", newLine=true);
    } else {
        print("FAIL: dilution_final_volume(2.0, 0.5, 0.1)", newLine=true);
    };
    print(r6, newLine=true);

    // van der Waals pressure: CO2, n=1, T=300K, V=1L — expected: 22.074330
    var r7: float = van_der_waals_pressure(1.0, 300.0, 1.0, 3.640, 0.04267);
    var diff7: float = r7 - 22.074330;
    var abs7: float = 0.0;
    if (diff7 < 0.0) {
        abs7 = -diff7;
    } else {
        abs7 = diff7;
    };
    if (abs7 < 0.0001) {
        print("PASS: van_der_waals_pressure ~ 22.0743", newLine=true);
    } else {
        print("FAIL: van_der_waals_pressure", newLine=true);
    };
    print(r7, newLine=true);

    // van der Waals molar volume: CO2, 10 atm, 300K — expected: 2.352455
    var r8: float = van_der_waals_molar_volume(10.0, 300.0, 3.640, 0.04267);
    var diff8: float = r8 - 2.352455;
    var abs8: float = 0.0;
    if (diff8 < 0.0) {
        abs8 = -diff8;
    } else {
        abs8 = diff8;
    };
    if (abs8 < 0.0001) {
        print("PASS: van_der_waals_molar_volume ~ 2.3525", newLine=true);
    } else {
        print("FAIL: van_der_waals_molar_volume", newLine=true);
    };
    print(r8, newLine=true);

    // graham effusion: H2 vs O2 — expected: 3.984095
    var r9: float = graham_effusion_ratio(2.016, 32.0);
    var diff9: float = r9 - 3.984095;
    var abs9: float = 0.0;
    if (diff9 < 0.0) {
        abs9 = -diff9;
    } else {
        abs9 = diff9;
    };
    if (abs9 < 0.0001) {
        print("PASS: graham_effusion_ratio ~ 3.9841", newLine=true);
    } else {
        print("FAIL: graham_effusion_ratio", newLine=true);
    };
    print(r9, newLine=true);

    // ----- Section 2: Thermodynamics -----

    var t1: float = heat_q(100.0, 4.184, 10.0);
    if (t1 == 4184.0) {
        print("PASS: heat_q(100, 4.184, 10) == 4184.0", newLine=true);
    } else {
        print("FAIL: heat_q(100, 4.184, 10)", newLine=true);
    };
    print(t1, newLine=true);

    var t2: float = gibbs_free_energy(-285830.0, 298.0, -163.3);
    var diff_t2: float = t2 - (-237166.6);
    var abs_t2: float = 0.0;
    if (diff_t2 < 0.0) {
        abs_t2 = -diff_t2;
    } else {
        abs_t2 = diff_t2;
    };
    if (abs_t2 < 0.1) {
        print("PASS: gibbs_free_energy ~ -237166.6", newLine=true);
    } else {
        print("FAIL: gibbs_free_energy", newLine=true);
    };
    print(t2, newLine=true);

    // gibbs_from_keq: T=298, K=1e10 — expected: -57048.2035
    var t3: float = gibbs_from_keq(298.0, 10000000000.0);
    var diff_t3: float = t3 - (-57048.2035);
    var abs_t3: float = 0.0;
    if (diff_t3 < 0.0) {
        abs_t3 = -diff_t3;
    } else {
        abs_t3 = diff_t3;
    };
    if (abs_t3 < 0.01) {
        print("PASS: gibbs_from_keq ~ -57048.20", newLine=true);
    } else {
        print("FAIL: gibbs_from_keq", newLine=true);
    };
    print(t3, newLine=true);

    // keq_from_gibbs: dg=-57100, T=298 — expected: ~10211262012.31
    var t4: float = keq_from_gibbs(-57100.0, 298.0);
    var diff_t4: float = t4 - 10211262012.31;
    var abs_t4: float = 0.0;
    if (diff_t4 < 0.0) {
        abs_t4 = -diff_t4;
    } else {
        abs_t4 = diff_t4;
    };
    if (abs_t4 < 1000.0) {
        print("PASS: keq_from_gibbs ~ 1.021e10", newLine=true);
    } else {
        print("FAIL: keq_from_gibbs", newLine=true);
    };
    print(t4, newLine=true);

    // clausius_clapeyron_p2: P1=1atm, T1=373K, T2=353K, dHvap=40700 — expected: 0.475406
    var t5: float = clausius_clapeyron_p2(1.0, 373.0, 353.0, 40700.0);
    var diff_t5: float = t5 - 0.475406;
    var abs_t5: float = 0.0;
    if (diff_t5 < 0.0) {
        abs_t5 = -diff_t5;
    } else {
        abs_t5 = diff_t5;
    };
    if (abs_t5 < 0.0001) {
        print("PASS: clausius_clapeyron_p2 ~ 0.4754", newLine=true);
    } else {
        print("FAIL: clausius_clapeyron_p2", newLine=true);
    };
    print(t5, newLine=true);

    // clausius_clapeyron_t2: P1=1atm, P2=0.5atm, T1=373K, dHvap=40700 — expected: 354.2886
    var t6: float = clausius_clapeyron_t2(1.0, 0.5, 373.0, 40700.0);
    var diff_t6: float = t6 - 354.2886;
    var abs_t6: float = 0.0;
    if (diff_t6 < 0.0) {
        abs_t6 = -diff_t6;
    } else {
        abs_t6 = diff_t6;
    };
    if (abs_t6 < 0.001) {
        print("PASS: clausius_clapeyron_t2 ~ 354.2886", newLine=true);
    } else {
        print("FAIL: clausius_clapeyron_t2", newLine=true);
    };
    print(t6, newLine=true);

    var t7: float = kirchhoff_enthalpy(-285830.0, -42.0, 298.0, 373.0);
    if (t7 == -288980.0) {
        print("PASS: kirchhoff_enthalpy == -288980.0", newLine=true);
    } else {
        print("FAIL: kirchhoff_enthalpy", newLine=true);
    };
    print(t7, newLine=true);

    var t8: float = gibbs_equilibrium_temp(44000.0, 119.0);
    var diff_t8: float = t8 - 369.7479;
    var abs_t8: float = 0.0;
    if (diff_t8 < 0.0) {
        abs_t8 = -diff_t8;
    } else {
        abs_t8 = diff_t8;
    };
    if (abs_t8 < 0.001) {
        print("PASS: gibbs_equilibrium_temp ~ 369.7479 K", newLine=true);
    } else {
        print("FAIL: gibbs_equilibrium_temp", newLine=true);
    };
    print(t8, newLine=true);

    print("mocha-chem sections 1-2 tests done.", newLine=true);
};