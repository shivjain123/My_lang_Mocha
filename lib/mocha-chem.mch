~~ mocha-chem: Section 1 — Stoichiometry & Real Gases
~~ Mole/mass conversions, concentration units, yield,
~~ effusion, and real gas behavior via van der Waals.
~~ Ideal gas law excluded by design; PV = nRT does not model reality.

// mocha-lib-deps: mocha-math

local function c_print_err(msg: str) -> null native mocha_print_stderr;
local function c_exit(code: int) -> null native mocha_exit;
local function c_exp(x: float) -> float native mocha_wrap_exp;
local function unsafe_mul(a: float, b: float) -> float native mocha_unsafe_mul;
local function unsafe_div(a: float, b: float) -> float native mocha_unsafe_div;
const R_GAS: float = 0.082057;

~~ moles_from_mass: grams to moles given molar mass (g/mol). mass >= 0, molar_mass > 0.
function moles_from_mass(mass_g: float, molar_mass: float) -> float {
    if (molar_mass <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molar mass must be positive.");
        c_exit(2);
    };
    if (mass_g < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Mass cannot be negative.");
        c_exit(2);
    };
    return mass_g / molar_mass;
};

~~ mass_from_moles: moles to grams given molar mass (g/mol). moles >= 0, molar_mass > 0.
function mass_from_moles(moles: float, molar_mass: float) -> float {
    if (moles < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Moles cannot be negative.");
        c_exit(2);
    };
    if (molar_mass <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molar mass must be positive.");
        c_exit(2);
    };
    return moles * molar_mass;
};

~~ stoich_moles: scale moles through a stoichiometric ratio.
~~ moles_given >= 0, coeff_given > 0, coeff_wanted > 0 (coefficients are counts, always >= 1).
function stoich_moles(moles_given: float, coeff_given: float, coeff_wanted: float) -> float {
    if (moles_given < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Moles given cannot be negative.");
        c_exit(2);
    };
    if (coeff_given <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Given coefficient must be positive (stoichiometric coefficients are counts).");
        c_exit(2);
    };
    if (coeff_wanted <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Wanted coefficient must be positive (stoichiometric coefficients are counts).");
        c_exit(2);
    };
    return moles_given * (coeff_wanted / coeff_given);
};

~~ percent_yield: actual yield as percentage of theoretical yield (%).
~~ actual_g >= 0, theoretical_g > 0. Yield > 100% is physically possible (impure/wet product) and not guarded.
function percent_yield(actual_g: float, theoretical_g: float) -> float {
    if (theoretical_g <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Theoretical yield must be positive.");
        c_exit(2);
    };
    if (actual_g < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Actual yield cannot be negative.");
        c_exit(2);
    };
    return (actual_g / theoretical_g) * 100.0;
};

~~ percent_composition: mass fraction of an element in a compound (%).
~~ mass_element_g >= 0, molar_mass_compound > 0, mass_element_g <= molar_mass_compound.
function percent_composition(mass_element_g: float, molar_mass_compound: float) -> float {
    if (molar_mass_compound <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molar mass of compound must be positive.");
        c_exit(2);
    };
    if (mass_element_g < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Element mass cannot be negative.");
        c_exit(2);
    };
    if (mass_element_g > molar_mass_compound) {
        c_print_err("MochaLibError (mocha-chem): Element mass cannot exceed compound molar mass.");
        c_exit(2);
    };
    return (mass_element_g / molar_mass_compound) * 100.0;
};

~~ molarity: moles of solute per litre of solution (mol/L). moles >= 0, volume_l > 0.
function molarity(moles_solute: float, volume_l: float) -> float {
    if (volume_l <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Volume must be positive.");
        c_exit(2);
    };
    if (moles_solute < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Moles of solute cannot be negative.");
        c_exit(2);
    };
    return moles_solute / volume_l;
};

~~ molality: moles of solute per kilogram of solvent (mol/kg). moles >= 0, mass_solvent_kg > 0.
function molality(moles_solute: float, mass_solvent_kg: float) -> float {
    if (mass_solvent_kg <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Solvent mass must be positive.");
        c_exit(2);
    };
    if (moles_solute < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Moles of solute cannot be negative.");
        c_exit(2);
    };
    return moles_solute / mass_solvent_kg;
};

~~ mole_fraction: component moles / total moles (dimensionless, 0-1).
~~ moles_component in [0, total_moles], total_moles > 0.
function mole_fraction(moles_component: float, total_moles: float) -> float {
    if (total_moles <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Total moles must be positive.");
        c_exit(2);
    };
    if (moles_component < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Component moles cannot be negative.");
        c_exit(2);
    };
    if (moles_component > total_moles) {
        c_print_err("MochaLibError (mocha-chem): Component moles cannot exceed total moles.");
        c_exit(2);
    };
    return moles_component / total_moles;
};

~~ ppm_by_mass: parts per million by mass (mg solute / kg solution).
~~ mass_solute_g >= 0, mass_solution_g > 0, mass_solute <= mass_solution.
function ppm_by_mass(mass_solute_g: float, mass_solution_g: float) -> float {
    if (mass_solution_g <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Solution mass must be positive.");
        c_exit(2);
    };
    if (mass_solute_g < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Solute mass cannot be negative.");
        c_exit(2);
    };
    if (mass_solute_g > mass_solution_g) {
        c_print_err("MochaLibError (mocha-chem): Solute mass cannot exceed solution mass.");
        c_exit(2);
    };
    return (mass_solute_g / mass_solution_g) * 1000000.0;
};

~~ ppb_by_mass: parts per billion by mass (ug solute / kg solution).
~~ Same constraints as ppm_by_mass.
function ppb_by_mass(mass_solute_g: float, mass_solution_g: float) -> float {
    if (mass_solution_g <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Solution mass must be positive.");
        c_exit(2);
    };
    if (mass_solute_g < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Solute mass cannot be negative.");
        c_exit(2);
    };
    if (mass_solute_g > mass_solution_g) {
        c_print_err("MochaLibError (mocha-chem): Solute mass cannot exceed solution mass.");
        c_exit(2);
    };
    return (mass_solute_g / mass_solution_g) * 1000000000.0;
};

~~ dilution_final_volume: find V2 from M1V1 = M2V2. c1 > 0, v1 > 0, c2 > 0.
function dilution_final_volume(c1: float, v1: float, c2: float) -> float {
    if (c2 <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Final concentration must be positive.");
        c_exit(2);
    };
    if (c1 < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial concentration cannot be negative.");
        c_exit(2);
    };
    if (v1 < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial volume cannot be negative.");
        c_exit(2);
    };
    return (c1 * v1) / c2;
};

~~ van_der_waals_pressure: pressure of a real gas (atm). Uses R = 0.082057 L·atm/(mol·K).
~~ n > 0, t_k > 0, v_l > n*b (volume must exceed excluded volume), a > 0, b > 0.
~~ P = nRT/(V - nb) - a(n/V)^2.
function van_der_waals_pressure(n: float, t_k: float, v_l: float, a: float, b: float) -> float {
    if (n <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Moles must be positive.");
        c_exit(2);
    };
    if (t_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Temperature must be positive (Kelvin).");
        c_exit(2);
    };
    if (a < 0.0) {
        c_print_err("MochaLibError (mocha-chem): van der Waals constant a cannot be negative.");
        c_exit(2);
    };
    if (b <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): van der Waals constant b must be positive.");
        c_exit(2);
    };
    const V_EXCL: float = v_l - (n * b);
    if (V_EXCL <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Volume must exceed excluded volume n*b — gas cannot exist below this.");
        c_exit(2);
    };
    const PRESSURE_TERM: float = (n * R_GAS * t_k) / V_EXCL;
    const N_OVER_V: float = n / v_l;
    const ATTRACTION: float = a * (N_OVER_V * N_OVER_V);
    return PRESSURE_TERM - ATTRACTION;
};

~~ van_der_waals_molar_volume: molar volume (L/mol) of a real gas, via Newton-Raphson.
~~ p > 0, t_k > 0, a > 0, b > 0. Valid for gas-phase conditions (above critical temperature).
~~ Errors if Newton-Raphson fails to converge in 50 iterations.
function van_der_waals_molar_volume(p: float, t_k: float, a: float, b: float) -> float {
    if (p <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Pressure must be positive.");
        c_exit(2);
    };
    if (t_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Temperature must be positive (Kelvin).");
        c_exit(2);
    };
    if (a < 0.0) {
        c_print_err("MochaLibError (mocha-chem): van der Waals constant a cannot be negative.");
        c_exit(2);
    };
    if (b <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): van der Waals constant b must be positive.");
        c_exit(2);
    };
    const RT: float = R_GAS * t_k;
    var vm: float = RT / p;
    var i: int = 0;
    var converged: bool = false;
    while (i < 50) {
        const VM2: float = vm * vm;
        const VM3: float = VM2 * vm;
        const F: float = (p * VM3) - ((p * b + RT) * VM2) + (a * vm) - (a * b);
        const DF: float = (3.0 * p * VM2) - (2.0 * (p * b + RT) * vm) + a;
        if (DF == 0.0) {
            c_print_err("MochaLibError (mocha-chem): Newton-Raphson derivative is zero — cannot proceed.");
            c_exit(2);
        };
        var new_vm: float = vm - (F / DF);
        if (abs(new_vm - vm) < 1E-10) {
            converged = true;
            vm = new_vm;
            i = 50;
        } else {
            vm = new_vm;
        };
        i++;
    };
    if (!converged) {
        c_print_err("MochaLibError (mocha-chem): van der Waals molar volume solver failed to converge — check conditions (above critical temperature?).");
        c_exit(2);
    };
    if (vm <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Solver converged to non-positive molar volume — invalid physical solution.");
        c_exit(2);
    };
    return vm;
};

~~ dalton_partial_pressure: partial pressure of a gas component.
~~ mole_frac in [0, 1], p_total >= 0. p_i = mole_frac * p_total.
function dalton_partial_pressure(mole_frac: float, p_total: float) -> float {
    if (mole_frac < 0.0 || mole_frac > 1.0) {
        c_print_err("MochaLibError (mocha-chem): Mole fraction must be in [0, 1].");
        c_exit(2);
    };
    if (p_total < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Total pressure cannot be negative.");
        c_exit(2);
    };
    return mole_frac * p_total;
};

~~ graham_effusion_ratio: relative effusion rate of gas 1 vs gas 2. rate1/rate2 = sqrt(m2/m1).
~~ m1 > 0, m2 > 0 (molar masses in g/mol).
function graham_effusion_ratio(m1: float, m2: float) -> float {
    if (m1 <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molar mass of gas 1 must be positive.");
        c_exit(2);
    };
    if (m2 <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molar mass of gas 2 must be positive.");
        c_exit(2);
    };
    const RATIO: float = m2 / m1;
    return RATIO.sqrt().real;
};

// ─── Section 2: Thermodynamics ────────────────────────────────────────────

const R_THERMO: float = 8.314;

~~ heat_q: heat transferred via specific heat capacity (J). mass >= 0, specific_heat >= 0.
~~ q = m * c * delta_t.
function heat_q(mass_g: float, specific_heat: float, delta_t: float) -> float {
    if (mass_g < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Mass cannot be negative.");
        c_exit(2);
    };
    if (specific_heat < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Specific heat capacity cannot be negative.");
        c_exit(2);
    };
    return mass_g * specific_heat * delta_t;
};

~~ heat_constant_pressure: heat at constant pressure (J). n_moles >= 0, molar_cp >= 0.
~~ q = n * cp * delta_t.
function heat_constant_pressure(n_moles: float, molar_cp: float, delta_t: float) -> float {
    if (n_moles < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Moles cannot be negative.");
        c_exit(2);
    };
    if (molar_cp < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molar heat capacity cannot be negative.");
        c_exit(2);
    };
    return n_moles * molar_cp * delta_t;
};

~~ enthalpy_rxn: standard enthalpy of reaction (kJ/mol). No constraints (formation enthalpies can be negative).
~~ delta_h_rxn = sum_hf_products - sum_hf_reactants.
function enthalpy_rxn(sum_hf_products: float, sum_hf_reactants: float) -> float {
    return sum_hf_products - sum_hf_reactants;
};

~~ entropy_rxn: standard entropy of reaction (J/(mol·K)). No constraints.
~~ delta_s_rxn = sum_s_products - sum_s_reactants.
function entropy_rxn(sum_s_products: float, sum_s_reactants: float) -> float {
    return sum_s_products - sum_s_reactants;
};

~~ gibbs_free_energy: Gibbs free energy change (J/mol). t_k > 0 (absolute temperature).
~~ delta_g = delta_h - t_k * delta_s.
function gibbs_free_energy(delta_h: float, t_k: float, delta_s: float) -> float {
    if (t_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Temperature must be positive (Kelvin).");
        c_exit(2);
    };
    return delta_h - (t_k * delta_s);
};

~~ gibbs_from_keq: standard Gibbs free energy from equilibrium constant (J/mol).
~~ Requires t_k > 0 and keq > 0. delta_g_std = -RT ln(K).
function gibbs_from_keq(t_k: float, keq: float) -> float {
    if (t_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Temperature must be positive (Kelvin).");
        c_exit(2);
    };
    if (keq <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Equilibrium constant must be positive.");
        c_exit(2);
    };
    const LN_K: float = keq.log().real;
    return -(R_THERMO * t_k) * LN_K;
};

~~ keq_from_gibbs: equilibrium constant from standard Gibbs free energy.
~~ Requires t_k > 0. K = exp(-delta_g_std / RT).
function keq_from_gibbs(delta_g_std: float, t_k: float) -> float {
    if (t_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Temperature must be positive (Kelvin).");
        c_exit(2);
    };
    const EXPONENT: float = -(delta_g_std) / (R_THERMO * t_k);
    if (EXPONENT > 700.0 || EXPONENT < -700.0) {
        c_print_err("MochaLibError (mocha-chem): Exponent out of safe range — result would overflow.");
        c_exit(2);
    };
    return float(c_exp(EXPONENT));
};

~~ clausius_clapeyron_p2: vapour pressure at t2_k given known p1 at t1_k (same units as p1).
~~ Requires p1 > 0, t1_k > 0, t2_k > 0, delta_h_vap > 0.
~~ ln(P2/P1) = -(delta_h_vap/R) * (1/T2 - 1/T1).
function clausius_clapeyron_p2(p1: float, t1_k: float, t2_k: float, delta_h_vap: float) -> float {
    if (p1 <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial vapour pressure must be positive.");
        c_exit(2);
    };
    if (t1_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial temperature must be positive (Kelvin).");
        c_exit(2);
    };
    if (t2_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Final temperature must be positive (Kelvin).");
        c_exit(2);
    };
    if (delta_h_vap <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Enthalpy of vaporization must be positive.");
        c_exit(2);
    };
    const EXPONENT: float = -(delta_h_vap / R_THERMO) * ((1.0 / t2_k) - (1.0 / t1_k));
    if (EXPONENT > 700.0 || EXPONENT < -700.0) {
        c_print_err("MochaLibError (mocha-chem): Exponent out of safe range — result would overflow.");
        c_exit(2);
    };
    return p1 * float(c_exp(EXPONENT));
};

~~ clausius_clapeyron_t2: temperature at p2 given known p1 at t1_k (K).
~~ Requires p1 > 0, p2 > 0, t1_k > 0, delta_h_vap > 0. Errors if T2 solution is non-physical.
~~ 1/T2 = 1/T1 - (R/delta_h_vap) * ln(P2/P1).
function clausius_clapeyron_t2(p1: float, p2: float, t1_k: float, delta_h_vap: float) -> float {
    if (p1 <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial pressure must be positive.");
        c_exit(2);
    };
    if (p2 <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Final pressure must be positive.");
        c_exit(2);
    };
    if (t1_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial temperature must be positive (Kelvin).");
        c_exit(2);
    };
    if (delta_h_vap <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Enthalpy of vaporization must be positive.");
        c_exit(2);
    };
    const LN_RATIO: float = (p2 / p1).log().real;
    const INV_T2: float = (1.0 / t1_k) - ((R_THERMO / delta_h_vap) * LN_RATIO);
    if (INV_T2 <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Solution yields non-positive temperature — check inputs (P2/P1 direction).");
        c_exit(2);
    };
    return 1.0 / INV_T2;
};

~~ bond_enthalpy_rxn: enthalpy of reaction from bond energies (kJ/mol). No constraints.
~~ delta_h = bonds_broken - bonds_formed.
function bond_enthalpy_rxn(bonds_broken: float, bonds_formed: float) -> float {
    return bonds_broken - bonds_formed;
};

~~ kirchhoff_enthalpy: enthalpy at t2_k corrected for heat capacity (J/mol).
~~ Requires t1_k > 0 and t2_k > 0 (both absolute temperatures).
~~ delta_h(T2) = delta_h(T1) + delta_cp * (T2 - T1).
function kirchhoff_enthalpy(delta_h_t1: float, delta_cp: float, t1_k: float, t2_k: float) -> float {
    if (t1_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial temperature must be positive (Kelvin).");
        c_exit(2);
    };
    if (t2_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Final temperature must be positive (Kelvin).");
        c_exit(2);
    };
    return delta_h_t1 + (delta_cp * (t2_k - t1_k));
};

~~ entropy_surroundings: entropy change of surroundings (J/K).
~~ Requires t_k > 0. delta_s_surr = -delta_h_sys / T.
function entropy_surroundings(delta_h_sys: float, t_k: float) -> float {
    if (t_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Temperature must be positive (Kelvin).");
        c_exit(2);
    };
    return -(delta_h_sys) / t_k;
};

~~ entropy_universe: total entropy change (J/K). No constraints.
~~ delta_s_univ = delta_s_sys + delta_s_surr.
function entropy_universe(delta_s_sys: float, delta_s_surr: float) -> float {
    return delta_s_sys + delta_s_surr;
};

~~ gibbs_equilibrium_temp: temperature at which delta_g = 0 (K).
~~ T = delta_h / delta_s. Errors if delta_s = 0 (division by zero).
~~ NOTE: if delta_h and delta_s have opposite signs, the equation has NO positive-temperature solution — errors with explanation.
function gibbs_equilibrium_temp(delta_h: float, delta_s: float) -> float {
    if (delta_s == 0.0) {
        c_print_err("MochaLibError (mocha-chem): Entropy change cannot be zero (equilibrium temperature undefined).");
        c_exit(2);
    };
    var t_eq: float = delta_h / delta_s;
    if (t_eq <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): No positive equilibrium temperature exists — delta_h and delta_s have opposite signs (reaction never crosses delta_g = 0).");
        c_exit(2);
    };
    return t_eq;
};

// ─── Section 3: Chemical Kinetics ─────────────────────────────────────────

~~ conc_zero_order: concentration at time t for zero-order reaction (mol/L).
~~ Requires conc_init >= 0, k >= 0, t >= 0. Errors if k*t > conc_init (would give negative concentration).
~~ [A]t = [A]0 - k*t.
function conc_zero_order(conc_init: float, k: float, t: float) -> float {
    if (conc_init < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial concentration cannot be negative.");
        c_exit(2);
    };
    if (k < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Rate constant cannot be negative.");
        c_exit(2);
    };
    if (t < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Time cannot be negative.");
        c_exit(2);
    };
    var conc_t: float = conc_init - (k * t);
    if (conc_t < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Zero-order reaction would exhaust all reactant before time t — concentration cannot go below zero.");
        c_exit(2);
    };
    return conc_t;
};

~~ conc_first_order: concentration at time t for first-order reaction (mol/L).
~~ Requires conc_init >= 0, k >= 0, t >= 0. [A]t = [A]0 * exp(-k*t).
function conc_first_order(conc_init: float, k: float, t: float) -> float {
    if (conc_init < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial concentration cannot be negative.");
        c_exit(2);
    };
    if (k < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Rate constant cannot be negative.");
        c_exit(2);
    };
    if (t < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Time cannot be negative.");
        c_exit(2);
    };
    return conc_init * float(c_exp(-(k * t)));
};

~~ conc_second_order: concentration at time t for second-order reaction (mol/L).
~~ Requires conc_init > 0, k >= 0, t >= 0. [A]t = 1 / (1/[A]0 + k*t).
function conc_second_order(conc_init: float, k: float, t: float) -> float {
    if (conc_init <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial concentration must be positive for second-order kinetics.");
        c_exit(2);
    };
    if (k < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Rate constant cannot be negative.");
        c_exit(2);
    };
    if (t < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Time cannot be negative.");
        c_exit(2);
    };
    return 1.0 / ((1.0 / conc_init) + (k * t));
};

~~ half_life_zero_order: half-life for zero-order reaction (s).
~~ Requires conc_init > 0, k > 0. t½ = [A]0 / (2k).
function half_life_zero_order(conc_init: float, k: float) -> float {
    if (conc_init <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial concentration must be positive.");
        c_exit(2);
    };
    if (k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Rate constant must be positive for half-life calculation.");
        c_exit(2);
    };
    return conc_init / (2.0 * k);
};

~~ half_life_first_order: half-life for first-order reaction (s).
~~ Requires k > 0. t½ = ln(2) / k.
function half_life_first_order(k: float) -> float {
    if (k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Rate constant must be positive for half-life calculation.");
        c_exit(2);
    };
    const LN2: float = 2.0.log().real;
    return LN2 / k;
};

~~ half_life_second_order: half-life for second-order reaction (s).
~~ Requires conc_init > 0, k > 0. t½ = 1 / (k * [A]0).
function half_life_second_order(conc_init: float, k: float) -> float {
    if (conc_init <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial concentration must be positive.");
        c_exit(2);
    };
    if (k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Rate constant must be positive for half-life calculation.");
        c_exit(2);
    };
    return 1.0 / (k * conc_init);
};

~~ arrhenius_k: rate constant from Arrhenius equation.
~~ Requires a_factor > 0, ea >= 0, t_k > 0. k = A * exp(-Ea / RT).
function arrhenius_k(a_factor: float, ea: float, t_k: float) -> float {
    if (a_factor <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Pre-exponential factor must be positive.");
        c_exit(2);
    };
    if (ea < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Activation energy cannot be negative (k would exceed A).");
        c_exit(2);
    };
    if (t_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Temperature must be positive (Kelvin).");
        c_exit(2);
    };
    return a_factor * float(c_exp(-(ea / (R_THERMO * t_k))));
};

~~ activation_energy_two_point: Ea from two rate constants at two temperatures (J/mol).
~~ Requires k1 > 0, k2 > 0, t1_k > 0, t2_k > 0, t1_k != t2_k.
~~ Ea = -R * ln(k2/k1) / (1/T2 - 1/T1).
function activation_energy_two_point(k1: float, k2: float, t1_k: float, t2_k: float) -> float {
    if (k1 <= 0.0 || k2 <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Rate constants must be positive.");
        c_exit(2);
    };
    if (t1_k <= 0.0 || t2_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Temperatures must be positive (Kelvin).");
        c_exit(2);
    };
    if (t1_k == t2_k) {
        c_print_err("MochaLibError (mocha-chem): Two-point activation energy requires two different temperatures.");
        c_exit(2);
    };
    const LN_RATIO: float = (k2 / k1).log().real;
    const INV_DIFF: float = (1.0 / t2_k) - (1.0 / t1_k);
    return -(R_THERMO * LN_RATIO) / INV_DIFF;
};

~~ rate_law: reaction rate from concentrations and orders.
~~ Requires k >= 0, conc_a > 0, conc_b > 0. rate = k * [A]^a * [B]^b.
function rate_law(k: float, conc_a: float, order_a: float, conc_b: float, order_b: float) -> float {
    if (k < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Rate constant cannot be negative.");
        c_exit(2);
    };
    if (conc_a <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Concentration of A must be positive (c_pow requires positive base).");
        c_exit(2);
    };
    if (conc_b <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Concentration of B must be positive (c_pow requires positive base).");
        c_exit(2);
    };
    return k * c_pow(conc_a, order_a) * c_pow(conc_b, order_b);
};

~~ time_to_conc_first_order: time to reach conc_final from conc_init (s).
~~ Requires conc_init > 0, conc_final > 0, k > 0. t = ln([A]0 / [A]t) / k.
function time_to_conc_first_order(conc_init: float, conc_final: float, k: float) -> float {
    if (conc_init <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial concentration must be positive.");
        c_exit(2);
    };
    if (conc_final <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Final concentration must be positive (time to reach zero is infinite).");
        c_exit(2);
    };
    if (k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Rate constant must be positive for time calculation.");
        c_exit(2);
    };
    return (conc_init / conc_final).log().real / k;
};

~~ time_to_conc_second_order: time to reach conc_final from conc_init (s).
~~ Requires conc_init > 0, conc_final > 0, k > 0. t = (1/[A]t - 1/[A]0) / k.
function time_to_conc_second_order(conc_init: float, conc_final: float, k: float) -> float {
    if (conc_init <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial concentration must be positive.");
        c_exit(2);
    };
    if (conc_final <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Final concentration must be positive.");
        c_exit(2);
    };
    if (k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Rate constant must be positive for time calculation.");
        c_exit(2);
    };
    var t: float = ((1.0 / conc_final) - (1.0 / conc_init)) / k;
    if (t < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Negative time — final concentration must be less than initial for decay.");
        c_exit(2);
    };
    return t;
};

~~ arrhenius_ratio: ratio k2/k1 at two temperatures given activation energy.
~~ Requires ea >= 0, t1_k > 0, t2_k > 0. k2/k1 = exp(-Ea/R * (1/T2 - 1/T1)).
function arrhenius_ratio(ea: float, t1_k: float, t2_k: float) -> float {
    if (ea < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Activation energy cannot be negative.");
        c_exit(2);
    };
    if (t1_k <= 0.0 || t2_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Temperatures must be positive (Kelvin).");
        c_exit(2);
    };
    const EXPONENT: float = -(ea / R_THERMO) * ((1.0 / t2_k) - (1.0 / t1_k));
    if (EXPONENT > 700.0 || EXPONENT < -700.0) {
        c_print_err("MochaLibError (mocha-chem): Exponent out of safe range — result would overflow.");
        c_exit(2);
    };
    return float(c_exp(EXPONENT));
};

// ─── Section 4: Equilibrium & Acid-Base ───────────────────────────────────

~~ kc_from_kp: equilibrium constant in concentration from pressure form. Kc = Kp / (RT)^delta_n.
~~ Requires kp > 0, t_k > 0.
function kc_from_kp(kp: float, t_k: float, delta_n: float) -> float {
    if (kp <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Kp must be positive.");
        c_exit(2);
    };
    if (t_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Temperature must be positive (Kelvin).");
        c_exit(2);
    };
    const RT: float = R_GAS * t_k;
    return kp / c_pow(RT, delta_n);
};

~~ kp_from_kc: equilibrium constant in pressure from concentration form. Kp = Kc * (RT)^delta_n.
~~ Requires kc > 0, t_k > 0.
function kp_from_kc(kc: float, t_k: float, delta_n: float) -> float {
    if (kc <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Kc must be positive.");
        c_exit(2);
    };
    if (t_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Temperature must be positive (Kelvin).");
        c_exit(2);
    };
    const RT: float = R_GAS * t_k;
    return kc * c_pow(RT, delta_n);
};

~~ reaction_quotient: Q = conc_products / conc_reactants.
~~ Requires conc_products >= 0, conc_reactants > 0.
function reaction_quotient(conc_products: float, conc_reactants: float) -> float {
    if (conc_products < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Product concentration cannot be negative.");
        c_exit(2);
    };
    if (conc_reactants <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Reactant concentration must be positive.");
        c_exit(2);
    };
    return conc_products / conc_reactants;
};

~~ ksp_from_concentrations: Ksp = [A]*[B] (pre-powered values).
~~ Requires ion_a >= 0, ion_b >= 0.
function ksp_from_concentrations(ion_a: float, ion_b: float) -> float {
    if (ion_a < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Ion A concentration cannot be negative.");
        c_exit(2);
    };
    if (ion_b < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Ion B concentration cannot be negative.");
        c_exit(2);
    };
    return ion_a * ion_b;
};

~~ solubility_from_ksp_1_1: molar solubility for 1:1 salt (mol/L). s = sqrt(Ksp).
~~ Requires ksp >= 0.
function solubility_from_ksp_1_1(ksp: float) -> float {
    if (ksp < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Ksp cannot be negative.");
        c_exit(2);
    };
    return ksp.sqrt().real;
};

~~ common_ion_solubility: molar solubility of AB in solution containing B-.
~~ Requires ksp >= 0, c_ion >= 0. s = (-c_ion + sqrt(c_ion^2 + 4*Ksp)) / 2.
function common_ion_solubility(ksp: float, c_ion: float) -> float {
    if (ksp < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Ksp cannot be negative.");
        c_exit(2);
    };
    if (c_ion < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Common ion concentration cannot be negative.");
        c_exit(2);
    };
    const DISCRIMINANT: float = (c_ion * c_ion) + (4.0 * ksp);
    return (-(c_ion) + DISCRIMINANT.sqrt().real) / 2.0;
};

~~ ph_from_h_conc: pH = -log10([H+]). Requires h_conc > 0.
function ph_from_h_conc(h_conc: float) -> float {
    if (h_conc <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): H+ concentration must be positive (log10 undefined for zero/negative).");
        c_exit(2);
    };
    const LOG10_H: float = h_conc.log10().real;
    return -(LOG10_H);
};

~~ h_conc_from_ph: [H+] = 10^(-pH) (mol/L). No constraints (any real pH is mathematically valid).
function h_conc_from_ph(ph: float) -> float {
    const EXPONENT: float = -(ph);
    if (EXPONENT > 700.0 || EXPONENT < -700.0) {
        c_print_err("MochaLibError (mocha-chem): pH out of representable range — exponent would overflow.");
        c_exit(2);
    };
    return float(c_pow(10.0, EXPONENT));
};

~~ poh_from_oh_conc: pOH = -log10([OH-]). Requires oh_conc > 0.
function poh_from_oh_conc(oh_conc: float) -> float {
    if (oh_conc <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): OH- concentration must be positive (log10 undefined for zero/negative).");
        c_exit(2);
    };
    const LOG10_OH: float = oh_conc.log10().real;
    return -(LOG10_OH);
};

~~ ph_from_poh: pH = 14 - pOH (valid at 25°C). No constraints.
function ph_from_poh(poh: float) -> float {
    return 14.0 - poh;
};

~~ henderson_hasselbalch: pH = pKa + log10([A-]/[HA]).
~~ Requires conc_base > 0, conc_acid > 0.
function henderson_hasselbalch(pka: float, conc_base: float, conc_acid: float) -> float {
    if (conc_base <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Base concentration must be positive.");
        c_exit(2);
    };
    if (conc_acid <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Acid concentration must be positive.");
        c_exit(2);
    };
    const LOG_RATIO: float = (conc_base / conc_acid).log10().real;
    return pka + LOG_RATIO;
};

~~ ph_weak_acid: approximate pH of weak acid solution. [H+] = sqrt(Ka*Ca).
~~ Requires ka > 0, conc_acid > 0. Approximation valid for alpha << 1 (Ka << Ca).
function ph_weak_acid(ka: float, conc_acid: float) -> float {
    if (ka <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Ka must be positive.");
        c_exit(2);
    };
    if (conc_acid <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Acid concentration must be positive.");
        c_exit(2);
    };
    const H_CONC: float = (ka * conc_acid).sqrt().real;
    return -(H_CONC.log10().real);
};

~~ ph_weak_base: approximate pH of weak base solution. [OH-] = sqrt(Kb*Cb), pH = 14 - pOH.
~~ Requires kb > 0, conc_base > 0. Approximation valid for alpha << 1 (Kb << Cb).
function ph_weak_base(kb: float, conc_base: float) -> float {
    if (kb <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Kb must be positive.");
        c_exit(2);
    };
    if (conc_base <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Base concentration must be positive.");
        c_exit(2);
    };
    const OH_CONC: float = (kb * conc_base).sqrt().real;
    const POH: float = -(OH_CONC.log10().real);
    return 14.0 - POH;
};

~~ buffer_capacity: resistance of buffer to pH change (mol/(L·pH)).
~~ Requires total_conc > 0, ka > 0. beta = 2.303 * C * Ka*[H+] / (Ka + [H+])^2.
function buffer_capacity(total_conc: float, ka: float, ph: float) -> float {
    if (total_conc <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Total buffer concentration must be positive.");
        c_exit(2);
    };
    if (ka <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Ka must be positive.");
        c_exit(2);
    };
    const H: float = float(c_pow(10.0, -(ph)));
    const NUMER: float = ka * H;
    const SUM: float = ka + H;
    if (SUM <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): (Ka + [H+]) is zero or negative — cannot compute buffer capacity.");
        c_exit(2);
    };
    const DENOM: float = SUM * SUM;
    return 2.303 * total_conc * (NUMER / DENOM);
};

~~ degree_of_dissociation: fraction of weak acid dissociated (approx, alpha << 1).
~~ Requires ka > 0, conc_acid > 0. Result must be <= 1 for approximation to be valid.
function degree_of_dissociation(ka: float, conc_acid: float) -> float {
    if (ka <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Ka must be positive.");
        c_exit(2);
    };
    if (conc_acid <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Acid concentration must be positive.");
        c_exit(2);
    };
    var alpha: float = (ka / conc_acid).sqrt().real;
    if (alpha > 1.0) {
        c_print_err("MochaLibError (mocha-chem): Degree of dissociation > 1 — approximation broken (Ka >= Ca). Use exact quadratic solution.");
        c_exit(2);
    };
    return alpha;
};

~~ pka_from_ka: pKa = -log10(Ka). Requires ka > 0.
function pka_from_ka(ka: float) -> float {
    if (ka <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Ka must be positive (log10 undefined for zero/negative).");
        c_exit(2);
    };
    return -(ka.log10().real);
};

// ─── Section 5: Electrochemistry ──────────────────────────────────────────

const FARADAY: float = 96485.0;

~~ cell_potential_standard: E°cell = E°cathode - E°anode (V). No constraints (potentials can be negative).
function cell_potential_standard(e_cathode: float, e_anode: float) -> float {
    return e_cathode - e_anode;
};

~~ nernst_equation: cell potential at non-standard conditions (V).
~~ Requires n_electrons > 0, q > 0, t_k > 0. E = E° - (RT/nF) * ln(Q).
function nernst_equation(e_std: float, n_electrons: float, q: float, t_k: float) -> float {
    if (n_electrons <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Electron count must be positive.");
        c_exit(2);
    };
    if (q <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Reaction quotient must be positive (log undefined for zero/negative).");
        c_exit(2);
    };
    if (t_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Temperature must be positive (Kelvin).");
        c_exit(2);
    };
    const LN_Q: float = q.log().real;
    const FACTOR: float = (R_THERMO * t_k) / (n_electrons * FARADAY);
    return e_std - (FACTOR * LN_Q);
};

~~ nernst_at_25c: Nernst equation at 298K (V). Requires n_electrons > 0, q > 0.
~~ E = E° - (0.05916/n) * log10(Q).
function nernst_at_25c(e_std: float, n_electrons: float, q: float) -> float {
    if (n_electrons <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Electron count must be positive.");
        c_exit(2);
    };
    if (q <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Reaction quotient must be positive (log10 undefined for zero/negative).");
        c_exit(2);
    };
    const LOG10_Q: float = q.log10().real;
    return e_std - ((0.05916 / n_electrons) * LOG10_Q);
};

~~ gibbs_from_emf: standard Gibbs free energy from cell potential (J/mol).
~~ Requires n_electrons > 0. delta_g = -n * F * E°.
function gibbs_from_emf(n_electrons: float, e_cell: float) -> float {
    if (n_electrons <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Electron count must be positive.");
        c_exit(2);
    };
    return -(n_electrons * FARADAY * e_cell);
};

~~ keq_from_emf: equilibrium constant from standard cell potential.
~~ Requires n_electrons > 0, t_k > 0. K = exp(nFE° / RT). Errors if exponent overflows.
function keq_from_emf(n_electrons: float, e_std: float, t_k: float) -> float {
    if (n_electrons <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Electron count must be positive.");
        c_exit(2);
    };
    if (t_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Temperature must be positive (Kelvin).");
        c_exit(2);
    };
    const EXPONENT: float = (n_electrons * FARADAY * e_std) / (R_THERMO * t_k);
    if (EXPONENT > 700.0 || EXPONENT < -700.0) {
        c_print_err("MochaLibError (mocha-chem): Exponent out of safe range — K would overflow.");
        c_exit(2);
    };
    return float(c_exp(EXPONENT));
};

~~ emf_from_keq: standard cell potential from equilibrium constant (V).
~~ Requires n_electrons > 0, keq > 0, t_k > 0. E° = (RT/nF) * ln(K).
function emf_from_keq(n_electrons: float, keq: float, t_k: float) -> float {
    if (n_electrons <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Electron count must be positive.");
        c_exit(2);
    };
    if (keq <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Equilibrium constant must be positive (log undefined for zero/negative).");
        c_exit(2);
    };
    if (t_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Temperature must be positive (Kelvin).");
        c_exit(2);
    };
    const LN_K: float = keq.log().real;
    return (R_THERMO * t_k / (n_electrons * FARADAY)) * LN_K;
};

~~ electrolysis_mass: mass deposited by electrolysis (g). m = I*t*M/(nF).
~~ Requires molar_mass > 0, current_a >= 0, time_s >= 0, n_electrons > 0.
function electrolysis_mass(molar_mass: float, current_a: float, time_s: float, n_electrons: float) -> float {
    if (molar_mass <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molar mass must be positive.");
        c_exit(2);
    };
    if (current_a < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Current cannot be negative (use sign convention on current direction externally).");
        c_exit(2);
    };
    if (time_s < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Time cannot be negative.");
        c_exit(2);
    };
    if (n_electrons <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Electron count must be positive.");
        c_exit(2);
    };
    return (current_a * time_s * molar_mass) / (n_electrons * FARADAY);
};

~~ electrolysis_time: time needed to deposit a given mass (s). t = m*n*F/(I*M).
~~ Requires molar_mass > 0, mass_g >= 0, current_a > 0, n_electrons > 0.
function electrolysis_time(molar_mass: float, mass_g: float, current_a: float, n_electrons: float) -> float {
    if (molar_mass <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molar mass must be positive.");
        c_exit(2);
    };
    if (mass_g < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Mass cannot be negative.");
        c_exit(2);
    };
    if (current_a <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Current must be positive for electrolysis time.");
        c_exit(2);
    };
    if (n_electrons <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Electron count must be positive.");
        c_exit(2);
    };
    return (mass_g * n_electrons * FARADAY) / (current_a * molar_mass);
};

~~ molar_conductivity: molar conductivity from measured conductivity (S·m²/mol).
~~ Requires conductivity >= 0, conc_mol_m3 > 0. lambda_m = kappa / c.
function molar_conductivity(conductivity: float, conc_mol_m3: float) -> float {
    if (conductivity < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Conductivity cannot be negative.");
        c_exit(2);
    };
    if (conc_mol_m3 <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Concentration must be positive.");
        c_exit(2);
    };
    return conductivity / conc_mol_m3;
};

~~ kohlrausch_conductivity: molar conductivity from Kohlrausch law (S·m²/mol).
~~ Requires lambda_inf >= 0, k_const >= 0, conc >= 0. lambda_m = lambda_inf - k_const * sqrt(c).
function kohlrausch_conductivity(lambda_inf: float, k_const: float, conc: float) -> float {
    if (lambda_inf < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Limiting molar conductivity cannot be negative.");
        c_exit(2);
    };
    if (k_const < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Kohlrausch constant cannot be negative.");
        c_exit(2);
    };
    if (conc < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Concentration cannot be negative.");
        c_exit(2);
    };
    return lambda_inf - (k_const * conc.sqrt().real);
};

// ─── Section 6: Nuclear Chemistry ─────────────────────────────────────────

const AMU_TO_MEV: float = 931.494;
const CURIE_IN_BQ: float = 37000000000.0;

~~ decay_constant: lambda = ln(2) / t_half. Requires t_half > 0.
function decay_constant(t_half: float) -> float {
    if (t_half <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Half-life must be positive.");
        c_exit(2);
    };
    const LN2: float = 2.0.log().real;
    return LN2 / t_half;
};

~~ activity: decays per unit time (same unit as lambda). A = lambda * n_nuclei.
~~ Requires lamb_da >= 0, n_nuclei >= 0.
function activity(lamb_da: float, n_nuclei: float) -> float {
    if (lamb_da < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Decay constant cannot be negative.");
        c_exit(2);
    };
    if (n_nuclei < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Nuclei count cannot be negative.");
        c_exit(2);
    };
    return lamb_da * n_nuclei;
};

~~ nuclei_remaining: N(t) = N0 * exp(-lambda * t). Requires n0 >= 0, lamb_da >= 0, t >= 0.
~~ Uses unsafe_mul: N0 can be astronomically large (atom counts).
function nuclei_remaining(n0: float, lamb_da: float, t: float) -> float {
    if (n0 < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial nuclei count cannot be negative.");
        c_exit(2);
    };
    if (lamb_da < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Decay constant cannot be negative.");
        c_exit(2);
    };
    if (t < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Time cannot be negative.");
        c_exit(2);
    };
    return float(unsafe_mul(n0, float(c_exp(-(lamb_da * t)))));
};

~~ activity_remaining: A(t) = A0 * exp(-lambda * t). Requires a0 >= 0, lamb_da >= 0, t >= 0.
function activity_remaining(a0: float, lamb_da: float, t: float) -> float {
    if (a0 < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial activity cannot be negative.");
        c_exit(2);
    };
    if (lamb_da < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Decay constant cannot be negative.");
        c_exit(2);
    };
    if (t < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Time cannot be negative.");
        c_exit(2);
    };
    return a0 * float(c_exp(-(lamb_da * t)));
};

~~ radiometric_age: t = ln(n0/n) / lambda. Requires n0 > 0, n > 0, lamb_da > 0.
~~ Errors if n > n0 (would give negative age — physically impossible in decay).
function radiometric_age(n0: float, n: float, lamb_da: float) -> float {
    if (n0 <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Initial nuclei count must be positive (log undefined for zero/negative).");
        c_exit(2);
    };
    if (n <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Current nuclei count must be positive (log undefined for zero/negative).");
        c_exit(2);
    };
    if (lamb_da <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Decay constant must be positive.");
        c_exit(2);
    };
    if (n > n0) {
        c_print_err("MochaLibError (mocha-chem): Current nuclei count exceeds initial — impossible in decay.");
        c_exit(2);
    };
    return (n0 / n).log().real / lamb_da;
};

~~ carbon14_age: age from specific activity ratio (years).
~~ Requires a0 > 0, a > 0, a <= a0. Errors if a > a0 (would give negative C-14 age).
~~ t = ln(a0/a) / lambda_c14.
function carbon14_age(a0: float, a: float) -> float {
    if (a0 <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Modern activity must be positive.");
        c_exit(2);
    };
    if (a <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Sample activity must be positive.");
        c_exit(2);
    };
    if (a > a0) {
        c_print_err("MochaLibError (mocha-chem): Sample activity exceeds modern activity — impossible in radiocarbon dating.");
        c_exit(2);
    };
    const LAMBDA_C14: float = 2.0.log().real / 5730.0;
    return (a0 / a).log().real / LAMBDA_C14;
};

~~ mass_defect: difference between constituent masses and atomic mass (u). No constraints.
~~ delta_m = Z*m_proton + N*m_neutron - m_atom.
function mass_defect(z: float, n_neutrons: float, m_proton: float, m_neutron: float, m_atom: float) -> float {
    return (z * m_proton) + (n_neutrons * m_neutron) - m_atom;
};

~~ binding_energy: nuclear binding energy (MeV). Requires mass_defect_u >= 0.
~~ E = mass_defect * 931.494 MeV/u.
function binding_energy(mass_defect_u: float) -> float {
    if (mass_defect_u < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Mass defect cannot be negative for a bound nucleus.");
        c_exit(2);
    };
    return mass_defect_u * AMU_TO_MEV;
};

~~ binding_energy_per_nucleon: binding energy per nucleon (MeV/nucleon).
~~ Requires binding_energy_mev >= 0, mass_number > 0.
function binding_energy_per_nucleon(binding_energy_mev: float, mass_number: float) -> float {
    if (binding_energy_mev < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Binding energy cannot be negative.");
        c_exit(2);
    };
    if (mass_number <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Mass number must be positive.");
        c_exit(2);
    };
    return binding_energy_mev / mass_number;
};

~~ q_value_decay: energy released in nuclear decay (MeV). No constraints.
~~ Positive Q means spontaneous decay; negative Q means energetically forbidden.
~~ Q = (m_parent - m_daughter - m_emitted) * 931.494.
function q_value_decay(m_parent: float, m_daughter: float, m_emitted: float) -> float {
    return (m_parent - m_daughter - m_emitted) * AMU_TO_MEV;
};

~~ becquerel_to_curie: convert activity units (1 Ci = 3.7e10 Bq). Requires bq >= 0.
function becquerel_to_curie(bq: float) -> float {
    if (bq < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Activity cannot be negative.");
        c_exit(2);
    };
    return bq / CURIE_IN_BQ;
};

~~ curie_to_becquerel: convert activity units. Requires ci >= 0.
function curie_to_becquerel(ci: float) -> float {
    if (ci < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Activity cannot be negative.");
        c_exit(2);
    };
    return ci * CURIE_IN_BQ;
};

// ─── Section 7: Quantum & Atomic Structure ────────────────────────────────

const PLANCK: float = 0.000000000000000000000000000000000662607;
const HBAR: float = 0.000000000000000000000000000000000105457;
const SPEED_OF_LIGHT: float = 299792458.0;
const RYDBERG: float = 10973730.0;
const BOHR_RADIUS: float = 0.0000000000529177;

~~ bohr_energy: electron energy at quantum level n (eV). En = -13.6 / n^2.
~~ Requires n > 0 (quantum number, positive).
function bohr_energy(n: float) -> float {
    if (n <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Principal quantum number must be positive.");
        c_exit(2);
    };
    return -13.6 / (n * n);
};

~~ bohr_radius_n: orbital radius at quantum level n (m). rn = n^2 * a0.
~~ Requires n > 0 (quantum number, positive).
function bohr_radius_n(n: float) -> float {
    if (n <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Principal quantum number must be positive.");
        c_exit(2);
    };
    return (n * n) * BOHR_RADIUS;
};

~~ rydberg_wavelength: photon wavelength for electronic transition (m).
~~ 1/lambda = R_inf * (1/n1^2 - 1/n2^2). Requires n1 > 0, n2 > 0, n2 > n1 (emission).
function rydberg_wavelength(n1: float, n2: float) -> float {
    if (n1 <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Lower quantum level n1 must be positive.");
        c_exit(2);
    };
    if (n2 <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Upper quantum level n2 must be positive.");
        c_exit(2);
    };
    if (n2 <= n1) {
        c_print_err("MochaLibError (mocha-chem): Upper level n2 must exceed lower level n1 for emission.");
        c_exit(2);
    };
    const INV_N1: float = 1.0 / (n1 * n1);
    const INV_N2: float = 1.0 / (n2 * n2);
    const INV_LAM: float = RYDBERG * (INV_N1 - INV_N2);
    return 1.0 / INV_LAM;
};

~~ photon_energy: energy of a photon given frequency (J). E = h * f.
~~ Requires freq_hz > 0 (photon energy must be positive).
function photon_energy(freq_hz: float) -> float {
    if (freq_hz <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Photon frequency must be positive.");
        c_exit(2);
    };
    return float(unsafe_mul(PLANCK, freq_hz));
};

~~ photon_energy_wavelength: energy of a photon given wavelength (J). E = hc / lambda.
~~ Requires wavelength_m > 0 (photon energy must be positive).
function photon_energy_wavelength(wavelength_m: float) -> float {
    if (wavelength_m <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Photon wavelength must be positive.");
        c_exit(2);
    };
    return float(unsafe_div(float(unsafe_mul(PLANCK, SPEED_OF_LIGHT)), wavelength_m));
};

~~ de_broglie_wavelength: matter wave wavelength (m). lambda = h / (m * v).
~~ Requires mass_kg > 0, velocity_ms > 0.
~~ Uses unsafe_mul/div: quantum-scale values outside fixed-point safe range.
function de_broglie_wavelength(mass_kg: float, velocity_ms: float) -> float {
    if (mass_kg <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Mass must be positive.");
        c_exit(2);
    };
    if (velocity_ms <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Velocity must be positive (use magnitude).");
        c_exit(2);
    };
    return float(unsafe_div(PLANCK, float(unsafe_mul(mass_kg, velocity_ms))));
};

~~ heisenberg_uncertainty_x: minimum position uncertainty (m). delta_x = hbar / (2 * delta_p).
~~ Requires delta_p > 0.
function heisenberg_uncertainty_x(delta_p: float) -> float {
    if (delta_p <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Momentum uncertainty must be positive.");
        c_exit(2);
    };
    return float(unsafe_div(HBAR, float(unsafe_mul(2.0, delta_p))));
};

~~ heisenberg_uncertainty_e: minimum energy uncertainty (J). delta_E = hbar / (2 * delta_t).
~~ Requires delta_t > 0.
function heisenberg_uncertainty_e(delta_t: float) -> float {
    if (delta_t <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Time uncertainty must be positive.");
        c_exit(2);
    };
    return float(unsafe_div(HBAR, float(unsafe_mul(2.0, delta_t))));
};

~~ effective_nuclear_charge: Z_eff = Z - sigma (Slater screening).
~~ Requires z >= 0, sigma >= 0, sigma < z (result must be positive).
function effective_nuclear_charge(z: float, sigma: float) -> float {
    if (z < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Atomic number cannot be negative.");
        c_exit(2);
    };
    if (sigma < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Shielding constant cannot be negative.");
        c_exit(2);
    };
    if (sigma >= z) {
        c_print_err("MochaLibError (mocha-chem): Shielding constant cannot equal or exceed atomic number (Z_eff must be positive).");
        c_exit(2);
    };
    return z - sigma;
};

~~ ionization_energy: energy to remove electron (eV). IE = 13.6 * Z_eff^2 / n^2.
~~ Requires z_eff > 0, n > 0.
function ionization_energy(z_eff: float, n: float) -> float {
    if (z_eff <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Effective nuclear charge must be positive.");
        c_exit(2);
    };
    if (n <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Principal quantum number must be positive.");
        c_exit(2);
    };
    return 13.6 * (z_eff * z_eff) / (n * n);
};

// ─── Section 8: Solutions & Colligative Properties ────────────────────────

~~ boiling_point_elevation: delta_Tb = Kb * molality * i (°C).
~~ Requires kb > 0, molality >= 0, i >= 1 (van't Hoff factor for dissociation; use i = 1 for non-electrolytes).
function boiling_point_elevation(kb: float, molality: float, i: float) -> float {
    if (kb <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Ebullioscopic constant must be positive.");
        c_exit(2);
    };
    if (molality < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molality cannot be negative.");
        c_exit(2);
    };
    if (i < 1.0) {
        c_print_err("MochaLibError (mocha-chem): van't Hoff factor must be >= 1 for colligative properties (use 1 for non-electrolytes).");
        c_exit(2);
    };
    return kb * molality * i;
};

~~ freezing_point_depression: delta_Tf = Kf * molality * i (°C).
~~ Requires kf > 0, molality >= 0, i >= 1.
function freezing_point_depression(kf: float, molality: float, i: float) -> float {
    if (kf <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Cryoscopic constant must be positive.");
        c_exit(2);
    };
    if (molality < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molality cannot be negative.");
        c_exit(2);
    };
    if (i < 1.0) {
        c_print_err("MochaLibError (mocha-chem): van't Hoff factor must be >= 1 for colligative properties.");
        c_exit(2);
    };
    return kf * molality * i;
};

~~ osmotic_pressure: pi = M * R * T * i (atm).
~~ Requires molarity >= 0, t_k > 0, i >= 1.
function osmotic_pressure(molarity: float, t_k: float, i: float) -> float {
    if (molarity < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molarity cannot be negative.");
        c_exit(2);
    };
    if (t_k <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Temperature must be positive (Kelvin).");
        c_exit(2);
    };
    if (i < 1.0) {
        c_print_err("MochaLibError (mocha-chem): van't Hoff factor must be >= 1 for colligative properties.");
        c_exit(2);
    };
    return molarity * R_GAS * t_k * i;
};

~~ raoult_law_ideal: vapour pressure of ideal solution. P_solution = x_solvent * P_pure.
~~ Requires x_solvent in [0, 1], p_pure >= 0.
function raoult_law_ideal(x_solvent: float, p_pure: float) -> float {
    if (x_solvent < 0.0 || x_solvent > 1.0) {
        c_print_err("MochaLibError (mocha-chem): Solvent mole fraction must be in [0, 1].");
        c_exit(2);
    };
    if (p_pure < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Pure solvent vapour pressure cannot be negative.");
        c_exit(2);
    };
    return x_solvent * p_pure;
};

~~ raoult_law_pressure_lowering: delta_P = x_solute * P_pure.
~~ Requires x_solute in [0, 1], p_pure >= 0.
function raoult_law_pressure_lowering(x_solute: float, p_pure: float) -> float {
    if (x_solute < 0.0 || x_solute > 1.0) {
        c_print_err("MochaLibError (mocha-chem): Solute mole fraction must be in [0, 1].");
        c_exit(2);
    };
    if (p_pure < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Pure solvent vapour pressure cannot be negative.");
        c_exit(2);
    };
    return x_solute * p_pure;
};

~~ henry_law: dissolved gas concentration from partial pressure (mol/L). C = k_H * P.
~~ Requires k_h >= 0, partial_pressure >= 0.
function henry_law(k_h: float, partial_pressure: float) -> float {
    if (k_h < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Henry's law constant cannot be negative.");
        c_exit(2);
    };
    if (partial_pressure < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Partial pressure cannot be negative.");
        c_exit(2);
    };
    return k_h * partial_pressure;
};

~~ molarity_to_molality: convert molarity to molality (mol/kg).
~~ m = (M * 1000) / (rho - M * molar_mass). Requires molarity >= 0, rho_g_per_l > 0, molar_mass > 0.
~~ Errors if denominator (rho - M*molar_mass) <= 0 (impossible solution density).
function molarity_to_molality(molarity: float, rho_g_per_l: float, molar_mass: float) -> float {
    if (molarity < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molarity cannot be negative.");
        c_exit(2);
    };
    if (rho_g_per_l <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Solution density must be positive.");
        c_exit(2);
    };
    if (molar_mass <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molar mass must be positive.");
        c_exit(2);
    };
    const DENOM: float = rho_g_per_l - (molarity * molar_mass);
    if (DENOM <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Solvent mass per litre is non-positive — solution density too low for this concentration.");
        c_exit(2);
    };
    return (molarity * 1000.0) / DENOM;
};

~~ mole_fraction_to_molality: convert mole fraction to molality (mol/kg).
~~ m = x_solute / (x_solvent * M_solvent). Requires x_solute >= 0, x_solvent > 0, m_solvent_kg > 0.
~~ Errors if x_solute + x_solvent != 1 (within tolerance).
function mole_fraction_to_molality(x_solute: float, x_solvent: float, m_solvent_kg: float) -> float {
    if (x_solute < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Solute mole fraction cannot be negative.");
        c_exit(2);
    };
    if (x_solvent <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Solvent mole fraction must be positive.");
        c_exit(2);
    };
    if (m_solvent_kg <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Solvent molar mass must be positive.");
        c_exit(2);
    };
    if (abs((x_solute + x_solvent) - 1.0) > 0.001) {
        c_print_err("MochaLibError (mocha-chem): Mole fractions must sum to 1.0 (within 0.001 tolerance).");
        c_exit(2);
    };
    return x_solute / (x_solvent * m_solvent_kg);
};

~~ van_t_hoff_factor_apparent: observed i from colligative property measurement. i = delta_T / (K * molality).
~~ Requires delta_t >= 0, k_const > 0, molality > 0.
function van_t_hoff_factor_apparent(delta_t: float, k_const: float, molality: float) -> float {
    if (delta_t < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Colligative property change cannot be negative.");
        c_exit(2);
    };
    if (k_const <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Colligative constant must be positive.");
        c_exit(2);
    };
    if (molality <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molality must be positive.");
        c_exit(2);
    };
    return delta_t / (k_const * molality);
};

~~ degree_of_dissociation_vant: fraction dissociated from van't Hoff factor. alpha = (i - 1) / (n - 1).
~~ Requires i >= 1, n > 1 (use only for electrolytes), i <= n (alpha must be <= 1).
function degree_of_dissociation_vant(i: float, n: float) -> float {
    if (i < 1.0) {
        c_print_err("MochaLibError (mocha-chem): van't Hoff factor must be >= 1.");
        c_exit(2);
    };
    if (n <= 1.0) {
        c_print_err("MochaLibError (mocha-chem): Number of ions per formula unit must be > 1 (use only for electrolytes).");
        c_exit(2);
    };
    if (i > n) {
        c_print_err("MochaLibError (mocha-chem): van't Hoff factor cannot exceed n (degree of dissociation would exceed 100%).");
        c_exit(2);
    };
    return (i - 1.0) / (n - 1.0);
};

// ─── Section 9: Inorganic / Solid State ───────────────────────────────────

const AVOGADRO: float = 6.02214E23;              // 6.02214 × 10²³
const COULOMB_K: float = 8.98755E9;              // 8.98755 × 10⁹ N·m²/C²
const ELEM_CHARGE: float = 1.60218E-19;          // 1.60218 × 10⁻¹⁹ C

~~ born_lande_lattice_energy: lattice energy via Born-Landé equation (J/mol).
~~ Requires m_const > 0, r0_m > 0, n_born > 1.
~~ Uses unsafe_mul: elementary charge is quantum-scale, underflows fixed-point.
function born_lande_lattice_energy(m_const: float, z_plus: float, z_minus: float, r0_m: float, n_born: float) -> float {
    if (m_const <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Madelung constant must be positive.");
        c_exit(2);
    };
    if (r0_m <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Internuclear distance must be positive.");
        c_exit(2);
    };
    if (n_born <= 1.0) {
        c_print_err("MochaLibError (mocha-chem): Born exponent must be > 1 (typically 5-12).");
        c_exit(2);
    };
    const E_SQ: float = float(unsafe_mul(ELEM_CHARGE, ELEM_CHARGE));
    const STEP1: float = float(unsafe_mul(AVOGADRO, m_const));
    const STEP2: float = float(unsafe_mul(STEP1, z_plus * z_minus));
    const STEP3: float = float(unsafe_mul(STEP2, E_SQ));
    const NUMER: float = float(unsafe_mul(STEP3, COULOMB_K));
    const BASE: float = NUMER / r0_m;
    const BORN_FACTOR: float = 1.0 - (1.0 / n_born);
    return -(BASE) * BORN_FACTOR;
};

~~ born_haber_lattice_energy: lattice energy from Born-Haber cycle (kJ/mol). No constraints.
~~ U = dHf - dHsub - dHdiss - IE - EA (Hess's law arrangement).
function born_haber_lattice_energy(delta_hf: float, delta_hsub: float, delta_hdiss: float, ie: float, ea: float) -> float {
    return delta_hf - delta_hsub - delta_hdiss - ie - ea;
};

~~ kapustinskii_lattice_energy: lattice energy without crystal structure (kJ/mol).
~~ Requires nu_ions >= 2, r0_pm > 0.
~~ U = (1.2025e5 * nu * |z+z-| / r0) * (1 - 0.345/r0) | r0_pm in picometres.
function kapustinskii_lattice_energy(nu_ions: float, z_plus: float, z_minus: float, r0_pm: float) -> float {
    if (nu_ions < 2.0) {
        c_print_err("MochaLibError (mocha-chem): Ion count per formula unit must be >= 2 for ionic crystals.");
        c_exit(2);
    };
    if (r0_pm <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Internuclear distance must be positive.");
        c_exit(2);
    };
    const FACTOR: float = 120250.0 * nu_ions * z_plus * z_minus / r0_pm;
    const CORRECTION: float = 1.0 - (0.345 / r0_pm);
    return FACTOR * CORRECTION;
};

~~ crystal_field_stabilization_energy: CFSE for octahedral complex (cm^-1).
~~ Requires n_t2g in [0, 6], n_eg in [0, 4], delta_o >= 0.
~~ CFSE = (-0.4*n_t2g + 0.6*n_eg) * delta_o.
function crystal_field_stabilization_energy(n_t2g: float, n_eg: float, delta_o: float) -> float {
    if (n_t2g < 0.0 || n_t2g > 6.0) {
        c_print_err("MochaLibError (mocha-chem): t2g electron count must be in [0, 6] (octahedral capacity).");
        c_exit(2);
    };
    if (n_eg < 0.0 || n_eg > 4.0) {
        c_print_err("MochaLibError (mocha-chem): eg electron count must be in [0, 4] (octahedral capacity).");
        c_exit(2);
    };
    if (delta_o < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Crystal field splitting must be non-negative.");
        c_exit(2);
    };
    return ((-0.4 * n_t2g) + (0.6 * n_eg)) * delta_o;
};

~~ ionic_radius_ratio: rho = r_cation / r_anion (dimensionless).
~~ Requires r_cation > 0, r_anion > 0.
function ionic_radius_ratio(r_cation: float, r_anion: float) -> float {
    if (r_cation <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Cation radius must be positive.");
        c_exit(2);
    };
    if (r_anion <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Anion radius must be positive.");
        c_exit(2);
    };
    return r_cation / r_anion;
};

~~ pauling_ionic_character: percent ionic character of a bond (%).
~~ %ionic = (1 - exp(-0.25*(delta_chi)^2)) * 100. No constraints (Δχ sign doesn't matter).
function pauling_ionic_character(delta_chi: float) -> float {
    const EXPONENT: float = -(0.25 * (delta_chi * delta_chi));
    const FRACTION: float = 1.0 - float(c_exp(EXPONENT));
    return FRACTION * 100.0;
};

~~ madelung_energy_per_ion: electrostatic energy per ion pair (J).
~~ Requires m_const > 0, r0_m > 0.
~~ Uses unsafe_mul: elementary charge is quantum-scale, underflows fixed-point.
function madelung_energy_per_ion(m_const: float, r0_m: float) -> float {
    if (m_const <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Madelung constant must be positive.");
        c_exit(2);
    };
    if (r0_m <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Internuclear distance must be positive.");
        c_exit(2);
    };
    const E_SQ: float = float(unsafe_mul(ELEM_CHARGE, ELEM_CHARGE));
    const STEP1: float = float(unsafe_mul(COULOMB_K, m_const));
    const STEP2: float = float(unsafe_mul(STEP1, E_SQ));
    return -(STEP2) / r0_m;
};

// ─── Section 10: Organic-Adjacent Calculations ────────────────────────────

~~ degree_of_unsaturation: DoU = (2C + 2 + N - H) / 2.
~~ Halogens count as H. C >= 0, H >= 0, N >= 0.
~~ Errors if the result is non-integer (invalid formula) or negative (impossible composition).
function degree_of_unsaturation(c_count: float, h_count: float, n_count: float) -> float {
    if (c_count < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Carbon count cannot be negative.");
        c_exit(2);
    };
    if (h_count < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Hydrogen (and halogen) count cannot be negative.");
        c_exit(2);
    };
    if (n_count < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Nitrogen count cannot be negative.");
        c_exit(2);
    };
    var dou: float = ((2.0 * c_count) + 2.0 + n_count - h_count) / 2.0;
    if (dou < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Negative degree of unsaturation — formula violates valence rules.");
        c_exit(2);
    };
    if (abs(dou - rdown(dou)) > 1E-6) {
        c_print_err("MochaLibError (mocha-chem): Degree of unsaturation must be an integer — check atom counts.");
        c_exit(2);
    };
    return dou;
};

~~ empirical_ratio: ratio of an element's moles to the smallest mole count in the sample.
~~ moles_element >= 0, moles_smallest > 0.
function empirical_ratio(moles_element: float, moles_smallest: float) -> float {
    if (moles_element < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Element moles cannot be negative.");
        c_exit(2);
    };
    if (moles_smallest <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Smallest mole count must be positive.");
        c_exit(2);
    };
    return moles_element / moles_smallest;
};

~~ molecular_formula_multiplier: n = molar_mass_actual / empirical_formula_mass.
~~ Requires molar_mass_actual > 0, empirical_formula_mass > 0.
~~ Errors if result is non-integer (empirical and molecular masses are inconsistent).
function molecular_formula_multiplier(molar_mass_actual: float, empirical_formula_mass: float) -> float {
    if (molar_mass_actual <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molar mass must be positive.");
        c_exit(2);
    };
    if (empirical_formula_mass <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Empirical formula mass must be positive.");
        c_exit(2);
    };
    var mult: float = molar_mass_actual / empirical_formula_mass;
    if (abs(mult - rup(mult)) > 0.05 && abs(mult - rdown(mult)) > 0.05) {
        c_print_err("MochaLibError (mocha-chem): Molecular formula multiplier is not near an integer — empirical and molecular masses are inconsistent.");
        c_exit(2);
    };
    return mult;
};

~~ moles_from_combustion_co2: moles of carbon in sample from CO2 produced (mol).
~~ Requires mass_co2_g >= 0. moles_C = mass_CO2 / 44.01.
function moles_from_combustion_co2(mass_co2_g: float) -> float {
    if (mass_co2_g < 0.0) {
        c_print_err("MochaLibError (mocha-chem): CO2 mass cannot be negative.");
        c_exit(2);
    };
    return mass_co2_g / 44.01;
};

~~ moles_from_combustion_h2o: moles of hydrogen in sample from H2O produced (mol).
~~ Requires mass_h2o_g >= 0. moles_H = 2 * (mass_H2O / 18.015).
function moles_from_combustion_h2o(mass_h2o_g: float) -> float {
    if (mass_h2o_g < 0.0) {
        c_print_err("MochaLibError (mocha-chem): H2O mass cannot be negative.");
        c_exit(2);
    };
    return 2.0 * (mass_h2o_g / 18.015);
};

~~ mass_oxygen_by_difference: mass of oxygen in CHO sample (g).
~~ mass_O = mass_sample - mass_C - mass_H. Requires all masses >= 0 and mass_C + mass_H <= mass_sample.
function mass_oxygen_by_difference(mass_sample_g: float, mass_c_g: float, mass_h_g: float) -> float {
    if (mass_sample_g < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Sample mass cannot be negative.");
        c_exit(2);
    };
    if (mass_c_g < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Carbon mass cannot be negative.");
        c_exit(2);
    };
    if (mass_h_g < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Hydrogen mass cannot be negative.");
        c_exit(2);
    };
    if (mass_c_g + mass_h_g > mass_sample_g) {
        c_print_err("MochaLibError (mocha-chem): Carbon + hydrogen mass exceeds sample mass — oxygen mass would be negative.");
        c_exit(2);
    };
    return mass_sample_g - mass_c_g - mass_h_g;
};

// ─── Section 11: Spectroscopy ──────────────────────────────────────────────

~~ beer_lambert_absorbance: A = epsilon * c * l.
~~ Requires epsilon >= 0, conc >= 0, path_length_cm >= 0.
function beer_lambert_absorbance(epsilon: float, conc: float, path_length_cm: float) -> float {
    if (epsilon < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molar absorptivity cannot be negative.");
        c_exit(2);
    };
    if (conc < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Concentration cannot be negative.");
        c_exit(2);
    };
    if (path_length_cm < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Path length cannot be negative.");
        c_exit(2);
    };
    return epsilon * conc * path_length_cm;
};

~~ beer_lambert_concentration: solve for concentration from absorbance (mol/L). c = A / (epsilon * l).
~~ Requires absorbance >= 0, epsilon > 0, path_length_cm > 0.
function beer_lambert_concentration(absorbance: float, epsilon: float, path_length_cm: float) -> float {
    if (absorbance < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Absorbance cannot be negative.");
        c_exit(2);
    };
    if (epsilon <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Molar absorptivity must be positive (division requires nonzero).");
        c_exit(2);
    };
    if (path_length_cm <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Path length must be positive (division requires nonzero).");
        c_exit(2);
    };
    return absorbance / (epsilon * path_length_cm);
};

~~ transmittance_from_absorbance: T = 10^(-A) (fraction, 0-1).
~~ Requires absorbance >= 0. Errors if result would overflow/underflow.
function transmittance_from_absorbance(absorbance: float) -> float {
    if (absorbance < 0.0) {
        c_print_err("MochaLibError (mocha-chem): Absorbance cannot be negative.");
        c_exit(2);
    };
    if (absorbance > 700.0) {
        c_print_err("MochaLibError (mocha-chem): Absorbance too large — transmittance would underflow.");
        c_exit(2);
    };
    return float(c_pow(10.0, -(absorbance)));
};

~~ absorbance_from_transmittance: A = -log10(T).
~~ Requires transmittance in (0, 1].
function absorbance_from_transmittance(transmittance: float) -> float {
    if (transmittance <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Transmittance must be positive (log10 undefined for zero/negative).");
        c_exit(2);
    };
    if (transmittance > 1.0) {
        c_print_err("MochaLibError (mocha-chem): Transmittance cannot exceed 1.0 (would give negative absorbance).");
        c_exit(2);
    };
    const LOG10_T: float = transmittance.log10().real;
    return -(LOG10_T);
};

~~ wavelength_to_frequency: f = c / lambda (Hz). Requires wavelength_m > 0.
function wavelength_to_frequency(wavelength_m: float) -> float {
    if (wavelength_m <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Wavelength must be positive.");
        c_exit(2);
    };
    return SPEED_OF_LIGHT / wavelength_m;
};

~~ frequency_to_wavelength: lambda = c / f (m). Requires freq_hz > 0.
function frequency_to_wavelength(freq_hz: float) -> float {
    if (freq_hz <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Frequency must be positive.");
        c_exit(2);
    };
    return SPEED_OF_LIGHT / freq_hz;
};

~~ wavenumber_to_wavelength: lambda = 1 / wavenumber. Requires wavenumber > 0.
function wavenumber_to_wavelength(wavenumber: float) -> float {
    if (wavenumber <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Wavenumber must be positive.");
        c_exit(2);
    };
    return 1.0 / wavenumber;
};

~~ wavelength_to_wavenumber: wavenumber = 1 / lambda. Requires wavelength > 0.
function wavelength_to_wavenumber(wavelength: float) -> float {
    if (wavelength <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Wavelength must be positive.");
        c_exit(2);
    };
    return 1.0 / wavelength;
};

~~ energy_per_mole_photons: energy of one mole of photons at given frequency (J/mol).
~~ Requires freq_hz > 0. E_mol = N_A * h * f.
~~ Uses unsafe_mul: N_A is astronomically large.
function energy_per_mole_photons(freq_hz: float) -> float {
    if (freq_hz <= 0.0) {
        c_print_err("MochaLibError (mocha-chem): Frequency must be positive.");
        c_exit(2);
    };
    const E_PHOTON: float = float(unsafe_mul(PLANCK, freq_hz));
    return float(unsafe_mul(AVOGADRO, E_PHOTON));
};