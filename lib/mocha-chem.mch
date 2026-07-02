~~ mocha-chem: Section 1 — Stoichiometry & Real Gases
~~ Mole/mass conversions, concentration units, yield,
~~ effusion, and real gas behavior via van der Waals.
~~ Ideal gas law excluded by design; PV = nRT does not model reality.

// mocha-lib-deps: mocha-math

function c_exp(x: float) -> float native mocha_wrap_exp;
function unsafe_mul(a: float, b: float) -> float native mocha_unsafe_mul;
function unsafe_div(a: float, b: float) -> float native mocha_unsafe_div;
const R_GAS: float = 0.082057;

~~ moles_from_mass: grams to moles given molar mass (g/mol)
function moles_from_mass(mass_g: float, molar_mass: float) -> float {
    return mass_g / molar_mass;
};

~~ mass_from_moles: moles to grams given molar mass (g/mol)
function mass_from_moles(moles: float, molar_mass: float) -> float {
    return moles * molar_mass;
};

~~ stoich_moles: scale moles through a stoichiometric ratio
~~ e.g. 6 mol H2 (coeff 3) to NH3 (coeff 2) = 4 mol
function stoich_moles(moles_given: float, coeff_given: float, coeff_wanted: float) -> float {
    return moles_given * (coeff_wanted / coeff_given);
};

~~ percent_yield: actual yield as percentage of theoretical yield (%)
function percent_yield(actual_g: float, theoretical_g: float) -> float {
    return (actual_g / theoretical_g) * 100.0;
};

~~ percent_composition: mass fraction of an element in a compound (%)
~~ mass_element_g: mass of that element per mole of compound
function percent_composition(mass_element_g: float, molar_mass_compound: float) -> float {
    return (mass_element_g / molar_mass_compound) * 100.0;
};

~~ molarity: moles of solute per litre of solution (mol/L)
function molarity(moles_solute: float, volume_l: float) -> float {
    return moles_solute / volume_l;
};

~~ molality: moles of solute per kilogram of solvent (mol/kg)
function molality(moles_solute: float, mass_solvent_kg: float) -> float {
    return moles_solute / mass_solvent_kg;
};

~~ mole_fraction: component moles / total moles (dimensionless, 0-1)
function mole_fraction(moles_component: float, total_moles: float) -> float {
    return moles_component / total_moles;
};

~~ ppm_by_mass: parts per million by mass (mg solute / kg solution)
function ppm_by_mass(mass_solute_g: float, mass_solution_g: float) -> float {
    return (mass_solute_g / mass_solution_g) * 1000000.0;
};

~~ ppb_by_mass: parts per billion by mass (ug solute / kg solution)
function ppb_by_mass(mass_solute_g: float, mass_solution_g: float) -> float {
    return (mass_solute_g / mass_solution_g) * 1000000000.0;
};

~~ dilution_final_volume: find V2 from M1V1 = M2V2 (same units throughout)
function dilution_final_volume(c1: float, v1: float, c2: float) -> float {
    return (c1 * v1) / c2;
};

~~ van_der_waals_pressure: pressure of a real gas (atm)
~~ n: moles | t_k: temperature (K) | v_l: volume (L)
~~ a: attraction constant (atm.L2/mol2) | b: excluded volume (L/mol)
~~ P = nRT/(V - nb) - a(n/V)^2
function van_der_waals_pressure(n: float, t_k: float, v_l: float, a: float, b: float) -> float {
    const V_EXCL: float = v_l - (n * b);
    const PRESSURE_TERM: float = (n * R_GAS * t_k) / V_EXCL;
    const N_OVER_V: float = n / v_l;
    const ATTRACTION: float = a * (N_OVER_V * N_OVER_V);
    return PRESSURE_TERM - ATTRACTION;
};

~~ van_der_waals_molar_volume: molar volume (L/mol) of a real gas
~~ p: pressure (atm) | t_k: temperature (K) | a (atm.L2/mol2) | b (L/mol)
~~ solves cubic P.Vm3 - (Pb+RT).Vm2 + a.Vm - ab = 0
~~ via Newton-Raphson from ideal-gas initial guess
~~ valid for gas-phase conditions above critical temperature
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

~~ dalton_partial_pressure: partial pressure of a gas component
~~ p_i = mole_frac * p_total
function dalton_partial_pressure(mole_frac: float, p_total: float) -> float {
    return mole_frac * p_total;
};

~~ graham_effusion_ratio: relative effusion rate of gas 1 vs gas 2
~~ rate1/rate2 = sqrt(m2/m1) | m in g/mol
function graham_effusion_ratio(m1: float, m2: float) -> float {
    const RATIO: float = m2 / m1;
    return RATIO.sqrt().real;
};

~~ ─── Section 2: Thermodynamics ────────────────────────────────────────────

const R_THERMO: float = 8.314;

~~ heat_q: heat transferred via specific heat capacity (J)
~~ q = m * c * delta_t | mass in g, c in J/(g·K), delta_t in K
function heat_q(mass_g: float, specific_heat: float, delta_t: float) -> float {
    return mass_g * specific_heat * delta_t;
};

~~ heat_constant_pressure: heat at constant pressure (J)
~~ q = n * cp * delta_t | n in mol, cp in J/(mol·K)
function heat_constant_pressure(n_moles: float, molar_cp: float, delta_t: float) -> float {
    return n_moles * molar_cp * delta_t;
};

~~ enthalpy_rxn: standard enthalpy of reaction from formation enthalpies (kJ/mol)
~~ delta_h_rxn = sum_hf_products - sum_hf_reactants (pre-weighted by stoich coeffs)
function enthalpy_rxn(sum_hf_products: float, sum_hf_reactants: float) -> float {
    return sum_hf_products - sum_hf_reactants;
};

~~ entropy_rxn: standard entropy of reaction (J/(mol·K))
~~ delta_s_rxn = sum_s_products - sum_s_reactants (pre-weighted by stoich coeffs)
function entropy_rxn(sum_s_products: float, sum_s_reactants: float) -> float {
    return sum_s_products - sum_s_reactants;
};

~~ gibbs_free_energy: Gibbs free energy change (J/mol)
~~ delta_g = delta_h - t_k * delta_s | delta_h in J/mol, delta_s in J/(mol·K)
function gibbs_free_energy(delta_h: float, t_k: float, delta_s: float) -> float {
    return delta_h - (t_k * delta_s);
};

~~ gibbs_from_keq: standard Gibbs free energy from equilibrium constant (J/mol)
~~ delta_g_std = -RT ln(K)
function gibbs_from_keq(t_k: float, keq: float) -> float {
    const LN_K: float = keq.log().real;
    return -(R_THERMO * t_k) * LN_K;
};

~~ keq_from_gibbs: equilibrium constant from standard Gibbs free energy
~~ K = exp(-delta_g_std / RT)
function keq_from_gibbs(delta_g_std: float, t_k: float) -> float {
    return float(c_exp(-(delta_g_std) / (R_THERMO * t_k)));
};

~~ clausius_clapeyron_p2: vapour pressure at t2_k given known p1 at t1_k (same units as p1)
~~ ln(P2/P1) = -(delta_h_vap/R) * (1/T2 - 1/T1) | delta_h_vap in J/mol
function clausius_clapeyron_p2(p1: float, t1_k: float, t2_k: float, delta_h_vap: float) -> float {
    const EXPONENT: float = -(delta_h_vap / R_THERMO) * ((1.0 / t2_k) - (1.0 / t1_k));
    return p1 * float(c_exp(EXPONENT));
};

~~ clausius_clapeyron_t2: temperature at p2 given known p1 at t1_k (K)
~~ 1/T2 = 1/T1 - (R/delta_h_vap) * ln(P2/P1)
function clausius_clapeyron_t2(p1: float, p2: float, t1_k: float, delta_h_vap: float) -> float {
    const LN_RATIO: float = (p2 / p1).log().real;
    const INV_T2: float = (1.0 / t1_k) - ((R_THERMO / delta_h_vap) * LN_RATIO);
    return 1.0 / INV_T2;
};

~~ bond_enthalpy_rxn: enthalpy of reaction from bond energies (kJ/mol)
~~ delta_h = bonds_broken - bonds_formed (pre-summed totals)
function bond_enthalpy_rxn(bonds_broken: float, bonds_formed: float) -> float {
    return bonds_broken - bonds_formed;
};

~~ kirchhoff_enthalpy: enthalpy at t2_k corrected for heat capacity (J/mol)
~~ delta_h(T2) = delta_h(T1) + delta_cp * (T2 - T1)
function kirchhoff_enthalpy(delta_h_t1: float, delta_cp: float, t1_k: float, t2_k: float) -> float {
    return delta_h_t1 + (delta_cp * (t2_k - t1_k));
};

~~ entropy_surroundings: entropy change of surroundings (J/K)
~~ delta_s_surr = -delta_h_sys / T
function entropy_surroundings(delta_h_sys: float, t_k: float) -> float {
    return -(delta_h_sys) / t_k;
};

~~ entropy_universe: total entropy change, positive = spontaneous (J/K)
~~ delta_s_univ = delta_s_sys + delta_s_surr
function entropy_universe(delta_s_sys: float, delta_s_surr: float) -> float {
    return delta_s_sys + delta_s_surr;
};

~~ gibbs_equilibrium_temp: temperature at which delta_g = 0 (K)
~~ T = delta_h / delta_s | delta_h in J/mol, delta_s in J/(mol·K)
function gibbs_equilibrium_temp(delta_h: float, delta_s: float) -> float {
    return delta_h / delta_s;
};

~~ ─── Section 3: Chemical Kinetics ─────────────────────────────────────────

~~ conc_zero_order: concentration at time t for zero-order reaction (mol/L)
~~ [A]t = [A]0 - k*t | k in mol/(L·s), t in s
function conc_zero_order(conc_init: float, k: float, t: float) -> float {
    return conc_init - (k * t);
};

~~ conc_first_order: concentration at time t for first-order reaction (mol/L)
~~ [A]t = [A]0 * exp(-k*t) | k in s⁻¹
function conc_first_order(conc_init: float, k: float, t: float) -> float {
    return conc_init * float(c_exp(-(k * t)));
};

~~ conc_second_order: concentration at time t for second-order reaction (mol/L)
~~ [A]t = 1 / (1/[A]0 + k*t) | k in L/(mol·s)
function conc_second_order(conc_init: float, k: float, t: float) -> float {
    return 1.0 / ((1.0 / conc_init) + (k * t));
};

~~ half_life_zero_order: half-life for zero-order reaction (s)
~~ t½ = [A]0 / (2k)
function half_life_zero_order(conc_init: float, k: float) -> float {
    return conc_init / (2.0 * k);
};

~~ half_life_first_order: half-life for first-order reaction (s)
~~ t½ = ln(2) / k | k in s⁻¹
function half_life_first_order(k: float) -> float {
    const LN2: float = 2.0.log().real;
    return LN2 / k;
};

~~ half_life_second_order: half-life for second-order reaction (s)
~~ t½ = 1 / (k * [A]0)
function half_life_second_order(conc_init: float, k: float) -> float {
    return 1.0 / (k * conc_init);
};

~~ arrhenius_k: rate constant from Arrhenius equation
~~ k = A * exp(-Ea / RT) | ea in J/mol, t_k in K
function arrhenius_k(a_factor: float, ea: float, t_k: float) -> float {
    return a_factor * float(c_exp(-(ea / (R_THERMO * t_k))));
};

~~ activation_energy_two_point: Ea from two rate constants at two temperatures (J/mol)
~~ Ea = -R * ln(k2/k1) / (1/T2 - 1/T1)
function activation_energy_two_point(k1: float, k2: float, t1_k: float, t2_k: float) -> float {
    const LN_RATIO: float = (k2 / k1).log().real;
    const INV_DIFF: float = (1.0 / t2_k) - (1.0 / t1_k);
    return -(R_THERMO * LN_RATIO) / INV_DIFF;
};

~~ rate_law: reaction rate from concentrations and orders
~~ rate = k * [A]^order_a * [B]^order_b
function rate_law(k: float, conc_a: float, order_a: float, conc_b: float, order_b: float) -> float {
    return k * c_pow(conc_a, order_a) * c_pow(conc_b, order_b);
};

~~ time_to_conc_first_order: time to reach conc_final from conc_init (s)
~~ t = ln([A]0 / [A]t) / k
function time_to_conc_first_order(conc_init: float, conc_final: float, k: float) -> float {
    return (conc_init / conc_final).log().real / k;
};

~~ time_to_conc_second_order: time to reach conc_final from conc_init (s)
~~ t = (1/[A]t - 1/[A]0) / k
function time_to_conc_second_order(conc_init: float, conc_final: float, k: float) -> float {
    return ((1.0 / conc_final) - (1.0 / conc_init)) / k;
};

~~ arrhenius_ratio: ratio k2/k1 at two temperatures given activation energy
~~ k2/k1 = exp(-Ea/R * (1/T2 - 1/T1))
function arrhenius_ratio(ea: float, t1_k: float, t2_k: float) -> float {
    const EXPONENT: float = -(ea / R_THERMO) * ((1.0 / t2_k) - (1.0 / t1_k));
    return float(c_exp(EXPONENT));
};

~~ ─── Section 4: Equilibrium & Acid-Base ───────────────────────────────────

~~ kc_from_kp: equilibrium constant in concentration from pressure form
~~ Kc = Kp / (RT)^delta_n | delta_n = moles gas products - moles gas reactants
function kc_from_kp(kp: float, t_k: float, delta_n: float) -> float {
    const RT: float = R_GAS * t_k;
    return kp / c_pow(RT, delta_n);
};

~~ kp_from_kc: equilibrium constant in pressure from concentration form
~~ Kp = Kc * (RT)^delta_n
function kp_from_kc(kc: float, t_k: float, delta_n: float) -> float {
    const RT: float = R_GAS * t_k;
    return kc * c_pow(RT, delta_n);
};

~~ reaction_quotient: Q = conc_products / conc_reactants (pre-powered and multiplied)
~~ compare to Keq: Q < K forward, Q > K reverse, Q == K at equilibrium
function reaction_quotient(conc_products: float, conc_reactants: float) -> float {
    return conc_products / conc_reactants;
};

~~ ksp_from_concentrations: solubility product from ion concentrations (pre-powered)
~~ Ksp = [A]^m * [B]^n — pass in already-raised values, just multiplies
function ksp_from_concentrations(ion_a: float, ion_b: float) -> float {
    return ion_a * ion_b;
};

~~ solubility_from_ksp_1_1: molar solubility for 1:1 salt AB → A+ + B- (mol/L)
~~ s = sqrt(Ksp)
function solubility_from_ksp_1_1(ksp: float) -> float {
    return ksp.sqrt().real;
};

~~ common_ion_solubility: molar solubility of AB in solution already containing B- (mol/L)
~~ Ksp = s*(s + c_ion) → s = (-c_ion + sqrt(c_ion^2 + 4*Ksp)) / 2
function common_ion_solubility(ksp: float, c_ion: float) -> float {
    const DISCRIMINANT: float = (c_ion * c_ion) + (4.0 * ksp);
    return (-(c_ion) + DISCRIMINANT.sqrt().real) / 2.0;
};

~~ ph_from_h_conc: pH = -log10([H+])
function ph_from_h_conc(h_conc: float) -> float {
    const LOG10_H: float = h_conc.log10().real;
    return -(LOG10_H);
};

~~ h_conc_from_ph: [H+] = 10^(-pH) (mol/L)
function h_conc_from_ph(ph: float) -> float {
    return float(c_pow(10.0, -(ph)));
};

~~ poh_from_oh_conc: pOH = -log10([OH-])
function poh_from_oh_conc(oh_conc: float) -> float {
    const LOG10_OH: float = oh_conc.log10().real;
    return -(LOG10_OH);
};

~~ ph_from_poh: pH = 14 - pOH (valid at 25°C)
function ph_from_poh(poh: float) -> float {
    return 14.0 - poh;
};

~~ henderson_hasselbalch: pH of a buffer solution
~~ pH = pKa + log10([A-]/[HA])
function henderson_hasselbalch(pka: float, conc_base: float, conc_acid: float) -> float {
    const LOG_RATIO: float = (conc_base / conc_acid).log10().real;
    return pka + LOG_RATIO;
};

~~ ph_weak_acid: approximate pH of weak acid solution
~~ [H+] = sqrt(Ka * Ca) → pH = -log10([H+])
function ph_weak_acid(ka: float, conc_acid: float) -> float {
    const H_CONC: float = (ka * conc_acid).sqrt().real;
    return -(H_CONC.log10().real);
};

~~ ph_weak_base: approximate pH of weak base solution
~~ [OH-] = sqrt(Kb * Cb) → pOH → pH = 14 - pOH
function ph_weak_base(kb: float, conc_base: float) -> float {
    const OH_CONC: float = (kb * conc_base).sqrt().real;
    const POH: float = -(OH_CONC.log10().real);
    return 14.0 - POH;
};

~~ buffer_capacity: resistance of buffer to pH change (mol/(L·pH))
~~ beta = 2.303 * C * Ka*[H+] / (Ka + [H+])^2
function buffer_capacity(total_conc: float, ka: float, ph: float) -> float {
    const H: float = float(c_pow(10.0, -(ph)));
    const NUMER: float = ka * H;
    const DENOM: float = (ka + H) * (ka + H);
    return 2.303 * total_conc * (NUMER / DENOM);
};

~~ degree_of_dissociation: fraction of weak acid dissociated (approx, alpha << 1)
~~ alpha = sqrt(Ka / Ca)
function degree_of_dissociation(ka: float, conc_acid: float) -> float {
    return (ka / conc_acid).sqrt().real;
};

~~ pka_from_ka: pKa = -log10(Ka)
function pka_from_ka(ka: float) -> float {
    return -(ka.log10().real);
};

~~ ─── Section 5: Electrochemistry ──────────────────────────────────────────

const FARADAY: float = 96485.0;

~~ cell_potential_standard: E°cell = E°cathode - E°anode (V)
function cell_potential_standard(e_cathode: float, e_anode: float) -> float {
    return e_cathode - e_anode;
};

~~ nernst_equation: cell potential at non-standard conditions (V)
~~ E = E° - (RT/nF) * ln(Q) | n: moles electrons, q: reaction quotient
function nernst_equation(e_std: float, n_electrons: float, q: float, t_k: float) -> float {
    const LN_Q: float = q.log().real;
    const FACTOR: float = (R_THERMO * t_k) / (n_electrons * FARADAY);
    return e_std - (FACTOR * LN_Q);
};

~~ nernst_at_25c: Nernst equation simplified at 298K (V)
~~ E = E° - (0.05916/n) * log10(Q)
function nernst_at_25c(e_std: float, n_electrons: float, q: float) -> float {
    const LOG10_Q: float = q.log10().real;
    return e_std - ((0.05916 / n_electrons) * LOG10_Q);
};

~~ gibbs_from_emf: standard Gibbs free energy from cell potential (J/mol)
~~ delta_g = -n * F * E°
function gibbs_from_emf(n_electrons: float, e_cell: float) -> float {
    return -(n_electrons * FARADAY * e_cell);
};

~~ keq_from_emf: equilibrium constant from standard cell potential
~~ K = exp(nFE° / RT)
function keq_from_emf(n_electrons: float, e_std: float, t_k: float) -> float {
    const EXPONENT: float = (n_electrons * FARADAY * e_std) / (R_THERMO * t_k);
    return float(c_exp(EXPONENT));
};

~~ emf_from_keq: standard cell potential from equilibrium constant (V)
~~ E° = (RT/nF) * ln(K)
function emf_from_keq(n_electrons: float, keq: float, t_k: float) -> float {
    const LN_K: float = keq.log().real;
    return (R_THERMO * t_k / (n_electrons * FARADAY)) * LN_K;
};

~~ electrolysis_mass: mass deposited by electrolysis (g)
~~ m = I * t * M / (n * F) | I in A, t in s, M in g/mol
function electrolysis_mass(molar_mass: float, current_a: float, time_s: float, n_electrons: float) -> float {
    return (current_a * time_s * molar_mass) / (n_electrons * FARADAY);
};

~~ electrolysis_time: time needed to deposit a given mass (s)
~~ t = m * n * F / (I * M)
function electrolysis_time(molar_mass: float, mass_g: float, current_a: float, n_electrons: float) -> float {
    return (mass_g * n_electrons * FARADAY) / (current_a * molar_mass);
};

~~ molar_conductivity: molar conductivity from measured conductivity (S·m²/mol)
~~ lambda_m = kappa / c | kappa in S/m, c in mol/m³
function molar_conductivity(conductivity: float, conc_mol_m3: float) -> float {
    return conductivity / conc_mol_m3;
};

~~ kohlrausch_conductivity: molar conductivity from Kohlrausch law (S·m²/mol)
~~ lambda_m = lambda_inf - k_const * sqrt(c)
function kohlrausch_conductivity(lambda_inf: float, k_const: float, conc: float) -> float {
    return lambda_inf - (k_const * conc.sqrt().real);
};

~~ ─── Section 6: Nuclear Chemistry ─────────────────────────────────────────

const AMU_TO_MEV: float = 931.494;
const CURIE_IN_BQ: float = 37000000000.0;

~~ decay_constant: lambda = ln(2) / t_half | same time units as t_half
function decay_constant(t_half: float) -> float {
    const LN2: float = 2.0.log().real;
    return LN2 / t_half;
};

~~ activity: decays per unit time (same unit as lambda)
~~ A = lambda * n_nuclei
function activity(lamb_da: float, n_nuclei: float) -> float {
    return lamb_da * n_nuclei;
};

~~ nuclei_remaining: N(t) = N0 * exp(-lambda * t)
~~ uses unsafe_mul: N0 can be astronomically large (atom counts)
function nuclei_remaining(n0: float, lamb_da: float, t: float) -> float {
    return float(unsafe_mul(n0, float(c_exp(-(lamb_da * t)))));
};

~~ activity_remaining: A(t) = A0 * exp(-lambda * t)
function activity_remaining(a0: float, lamb_da: float, t: float) -> float {
    return a0 * float(c_exp(-(lamb_da * t)));
};

~~ radiometric_age: t = ln(n0/n) / lambda (same unit as 1/lambda)
function radiometric_age(n0: float, n: float, lamb_da: float) -> float {
    return (n0 / n).log().real / lamb_da;
};

~~ carbon14_age: age from specific activity ratio (years)
~~ t = ln(a0/a) / lambda_c14 | a0: modern activity, a: sample activity (Bq/g)
function carbon14_age(a0: float, a: float) -> float {
    const LAMBDA_C14: float = 2.0.log().real / 5730.0;
    return (a0 / a).log().real / LAMBDA_C14;
};

~~ mass_defect: difference between constituent masses and actual atomic mass (u)
~~ delta_m = Z*m_proton + N*m_neutron - m_atom
function mass_defect(z: float, n_neutrons: float, m_proton: float, m_neutron: float, m_atom: float) -> float {
    return (z * m_proton) + (n_neutrons * m_neutron) - m_atom;
};

~~ binding_energy: nuclear binding energy (MeV)
~~ E = mass_defect * 931.494 MeV/u
function binding_energy(mass_defect_u: float) -> float {
    return mass_defect_u * AMU_TO_MEV;
};

~~ binding_energy_per_nucleon: binding energy divided by mass number (MeV/nucleon)
function binding_energy_per_nucleon(binding_energy_mev: float, mass_number: float) -> float {
    return binding_energy_mev / mass_number;
};

~~ q_value_decay: energy released in nuclear decay (MeV)
~~ Q = (m_parent - m_daughter - m_emitted) * 931.494
function q_value_decay(m_parent: float, m_daughter: float, m_emitted: float) -> float {
    return (m_parent - m_daughter - m_emitted) * AMU_TO_MEV;
};

~~ becquerel_to_curie: convert activity units (1 Ci = 3.7e10 Bq)
function becquerel_to_curie(bq: float) -> float {
    return bq / CURIE_IN_BQ;
};

~~ curie_to_becquerel: convert activity units
function curie_to_becquerel(ci: float) -> float {
    return ci * CURIE_IN_BQ;
};

~~ ─── Section 7: Quantum & Atomic Structure ────────────────────────────────

const PLANCK: float = 0.000000000000000000000000000000000662607;
const HBAR: float = 0.000000000000000000000000000000000105457;
const SPEED_OF_LIGHT: float = 299792458.0;
const RYDBERG: float = 10973730.0;
const BOHR_RADIUS: float = 0.0000000000529177;

~~ bohr_energy: electron energy at quantum level n (eV)
~~ En = -13.6 / n^2
function bohr_energy(n: float) -> float {
    return -13.6 / (n * n);
};

~~ bohr_radius_n: orbital radius at quantum level n (m)
~~ rn = n^2 * a0
function bohr_radius_n(n: float) -> float {
    return (n * n) * BOHR_RADIUS;
};

~~ rydberg_wavelength: photon wavelength for electronic transition (m)
~~ 1/lambda = R_inf * (1/n1^2 - 1/n2^2) | n2 > n1
function rydberg_wavelength(n1: float, n2: float) -> float {
    const INV_N1: float = 1.0 / (n1 * n1);
    const INV_N2: float = 1.0 / (n2 * n2);
    const INV_LAM: float = RYDBERG * (INV_N1 - INV_N2);
    return 1.0 / INV_LAM;
};

~~ photon_energy: energy of a photon given frequency (J)
~~ E = h * f
function photon_energy(freq_hz: float) -> float {
    return float(unsafe_mul(PLANCK, freq_hz));
};

~~ photon_energy_wavelength: energy of a photon given wavelength (J)
~~ E = hc / lambda
function photon_energy_wavelength(wavelength_m: float) -> float {
    return float(unsafe_div(float(unsafe_mul(PLANCK, SPEED_OF_LIGHT)), wavelength_m));
};

~~ de_broglie_wavelength: matter wave wavelength (m)
~~ lambda = h / (m * v)
~~ uses unsafe_mul/div: quantum-scale values outside fixed-point safe range
function de_broglie_wavelength(mass_kg: float, velocity_ms: float) -> float {
    return float(unsafe_div(PLANCK, float(unsafe_mul(mass_kg, velocity_ms))));
};

~~ heisenberg_uncertainty_x: minimum position uncertainty (m)
~~ delta_x = hbar / (2 * delta_p)
function heisenberg_uncertainty_x(delta_p: float) -> float {
    return float(unsafe_div(HBAR, float(unsafe_mul(2.0, delta_p))));
};

~~ heisenberg_uncertainty_e: minimum energy uncertainty (J)
~~ delta_E = hbar / (2 * delta_t)
function heisenberg_uncertainty_e(delta_t: float) -> float {
    return float(unsafe_div(HBAR, float(unsafe_mul(2.0, delta_t))));
};

~~ effective_nuclear_charge: Z_eff = Z - sigma (Slater screening)
~~ sigma: total shielding constant calculated by Slater's rules
function effective_nuclear_charge(z: float, sigma: float) -> float {
    return z - sigma;
};

~~ ionization_energy: energy to remove electron (eV)
~~ IE = 13.6 * Z_eff^2 / n^2
function ionization_energy(z_eff: float, n: float) -> float {
    return 13.6 * (z_eff * z_eff) / (n * n);
};

~~ ─── Section 8: Solutions & Colligative Properties ────────────────────────

~~ boiling_point_elevation: delta_Tb = Kb * molality * i (°C)
~~ kb: ebullioscopic constant (°C·kg/mol) | i: van't Hoff factor
function boiling_point_elevation(kb: float, molality: float, i: float) -> float {
    return kb * molality * i;
};

~~ freezing_point_depression: delta_Tf = Kf * molality * i (°C)
~~ kf: cryoscopic constant (°C·kg/mol) | i: van't Hoff factor
function freezing_point_depression(kf: float, molality: float, i: float) -> float {
    return kf * molality * i;
};

~~ osmotic_pressure: pi = M * R * T * i (atm)
~~ molarity in mol/L, t_k in K, i: van't Hoff factor
function osmotic_pressure(molarity: float, t_k: float, i: float) -> float {
    return molarity * R_GAS * t_k * i;
};

~~ raoult_law_ideal: vapour pressure of ideal solution (same units as p_pure)
~~ P_solution = x_solvent * P_pure
function raoult_law_ideal(x_solvent: float, p_pure: float) -> float {
    return x_solvent * p_pure;
};

~~ raoult_law_pressure_lowering: vapour pressure lowering (same units as p_pure)
~~ delta_P = x_solute * P_pure
function raoult_law_pressure_lowering(x_solute: float, p_pure: float) -> float {
    return x_solute * p_pure;
};

~~ henry_law: dissolved gas concentration from partial pressure (mol/L)
~~ C = k_H * P | k_H in mol/(L·atm), P in atm
function henry_law(k_h: float, partial_pressure: float) -> float {
    return k_h * partial_pressure;
};

~~ molarity_to_molality: convert molarity to molality (mol/kg)
~~ m = (M * 1000) / (rho - M * molar_mass)
~~ rho: solution density in g/L, molar_mass in g/mol
function molarity_to_molality(molarity: float, rho_g_per_l: float, molar_mass: float) -> float {
    return (molarity * 1000.0) / (rho_g_per_l - (molarity * molar_mass));
};

~~ mole_fraction_to_molality: convert mole fraction to molality (mol/kg)
~~ m = x_solute / (x_solvent * M_solvent) | M_solvent in kg/mol
function mole_fraction_to_molality(x_solute: float, x_solvent: float, m_solvent_kg: float) -> float {
    return x_solute / (x_solvent * m_solvent_kg);
};

~~ van_t_hoff_factor_apparent: observed i from colligative property measurement
~~ i = delta_T / (K * molality)
function van_t_hoff_factor_apparent(delta_t: float, k_const: float, molality: float) -> float {
    return delta_t / (k_const * molality);
};

~~ degree_of_dissociation_vant: fraction dissociated from van't Hoff factor
~~ alpha = (i - 1) / (n - 1) | n: number of ions produced per formula unit
function degree_of_dissociation_vant(i: float, n: float) -> float {
    return (i - 1.0) / (n - 1.0);
};

~~ ─── Section 9: Inorganic / Solid State ───────────────────────────────────

const AVOGADRO: float = 602214000000000000000000.0;
const COULOMB_K: float = 8987550000.0;
const ELEM_CHARGE: float = 0.000000000000000000160218;

~~ born_lande_lattice_energy: lattice energy via Born-Landé equation (J/mol)
~~ uses unsafe_mul: elementary charge is quantum-scale, underflows fixed-point
function born_lande_lattice_energy(m_const: float, z_plus: float, z_minus: float, r0_m: float, n_born: float) -> float {
    const E_SQ: float = float(unsafe_mul(ELEM_CHARGE, ELEM_CHARGE));
    const STEP1: float = float(unsafe_mul(AVOGADRO, m_const));
    const STEP2: float = float(unsafe_mul(STEP1, z_plus * z_minus));
    const STEP3: float = float(unsafe_mul(STEP2, E_SQ));
    const NUMER: float = float(unsafe_mul(STEP3, COULOMB_K));
    const BASE: float = NUMER / r0_m;
    const BORN_FACTOR: float = 1.0 - (1.0 / n_born);
    return -(BASE) * BORN_FACTOR;
};

~~ born_haber_lattice_energy: lattice energy from Born-Haber cycle (kJ/mol)
~~ U = dHf - dHsub - dHdiss - IE - EA (Hess's law arrangement)
function born_haber_lattice_energy(delta_hf: float, delta_hsub: float, delta_hdiss: float, ie: float, ea: float) -> float {
    return delta_hf - delta_hsub - delta_hdiss - ie - ea;
};

~~ kapustinskii_lattice_energy: lattice energy without needing crystal structure (kJ/mol)
~~ U = (1.2025e5 * nu * |z+z-| / r0) * (1 - 0.345/r0) | r0_pm in picometres
function kapustinskii_lattice_energy(nu_ions: float, z_plus: float, z_minus: float, r0_pm: float) -> float {
    const FACTOR: float = 120250.0 * nu_ions * z_plus * z_minus / r0_pm;
    const CORRECTION: float = 1.0 - (0.345 / r0_pm);
    return FACTOR * CORRECTION;
};

~~ crystal_field_stabilization_energy: CFSE for octahedral complex (cm^-1)
~~ CFSE = (-0.4*n_t2g + 0.6*n_eg) * delta_o
function crystal_field_stabilization_energy(n_t2g: float, n_eg: float, delta_o: float) -> float {
    return ((-0.4 * n_t2g) + (0.6 * n_eg)) * delta_o;
};

~~ ionic_radius_ratio: rho = r_cation / r_anion (dimensionless, predicts coordination geometry)
function ionic_radius_ratio(r_cation: float, r_anion: float) -> float {
    return r_cation / r_anion;
};

~~ pauling_ionic_character: percent ionic character of a bond (%)
~~ %ionic = (1 - exp(-0.25*(delta_chi)^2)) * 100
function pauling_ionic_character(delta_chi: float) -> float {
    const EXPONENT: float = -(0.25 * (delta_chi * delta_chi));
    const FRACTION: float = 1.0 - float(c_exp(EXPONENT));
    return FRACTION * 100.0;
};

~~ madelung_energy_per_ion: electrostatic energy per ion pair (J)
~~ uses unsafe_mul: elementary charge is quantum-scale, underflows fixed-point
function madelung_energy_per_ion(m_const: float, r0_m: float) -> float {
    const E_SQ: float = float(unsafe_mul(ELEM_CHARGE, ELEM_CHARGE));
    const STEP1: float = float(unsafe_mul(COULOMB_K, m_const));
    const STEP2: float = float(unsafe_mul(STEP1, E_SQ));
    return -(STEP2) / r0_m;
};

~~ ─── Section 10: Organic-Adjacent Calculations ────────────────────────────

~~ degree_of_unsaturation: DoU = (2C + 2 + N - H) / 2
~~ halogens count as H | C: carbon count, h_count: hydrogen+halogen count, n_count: nitrogen count
function degree_of_unsaturation(c_count: float, h_count: float, n_count: float) -> float {
    return ((2.0 * c_count) + 2.0 + n_count - h_count) / 2.0;
};

~~ empirical_ratio: ratio of an element's moles to the smallest mole count in the sample
~~ used to find the simplest whole-number subscript ratio
function empirical_ratio(moles_element: float, moles_smallest: float) -> float {
    return moles_element / moles_smallest;
};

~~ molecular_formula_multiplier: n = molar_mass_actual / empirical_formula_mass
~~ multiply each empirical subscript by n to get the molecular formula
function molecular_formula_multiplier(molar_mass_actual: float, empirical_formula_mass: float) -> float {
    return molar_mass_actual / empirical_formula_mass;
};

~~ moles_from_combustion_co2: moles of carbon in original sample from CO2 produced (mol)
~~ moles_C = mass_CO2 / 44.01
function moles_from_combustion_co2(mass_co2_g: float) -> float {
    return mass_co2_g / 44.01;
};

~~ moles_from_combustion_h2o: moles of hydrogen in original sample from H2O produced (mol)
~~ moles_H = 2 * (mass_H2O / 18.015)
function moles_from_combustion_h2o(mass_h2o_g: float) -> float {
    return 2.0 * (mass_h2o_g / 18.015);
};

~~ mass_oxygen_by_difference: mass of oxygen in a CHO sample, found by subtraction (g)
~~ mass_O = mass_sample - mass_C - mass_H
function mass_oxygen_by_difference(mass_sample_g: float, mass_c_g: float, mass_h_g: float) -> float {
    return mass_sample_g - mass_c_g - mass_h_g;
};

~~ ─── Section 11: Spectroscopy ──────────────────────────────────────────────

~~ beer_lambert_absorbance: A = epsilon * c * l
~~ epsilon: molar absorptivity (L/(mol·cm)) | c: concentration (mol/L) | l: path length (cm)
function beer_lambert_absorbance(epsilon: float, conc: float, path_length_cm: float) -> float {
    return epsilon * conc * path_length_cm;
};

~~ beer_lambert_concentration: solve for concentration from absorbance (mol/L)
~~ c = A / (epsilon * l)
function beer_lambert_concentration(absorbance: float, epsilon: float, path_length_cm: float) -> float {
    return absorbance / (epsilon * path_length_cm);
};

~~ transmittance_from_absorbance: T = 10^(-A) (fraction, 0-1)
function transmittance_from_absorbance(absorbance: float) -> float {
    return float(c_pow(10.0, -(absorbance)));
};

~~ absorbance_from_transmittance: A = -log10(T)
function absorbance_from_transmittance(transmittance: float) -> float {
    const LOG10_T: float = transmittance.log10().real;
    return -(LOG10_T);
};

~~ wavelength_to_frequency: f = c / lambda (Hz)
function wavelength_to_frequency(wavelength_m: float) -> float {
    return SPEED_OF_LIGHT / wavelength_m;
};

~~ frequency_to_wavelength: lambda = c / f (m)
function frequency_to_wavelength(freq_hz: float) -> float {
    return SPEED_OF_LIGHT / freq_hz;
};

~~ wavenumber_to_wavelength: lambda = 1 / wavenumber (same length unit as input^-1)
~~ typically wavenumber in cm^-1, returns wavelength in cm
function wavenumber_to_wavelength(wavenumber: float) -> float {
    return 1.0 / wavenumber;
};

~~ wavelength_to_wavenumber: wavenumber = 1 / lambda (cm^-1 if lambda in cm)
function wavelength_to_wavenumber(wavelength: float) -> float {
    return 1.0 / wavelength;
};

~~ energy_per_mole_photons: energy of one mole of photons at given frequency (J/mol)
~~ E_mol = N_A * h * f
~~ uses unsafe_mul: N_A is astronomically large
function energy_per_mole_photons(freq_hz: float) -> float {
    const E_PHOTON: float = float(unsafe_mul(PLANCK, freq_hz));
    return float(unsafe_mul(AVOGADRO, E_PHOTON));
};