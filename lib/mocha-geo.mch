~~ mocha-geo — Geoscience Library for Mocha
~~ Section 1: Seismology
~~ Section 2: Mineralogy & Crystallography
~~
~~ Part of the Mocha Scientific Library Ecosystem
~~ License: Polyform Non-Commercial

// mocha-lib-deps: mocha-math
function c_exp(x: float) -> float native mocha_wrap_exp;
function c_print_err(msg: str) -> null native mocha_print_stderr;
function c_exit(code: int) -> null native mocha_exit;
function unsafe_mul(a: float, b: float) -> float native mocha_unsafe_mul;
function unsafe_div(a: float, b: float) -> float native mocha_unsafe_div;
function unsafe_add(a: float, b: float) -> float native mocha_unsafe_add;
function unsafe_sub(a: float, b: float) -> float native mocha_unsafe_sub;

const DEG_TO_RAD: float = 0.01745329251994;
const RAD_TO_DEG: float = 57.29577951308232;
const DENSITY_FACTOR: float = 1.6605;

// ================================================================
// SECTION 1: SEISMOLOGY
// ================================================================

~~ Computes Richter local magnitude (ML) from peak Wood-Anderson amplitude
~~ and epicentral distance. amplitude_mm in mm, distance_km in km.
function richter_magnitude(amplitude_mm: float, distance_km: float) -> float {
    const LOG10_A: float = amplitude_mm.log10().real;
    const LOG10_D: float = distance_km.log10().real;
    return LOG10_A + 1.11 * LOG10_D + 0.00189 * distance_km - 2.09;
};

~~ Computes moment magnitude (Mw) from scalar seismic moment M0 in N·m.
~~ Uses Hanks & Kanamori (1979): Mw = (2/3)*log10(M0) - 6.07.
function moment_magnitude(m0: float) -> float {
    const LOG10_M0: float = m0.log10().real;
    return (2.0 / 3.0) * LOG10_M0 - 6.07;
};

~~ Computes scalar seismic moment M0 = μ * A * D in N·m.
~~ rigidity in Pa, area in m², slip in m.
~~ Uses unsafe_mul: real fault products far exceed fixed-point range.
function seismic_moment(rigidity: float, area: float, slip: float) -> float {
    const STEP1: float = float(unsafe_mul(rigidity, area));
    const M0: float = float(unsafe_mul(STEP1, slip));
    return M0;
};

~~ Radiated seismic energy in joules from moment magnitude.
~~ Gutenberg-Richter energy relation: E = 10^(1.5*Mw + 4.8).
~~ Keep test values Mw <= 6.0 to stay within fixed-point range.
function energy_release(mw: float) -> float {
    const EXPONENT: float = 1.5 * mw + 4.8;
    const ENERGY: float = float(c_pow(10.0, EXPONENT));
    return ENERGY;
};

~~ P-wave travel time in seconds from epicentral distance and P-wave velocity.
~~ distance_km in km, vp in km/s (typical crustal range: 5.5-8.0).
function p_wave_travel_time(distance_km: float, vp: float) -> float {
    return distance_km / vp;
};

~~ S-wave travel time in seconds from epicentral distance and S-wave velocity.
~~ distance_km in km, vs in km/s (typical crustal range: 3.0-5.0).
function s_wave_travel_time(distance_km: float, vs: float) -> float {
    return distance_km / vs;
};

~~ Estimates epicentral distance in km from S-P arrival time interval.
~~ Wadati method: distance = (vp*vs)/(vp-vs) * (ts-tp).
function sp_time_interval_distance(sp_interval: float, vp: float, vs: float) -> float {
    const VP_VS: float = vp * vs;
    const VP_MINUS_VS: float = vp - vs;
    return (VP_VS / VP_MINUS_VS) * sp_interval;
};

~~ Estimates epicenter lat/lon from three station distances via flat-Earth trilateration.
~~ d1/d2/d3 in km. lat/lon in degrees. Valid for distances < 500 km.
~~ Returns (lat, lon) tuple.
function epicenter_triangulation(d1: float, d2: float, d3: float, lat1: float, lon1: float, lat2: float, lon2: float, lat3: float, lon3: float) -> (float, 2) {
    const KM_LAT: float = 111.32;
    const LAT1_RAD: float = lat1 * DEG_TO_RAD;
    const COS_LAT: float = LAT1_RAD.cos(RAD);
    const KM_LON: float = KM_LAT * COS_LAT;

    const X2: float = (lon2 - lon1) * KM_LON;
    const Y2: float = (lat2 - lat1) * KM_LAT;
    const X3: float = (lon3 - lon1) * KM_LON;
    const Y3: float = (lat3 - lat1) * KM_LAT;

    const D1SQ: float = d1 * d1;
    const D2SQ: float = d2 * d2;
    const D3SQ: float = d3 * d3;

    const A_COEF: float = 2.0 * X2;
    const B_COEF: float = 2.0 * Y2;
    const C_COEF: float = D1SQ - D2SQ + X2*X2 + Y2*Y2;
    const D_COEF: float = 2.0 * X3;
    const E_COEF: float = 2.0 * Y3;
    const F_COEF: float = D1SQ - D3SQ + X3*X3 + Y3*Y3;

    const DENOM: float = A_COEF*E_COEF - B_COEF*D_COEF;
    const X_EPI: float = (C_COEF*E_COEF - B_COEF*F_COEF) / DENOM;
    const Y_EPI: float = (A_COEF*F_COEF - C_COEF*D_COEF) / DENOM;

    const LAT_EPI: float = lat1 + Y_EPI / KM_LAT;
    const LON_EPI: float = lon1 + X_EPI / KM_LON;

    return (LAT_EPI, LON_EPI);
};

~~ Peak ground acceleration in g from moment magnitude and distance.
~~ Joyner-Boore (1981) simplified attenuation relation.
~~ Valid range: Mw 5.0-7.5, distance 10-100 km.
function peak_ground_acceleration(mw: float, distance_km: float) -> float {
    const LOG10_R: float = distance_km.log10().real;
    const LOG10_PGA: float = 0.49 + 0.23 * (mw - 6.0) - LOG10_R - 0.0027 * distance_km;
    const PGA: float = float(c_pow(10.0, LOG10_PGA));
    return PGA;
};

~~ Estimates Modified Mercalli Intensity (MMI) from peak ground acceleration in g.
~~ Wald et al. (1999). Returns continuous value; round to nearest 0.5 for reporting.
function mercalli_intensity_estimate(pga_g: float) -> float {
    const LOG10_PGA: float = pga_g.log10().real;
    return 3.66 * LOG10_PGA + 9.287;
};

// ================================================================
// SECTION 2: MINERALOGY & CRYSTALLOGRAPHY
// ================================================================

tag CrystalStructure {
  FCC,
  BCC,
  HCP,
  SC
};

~~ Specific gravity of a mineral as ratio of its density to water (1000 kg/m³).
~~ Input density in kg/m³. Returns dimensionless SG value.
function specific_gravity(density_kg_m3: float) -> float {
    return density_kg_m3 / 1000.0;
};

~~ Unit cell volume in Å³ from lattice parameters using general triclinic formula.
~~ a, b, c in Angstroms; alpha, beta, gamma in degrees. Covers all 7 crystal systems.
function unit_cell_volume(a: float, b: float, c: float, alpha: float, beta: float, gamma: float) -> float {
    const COS_A: float = alpha.cos(DEG);
    const COS_B: float = beta.cos(DEG);
    const COS_G: float = gamma.cos(DEG);
    const CA2: float = COS_A * COS_A;
    const CB2: float = COS_B * COS_B;
    const CG2: float = COS_G * COS_G;
    const CROSS: float = 2.0 * COS_A * COS_B * COS_G;
    const INNER: float = 1.0 - CA2 - CB2 - CG2 + CROSS;
    const SQRT_INNER: float = INNER.sqrt().real;
    const ABC: float = a * b * c;
    return ABC * SQRT_INNER;
};

~~ Theoretical density in g/cm³ from unit cell parameters.
~~ formula_mass in g/mol, z = atoms per unit cell, cell_volume in Å³.
~~ Uses 1.6605 conversion factor (1e24 / Avogadro).
function theoretical_density(formula_mass: float, z: float, cell_volume: float) -> float {
    const NUMERATOR: float = z * formula_mass * DENSITY_FACTOR;
    return NUMERATOR / cell_volume;
};

~~ Bragg diffraction angle θ in degrees from wavelength, d-spacing, and reflection order n.
~~ wavelength and d_spacing in Angstroms. Note: diffractometers report 2θ, so double if needed.
function bragg_angle(wavelength: float, d_spacing: float, n: int) -> float {
    const SIN_THETA: float = (float(n) * wavelength) / (2.0 * d_spacing);
    const THETA_RAD: float = SIN_THETA.inv_sin().real;
    return THETA_RAD * RAD_TO_DEG;
};

~~ d-spacing in Angstroms for cubic crystal system from Miller indices (hkl).
~~ d = a / sqrt(h² + k² + l²). a in Angstroms.
function d_spacing_cubic(a: float, h: int, k: int, l: int) -> float {
    const SUM_SQ: float = float(h*h + k*k + l*l);
    const SQRT_SUM: float = SUM_SQ.sqrt().real;
    return a / SQRT_SUM;
};

~~ d-spacing in Angstroms for hexagonal crystal system from Miller indices (hkl).
~~ Covers quartz, calcite, apatite and most rock-forming hexagonal minerals.
function d_spacing_hexagonal(a: float, c: float, h: int, k: int, l: int) -> float {
    const HH: float = float(h*h);
    const HK: float = float(h*k);
    const KK: float = float(k*k);
    const LL: float = float(l*l);
    const TERM1: float = (4.0 / 3.0) * (HH + HK + KK) / (a*a);
    const TERM2: float = LL / (c*c);
    const INV_D2: float = TERM1 + TERM2;
    const INV_D: float = INV_D2.sqrt().real;
    return 1.0 / INV_D;
};

~~ Estimates Vickers hardness (HV) from Mohs hardness scale value.
~~ Tabor empirical approximation: HV ≈ 10^(0.6 * Mohs). Rough ±50%.
function mohs_to_vickers_estimate(mohs: float) -> float {
    const EXPONENT: float = 0.6 * mohs;
    return float(c_pow(10.0, EXPONENT));
};

~~ Atomic packing efficiency for ideal hard-sphere model by crystal structure.
~~ FCC/HCP: 0.7405 | BCC: 0.6802 | SC: 0.5236.
function packing_efficiency(structure: CrystalStructure) -> float {
    var result: float = 0.0;
    match(structure) {
        case CrystalStructure.FCC: result = 0.7405;
        case CrystalStructure.BCC: result = 0.6802;
        case CrystalStructure.HCP: result = 0.7405;
        case CrystalStructure.SC:  result = 0.5236;
        default:                   result = 0.0;
    };
    return result;
};

~~ Predicted coordination number from Pauling radius ratio rule.
~~ radius_cation and radius_anion in same units (typically Angstroms).
function coordination_number_estimate(radius_cation: float, radius_anion: float) -> int {
    const RATIO: float = radius_cation / radius_anion;
    if (RATIO < 0.155) {
        return 2;
    };
    if (RATIO < 0.225) {
        return 3;
    };
    if (RATIO < 0.414) {
        return 4;
    };
    if (RATIO < 0.732) {
        return 6;
    };
    if (RATIO < 1.0) {
        return 8;
    };
    return 12;
};

~~ Madelung constant for common ionic crystal structures, looked up by coordination number.
~~ CN 4: zinc blende (1.6381) | CN 6: NaCl rock salt (1.7476) | CN 8: CsCl (1.7627).
function madelung_constant_estimate(coordination_number: int) -> float {
    if (coordination_number == 2) {
        return 1.0000;
    } else if (coordination_number == 3) {
        return 1.3765;
    } else if (coordination_number == 4) {
        return 1.6381;
    } else if (coordination_number == 6) {
        return 1.7476;
    } else if (coordination_number == 8) {
        return 1.7627;
    } else if (coordination_number == 12) {
        return 1.7918;
    } else{
        c_print_err("MochaLibError (mocha-geo): Madelung constant for CN " + str(coordination_number) + " is undefined.");
        c_exit(2);
    };
    return 0.0;
};

// ================================================================
// SECTION 3: STRUCTURAL GEOLOGY & PLATE TECTONICS
// ================================================================

~~ Plate velocity in cm/yr from displacement in km and time in Myr.
~~ Conversion: 1 km/Myr = 0.1 cm/yr.
function plate_velocity(displacement_km: float, time_myr: float) -> float {
    const V_KM_MYR: float = displacement_km / time_myr;
    return V_KM_MYR * 0.1;
};

~~ Linear plate velocity in cm/yr from Euler pole angular velocity and angular distance.
~~ angular_velocity in deg/Myr, angular_distance in degrees (angle from Euler pole).
~~ v = ω * R * sin(δ), using Earth radius R = 6371 km.
function euler_pole_velocity(angular_velocity_deg_myr: float, angular_distance_deg: float) -> float {
    const R: float = 6371.0;
    const OMEGA_RAD: float = angular_velocity_deg_myr * DEG_TO_RAD;
    const DELTA_RAD: float = angular_distance_deg * DEG_TO_RAD;
    const SIN_DELTA: float = DELTA_RAD.sin(RAD);
    const V_KM_MYR: float = OMEGA_RAD * R * SIN_DELTA;
    return V_KM_MYR * 0.1;
};

~~ Relative plate motion vector from two absolute plate velocity vectors (cm/yr).
~~ Returns (rel_vx, rel_vy) = (v1 - v2) as a tuple.
function relative_plate_motion(vx1: float, vy1: float, vx2: float, vy2: float) -> (float, 2) {
    const REL_VX: float = vx1 - vx2;
    const REL_VY: float = vy1 - vy2;
    return (REL_VX, REL_VY);
};

~~ Normal stress on a plane oriented at angle theta from sigma1, using 2D Mohr circle relation.
~~ sigma1, sigma3 in MPa (or consistent units), theta in degrees.
function normal_stress(sigma1: float, sigma3: float, theta_deg: float) -> float {
    const THETA_RAD: float = theta_deg * DEG_TO_RAD;
    const TWO_THETA: float = 2.0 * THETA_RAD;
    const COS_2T: float = TWO_THETA.cos(RAD);
    const AVG: float = (sigma1 + sigma3) / 2.0;
    const DIFF: float = (sigma1 - sigma3) / 2.0;
    return AVG + DIFF * COS_2T;
};

~~ Shear stress on a plane oriented at angle theta, using 2D Mohr circle relation.
~~ sigma1, sigma3 in MPa (or consistent units), theta in degrees.
function shear_stress(sigma1: float, sigma3: float, theta_deg: float) -> float {
    const THETA_RAD: float = theta_deg * DEG_TO_RAD;
    const TWO_THETA: float = 2.0 * THETA_RAD;
    const SIN_2T: float = TWO_THETA.sin(RAD);
    const DIFF: float = (sigma1 - sigma3) / 2.0;
    return DIFF * SIN_2T;
};

~~ True dip in degrees from apparent dip and the angle between the vertical cross-section and true dip direction.
~~ tan(true_dip) = tan(apparent_dip) / cos(alpha).
function true_dip(apparent_dip_deg: float, alpha_deg: float) -> float {
    const APP_RAD: float = apparent_dip_deg * DEG_TO_RAD;
    const ALPHA_RAD: float = alpha_deg * DEG_TO_RAD;
    const TAN_APP: float = APP_RAD.tan(RAD);
    const COS_ALPHA: float = ALPHA_RAD.cos(RAD);
    const TAN_TRUE: float = TAN_APP / COS_ALPHA;
    const TRUE_RAD: float = TAN_TRUE.inv_tan();
    return TRUE_RAD * RAD_TO_DEG;
};

~~ Strike in degrees from dip direction, using the rule strike = dip_direction - 90°.
~~ Wraps result into [0, 360) range.
function strike_from_dip_direction(dip_direction_deg: float) -> float {
    var strike: float = dip_direction_deg - 90.0;
    if (strike < 0.0) {
        strike = strike + 360.0;
    };
    return strike;
};

~~ Crustal root depth in km via Airy isostasy from topographic elevation and density contrast.
~~ elevation_km in km, crust_density and mantle_density in kg/m³.
~~ r = h * ρc / (ρm - ρc).
function airy_isostasy_root(elevation_km: float, crust_density: float, mantle_density: float) -> float {
    const NUMERATOR: float = elevation_km * crust_density;
    const DENOM: float = mantle_density - crust_density;
    return NUMERATOR / DENOM;
};

~~ Fault heave and throw from slip vector magnitude and dip angle.
~~ slip in any length unit, dip_deg in degrees. Returns (heave, throw) tuple.
function fault_heave_throw(slip: float, dip_deg: float) -> (float, 2) {
    const DIP_RAD: float = dip_deg * DEG_TO_RAD;
    const COS_DIP: float = DIP_RAD.cos(RAD);
    const SIN_DIP: float = DIP_RAD.sin(RAD);
    const HEAVE: float = slip * COS_DIP;
    const THROW: float = slip * SIN_DIP;
    return (HEAVE, THROW);
};

~~ Strain ellipse axial ratio Rs from principal extensions e1 (max) and e3 (min).
~~ Rs = (1 + e1) / (1 + e3). e1, e3 as decimal extension values (e.g. 0.3 = 30%).
function strain_ellipse_ratio(e1: float, e3: float) -> float {
    const NUMERATOR: float = 1.0 + e1;
    const DENOM: float = 1.0 + e3;
    return NUMERATOR / DENOM;
};

// ================================================================
// SECTION 4: HYDROLOGY
// ================================================================

~~ Hydraulic gradient (dimensionless) between two points in an aquifer.
~~ h1, h2 = hydraulic head at points 1 and 2 (same length units), L = distance between them.
function hydraulic_gradient(h1: float, h2: float, distance: float) -> float {
    return (h1 - h2) / distance;
};

~~ Darcy flux (specific discharge) in m/s from hydraulic conductivity and gradient.
~~ K = hydraulic conductivity (m/s), i = hydraulic gradient (dimensionless).
function darcy_flux(k: float, i: float) -> float {
    return k * i;
};

~~ Darcy volumetric discharge in m³/s through a cross-sectional area.
~~ K in m/s, area in m², i = hydraulic gradient.
function darcy_discharge(k: float, area: float, i: float) -> float {
    return k * area * i;
};

~~ Aquifer transmissivity in m²/s from hydraulic conductivity and saturated thickness.
~~ K in m/s, thickness in m.
function transmissivity(k: float, thickness: float) -> float {
    return k * thickness;
};

~~ Seepage (linear) velocity in m/s, the actual average velocity of water through pore spaces.
~~ darcy_flux in m/s, porosity as decimal fraction (e.g. 0.3 = 30%).
function seepage_velocity(darcy_flux_val: float, porosity: float) -> float {
    return darcy_flux_val / porosity;
};

~~ Porosity as a decimal fraction from void volume and total volume.
~~ Same units for both volumes.
function porosity(void_volume: float, total_volume: float) -> float {
    return void_volume / total_volume;
};

~~ Open-channel flow velocity in m/s via Manning's equation.
~~ manning_n = roughness coefficient (dimensionless), hydraulic_radius in m, slope as decimal.
function manning_velocity(manning_n: float, hydraulic_radius: float, slope: float) -> float {
    const R_EXP: float = float(c_pow(hydraulic_radius, 0.666667));
    const S_SQRT: float = slope.sqrt().real;
    return (1.0 / manning_n) * R_EXP * S_SQRT;
};

~~ Stream discharge in m³/s from channel cross-sectional area and average velocity.
~~ area in m², velocity in m/s.
function stream_discharge(area: float, velocity: float) -> float {
    return area * velocity;
};

~~ Reynolds number for pipe flow (dimensionless), determines laminar vs turbulent regime.
~~ velocity in m/s, diameter in m, kinematic_viscosity in m²/s (water ≈ 1.0e-6).
function reynolds_number_pipe(velocity: float, diameter: float, kinematic_viscosity: float) -> float {
    return (velocity * diameter) / kinematic_viscosity;
};

~~ Cooper-Jacob approximation for aquifer drawdown at distance r and time t (confined aquifer, pumping test).
~~ Q in m³/s, T = transmissivity in m²/s, t in seconds, r in m, S = storativity (dimensionless).
~~ Valid for large t / small r (u < 0.01).
function cooper_jacob_drawdown(q: float, t_aquifer: float, time_s: float, r: float, storativity: float) -> float {
    const COEF: float = (2.3 * q) / (4.0 * PI * t_aquifer);
    const NUMERATOR: float = 2.25 * t_aquifer * time_s;
    const DENOM: float = r * r * storativity;
    const LOG_ARG: float = NUMERATOR / DENOM;
    const LOG10_VAL: float = LOG_ARG.log10().real;
    return COEF * LOG10_VAL;
};

~~ Groundwater time of travel in seconds over a flow path length using seepage velocity.
~~ path_length in m, seepage_velocity in m/s.
function time_of_travel(path_length: float, seepage_velocity_val: float) -> float {
    return path_length / seepage_velocity_val;
};

// ================================================================
// SECTION 5: VOLCANOLOGY
// ================================================================

tag RockType {
  BASALT,
  ANDESITE,
  DACITE,
  RHYOLITE
};

~~ Estimates Volcanic Explosivity Index (0-8) from erupted tephra volume.
~~ volume_km3 in cubic kilometers. Coarse approximation from Newhall & Self (1982) volume boundaries.
~~ VEI = floor(log10(V_m3)) - 3, clamped to [0, 8].
function volcanic_explosivity_index_estimate(volume_km3: float) -> int {
    const V_M3: float = volume_km3 * 1000000000.0;
    const LOG10_V: float = V_M3.log10().real;
    const VEI_RAW: float = LOG10_V - 3.0;
    var vei: int = int(VEI_RAW);
    if (vei < 0) {
        vei = 0;
    };
    if (vei > 8) {
        vei = 8;
    };
    return vei;
};

~~ Eruption column height in km from mass eruption rate, via the Sparks et al. scaling law.
~~ mass_rate_kgs in kg/s. H = 0.236 * Q^0.25.
function eruption_column_height(mass_rate_kgs: float) -> float {
    const Q_POW: float = float(c_pow(mass_rate_kgs, 0.25));
    return 0.236 * Q_POW;
};

~~ Mass eruption rate in kg/s from eruption column height (inverse Sparks scaling).
~~ height_km in km. Q = (H/0.236)^4.
function mass_eruption_rate(height_km: float) -> float {
    const BASE: float = height_km / 0.236;
    return float(c_pow(BASE, 4.0));
};

~~ Magma ascent velocity in m/s through a cylindrical conduit via Hagen-Poiseuille flow.
~~ pressure_gradient in Pa, radius in m, viscosity in Pa·s, conduit_length in m.
~~ v = ΔP·r² / (8·η·L).
function magma_ascent_velocity(pressure_gradient: float, radius: float, viscosity: float, conduit_length: float) -> float {
    const NUMERATOR: float = pressure_gradient * radius * radius;
    const DENOM: float = 8.0 * viscosity * conduit_length;
    return NUMERATOR / DENOM;
};

~~ Effusion rate in m³/s from erupted lava volume and eruption duration.
~~ volume_km3 in cubic kilometers, duration_days in days.
function effusion_rate(volume_km3: float, duration_days: float) -> float {
    const VOL_M3: float = volume_km3 * 1000000000.0;
    const TIME_S: float = duration_days * 86400.0;
    return VOL_M3 / TIME_S;
};

~~ Total lava volume in m³ from effusion rate and eruption duration.
~~ effusion_rate_m3s in m³/s, duration_s in seconds.
function lava_volume_from_effusion(effusion_rate_m3s: float, duration_s: float) -> float {
    return effusion_rate_m3s * duration_s;
};

~~ Crystal-bearing magma suspension viscosity via the Einstein-Roscoe equation.
~~ melt_viscosity in Pa·s, crystal_fraction and max_packing_fraction as decimals (0-1).
~~ η_suspension = η_melt * (1 - φ/φmax)^(-2.5·φmax).
function magma_viscosity_suspension(melt_viscosity: float, crystal_fraction: float, max_packing_fraction: float) -> float {
    const RATIO: float = crystal_fraction / max_packing_fraction;
    const BASE: float = 1.0 - RATIO;
    const EXPONENT: float = -2.5 * max_packing_fraction;
    const POW_TERM: float = float(c_pow(BASE, EXPONENT));
    return melt_viscosity * POW_TERM;
};

~~ Critical overpressure in Pa needed for dike initiation from a magma chamber (Gudmundsson model).
~~ tensile_strength in Pa, rock_density and magma_density in kg/m³, depth in m.
~~ ΔPc = σt + (ρrock - ρmagma)·g·depth.
function magma_chamber_overpressure(tensile_strength: float, rock_density: float, magma_density: float, depth: float) -> float {
    const G: float = 9.80665;
    const DENSITY_DIFF: float = rock_density - magma_density;
    const BUOYANCY_TERM: float = DENSITY_DIFF * G * depth;
    return tensile_strength + BUOYANCY_TERM;
};

~~ Tephra deposit thickness in cm at a given distance from vent, via the Pyle (1989) exponential thinning model.
~~ t0 = thickness at vent (cm), decay_constant per km, distance_km from vent.
function tephra_fallout_thickness(t0: float, decay_constant: float, distance_km: float) -> float {
    const EXPONENT: float = -decay_constant * distance_km;
    const EXP_VAL: float = float(c_exp(EXPONENT));
    return t0 * EXP_VAL;
};

~~ Classifies volcanic rock type from silica content using standard TAS-adjacent thresholds.
~~ sio2_wt_pct in weight percent. Basalt <52%, Andesite 52-63%, Dacite 63-70%, Rhyolite >70%.
function silica_classification_index(sio2_wt_pct: float) -> RockType {
    var result: RockType = RockType.BASALT;
    if (sio2_wt_pct < 52.0) {
        result = RockType.BASALT;
    };
    if (sio2_wt_pct >= 52.0 && sio2_wt_pct < 63.0) {
        result = RockType.ANDESITE;
    };
    if (sio2_wt_pct >= 63.0 && sio2_wt_pct < 70.0) {
        result = RockType.DACITE;
    };
    if (sio2_wt_pct >= 70.0) {
        result = RockType.RHYOLITE;
    };
    return result;
};

// ================================================================
// SECTION 6: GEOCHRONOLOGY
// ================================================================
// NOTE: All decay constants use Myr (million years) as the base time
// unit, not years. Geological half-lives in yr^-1 (e.g. U-238's
// ~1.55e-10) sit right at the fixed-point precision floor (scale
// 10^-12) — same underflow class as mocha-chem's quantum constants.
// Myr keeps every lambda in a safely representable ~1e-4 to 1e-6
// range, and matches standard geochronology convention (ages in Ma).

~~ Decay constant in Myr⁻¹ from half-life in Myr. λ = ln(2)/t_half.
function decay_constant_myr(half_life_myr: float) -> float {
    const LN2: float = 2.0.log().real;
    return LN2 / half_life_myr;
};

~~ General radiometric age in Myr from decay constant and parent/daughter isotope amounts.
~~ lambda in Myr⁻¹, daughter_excess and parent_remaining in same units (e.g. mol, or isotope ratio).
~~ age = (1/λ) * ln(1 + D/P).
function parent_daughter_age(lambda_myr: float, daughter_excess: float, parent_remaining: float) -> float {
    const RATIO: float = daughter_excess / parent_remaining;
    const LN_TERM: float = (1.0 + RATIO).log().real;
    return LN_TERM / lambda_myr;
};

~~ U-238/Pb-206 radiometric age in Myr. Half-life = 4468 Myr.
~~ pb206_excess and u238_remaining in same units (e.g. mol or isotope ratio).
function u238_pb206_age(pb206_excess: float, u238_remaining: float) -> float {
    const HALF_LIFE: float = 4468.0;
    const LAMBDA: float = decay_constant_myr(HALF_LIFE);
    return parent_daughter_age(LAMBDA, pb206_excess, u238_remaining);
};

~~ U-235/Pb-207 radiometric age in Myr. Half-life = 703.8 Myr.
~~ pb207_excess and u235_remaining in same units.
function u235_pb207_age(pb207_excess: float, u235_remaining: float) -> float {
    const HALF_LIFE: float = 703.8;
    const LAMBDA: float = decay_constant_myr(HALF_LIFE);
    return parent_daughter_age(LAMBDA, pb207_excess, u235_remaining);
};

~~ Rb-87/Sr-87 radiometric age in Myr. Half-life = 48800 Myr.
~~ sr87_excess and rb87_remaining in same units.
function rb87_sr87_age(sr87_excess: float, rb87_remaining: float) -> float {
    const HALF_LIFE: float = 48800.0;
    const LAMBDA: float = decay_constant_myr(HALF_LIFE);
    return parent_daughter_age(LAMBDA, sr87_excess, rb87_remaining);
};

~~ Sm-147/Nd-143 radiometric age in Myr. Half-life = 106000 Myr.
~~ nd143_excess and sm147_remaining in same units.
function sm147_nd143_age(nd143_excess: float, sm147_remaining: float) -> float {
    const HALF_LIFE: float = 106000.0;
    const LAMBDA: float = decay_constant_myr(HALF_LIFE);
    return parent_daughter_age(LAMBDA, nd143_excess, sm147_remaining);
};

~~ K-40/Ar-40 radiometric age in Myr, accounting for the electron-capture branching ratio.
~~ ar40_excess and k40_remaining in same units. Uses Steiger & Jäger (1977) constants:
~~ λtotal = 5.543e-4/Myr, λε = 0.581e-4/Myr.
function k40_ar40_age(ar40_excess: float, k40_remaining: float) -> float {
    const LAMBDA_TOTAL: float = 0.0005543;
    const LAMBDA_E: float = 0.0000581;
    const BRANCH_RATIO: float = LAMBDA_TOTAL / LAMBDA_E;
    const RATIO: float = ar40_excess / k40_remaining;
    const LN_TERM: float = (1.0 + BRANCH_RATIO * RATIO).log().real;
    return LN_TERM / LAMBDA_TOTAL;
};

~~ Sediment deposition rate in m/kyr from layer thickness and time elapsed.
~~ thickness_m in meters, time_kyr in thousands of years.
function deposition_rate(thickness_m: float, time_kyr: float) -> float {
    return thickness_m / time_kyr;
};

~~ Sediment age in kyr from burial depth and deposition rate.
~~ depth_m in meters, rate in m/kyr.
function sediment_age_from_depth(depth_m: float, rate: float) -> float {
    return depth_m / rate;
};

~~ Luminescence (OSL/TL) age in kyr from paleodose and environmental dose rate.
~~ paleodose_gy in Gray (Gy), dose_rate in Gy/kyr.
function luminescence_age(paleodose_gy: float, dose_rate: float) -> float {
    return paleodose_gy / dose_rate;
};