""" mocha-chem: Section 1 — Stoichiometry & Real Gases
~~ Mole/mass conversions, concentration units, yield,
~~ effusion, and real gas behavior via van der Waals.
~~ Ideal gas law excluded by design; PV = nRT does not model reality. """

// mocha-lib-deps: mocha-math

function c_exp(x: float) -> float native mocha_wrap_exp;
const R_GAS: float = 0.082057;

// moles_from_mass: grams to moles given molar mass (g/mol)
function moles_from_mass(mass_g: float, molar_mass: float) -> float {
    return mass_g / molar_mass;
};

// mass_from_moles: moles to grams given molar mass (g/mol)
function mass_from_moles(moles: float, molar_mass: float) -> float {
    return moles * molar_mass;
};

// stoich_moles: scale moles through a stoichiometric ratio
// e.g. 6 mol H2 (coeff 3) to NH3 (coeff 2) = 4 mol
function stoich_moles(moles_given: float, coeff_given: float, coeff_wanted: float) -> float {
    return moles_given * (coeff_wanted / coeff_given);
};

// percent_yield: actual yield as percentage of theoretical yield (%)
function percent_yield(actual_g: float, theoretical_g: float) -> float {
    return (actual_g / theoretical_g) * 100.0;
};

// percent_composition: mass fraction of an element in a compound (%)
// mass_element_g: mass of that element per mole of compound
function percent_composition(mass_element_g: float, molar_mass_compound: float) -> float {
    return (mass_element_g / molar_mass_compound) * 100.0;
};

// molarity: moles of solute per litre of solution (mol/L)
function molarity(moles_solute: float, volume_l: float) -> float {
    return moles_solute / volume_l;
};

// molality: moles of solute per kilogram of solvent (mol/kg)
function molality(moles_solute: float, mass_solvent_kg: float) -> float {
    return moles_solute / mass_solvent_kg;
};

// mole_fraction: component moles / total moles (dimensionless, 0-1)
function mole_fraction(moles_component: float, total_moles: float) -> float {
    return moles_component / total_moles;
};

// ppm_by_mass: parts per million by mass (mg solute / kg solution)
function ppm_by_mass(mass_solute_g: float, mass_solution_g: float) -> float {
    return (mass_solute_g / mass_solution_g) * 1000000.0;
};

// ppb_by_mass: parts per billion by mass (ug solute / kg solution)
function ppb_by_mass(mass_solute_g: float, mass_solution_g: float) -> float {
    return (mass_solute_g / mass_solution_g) * 1000000000.0;
};

// dilution_final_volume: find V2 from M1V1 = M2V2 (same units throughout)
function dilution_final_volume(c1: float, v1: float, c2: float) -> float {
    return (c1 * v1) / c2;
};

// van_der_waals_pressure: pressure of a real gas (atm)
// n: moles | t_k: temperature (K) | v_l: volume (L)
// a: attraction constant (atm.L2/mol2) | b: excluded volume (L/mol)
// P = nRT/(V - nb) - a(n/V)^2
function van_der_waals_pressure(n: float, t_k: float, v_l: float, a: float, b: float) -> float {
    const V_EXCL: float = v_l - (n * b);
    const PRESSURE_TERM: float = (n * R_GAS * t_k) / V_EXCL;
    const N_OVER_V: float = n / v_l;
    const ATTRACTION: float = a * (N_OVER_V * N_OVER_V);
    return PRESSURE_TERM - ATTRACTION;
};

// van_der_waals_molar_volume: molar volume (L/mol) of a real gas
// p: pressure (atm) | t_k: temperature (K) | a (atm.L2/mol2) | b (L/mol)
// solves cubic P.Vm3 - (Pb+RT).Vm2 + a.Vm - ab = 0
// via Newton-Raphson from ideal-gas initial guess
// valid for gas-phase conditions above critical temperature
function van_der_waals_molar_volume(p: float, t_k: float, a: float, b: float) -> float {
    const RT: float = R_GAS * t_k;
    var vm: float = RT / p;
    var i: int = 0;
    while (i < 50) {
        const VM2: float = vm * vm;
        const VM3: float = VM2 * vm;
        const F: float = (p * VM3) - ((p * b + RT) * VM2) + (a * vm) - (a * b);
        const DF: float = (3.0 * p * VM2) - (2.0 * (p * b + RT) * vm) + a;
        vm = vm - (F / DF);
        i++;
    };
    return vm;
};

// dalton_partial_pressure: partial pressure of a gas component
// p_i = mole_frac * p_total
function dalton_partial_pressure(mole_frac: float, p_total: float) -> float {
    return mole_frac * p_total;
};

// graham_effusion_ratio: relative effusion rate of gas 1 vs gas 2
// rate1/rate2 = sqrt(m2/m1) | m in g/mol
function graham_effusion_ratio(m1: float, m2: float) -> float {
    const RATIO: float = m2 / m1;
    return RATIO.sqrt().real;
};

// ─── Section 2: Thermodynamics ────────────────────────────────────────────

const R_THERMO: float = 8.314;

// heat_q: heat transferred via specific heat capacity (J)
// q = m * c * delta_t | mass in g, c in J/(g·K), delta_t in K
function heat_q(mass_g: float, specific_heat: float, delta_t: float) -> float {
    return mass_g * specific_heat * delta_t;
};

// heat_constant_pressure: heat at constant pressure (J)
// q = n * cp * delta_t | n in mol, cp in J/(mol·K)
function heat_constant_pressure(n_moles: float, molar_cp: float, delta_t: float) -> float {
    return n_moles * molar_cp * delta_t;
};

// enthalpy_rxn: standard enthalpy of reaction from formation enthalpies (kJ/mol)
// delta_h_rxn = sum_hf_products - sum_hf_reactants (pre-weighted by stoich coeffs)
function enthalpy_rxn(sum_hf_products: float, sum_hf_reactants: float) -> float {
    return sum_hf_products - sum_hf_reactants;
};

// entropy_rxn: standard entropy of reaction (J/(mol·K))
// delta_s_rxn = sum_s_products - sum_s_reactants (pre-weighted by stoich coeffs)
function entropy_rxn(sum_s_products: float, sum_s_reactants: float) -> float {
    return sum_s_products - sum_s_reactants;
};

// gibbs_free_energy: Gibbs free energy change (J/mol)
// delta_g = delta_h - t_k * delta_s | delta_h in J/mol, delta_s in J/(mol·K)
function gibbs_free_energy(delta_h: float, t_k: float, delta_s: float) -> float {
    return delta_h - (t_k * delta_s);
};

// gibbs_from_keq: standard Gibbs free energy from equilibrium constant (J/mol)
// delta_g_std = -RT ln(K)
function gibbs_from_keq(t_k: float, keq: float) -> float {
    return -(R_THERMO * t_k) * keq.log().real;
};

// keq_from_gibbs: equilibrium constant from standard Gibbs free energy
// K = exp(-delta_g_std / RT)
function keq_from_gibbs(delta_g_std: float, t_k: float) -> float {
    return float(c_exp(-(delta_g_std) / (R_THERMO * t_k)));
};

// clausius_clapeyron_p2: vapour pressure at t2_k given known p1 at t1_k (same units as p1)
// ln(P2/P1) = -(delta_h_vap/R) * (1/T2 - 1/T1) | delta_h_vap in J/mol
function clausius_clapeyron_p2(p1: float, t1_k: float, t2_k: float, delta_h_vap: float) -> float {
    const EXPONENT: float = -(delta_h_vap / R_THERMO) * ((1.0 / t2_k) - (1.0 / t1_k));
    return p1 * float(c_exp(EXPONENT));
};

// clausius_clapeyron_t2: temperature at p2 given known p1 at t1_k (K)
// 1/T2 = 1/T1 - (R/delta_h_vap) * ln(P2/P1)
function clausius_clapeyron_t2(p1: float, p2: float, t1_k: float, delta_h_vap: float) -> float {
    const LN_RATIO: float = (p2 / p1).log().real;
    const INV_T2: float = (1.0 / t1_k) - ((R_THERMO / delta_h_vap) * LN_RATIO);
    return 1.0 / INV_T2;
};

// bond_enthalpy_rxn: enthalpy of reaction from bond energies (kJ/mol)
// delta_h = bonds_broken - bonds_formed (pre-summed totals)
function bond_enthalpy_rxn(bonds_broken: float, bonds_formed: float) -> float {
    return bonds_broken - bonds_formed;
};

// kirchhoff_enthalpy: enthalpy at t2_k corrected for heat capacity (J/mol)
// delta_h(T2) = delta_h(T1) + delta_cp * (T2 - T1)
function kirchhoff_enthalpy(delta_h_t1: float, delta_cp: float, t1_k: float, t2_k: float) -> float {
    return delta_h_t1 + (delta_cp * (t2_k - t1_k));
};

// entropy_surroundings: entropy change of surroundings (J/K)
// delta_s_surr = -delta_h_sys / T
function entropy_surroundings(delta_h_sys: float, t_k: float) -> float {
    return -(delta_h_sys) / t_k;
};

// entropy_universe: total entropy change, positive = spontaneous (J/K)
// delta_s_univ = delta_s_sys + delta_s_surr
function entropy_universe(delta_s_sys: float, delta_s_surr: float) -> float {
    return delta_s_sys + delta_s_surr;
};

// gibbs_equilibrium_temp: temperature at which delta_g = 0 (K)
// T = delta_h / delta_s | delta_h in J/mol, delta_s in J/(mol·K)
function gibbs_equilibrium_temp(delta_h: float, delta_s: float) -> float {
    return delta_h / delta_s;
};

// ─── Section 3: Chemical Kinetics ─────────────────────────────────────────

// conc_zero_order: concentration at time t for zero-order reaction (mol/L)
// [A]t = [A]0 - k*t | k in mol/(L·s), t in s
function conc_zero_order(conc_init: float, k: float, t: float) -> float {
    return conc_init - (k * t);
};

// conc_first_order: concentration at time t for first-order reaction (mol/L)
// [A]t = [A]0 * exp(-k*t) | k in s⁻¹
function conc_first_order(conc_init: float, k: float, t: float) -> float {
    return conc_init * float(c_exp(-(k * t)));
};

// conc_second_order: concentration at time t for second-order reaction (mol/L)
// [A]t = 1 / (1/[A]0 + k*t) | k in L/(mol·s)
function conc_second_order(conc_init: float, k: float, t: float) -> float {
    return 1.0 / ((1.0 / conc_init) + (k * t));
};

// half_life_zero_order: half-life for zero-order reaction (s)
// t½ = [A]0 / (2k)
function half_life_zero_order(conc_init: float, k: float) -> float {
    return conc_init / (2.0 * k);
};

// half_life_first_order: half-life for first-order reaction (s)
// t½ = ln(2) / k | k in s⁻¹
function half_life_first_order(k: float) -> float {
    const LN2: float = 2.0.log().real;
    return LN2 / k;
};

// half_life_second_order: half-life for second-order reaction (s)
// t½ = 1 / (k * [A]0)
function half_life_second_order(conc_init: float, k: float) -> float {
    return 1.0 / (k * conc_init);
};

// arrhenius_k: rate constant from Arrhenius equation
// k = A * exp(-Ea / RT) | ea in J/mol, t_k in K
function arrhenius_k(a_factor: float, ea: float, t_k: float) -> float {
    return a_factor * float(c_exp(-(ea / (R_THERMO * t_k))));
};

// activation_energy_two_point: Ea from two rate constants at two temperatures (J/mol)
// Ea = -R * ln(k2/k1) / (1/T2 - 1/T1)
function activation_energy_two_point(k1: float, k2: float, t1_k: float, t2_k: float) -> float {
    const LN_RATIO: float = (k2 / k1).log().real;
    const INV_DIFF: float = (1.0 / t2_k) - (1.0 / t1_k);
    return -(R_THERMO * LN_RATIO) / INV_DIFF;
};

// rate_law: reaction rate from concentrations and orders
// rate = k * [A]^order_a * [B]^order_b
function rate_law(k: float, conc_a: float, order_a: float, conc_b: float, order_b: float) -> float {
    return k * c_pow(conc_a, order_a) * c_pow(conc_b, order_b);
};

// time_to_conc_first_order: time to reach conc_final from conc_init (s)
// t = ln([A]0 / [A]t) / k
function time_to_conc_first_order(conc_init: float, conc_final: float, k: float) -> float {
    return (conc_init / conc_final).log().real / k;
};

// time_to_conc_second_order: time to reach conc_final from conc_init (s)
// t = (1/[A]t - 1/[A]0) / k
function time_to_conc_second_order(conc_init: float, conc_final: float, k: float) -> float {
    return ((1.0 / conc_final) - (1.0 / conc_init)) / k;
};

// arrhenius_ratio: ratio k2/k1 at two temperatures given activation energy
// k2/k1 = exp(-Ea/R * (1/T2 - 1/T1))
function arrhenius_ratio(ea: float, t1_k: float, t2_k: float) -> float {
    const EXPONENT: float = -(ea / R_THERMO) * ((1.0 / t2_k) - (1.0 / t1_k));
    return float(c_exp(EXPONENT));
};

// ─── Section 4: Equilibrium & Acid-Base ───────────────────────────────────

// kc_from_kp: equilibrium constant in concentration from pressure form
// Kc = Kp / (RT)^delta_n | delta_n = moles gas products - moles gas reactants
function kc_from_kp(kp: float, t_k: float, delta_n: float) -> float {
    const RT: float = R_GAS * t_k;
    return kp / c_pow(RT, delta_n);
};

// kp_from_kc: equilibrium constant in pressure from concentration form
// Kp = Kc * (RT)^delta_n
function kp_from_kc(kc: float, t_k: float, delta_n: float) -> float {
    const RT: float = R_GAS * t_k;
    return kc * c_pow(RT, delta_n);
};

// reaction_quotient: Q = conc_products / conc_reactants (pre-powered and multiplied)
// compare to Keq: Q < K forward, Q > K reverse, Q == K at equilibrium
function reaction_quotient(conc_products: float, conc_reactants: float) -> float {
    return conc_products / conc_reactants;
};

// ksp_from_concentrations: solubility product from ion concentrations (pre-powered)
// Ksp = [A]^m * [B]^n — pass in already-raised values, just multiplies
function ksp_from_concentrations(ion_a: float, ion_b: float) -> float {
    return ion_a * ion_b;
};

// solubility_from_ksp_1_1: molar solubility for 1:1 salt AB → A+ + B- (mol/L)
// s = sqrt(Ksp)
function solubility_from_ksp_1_1(ksp: float) -> float {
    return ksp.sqrt().real;
};

// common_ion_solubility: molar solubility of AB in solution already containing B- (mol/L)
// Ksp = s*(s + c_ion) → s = (-c_ion + sqrt(c_ion^2 + 4*Ksp)) / 2
function common_ion_solubility(ksp: float, c_ion: float) -> float {
    const DISCRIMINANT: float = (c_ion * c_ion) + (4.0 * ksp);
    return (-(c_ion) + DISCRIMINANT.sqrt().real) / 2.0;
};

// ph_from_h_conc: pH = -log10([H+])
function ph_from_h_conc(h_conc: float) -> float {
    const LOG10_H: float = h_conc.log10().real;
    return -(LOG10_H);
};

// h_conc_from_ph: [H+] = 10^(-pH) (mol/L)
function h_conc_from_ph(ph: float) -> float {
    return float(c_pow(10.0, -(ph)));
};

// poh_from_oh_conc: pOH = -log10([OH-])
function poh_from_oh_conc(oh_conc: float) -> float {
    const LOG10_OH: float = oh_conc.log10().real;
    return -(LOG10_OH);
};

// ph_from_poh: pH = 14 - pOH (valid at 25°C)
function ph_from_poh(poh: float) -> float {
    return 14.0 - poh;
};

// henderson_hasselbalch: pH of a buffer solution
// pH = pKa + log10([A-]/[HA])
function henderson_hasselbalch(pka: float, conc_base: float, conc_acid: float) -> float {
    const LOG_RATIO: float = (conc_base / conc_acid).log10().real;
    return pka + LOG_RATIO;
};

// ph_weak_acid: approximate pH of weak acid solution
// [H+] = sqrt(Ka * Ca) → pH = -log10([H+])
function ph_weak_acid(ka: float, conc_acid: float) -> float {
    const H_CONC: float = (ka * conc_acid).sqrt().real;
    return -(H_CONC.log10().real);
};

// ph_weak_base: approximate pH of weak base solution
// [OH-] = sqrt(Kb * Cb) → pOH → pH = 14 - pOH
function ph_weak_base(kb: float, conc_base: float) -> float {
    const OH_CONC: float = (kb * conc_base).sqrt().real;
    const POH: float = -(OH_CONC.log10().real);
    return 14.0 - POH;
};

// buffer_capacity: resistance of buffer to pH change (mol/(L·pH))
// beta = 2.303 * C * Ka*[H+] / (Ka + [H+])^2
function buffer_capacity(total_conc: float, ka: float, ph: float) -> float {
    const H: float = float(c_pow(10.0, -(ph)));
    const NUMER: float = ka * H;
    const DENOM: float = (ka + H) * (ka + H);
    return 2.303 * total_conc * (NUMER / DENOM);
};

// degree_of_dissociation: fraction of weak acid dissociated (approx, alpha << 1)
// alpha = sqrt(Ka / Ca)
function degree_of_dissociation(ka: float, conc_acid: float) -> float {
    return (ka / conc_acid).sqrt().real;
};

// pka_from_ka: pKa = -log10(Ka)
function pka_from_ka(ka: float) -> float {
    return -(ka.log10().real);
};