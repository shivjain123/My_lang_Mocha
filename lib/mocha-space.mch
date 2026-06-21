"""
mocha-space — Astronomy & Astrophysics Library for Mocha
Section 1: Orbital Mechanics
Functions: 25 + atan2 helper
Reference: Bate/Mueller/White "Fundamentals of Astrodynamics";
           Curtis "Orbital Mechanics for Engineering Students"
"""

from "mocha-math" import *;

// ─── FFI ───────────────────────────────────────────────────────────────

//Bypasses fixed-point decimal scaling entirely. Use ONLY for values outside
//safe fixed-point range (~1e13+). No drift protection — raw IEEE 754.
function unsafe_mul(a: float, b: float) -> float native mocha_unsafe_mul;
function unsafe_div(a: float, b: float) -> float native mocha_unsafe_div;
function unsafe_add(a: float, b: float) -> float native mocha_unsafe_add;
function unsafe_sub(a: float, b: float) -> float native mocha_unsafe_sub;
function c_exp(x: float) -> float native mocha_wrap_exp;

// ─── CONSTANTS ───────────────────────────────────────────────────────────────

//use TAU as is
const DEG_TO_RAD: float = 0.017453292519943295;
const RAD_TO_DEG: float = 57.29577951308232;

const G: float = 6.674E-11;
const GM_SUN: float = 1.32712440018E20;
const GM_EARTH: float = 3.986004418E14;
const GM_MOON: float = 4.9048695E12;
const GM_JUPITER: float = 1.26686534E17;

const MASS_SUN: float = 1.989E30;
const MASS_EARTH: float = 5.972E24;
const MASS_MOON: float = 7.342E22;
const MASS_JUPITER: float = 1.898E27;

const RADIUS_SUN: float = 6.957E8;
const RADIUS_EARTH: float = 6.371E6;
const RADIUS_MOON: float = 1.7374E6;
const RADIUS_JUPITER: float = 6.9911E7;

// ─── TAGS ────────────────────────────────────────────────────────────────────

tag OrbitType {
    CIRCULAR,
    ELLIPTICAL,
    PARABOLIC,
    HYPERBOLIC
};

// ─── HELPER ──────────────────────────────────────────────────────────────────

"""
atan2(y, x) -> float
Two-argument arctangent (rad). Manual implementation — not in mocha-math.
"""
function atan2(y: float, x: float) -> float {
    if (x > 0.0) {
        return (y / x).inv_tan();
    };
    if (x < 0.0 && y >= 0.0) {
        return (y / x).inv_tan() + PI;
    };
    if (x < 0.0 && y < 0.0) {
        return (y / x).inv_tan() - PI;
    };
    if (x == 0.0 && y > 0.0) {
        return PI / 2.0;
    };
    if (x == 0.0 && y < 0.0) {
        return -(PI / 2.0);
    };
    return 0.0;
};

// ─── SECTION 1: ORBITAL MECHANICS ────────────────────────────────────────────

"""
orbital_period(a, mu) -> float
Kepler's 3rd law: orbital period (s).
t = 2π √(a³/μ)
"""
function orbital_period(a: float, mu: float) -> float {
    var a3: float = fast_pow(a, 3);
    var radicand: float = a3 / mu;
    return TAU * radicand.sqrt().real;
};

"""
semi_major_axis(t, mu) -> float
Semi-major axis from period (m).
a = (μ(t/2π)²)^(1/3)
"""
function semi_major_axis(t: float, mu: float) -> float {
    var t_over_2pi: float = t / TAU;
    var inner: float = unsafe_mul(unsafe_mul(mu, t_over_2pi), t_over_2pi);
    return inner.cubrot();
};

"""
orbital_velocity_circular(r, mu) -> float
Circular orbital velocity (m/s).
v = √(μ/r)
"""
function orbital_velocity_circular(r: float, mu: float) -> float {
    var radicand: float = mu / r;
    if (radicand < 0.0) {
        return 0.0;
    };
    return radicand.sqrt().real;
};

"""
orbital_velocity_visviva(r, a, mu) -> float
Orbital velocity at any point via vis-viva (m/s).
v = √(μ(2/r - 1/a))
"""
function orbital_velocity_visviva(r: float, a: float, mu: float) -> float {
    var term: float = (2.0 / r) - (1.0 / a);
    var radicand: float = mu * term;
    if (radicand < 0.0) {
        return 0.0;
    };
    return radicand.sqrt().real;
};

"""
escape_velocity(r, mu) -> float
Escape velocity from distance r (m/s).
v_esc = √(2μ/r)
"""
function escape_velocity(r: float, mu: float) -> float {
    var radicand: float = unsafe_div(unsafe_mul(2.0, mu), r);
    if (radicand < 0.0) {
        return 0.0;
    };
    return radicand.sqrt().real;
};
"""
periapsis(a, e) -> float
Closest approach (m). r_p = a(1 - e)
"""
function periapsis(a: float, e: float) -> float {
    return a * (1.0 - e);
};

"""
apoapsis(a, e) -> float
Farthest distance (m). r_a = a(1 + e)
"""
function apoapsis(a: float, e: float) -> float {
    return a * (1.0 + e);
};

"""
orbital_energy(a, mu) -> float
Specific orbital energy (J/kg). ε = -μ/(2a)
"""
function orbital_energy(a: float, mu: float) -> float {
    return -(mu / (2.0 * a));
};

"""
specific_angular_momentum(a, e, mu) -> float
Specific angular momentum (m²/s).
h = √(μ·a·(1-e²))
"""
function specific_angular_momentum(a: float, e: float, mu: float) -> float {
    var radicand: float = mu * a * (1.0 - e * e);
    if (radicand < 0.0) {
        return 0.0;
    };
    return radicand.sqrt().real;
};

"""
mean_motion(a, mu) -> float
Mean motion n (rad/s). n = √(μ/a³)
"""
function mean_motion(a: float, mu: float) -> float {
    var radicand: float = mu / c_pow(a, 3.0);
    if (radicand < 0.0) {
        return 0.0;
    };
    return radicand.sqrt().real;
};

"""
mean_anomaly(n, t, t_p) -> float
Mean anomaly m (rad). m = n(t - t_p)
"""
function mean_anomaly(n: float, t: float, t_p: float) -> float {
    return n * (t - t_p);
};

"""
eccentric_anomaly(m, e) -> float
Eccentric anomaly (rad) via Newton's method.
Solves Kepler's equation: m = E_cap - e·sin(E_cap)
Converges to 1E-10 in ≤50 iterations for e < 0.9
"""
function eccentric_anomaly(m: float, e: float) -> float {
    var E_cap: float = m;
    var i: int = 0;
    while (i < 50) {
        var dE: float = (E_cap - e * E_cap.sin(RAD) - m) / (1.0 - e * E_cap.cos(RAD));
        E_cap = E_cap - dE;
        if (abs(dE) < 1E-10) {
            i = 50;
        };
        i++;
    };
    return E_cap;
};

"""
true_anomaly_from_eccentric(E_cap, e) -> float
True anomaly ν (rad) from eccentric anomaly.
tan(ν/2) = √((1+e)/(1-e)) · tan(E_cap/2)
"""
function true_anomaly_from_eccentric(E_cap: float, e: float) -> float {
    var radicand: float = (1.0 + e) / (1.0 - e);
    if (radicand < 0.0) {
        radicand = 0.0;
    };
    var factor: float = radicand.sqrt().real;
    var tan_half_E: float = (E_cap / 2.0).tan(RAD);
    return 2.0 * (factor * tan_half_E).inv_tan();
};

"""
true_anomaly_from_mean(m, e) -> float
True anomaly ν (rad) directly from mean anomaly.
"""
function true_anomaly_from_mean(m: float, e: float) -> float {
    return true_anomaly_from_eccentric(eccentric_anomaly(m, e), e);
};

"""
radial_distance(a, e, E_cap) -> float
Radial distance at eccentric anomaly E_cap (m).
r = a(1 - e·cos(E_cap))
"""
function radial_distance(a: float, e: float, E_cap: float) -> float {
    return a * (1.0 - e * E_cap.cos(RAD));
};

"""
flight_path_angle(e, nu) -> float
Flight path angle γ (rad).
γ = atan2(e·sin(ν), 1 + e·cos(ν))
"""
function flight_path_angle(e: float, nu: float) -> float {
    return atan2(e * nu.sin(RAD), 1.0 + e * nu.cos(RAD));
};

"""
synodic_period(p1, p2) -> float
Synodic period (s). 1/P_syn = |1/p1 - 1/p2|
"""
function synodic_period(p1: float, p2: float) -> float {
    return 1.0 / abs((1.0 / p1) - (1.0 / p2));
};

"""
hohmann_transfer_sma(r1, r2) -> float
Hohmann transfer ellipse semi-major axis (m).
a_t = (r1 + r2) / 2
"""
function hohmann_transfer_sma(r1: float, r2: float) -> float {
    return (r1 + r2) / 2.0;
};

"""
hohmann_dv1(r1, r2, mu) -> float
Hohmann departure burn Δv (m/s).
Δv1 = √(μ/r1) · (√(2r2/(r1+r2)) - 1)
"""
function hohmann_dv1(r1: float, r2: float, mu: float) -> float {
    var radicand1: float = mu / r1;
    if (radicand1 < 0.0) { radicand1 = 0.0; };
    var v1: float = radicand1.sqrt().real;
    
    var radicand2: float = 2.0 * r2 / (r1 + r2);
    if (radicand2 < 0.0) { radicand2 = 0.0; };
    var factor: float = radicand2.sqrt().real;
    
    return v1 * (factor - 1.0);
};

"""
hohmann_dv2(r1, r2, mu) -> float
Hohmann arrival burn Δv (m/s).
Δv2 = √(μ/r2) · (1 - √(2r1/(r1+r2)))
"""
function hohmann_dv2(r1: float, r2: float, mu: float) -> float {
    var radicand1: float = mu / r2;
    if (radicand1 < 0.0) { radicand1 = 0.0; };
    var v2: float = radicand1.sqrt().real;
    
    var radicand2: float = 2.0 * r1 / (r1 + r2);
    if (radicand2 < 0.0) { radicand2 = 0.0; };
    var factor: float = radicand2.sqrt().real;
    
    return v2 * (1.0 - factor);
};

"""
hohmann_dv_total(r1, r2, mu) -> float
Total Hohmann Δv magnitude (m/s).
"""
function hohmann_dv_total(r1: float, r2: float, mu: float) -> float {
    return abs(hohmann_dv1(r1, r2, mu)) + abs(hohmann_dv2(r1, r2, mu));
};

"""
sphere_of_influence(a, m_small, m_large) -> float
Sphere of influence radius (m).
r_SOI = a · (m_small/m_large)^(2/5)
"""
function sphere_of_influence(a: float, m_small: float, m_large: float) -> float {
    return a * c_pow(m_small / m_large, 0.4);
};

"""
hill_sphere(a, e, m_small, m_large) -> float
Hill sphere radius (m).
r_H = a(1-e) · (m_small/(3·m_large))^(1/3)
"""
function hill_sphere(a: float, e: float, m_small: float, m_large: float) -> float {
    var inner: float = m_small / (3.0 * m_large);
    return a * (1.0 - e) * inner.cubrot();
};

"""
roche_limit_rigid(R_primary, rho_primary, rho_secondary) -> float
Roche limit for rigid satellite (m).
d = 2.46 · R_primary · (ρ_primary/ρ_secondary)^(1/3)
"""
function roche_limit_rigid(R_primary: float, rho_primary: float, rho_secondary: float) -> float {
    var inner: float = rho_primary / rho_secondary;
    return 2.46 * R_primary * inner.cubrot();
};

"""
roche_limit_fluid(R_primary, M_primary, M_secondary) -> float
Roche limit for fluid satellite (m).
d = 2.44 · R_primary · (M_primary/M_secondary)^(1/3)
"""
function roche_limit_fluid(R_primary: float, M_primary: float, M_secondary: float) -> float {
    var inner: float = M_primary / M_secondary;
    return 2.44 * R_primary * inner.cubrot();
};

"""
inclination_change_dv(v, delta_i_deg) -> float
Δv for pure inclination change (m/s).
Δv = 2v·sin(Δi/2)
"""
function inclination_change_dv(v: float, delta_i_deg: float) -> float {
    return 2.0 * v * (delta_i_deg * DEG_TO_RAD / 2.0).sin(RAD);
};

"""
orbit_type(e) -> OrbitType
Classify orbit by eccentricity.
"""
function orbit_type(e: float) -> OrbitType {
    if (e < 0.001) { return OrbitType.CIRCULAR; };
    if (e < 1.0)   { return OrbitType.ELLIPTICAL; };
    if (e == 1.0)  { return OrbitType.PARABOLIC; };
    return OrbitType.HYPERBOLIC;
};

"""
mocha-space — Astronomy & Astrophysics Library for Mocha
Section 2: Stellar Physics & Photometry
Functions: 18
Reference: Carroll & Ostlie "An Introduction to Modern Astrophysics";
           Zeilik & Gregory "Introductory Astronomy and Astrophysics"
"""

// ─── ADDITIONAL CONSTANTS ─────────────────────────────────────────────────────

const STEFAN_BOLTZMANN: float = 5.670374419E-8;   // W m^-2 K^-4
const WIEN_B: float = 2.897771955E-3;             // m·K
const PARSEC: float = 3.0856775814913673E16;      // m
const LIGHT_YEAR: float = 9.4607304725808E15;     // m
const AU: float = 1.495978707E11;                 // m
const LUMINOSITY_SUN: float = 3.828E26;           // W (IAU nominal)
const TEMP_SUN: float = 5772.0;                   // K (IAU nominal photosphere)
const SPEED_OF_LIGHT: float = 2.99792458E8;       // m/s
const PLANCK_H: float = 6.62607015E-34;           // J·s
const BOLTZMANN_K: float = 1.380649E-23;          // J/K

// ─── TAGS ────────────────────────────────────────────────────────────────────

tag SpectralClass {
    O, B, A, F, G, K, M
};

// ─── SECTION 2: STELLAR PHYSICS & PHOTOMETRY ─────────────────────────────────

"""
luminosity_from_radius_temp(r, t) -> float
Stefan-Boltzmann law: stellar luminosity (W).
L = 4π R² σ T⁴
"""
function luminosity_from_radius_temp(r: float, t: float) -> float {
    var r2: float = unsafe_mul(r, r);
    var t2: float = unsafe_mul(t, t);
    var t4: float = unsafe_mul(t2, t2);
    var area_term: float = unsafe_mul(4.0 * PI, r2);
    var flux_term: float = unsafe_mul(STEFAN_BOLTZMANN, t4);
    return unsafe_mul(area_term, flux_term);
};

"""
radius_from_luminosity_temp(l, t) -> float
Stellar radius from luminosity and temperature (m).
R = √(L / (4π σ T⁴))
"""
function radius_from_luminosity_temp(l: float, t: float) -> float {
    var t2: float = unsafe_mul(t, t);
    var t4: float = unsafe_mul(t2, t2);
    var denom: float = unsafe_mul(unsafe_mul(4.0 * PI, STEFAN_BOLTZMANN), t4);
    var radicand: float = unsafe_div(l, denom);
    if (radicand < 0.0) {
        return 0.0;
    };
    return radicand.sqrt().real;
};

"""
temp_from_luminosity_radius(l, r) -> float
Effective temperature from luminosity and radius (K).
T = (L / (4π R² σ))^(1/4)
"""
function temp_from_luminosity_radius(l: float, r: float) -> float {
    var r2: float = unsafe_mul(r, r);
    var denom: float = unsafe_mul(unsafe_mul(4.0 * PI, r2), STEFAN_BOLTZMANN);
    var inner: float = unsafe_div(l, denom);
    if (inner < 0.0) {
        return 0.0;
    };
    return c_pow(inner, 0.25);
};

"""
wien_peak_wavelength(t) -> float
Wien's displacement law: peak emission wavelength (m).
λ_max = b / T
"""
function wien_peak_wavelength(t: float) -> float {
    if (t <= 0.0) {
        return 0.0;
    };
    return WIEN_B / t;
};

"""
wien_temp_from_wavelength(lambda_max) -> float
Inverse Wien's law: temperature from peak wavelength (K).
T = b / λ_max
"""
function wien_temp_from_wavelength(lambda_max: float) -> float {
    if (lambda_max <= 0.0) {
        return 0.0;
    };
    return WIEN_B / lambda_max;
};

"""
parallax_to_distance_pc(p_arcsec) -> float
Stellar distance from parallax angle (parsecs).
d = 1 / p″
"""
function parallax_to_distance_pc(p_arcsec: float) -> float {
    if (p_arcsec <= 0.0) {
        return 0.0;
    };
    return 1.0 / p_arcsec;
};

"""
distance_to_parallax(d_pc) -> float
Parallax angle from distance (arcsec).
p″ = 1 / d
"""
function distance_to_parallax(d_pc: float) -> float {
    if (d_pc <= 0.0) {
        return 0.0;
    };
    return 1.0 / d_pc;
};

"""
distance_modulus(m, M_abs) -> float
Distance modulus (mag). μ = m - M
"""
function distance_modulus(m: float, M_abs: float) -> float {
    return m - M_abs;
};

"""
distance_from_modulus(mu) -> float
Distance from distance modulus (parsecs).
d = 10^((μ+5)/5)
"""
function distance_from_modulus(mu: float) -> float {
    var exponent: float = (mu + 5.0) / 5.0;
    return c_pow(10.0, exponent);
};

"""
absolute_magnitude(m, d_pc) -> float
Absolute magnitude from apparent magnitude and distance (mag).
M = m - 5·log10(d) + 5
"""
function absolute_magnitude(m: float, d_pc: float) -> float {
    if (d_pc <= 0.0) {
        return 0.0;
    };
    var log_d: float = d_pc.log10().real;
    return m - 5.0 * log_d + 5.0;
};

"""
apparent_magnitude(M_abs, d_pc) -> float
Apparent magnitude from absolute magnitude and distance (mag).
m = M + 5·log10(d) - 5
"""
function apparent_magnitude(M_abs: float, d_pc: float) -> float {
    if (d_pc <= 0.0) {
        return M_abs;
    };
    var log_d: float = d_pc.log10().real;
    return M_abs + 5.0 * log_d - 5.0;
};

"""
flux_ratio_from_magnitudes(m1, m2) -> float
Flux ratio between two objects from their magnitudes.
F1/F2 = 10^(0.4·(m2-m1))
"""
function flux_ratio_from_magnitudes(m1: float, m2: float) -> float {
    var exponent: float = 0.4 * (m2 - m1);
    return c_pow(10.0, exponent);
};

"""
magnitude_diff_from_flux_ratio(ratio) -> float
Magnitude difference from a flux ratio.
Δm = -2.5·log10(F1/F2)
"""
function magnitude_diff_from_flux_ratio(ratio: float) -> float {
    if (ratio <= 0.0) {
        return 0.0;
    };
    var log_ratio: float = ratio.log10().real;
    return -2.5 * log_ratio;
};

"""
luminosity_to_solar(l) -> float
Luminosity expressed in solar units (dimensionless).
"""
function luminosity_to_solar(l: float) -> float {
    return l / LUMINOSITY_SUN;
};

"""
luminosity_from_solar(l_sun) -> float
Solar-unit luminosity converted back to watts.
"""
function luminosity_from_solar(l_sun: float) -> float {
    return unsafe_mul(l_sun, LUMINOSITY_SUN);
};

"""
main_sequence_luminosity(mass_solar) -> float
Mass-luminosity relation for main sequence stars (solar units).
L/L_sun ≈ (M/M_sun)^3.5   (valid roughly 0.5–20 solar masses)
"""
function main_sequence_luminosity(mass_solar: float) -> float {
    if (mass_solar <= 0.0) {
        return 0.0;
    };
    return c_pow(mass_solar, 3.5);
};

"""
main_sequence_lifetime(mass_solar) -> float
Approximate main sequence lifetime (years).
t ≈ 10^10 · (M/M_sun) / (L/L_sun)
"""
function main_sequence_lifetime(mass_solar: float) -> float {
    var l_solar: float = main_sequence_luminosity(mass_solar);
    if (l_solar <= 0.0) {
        return 0.0;
    };
    return 1.0E10 * (mass_solar / l_solar);
};

"""
schwarzschild_radius(mass) -> float
Event horizon radius for a non-rotating mass (m).
r_s = 2GM/c²
"""
function schwarzschild_radius(mass: float) -> float {
    var numerator: float = unsafe_mul(unsafe_mul(2.0, G), mass);
    var c2: float = unsafe_mul(SPEED_OF_LIGHT, SPEED_OF_LIGHT);
    return unsafe_div(numerator, c2);
};

"""
photon_energy(wavelength) -> float
Energy of a photon at given wavelength (J).
E = hc/λ
"""
function photon_energy(wavelength: float) -> float {
    if (wavelength <= 0.0) {
        return 0.0;
    };
    var numerator: float = unsafe_mul(PLANCK_H, SPEED_OF_LIGHT);
    return unsafe_div(numerator, wavelength);
};

"""
mocha-space — Astronomy & Astrophysics Library for Mocha
Section 3: Planetary Atmospheres & Habitability
Functions: 12
Reference: Kasting, Whitmire & Reynolds (1993) "Habitable Zones around Main Sequence Stars";
           Carroll & Ostlie "An Introduction to Modern Astrophysics"
"""

// ─── ADDITIONAL CONSTANTS ─────────────────────────────────────────────────────

const EARTH_ALBEDO: float = 0.31;
const EARTH_GRAVITY: float = 9.80665;        // m/s^2
const EARTH_MEAN_MOLAR_MASS: float = 0.02896; // kg/mol, dry air
const AVOGADRO: float = 6.02214076E23;        // mol^-1
const SOLAR_CONSTANT: float = 1361.0;         // W/m^2 at 1 AU (TSI)

// ─── TAGS ────────────────────────────────────────────────────────────────────

tag HabitableZoneEdge {
    RUNAWAY_GREENHOUSE,
    MAXIMUM_GREENHOUSE
};

// ─── SECTION 3: PLANETARY ATMOSPHERES & HABITABILITY ─────────────────────────

"""
equilibrium_temp(l, d, albedo) -> float
Planetary equilibrium temperature from stellar luminosity, orbital
distance, and Bond albedo (K).
T_eq = (L(1-A) / (16π σ D²))^(1/4)
"""
function equilibrium_temp(l: float, d: float, albedo: float) -> float {
    if (d <= 0.0 || albedo >= 1.0) {
        return 0.0;
    };
    var d2: float = unsafe_mul(d, d);
    var denom: float = unsafe_mul(unsafe_mul(16.0 * PI, STEFAN_BOLTZMANN), d2);
    var numer: float = unsafe_mul(l, (1.0 - albedo));
    var inner: float = unsafe_div(numer, denom);
    if (inner < 0.0) {
        return 0.0;
    };
    return c_pow(inner, 0.25);
};

"""
equilibrium_temp_from_star(t_star, r_star, d, albedo) -> float
Planetary equilibrium temperature directly from stellar temperature
and radius (K), bypassing luminosity.
T_eq = T_star · √(R_star / (2D)) · (1-A)^(1/4)
"""
function equilibrium_temp_from_star(t_star: float, r_star: float, d: float, albedo: float) -> float {
    if (d <= 0.0 || albedo >= 1.0) {
        return 0.0;
    };
    var ratio: float = unsafe_div(r_star, unsafe_mul(2.0, d));
    if (ratio < 0.0) {
        return 0.0;
    };
    var sqrt_term: float = ratio.sqrt().real;
    var albedo_term: float = c_pow(1.0 - albedo, 0.25);
    return unsafe_mul(unsafe_mul(t_star, sqrt_term), albedo_term);
};

"""
solar_flux_at_distance(l, d) -> float
Stellar flux (insolation) received at orbital distance d (W/m²).
S = L / (4π D²)
"""
function solar_flux_at_distance(l: float, d: float) -> float {
    if (d <= 0.0) {
        return 0.0;
    };
    var d2: float = unsafe_mul(d, d);
    var denom: float = unsafe_mul(4.0 * PI, d2);
    return unsafe_div(l, denom);
};

"""
absorbed_power(l, d, r_planet, albedo) -> float
Total power absorbed by a planet from its star (W).
P_abs = (1-A) · L · (π R_planet²) / (4π D²)
"""
function absorbed_power(l: float, d: float, r_planet: float, albedo: float) -> float {
    if (d <= 0.0 || albedo >= 1.0) {
        return 0.0;
    };
    var flux: float = solar_flux_at_distance(l, d);
    var cross_section: float = unsafe_mul(PI, unsafe_mul(r_planet, r_planet));
    var absorbed_fraction: float = 1.0 - albedo;
    return unsafe_mul(unsafe_mul(flux, cross_section), absorbed_fraction);
};

"""
scale_height(t, molar_mass, g) -> float
Atmospheric scale height (m).
H = RT / (Mg)   [equivalent to kT/(mg) at molecular level]
"""
function scale_height(t: float, molar_mass: float, g: float) -> float {
    if (molar_mass <= 0.0 || g <= 0.0) {
        return 0.0;
    };
    const R_GAS: float = 8.314462618;  // J/(mol·K)
    var numer: float = unsafe_mul(R_GAS, t);
    var denom: float = unsafe_mul(molar_mass, g);
    return unsafe_div(numer, denom);
};

"""
atmospheric_pressure_at_height(p0, h, scale_h) -> float
Barometric formula: pressure at altitude h (Pa).
P(h) = P0 · e^(-h/H)
"""
function atmospheric_pressure_at_height(p0: float, h: float, scale_h: float) -> float {
    if (scale_h <= 0.0) {
        return 0.0;
    };
    var exponent: float = -(h / scale_h);
    return p0 * c_exp(exponent);
};

"""
surface_gravity(mass, radius) -> float
Surface gravitational acceleration (m/s²).
g = GM/r²
"""
function surface_gravity(mass: float, radius: float) -> float {
    if (radius <= 0.0) {
        return 0.0;
    };
    var r2: float = unsafe_mul(radius, radius);
    var gm: float = unsafe_mul(G, mass);
    return unsafe_div(gm, r2);
};

"""
escape_velocity_from_mass_radius(mass, radius) -> float
Escape velocity from a body's mass and radius (m/s).
v_esc = √(2GM/r)
"""
function escape_velocity_from_mass_radius(mass: float, radius: float) -> float {
    if (radius <= 0.0) {
        return 0.0;
    };
    var gm: float = unsafe_mul(G, mass);
    var radicand: float = unsafe_div(unsafe_mul(2.0, gm), radius);
    if (radicand < 0.0) {
        return 0.0;
    };
    return radicand.sqrt().real;
};

"""
habitable_zone_distance_simple(l_solar) -> float
Simplified Earth-equivalent-insolation habitable zone distance (AU),
scaling only with stellar luminosity. A first-pass estimate — does not
account for stellar temperature dependence (see Kasting et al. 1993
for the full model with temperature-dependent flux boundaries).
d_HZ = √(L / L_sun)
"""
function habitable_zone_distance_simple(l_solar: float) -> float {
    if (l_solar < 0.0) {
        return 0.0;
    };
    return l_solar.sqrt().real;
};

"""
mean_free_path(temp, pressure, molecule_diameter) -> float
Mean free path of gas molecules in an atmosphere (m).
λ = kT / (√2 · π · d² · P)
"""
function mean_free_path(temp: float, pressure: float, molecule_diameter: float) -> float {
    if (pressure <= 0.0 || molecule_diameter <= 0.0) {
        return 0.0;
    };
    var d2: float = unsafe_mul(molecule_diameter, molecule_diameter);
    var denom: float = unsafe_mul(unsafe_mul(1.4142135623730951 * PI, d2), pressure);
    var numer: float = unsafe_mul(BOLTZMANN_K, temp);
    return unsafe_div(numer, denom);
};

"""
jeans_escape_parameter(escape_v, thermal_v) -> float
Jeans escape parameter λ_J — ratio governing atmospheric retention.
Values >> 1 indicate the gas is gravitationally bound (retained);
values << 1 indicate rapid thermal escape.
λ_J = (v_esc / v_thermal)²
"""
function jeans_escape_parameter(escape_v: float, thermal_v: float) -> float {
    if (thermal_v <= 0.0) {
        return 0.0;
    };
    var ratio: float = unsafe_div(escape_v, thermal_v);
    return unsafe_mul(ratio, ratio);
};

"""
thermal_velocity(temp, molar_mass) -> float
Most probable thermal speed of gas molecules (m/s), from
Maxwell-Boltzmann distribution.
v_thermal = √(2RT/M)
"""
function thermal_velocity(temp: float, molar_mass: float) -> float {
    if (molar_mass <= 0.0) {
        return 0.0;
    };
    const R_GAS: float = 8.314462618;
    var numer: float = unsafe_mul(2.0 * R_GAS, temp);
    var radicand: float = unsafe_div(numer, molar_mass);
    if (radicand < 0.0) {
        return 0.0;
    };
    return radicand.sqrt().real;
};

"""
mocha-space — Astronomy & Astrophysics Library for Mocha
Section 4: Celestial Coordinates
Functions: 20
Reference: Meeus "Astronomical Algorithms"; Duffett-Smith "Practical Astronomy
           with your Calculator or Computer"; USNO Circular 179
"""

// ─── ADDITIONAL CONSTANTS ─────────────────────────────────────────────────────

const OBLIQUITY_J2000: float = 23.4392911;        // degrees, mean obliquity of ecliptic at J2000
const GALACTIC_POLE_RA: float = 192.859508;        // degrees, North Galactic Pole RA (J2000)
const GALACTIC_POLE_DEC: float = 27.128336;        // degrees, North Galactic Pole Dec (J2000)
const GALACTIC_NODE: float = 122.932;              // degrees, position angle of galactic node (J2000)
const PRECESSION_RATE: float = 50.290966;          // arcsec/year, general precession in longitude (IAU 1976)
const ARCSEC_TO_DEG: float = 0.0002777777777777778; // 1/3600
const HOUR_TO_DEG: float = 15.0;                   // 1 hour of RA = 15 degrees

// ─── SECTION 4: CELESTIAL COORDINATES ─────────────────────────────────────────

"""
hour_angle(lst, ra) -> float
Local hour angle (deg). H = LST - RA (both in degrees).
Result wrapped to [-180, 180).
"""
function hour_angle(lst: float, ra: float) -> float {
    var h: float = lst - ra;
    while (h < -180.0) { h = h + 360.0; };
    while (h >= 180.0) { h = h - 360.0; };
    return h;
};

"""
equatorial_to_horizontal(ra, dec, lat, lst) -> (float, 2)
Convert equatorial (RA/Dec) to horizontal (Alt/Az) coordinates.
All inputs/outputs in degrees. Azimuth measured from North, through
East (standard modern convention: 0°=N, 90°=E, 180°=S, 270°=W).
Returns (altitude, azimuth).
"""
function equatorial_to_horizontal(ra: float, dec: float, lat: float, lst: float) -> (float, 2) {
    var h: float = hour_angle(lst, ra) * DEG_TO_RAD;
    var dec_r: float = dec * DEG_TO_RAD;
    var lat_r: float = lat * DEG_TO_RAD;

    var sin_alt: float = dec_r.sin(RAD) * lat_r.sin(RAD) + dec_r.cos(RAD) * lat_r.cos(RAD) * h.cos(RAD);
    if (sin_alt > 1.0) { sin_alt = 1.0; };
    if (sin_alt < -1.0) { sin_alt = -1.0; };
    var alt: float = sin_alt.inv_sin().real;

    var sin_h: float = h.sin(RAD);
    var cos_h: float = h.cos(RAD);
    var az_south: float = atan2(sin_h, cos_h * lat_r.sin(RAD) - dec_r.tan(RAD) * lat_r.cos(RAD));
    var az: float = az_south * RAD_TO_DEG + 180.0;
    while (az < 0.0) { az = az + 360.0; };
    while (az >= 360.0) { az = az - 360.0; };

    return (alt * RAD_TO_DEG, az);
};

"""
horizontal_to_equatorial(alt, az, lat, lst) -> (float, 2)
Convert horizontal (Alt/Az) to equatorial (RA/Dec) coordinates.
All inputs/outputs in degrees. Azimuth is North-based (0°=N, 90°=E).
Returns (ra, dec).
"""
function horizontal_to_equatorial(alt: float, az: float, lat: float, lst: float) -> (float, 2) {
    var alt_r: float = alt * DEG_TO_RAD;
    var az_south_deg: float = az - 180.0;
    while (az_south_deg < 0.0) { az_south_deg = az_south_deg + 360.0; };
    var az_r: float = az_south_deg * DEG_TO_RAD;
    var lat_r: float = lat * DEG_TO_RAD;

    var sin_dec: float = lat_r.sin(RAD) * alt_r.sin(RAD) - lat_r.cos(RAD) * alt_r.cos(RAD) * az_r.cos(RAD);
    if (sin_dec > 1.0) { sin_dec = 1.0; };
    if (sin_dec < -1.0) { sin_dec = -1.0; };
    var dec: float = sin_dec.inv_sin().real;

    var h: float = atan2(az_r.sin(RAD), az_r.cos(RAD) * lat_r.sin(RAD) + alt_r.tan(RAD) * lat_r.cos(RAD));
    var h_deg: float = h * RAD_TO_DEG;

    var ra: float = lst - h_deg;
    while (ra < 0.0) { ra = ra + 360.0; };
    while (ra >= 360.0) { ra = ra - 360.0; };

    return (ra, dec * RAD_TO_DEG);
};

"""
angular_separation(ra1, dec1, ra2, dec2) -> float
Angular separation between two celestial coordinates (degrees), via
the spherical law of cosines. Exact for any separation (small or large).
"""
function angular_separation(ra1: float, dec1: float, ra2: float, dec2: float) -> float {
    var ra1_r: float = ra1 * DEG_TO_RAD;
    var dec1_r: float = dec1 * DEG_TO_RAD;
    var ra2_r: float = ra2 * DEG_TO_RAD;
    var dec2_r: float = dec2 * DEG_TO_RAD;

    var cos_sep: float = dec1_r.sin(RAD) * dec2_r.sin(RAD) +
                          dec1_r.cos(RAD) * dec2_r.cos(RAD) * (ra1_r - ra2_r).cos(RAD);
    if (cos_sep > 1.0) { cos_sep = 1.0; };
    if (cos_sep < -1.0) { cos_sep = -1.0; };
    return cos_sep.inv_cos().real * RAD_TO_DEG;
};

"""
angular_separation_small(ra1, dec1, ra2, dec2) -> float
Fast small-angle approximation for angular separation (degrees).
Valid only for separations under a few degrees.
γ ≈ √((Δra·cos(dec))² + Δdec²)
"""
function angular_separation_small(ra1: float, dec1: float, ra2: float, dec2: float) -> float {
    var d_ra: float = (ra1 - ra2) * DEG_TO_RAD;
    var d_dec: float = dec1 - dec2;
    var dec_avg_r: float = ((dec1 + dec2) / 2.0) * DEG_TO_RAD;
    var ra_term: float = d_ra * dec_avg_r.cos(RAD) * RAD_TO_DEG;
    var radicand: float = ra_term * ra_term + d_dec * d_dec;
    if (radicand < 0.0) { return 0.0; };
    return radicand.sqrt().real;
};

"""
equatorial_to_ecliptic(ra, dec, obliquity) -> (float, 2)
Convert equatorial to ecliptic coordinates (degrees).
Returns (ecliptic longitude, ecliptic latitude).
"""
function equatorial_to_ecliptic(ra: float, dec: float, obliquity: float) -> (float, 2) {
    var ra_r: float = ra * DEG_TO_RAD;
    var dec_r: float = dec * DEG_TO_RAD;
    var eps_r: float = obliquity * DEG_TO_RAD;

    var sin_beta: float = dec_r.sin(RAD) * eps_r.cos(RAD) - dec_r.cos(RAD) * eps_r.sin(RAD) * ra_r.sin(RAD);
    if (sin_beta > 1.0) { sin_beta = 1.0; };
    if (sin_beta < -1.0) { sin_beta = -1.0; };
    var beta: float = sin_beta.inv_sin().real;

    var y: float = ra_r.sin(RAD) * eps_r.cos(RAD) + dec_r.tan(RAD) * eps_r.sin(RAD);
    var x: float = ra_r.cos(RAD);
    var lambda_e: float = atan2(y, x) * RAD_TO_DEG;
    if (lambda_e < 0.0) { lambda_e = lambda_e + 360.0; };

    return (lambda_e, beta * RAD_TO_DEG);
};

"""
ecliptic_to_equatorial(lon, lat, obliquity) -> (float, 2)
Convert ecliptic to equatorial coordinates (degrees).
Returns (right ascension, declination).
"""
function ecliptic_to_equatorial(lon: float, lat: float, obliquity: float) -> (float, 2) {
    var lon_r: float = lon * DEG_TO_RAD;
    var lat_r: float = lat * DEG_TO_RAD;
    var eps_r: float = obliquity * DEG_TO_RAD;

    var sin_dec: float = lat_r.sin(RAD) * eps_r.cos(RAD) + lat_r.cos(RAD) * eps_r.sin(RAD) * lon_r.sin(RAD);
    if (sin_dec > 1.0) { sin_dec = 1.0; };
    if (sin_dec < -1.0) { sin_dec = -1.0; };
    var dec: float = sin_dec.inv_sin().real;

    var y: float = lon_r.sin(RAD) * eps_r.cos(RAD) - lat_r.tan(RAD) * eps_r.sin(RAD);
    var x: float = lon_r.cos(RAD);
    var ra: float = atan2(y, x) * RAD_TO_DEG;
    if (ra < 0.0) { ra = ra + 360.0; };

    return (ra, dec * RAD_TO_DEG);
};

"""
equatorial_to_galactic(ra, dec) -> (float, 2)
Convert J2000 equatorial coordinates to galactic coordinates (degrees).
Returns (galactic longitude, galactic latitude).
"""
function equatorial_to_galactic(ra: float, dec: float) -> (float, 2) {
    var ra_r: float = ra * DEG_TO_RAD;
    var dec_r: float = dec * DEG_TO_RAD;
    var pole_ra_r: float = GALACTIC_POLE_RA * DEG_TO_RAD;
    var pole_dec_r: float = GALACTIC_POLE_DEC * DEG_TO_RAD;

    var sin_b: float = dec_r.sin(RAD) * pole_dec_r.sin(RAD) +
                        dec_r.cos(RAD) * pole_dec_r.cos(RAD) * (ra_r - pole_ra_r).cos(RAD);
    if (sin_b > 1.0) { sin_b = 1.0; };
    if (sin_b < -1.0) { sin_b = -1.0; };
    var b: float = sin_b.inv_sin().real;

    var y: float = dec_r.cos(RAD) * (ra_r - pole_ra_r).sin(RAD);
    var x: float = dec_r.sin(RAD) * pole_dec_r.cos(RAD) - dec_r.cos(RAD) * pole_dec_r.sin(RAD) * (ra_r - pole_ra_r).cos(RAD);
    var l: float = GALACTIC_NODE - atan2(y, x) * RAD_TO_DEG;
    while (l < 0.0) { l = l + 360.0; };
    while (l >= 360.0) { l = l - 360.0; };

    return (l, b * RAD_TO_DEG);
};

"""
parallax_angle_to_distance(p_mas) -> float
Distance from parallax angle given in milliarcseconds (parsecs).
Convenience wrapper — same physics as Section 2's parallax_to_distance_pc.
d = 1000 / p_mas
"""
function parallax_angle_to_distance(p_mas: float) -> float {
    if (p_mas <= 0.0) {
        return 0.0;
    };
    return 1000.0 / p_mas;
};

"""
proper_motion_total(pm_ra, pm_dec, dec) -> float
Total proper motion magnitude (mas/year) from RA and Dec components,
where pm_ra is assumed already in mas/yr on the sky (true angle, i.e.
μ_α*cos δ), not raw RA-coordinate rate. For raw μ_α, use
proper_motion_total_raw instead.
μ_total = √(pm_ra² + pm_dec²)
"""
function proper_motion_total(pm_ra: float, pm_dec: float, dec: float) -> float {
    var radicand: float = pm_ra * pm_ra + pm_dec * pm_dec;
    if (radicand < 0.0) { return 0.0; };
    return radicand.sqrt().real;
};

"""
proper_motion_total_raw(pm_ra_raw, pm_dec, dec) -> float
Total proper motion (mas/year) from raw μ_α (not pre-multiplied by
cos(dec)) and μ_dec.
μ_total = √((μ_α·cos(dec))² + μ_dec²)
"""
function proper_motion_total_raw(pm_ra_raw: float, pm_dec: float, dec: float) -> float {
    var dec_r: float = dec * DEG_TO_RAD;
    var pm_ra_corrected: float = pm_ra_raw * dec_r.cos(RAD);
    var radicand: float = pm_ra_corrected * pm_ra_corrected + pm_dec * pm_dec;
    if (radicand < 0.0) { return 0.0; };
    return radicand.sqrt().real;
};

"""
position_angle(ra1, dec1, ra2, dec2) -> float
Position angle of object 2 relative to object 1 (degrees, 0=North,
90=East, measured counterclockwise from North).
"""
function position_angle(ra1: float, dec1: float, ra2: float, dec2: float) -> float {
    var ra1_r: float = ra1 * DEG_TO_RAD;
    var dec1_r: float = dec1 * DEG_TO_RAD;
    var ra2_r: float = ra2 * DEG_TO_RAD;
    var dec2_r: float = dec2 * DEG_TO_RAD;

    var d_ra: float = ra2_r - ra1_r;
    var y: float = d_ra.sin(RAD);
    var x: float = dec1_r.cos(RAD) * dec2_r.tan(RAD) - dec1_r.sin(RAD) * d_ra.cos(RAD);
    var pa: float = atan2(y, x) * RAD_TO_DEG;
    if (pa < 0.0) { pa = pa + 360.0; };
    return pa;
};

"""
atmospheric_refraction(apparent_alt) -> float
Approximate atmospheric refraction correction (arcminutes), valid for
altitudes above ~15°. Add to true altitude to get apparent altitude,
or subtract from apparent to get true altitude.
R = cot(alt)   [Bennett's simplified formula, low-precision form]
"""
function atmospheric_refraction(apparent_alt: float) -> float {
    if (apparent_alt <= 0.0 || apparent_alt >= 90.0) {
        return 0.0;
    };
    var alt_r: float = apparent_alt * DEG_TO_RAD;
    var tan_alt: float = alt_r.tan(RAD);
    if (tan_alt == 0.0) {
        return 0.0;
    };
    return 1.0 / tan_alt;
};

"""
precess_ra_dec(ra, dec, years) -> (float, 2)
Approximate precession correction over a number of years (degrees).
Uses the simplified general precession rate; not a substitute for the
rigorous Meeus precession algorithm for high-precision work.
"""
function precess_ra_dec(ra: float, dec: float, years: float) -> (float, 2) {
    var total_arcsec: float = PRECESSION_RATE * years;
    var total_deg: float = total_arcsec * ARCSEC_TO_DEG;
    var dec_r: float = dec * DEG_TO_RAD;

    var cos_dec: float = dec_r.cos(RAD);
    var ra_shift: float = 0.0;
    if (cos_dec != 0.0) {
        ra_shift = total_deg / cos_dec;
    };

    var new_ra: float = ra + ra_shift;
    while (new_ra < 0.0) { new_ra = new_ra + 360.0; };
    while (new_ra >= 360.0) { new_ra = new_ra - 360.0; };

    return (new_ra, dec);
};

"""
hours_to_degrees(hours) -> float
Convert hour-angle units (hours) to degrees. 1h = 15°.
"""
function hours_to_degrees(hours: float) -> float {
    return hours * HOUR_TO_DEG;
};

"""
degrees_to_hours(deg) -> float
Convert degrees to hour-angle units (hours). 1° = 1/15 h.
"""
function degrees_to_hours(deg: float) -> float {
    return deg / HOUR_TO_DEG;
};

"""
dms_to_degrees(d, m, s) -> float
Convert degrees/arcminutes/arcseconds to decimal degrees.
Sign of d determines overall sign (pass negative d for southern Dec).
"""
function dms_to_degrees(d: float, m: float, s: float) -> float {
    var sign: float = 1.0;
    if (d < 0.0) {
        sign = -1.0;
    };
    var abs_d: float = abs(d);
    return sign * (abs_d + m / 60.0 + s / 3600.0);
};

"""
degrees_to_dms(deg) -> (float, 3)
Convert decimal degrees to (degrees, arcminutes, arcseconds).
Sign is carried on the degrees component.
"""
function degrees_to_dms(deg: float) -> (float, 3) {
    var sign: float = 1.0;
    if (deg < 0.0) {
        sign = -1.0;
    };
    var abs_deg: float = abs(deg);
    var d: float = float(int(abs_deg));
    var rem_deg: float = abs_deg - d;
    var m_full: float = rem_deg * 60.0;
    var m: float = float(int(m_full));
    var rem_min: float = m_full - m;
    var s: float = rem_min * 60.0;
    return (sign * d, m, s);
};

"""
hms_to_degrees(h, m, s) -> float
Convert hours/minutes/seconds (RA format) to decimal degrees.
"""
function hms_to_degrees(h: float, m: float, s: float) -> float {
    var total_hours: float = h + m / 60.0 + s / 3600.0;
    return total_hours * HOUR_TO_DEG;
};

"""
degrees_to_hms(deg) -> (float, 3)
Convert decimal degrees (RA) to (hours, minutes, seconds).
"""
function degrees_to_hms(deg: float) -> (float, 3) {
    var d: float = deg;
    while (d < 0.0) { d = d + 360.0; };
    while (d >= 360.0) { d = d - 360.0; };
    var total_hours: float = d / HOUR_TO_DEG;
    var h: float = float(int(total_hours));
    var rem_hours: float = total_hours - h;
    var m_full: float = rem_hours * 60.0;
    var m: float = float(int(m_full));
    var rem_min: float = m_full - m;
    var s: float = rem_min * 60.0;
    return (h, m, s);
};

"""
mocha-space — Astronomy & Astrophysics Library for Mocha
Section 5: Time Systems
Functions: 14
Reference: Meeus "Astronomical Algorithms"; USNO Circular 179;
           Explanatory Supplement to the Astronomical Almanac
"""

// ─── ADDITIONAL CONSTANTS ─────────────────────────────────────────────────────

const JD_J2000: float = 2451545.0;
const JD_UNIX_EPOCH: float = 2440587.5;        // JD at 1970-01-01 00:00 UTC
const MJD_OFFSET: float = 2400000.5;            // MJD = JD - this offset
const TT_MINUS_UTC: float = 69.184;             // seconds, current as of 2017-2026 (37 leap sec + 32.184)
const SECONDS_PER_DAY: float = 86400.0;
const JULIAN_CENTURY_DAYS: float = 36525.0;
const BESSELIAN_EPOCH_JD0: float = 2415020.31352; // JD at B1900.0
const BESSELIAN_YEAR_DAYS: float = 365.242198781;

// ─── SECTION 5: TIME SYSTEMS ──────────────────────────────────────────────────

"""
julian_date(year, month, day) -> float
Convert a Gregorian calendar date to Julian Date. day may include a
fractional part for time-of-day (e.g. day=16.75 for 18:00 UT on the 16th).
Valid for Gregorian calendar dates (after 1582-10-15).
"""
function julian_date(year: int, month: int, day: float) -> float {
    var y: int = year;
    var m: int = month;
    if (m <= 2) {
        y = y - 1;
        m = m + 12;
    };
    var a: int = int(float(y) / 100.0);
    var b: int = 2 - a + int(float(a) / 4.0);
    var jd: float = float(int(365.25 * (float(y) + 4716.0))) +
                     float(int(30.6001 * (float(m) + 1.0))) +
                     day + float(b) - 1524.5;
    return jd;
};

"""
julian_date_to_mjd(jd) -> float
Convert Julian Date to Modified Julian Date.
MJD = JD - 2400000.5
"""
function julian_date_to_mjd(jd: float) -> float {
    return jd - MJD_OFFSET;
};

"""
mjd_to_julian_date(mjd) -> float
Convert Modified Julian Date to Julian Date.
"""
function mjd_to_julian_date(mjd: float) -> float {
    return mjd + MJD_OFFSET;
};

"""
j2000_centuries(jd) -> float
Number of Julian centuries (36525 days each) elapsed since the
J2000.0 epoch (JD 2451545.0). Used throughout astronomical formulas
as the standard time variable T.
"""
function j2000_centuries(jd: float) -> float {
    return (jd - JD_J2000) / JULIAN_CENTURY_DAYS;
};

"""
j2000_days(jd) -> float
Number of days elapsed since the J2000.0 epoch.
"""
function j2000_days(jd: float) -> float {
    return jd - JD_J2000;
};

"""
gmst_degrees(jd) -> float
Greenwich Mean Sidereal Time at the given Julian Date (degrees,
0-360). Uses the IAU standard polynomial (Meeus / USNO Circular 179),
accurate to about 0.1 second of time.
"""
function gmst_degrees(jd: float) -> float {
    var t: float = j2000_centuries(jd);
    var t2: float = t * t;
    var t3: float = t2 * t;
    var gmst_sec: float = 24110.54841 + 8640184.812866 * t + 0.093104 * t2 - 0.0000062 * t3;

    var wrapped: float = gmst_sec - SECONDS_PER_DAY * float(int(gmst_sec / SECONDS_PER_DAY));
    if (wrapped < 0.0) {
        wrapped = wrapped + SECONDS_PER_DAY;
    };

    var deg: float = (wrapped / SECONDS_PER_DAY) * 360.0;
    return deg;
};

"""
lst_degrees(jd, longitude) -> float
Local Sidereal Time at the given Julian Date and observer longitude
(degrees, east positive). Returns degrees, 0-360.
"""
function lst_degrees(jd: float, longitude: float) -> float {
    var lst: float = gmst_degrees(jd) + longitude;
    while (lst < 0.0) { lst = lst + 360.0; };
    while (lst >= 360.0) { lst = lst - 360.0; };
    return lst;
};

"""
unix_to_julian_date(unix_seconds) -> float
Convert a Unix timestamp (seconds since 1970-01-01 00:00 UTC) to
Julian Date.
"""
function unix_to_julian_date(unix_seconds: float) -> float {
    return (unix_seconds / SECONDS_PER_DAY) + JD_UNIX_EPOCH;
};

"""
julian_date_to_unix(jd) -> float
Convert Julian Date to a Unix timestamp (seconds since 1970-01-01
00:00 UTC).
"""
function julian_date_to_unix(jd: float) -> float {
    return (jd - JD_UNIX_EPOCH) * SECONDS_PER_DAY;
};

"""
utc_to_tt(jd_utc) -> float
Convert a Julian Date in UTC to Terrestrial Time (TT). Uses the
current fixed offset of 69.184s (37 leap seconds + 32.184s), valid
since 2017-01-01. This offset changes if a future leap second is
declared — not valid for dates before 2017 or after the next leap
second announcement.
"""
function utc_to_tt(jd_utc: float) -> float {
    return jd_utc + (TT_MINUS_UTC / SECONDS_PER_DAY);
};

"""
tt_to_utc(jd_tt) -> float
Convert a Julian Date in Terrestrial Time (TT) to UTC. See utc_to_tt
for validity caveats on the fixed offset used.
"""
function tt_to_utc(jd_tt: float) -> float {
    return jd_tt - (TT_MINUS_UTC / SECONDS_PER_DAY);
};

"""
besselian_epoch(jd) -> float
Convert a Julian Date to a Besselian epoch (e.g. B1950.0). Used in
older star catalogs and proper motion references.
B = 1900.0 + (JD - 2415020.31352) / 365.242198781
"""
function besselian_epoch(jd: float) -> float {
    return 1900.0 + (jd - BESSELIAN_EPOCH_JD0) / BESSELIAN_YEAR_DAYS;
};

"""
besselian_epoch_to_jd(b) -> float
Convert a Besselian epoch back to Julian Date.
"""
function besselian_epoch_to_jd(b: float) -> float {
    return BESSELIAN_EPOCH_JD0 + (b - 1900.0) * BESSELIAN_YEAR_DAYS;
};

"""
julian_epoch(jd) -> float
Convert a Julian Date to a Julian epoch (e.g. J2000.0). Modern star
catalogs (post-1984) use Julian epochs rather than Besselian.
J = 2000.0 + (JD - 2451545.0) / 365.25
"""
function julian_epoch(jd: float) -> float {
    return 2000.0 + (jd - JD_J2000) / 365.25;
};