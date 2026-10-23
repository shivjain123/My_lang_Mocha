"""
mocha-space — Astronomy & Astrophysics Library for Mocha
Section 1: Orbital Mechanics
Functions: 25 + atan2 helper
Reference: Bate/Mueller/White "Fundamentals of Astrodynamics";
           Curtis "Orbital Mechanics for Engineering Students"
"""

from "mocha-math" import *;

local function c_print_err(msg: str) -> null native mocha_print_stderr;
local function c_exit(code: int) -> null native mocha_exit;

// ─── FFI ───────────────────────────────────────────────────────────────

//Bypasses fixed-point decimal scaling entirely. Use ONLY for values outside
//safe fixed-point range (~1e13+). No drift protection — raw IEEE 754.
local function unsafe_mul(a: float, b: float) -> float native mocha_unsafe_mul;
local function unsafe_div(a: float, b: float) -> float native mocha_unsafe_div;
local function unsafe_add(a: float, b: float) -> float native mocha_unsafe_add;
local function unsafe_sub(a: float, b: float) -> float native mocha_unsafe_sub;
local function c_exp(x: float) -> float native mocha_wrap_exp;

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

// ─── STELLAR PHYSICS & PHOTOMETRY ───────────────────────────────────────────

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

// ─── PLANETARY ATMOSPHERES & HABITABILITY ───────────────────────────────────

const EARTH_ALBEDO: float = 0.31;
const EARTH_GRAVITY: float = 9.80665;        // m/s^2
const EARTH_MEAN_MOLAR_MASS: float = 0.02896; // kg/mol, dry air
const AVOGADRO: float = 6.02214076E23;        // mol^-1
const SOLAR_CONSTANT: float = 1361.0;         // W/m^2 at 1 AU (TSI)

// ─── CELESTIAL COORDINATES ──────────────────────────────────────────────────

const OBLIQUITY_J2000: float = 23.4392911;        // degrees, mean obliquity of ecliptic at J2000
const GALACTIC_POLE_RA: float = 192.859508;        // degrees, North Galactic Pole RA (J2000)
const GALACTIC_POLE_DEC: float = 27.128336;        // degrees, North Galactic Pole Dec (J2000)
const GALACTIC_NODE: float = 122.932;              // degrees, position angle of galactic node (J2000)
const PRECESSION_RATE: float = 50.290966;          // arcsec/year, general precession in longitude (IAU 1976)
const ARCSEC_TO_DEG: float = 0.0002777777777777778; // 1/3600
const HOUR_TO_DEG: float = 15.0;                   // 1 hour of RA = 15 degrees

// ─── TIME SYSTEMS ───────────────────────────────────────────────────────────

const JD_J2000: float = 2451545.0;
const JD_UNIX_EPOCH: float = 2440587.5;        // JD at 1970-01-01 00:00 UTC
const MJD_OFFSET: float = 2400000.5;            // MJD = JD - this offset
const TT_MINUS_UTC: float = 69.184;             // seconds, current as of 2017-2026 (37 leap sec + 32.184)
const SECONDS_PER_DAY: float = 86400.0;
const JULIAN_CENTURY_DAYS: float = 36525.0;
const BESSELIAN_EPOCH_JD0: float = 2415020.31352; // JD at B1900.0
const BESSELIAN_YEAR_DAYS: float = 365.242198781;

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
atan2(-0.0, x) with x < 0 returns π not *-π*. Different from C, different from IEEE 754
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

~~ Kepler's 3rd law: orbital period in seconds from semi-major axis a (m) and mu (m³/s²).
~~ t = 2π √(a³/μ). Requires a > 0 and mu > 0.
function orbital_period(a: float, mu: float) -> float {
    if (a <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Semi-major axis must be positive.");
        c_exit(2);
    };
    if (mu <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Gravitational parameter mu must be positive.");
        c_exit(2);
    };
    var a3: float = fast_pow(a, 3);
    var radicand: float = a3 / mu;
    return TAU * radicand.sqrt().real;
};

~~ Semi-major axis in m from orbital period t (s) and mu (m³/s²).
~~ a = (μ(t/2π)²)^(1/3). Requires t > 0 and mu > 0.
function semi_major_axis(t: float, mu: float) -> float {
    if (t <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Orbital period must be positive.");
        c_exit(2);
    };
    if (mu <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Gravitational parameter mu must be positive.");
        c_exit(2);
    };
    var t_over_2pi: float = t / TAU;
    var inner: float = unsafe_mul(unsafe_mul(mu, t_over_2pi), t_over_2pi);
    return inner.cubrot();
};

~~ Circular orbital velocity in m/s at radius r (m) with gravitational parameter mu (m³/s²).
~~ v = √(μ/r). Requires r > 0 and mu > 0.
function orbital_velocity_circular(r: float, mu: float) -> float {
    if (r <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Orbital radius must be positive.");
        c_exit(2);
    };
    if (mu <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Gravitational parameter mu must be positive.");
        c_exit(2);
    };
    var radicand: float = mu / r;
    return radicand.sqrt().real;
};

~~ Orbital velocity in m/s at radius r (m) via vis-viva equation.
~~ v = √(μ(2/r - 1/a)). Requires r > 0, a > 0, and mu > 0. For hyperbolic orbits use a > 0 convention or pass negative a.
function orbital_velocity_visviva(r: float, a: float, mu: float) -> float {
    if (r <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Orbital radius must be positive.");
        c_exit(2);
    };
    if (a == 0.0) {
        c_print_err("MochaLibError (mocha-space): Semi-major axis must be non-zero.");
        c_exit(2);
    };
    if (mu <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Gravitational parameter mu must be positive.");
        c_exit(2);
    };
    var term: float = (2.0 / r) - (1.0 / a);
    var radicand: float = mu * term;
    if (radicand < 0.0) {
        c_print_err("MochaLibError (mocha-space): Invalid orbit — (2/r - 1/a) is negative for these values.");
        c_exit(2);
    };
    return radicand.sqrt().real;
};

~~ Escape velocity in m/s at radius r (m) with gravitational parameter mu (m³/s²).
~~ v = √(2μ/r). Requires r > 0 and mu > 0.
function escape_velocity(r: float, mu: float) -> float {
    if (r <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Radius must be positive.");
        c_exit(2);
    };
    if (mu <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Gravitational parameter mu must be positive.");
        c_exit(2);
    };
    var radicand: float = unsafe_div(unsafe_mul(2.0, mu), r);
    return radicand.sqrt().real;
};

~~ Periapsis distance in m from semi-major axis a (m) and eccentricity e.
~~ r_p = a(1 - e). Requires a > 0 and 0 <= e < 1 (elliptical).
function periapsis(a: float, e: float) -> float {
    if (a <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Semi-major axis must be positive.");
        c_exit(2);
    };
    if (e < 0.0 || e >= 1.0) {
        c_print_err("MochaLibError (mocha-space): Eccentricity must be in [0, 1) for elliptical periapsis.");
        c_exit(2);
    };
    return a * (1.0 - e);
};

~~ Apoapsis distance in m from semi-major axis a (m) and eccentricity e.
~~ r_a = a(1 + e). Requires a > 0 and 0 <= e < 1 (elliptical).
function apoapsis(a: float, e: float) -> float {
    if (a <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Semi-major axis must be positive.");
        c_exit(2);
    };
    if (e < 0.0 || e >= 1.0) {
        c_print_err("MochaLibError (mocha-space): Eccentricity must be in [0, 1) for elliptical apoapsis.");
        c_exit(2);
    };
    return a * (1.0 + e);
};

~~ Specific orbital energy in J/kg from semi-major axis a (m) and mu (m³/s²).
~~ ε = -μ/(2a). Requires a non-zero and mu > 0.
function orbital_energy(a: float, mu: float) -> float {
    if (a == 0.0) {
        c_print_err("MochaLibError (mocha-space): Semi-major axis must be non-zero.");
        c_exit(2);
    };
    if (mu <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Gravitational parameter mu must be positive.");
        c_exit(2);
    };
    return -(mu / (2.0 * a));
};

~~ Specific angular momentum in m²/s from a (m), e, mu (m³/s²).
~~ h = √(μ·a·(1-e²)). Requires a > 0, 0 <= e <= 1 (elliptical/parabolic boundary).
function specific_angular_momentum(a: float, e: float, mu: float) -> float {
    if (a <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Semi-major axis must be positive.");
        c_exit(2);
    };
    if (e < 0.0 || e > 1.0) {
        c_print_err("MochaLibError (mocha-space): Eccentricity must be in [0, 1] for this formula.");
        c_exit(2);
    };
    if (mu <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Gravitational parameter mu must be positive.");
        c_exit(2);
    };
    var radicand: float = mu * a * (1.0 - e * e);
    return radicand.sqrt().real;
};

~~ Mean motion in rad/s from semi-major axis a (m) and mu (m³/s²).
~~ n = √(μ/a³). Requires a > 0 and mu > 0.
function mean_motion(a: float, mu: float) -> float {
    if (a <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Semi-major axis must be positive.");
        c_exit(2);
    };
    if (mu <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Gravitational parameter mu must be positive.");
        c_exit(2);
    };
    var radicand: float = mu / fast_pow(a, 3);
    return radicand.sqrt().real;
};

~~ Mean anomaly m (rad) at time t (s) given mean motion n (rad/s) and time of periapsis t_p (s).
~~ m = n(t - t_p).
function mean_anomaly(n: float, t: float, t_p: float) -> float {
    return n * (t - t_p);
};

~~ Eccentric anomaly E (rad) from mean anomaly m (rad) and eccentricity e via Newton's method.
~~ Solves Kepler's equation m = E - e·sin(E). Converges to 1E-10 in ≤50 iterations for e < 1.
function eccentric_anomaly(m: float, e: float) -> float {
    if (e < 0.0 || e >= 1.0) {
        c_print_err("MochaLibError (mocha-space): Eccentricity must be in [0, 1) for elliptical Kepler solver.");
        c_exit(2);
    };
    var E_cap: float = m;
    var i: int = 0;
    var converged: bool = false;
    while (i < 50) {
        var dE: float = (E_cap - e * E_cap.sin(RAD) - m) / (1.0 - e * E_cap.cos(RAD));
        E_cap = E_cap - dE;
        if (abs(dE) < 1E-10) {
            converged = true;
            i = 50;
        };
        i++;
    };
    if (!converged) {
        c_print_err("MochaLibError (mocha-space): Kepler solver did not converge in 50 iterations.");
        c_exit(2);
    };
    return E_cap;
};

~~ True anomaly ν (rad) from eccentric anomaly E (rad) and eccentricity e.
~~ tan(ν/2) = √((1+e)/(1-e))·tan(E/2). Requires 0 <= e < 1.
function true_anomaly_from_eccentric(E_cap: float, e: float) -> float {
    if (e < 0.0 || e >= 1.0) {
        c_print_err("MochaLibError (mocha-space): Eccentricity must be in [0, 1) for elliptical true anomaly.");
        c_exit(2);
    };
    var radicand: float = (1.0 + e) / (1.0 - e);
    var factor: float = radicand.sqrt().real;
    var tan_half_E: float = (E_cap / 2.0).tan(RAD);
    return 2.0 * (factor * tan_half_E).inv_tan();
};

~~ True anomaly ν (rad) from mean anomaly m (rad) and eccentricity e.
~~ Combines Kepler solver + true anomaly conversion. Requires 0 <= e < 1.
function true_anomaly_from_mean(m: float, e: float) -> float {
    if (e < 0.0 || e >= 1.0) {
        c_print_err("MochaLibError (mocha-space): Eccentricity must be in [0, 1) for elliptical true anomaly.");
        c_exit(2);
    };
    return true_anomaly_from_eccentric(eccentric_anomaly(m, e), e);
};

~~ Radial distance in m at eccentric anomaly E (rad).
~~ r = a(1 - e·cos(E)). Requires a > 0 and 0 <= e < 1.
function radial_distance(a: float, e: float, E_cap: float) -> float {
    if (a <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Semi-major axis must be positive.");
        c_exit(2);
    };
    if (e < 0.0 || e >= 1.0) {
        c_print_err("MochaLibError (mocha-space): Eccentricity must be in [0, 1) for elliptical radial distance.");
        c_exit(2);
    };
    return a * (1.0 - e * E_cap.cos(RAD));
};

~~ Flight path angle γ (rad) from eccentricity e and true anomaly ν (rad).
~~ γ = atan2(e·sin(ν), 1 + e·cos(ν)). Requires e >= 0.
function flight_path_angle(e: float, nu: float) -> float {
    if (e < 0.0) {
        c_print_err("MochaLibError (mocha-space): Eccentricity cannot be negative.");
        c_exit(2);
    };
    return atan2(e * nu.sin(RAD), 1.0 + e * nu.cos(RAD));
};

~~ Synodic period in s between two orbital periods p1 (s) and p2 (s).
~~ 1/P_syn = |1/p1 - 1/p2|. Requires p1 > 0, p2 > 0, and p1 != p2.
function synodic_period(p1: float, p2: float) -> float {
    if (p1 <= 0.0) {
        c_print_err("MochaLibError (mocha-space): First period must be positive.");
        c_exit(2);
    };
    if (p2 <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Second period must be positive.");
        c_exit(2);
    };
    if (p1 == p2) {
        c_print_err("MochaLibError (mocha-space): Synodic period undefined for identical orbits.");
        c_exit(2);
    };
    return 1.0 / abs((1.0 / p1) - (1.0 / p2));
};

~~ Hohmann transfer ellipse semi-major axis in m from inner radius r1 (m) and outer radius r2 (m).
~~ a_t = (r1 + r2)/2. Requires r1 > 0 and r2 > 0.
function hohmann_transfer_sma(r1: float, r2: float) -> float {
    if (r1 <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Inner radius must be positive.");
        c_exit(2);
    };
    if (r2 <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Outer radius must be positive.");
        c_exit(2);
    };
    return (r1 + r2) / 2.0;
};

~~ Hohmann departure burn Δv in m/s from r1 (m), r2 (m), mu (m³/s²).
~~ Δv1 = √(μ/r1)·(√(2r2/(r1+r2)) - 1). Requires r1 > 0, r2 > 0, mu > 0.
function hohmann_dv1(r1: float, r2: float, mu: float) -> float {
    if (r1 <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Inner radius must be positive.");
        c_exit(2);
    };
    if (r2 <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Outer radius must be positive.");
        c_exit(2);
    };
    if (mu <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Gravitational parameter mu must be positive.");
        c_exit(2);
    };
    var radicand1: float = mu / r1;
    var v1: float = radicand1.sqrt().real;
    var radicand2: float = 2.0 * r2 / (r1 + r2);
    var factor: float = radicand2.sqrt().real;
    return v1 * (factor - 1.0);
};

~~ Hohmann arrival burn Δv in m/s from r1 (m), r2 (m), mu (m³/s²).
~~ Δv2 = √(μ/r2)·(1 - √(2r1/(r1+r2))). Requires r1 > 0, r2 > 0, mu > 0.
function hohmann_dv2(r1: float, r2: float, mu: float) -> float {
    if (r1 <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Inner radius must be positive.");
        c_exit(2);
    };
    if (r2 <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Outer radius must be positive.");
        c_exit(2);
    };
    if (mu <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Gravitational parameter mu must be positive.");
        c_exit(2);
    };
    var radicand1: float = mu / r2;
    var v2: float = radicand1.sqrt().real;
    var radicand2: float = 2.0 * r1 / (r1 + r2);
    var factor: float = radicand2.sqrt().real;
    return v2 * (1.0 - factor);
};

~~ Total Hohmann transfer Δv magnitude in m/s (sum of departure and arrival burns).
~~ Requires r1 > 0, r2 > 0, mu > 0.
function hohmann_dv_total(r1: float, r2: float, mu: float) -> float {
    if (r1 <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Inner radius must be positive.");
        c_exit(2);
    };
    if (r2 <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Outer radius must be positive.");
        c_exit(2);
    };
    if (mu <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Gravitational parameter mu must be positive.");
        c_exit(2);
    };
    return abs(hohmann_dv1(r1, r2, mu)) + abs(hohmann_dv2(r1, r2, mu));
};

~~ Sphere of influence radius in m from semi-major axis a (m) and mass ratio.
~~ r_SOI = a·(m_small/m_large)^(2/5). Requires a > 0, m_small > 0, m_large > 0.
function sphere_of_influence(a: float, m_small: float, m_large: float) -> float {
    if (a <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Semi-major axis must be positive.");
        c_exit(2);
    };
    if (m_small <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Small body mass must be positive.");
        c_exit(2);
    };
    if (m_large <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Large body mass must be positive.");
        c_exit(2);
    };
    return a * c_pow(m_small / m_large, 0.4);
};

~~ Hill sphere radius in m from a (m), e, m_small (kg), m_large (kg).
~~ r_H = a(1-e)·(m_small/(3·m_large))^(1/3). Requires a > 0, 0 <= e < 1, masses > 0.
function hill_sphere(a: float, e: float, m_small: float, m_large: float) -> float {
    if (a <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Semi-major axis must be positive.");
        c_exit(2);
    };
    if (e < 0.0 || e >= 1.0) {
        c_print_err("MochaLibError (mocha-space): Eccentricity must be in [0, 1) for Hill sphere.");
        c_exit(2);
    };
    if (m_small <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Small body mass must be positive.");
        c_exit(2);
    };
    if (m_large <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Large body mass must be positive.");
        c_exit(2);
    };
    var inner: float = m_small / (3.0 * m_large);
    return a * (1.0 - e) * inner.cubrot();
};

~~ Roche limit in m for a rigid satellite from primary radius R (m) and densities (kg/m³).
~~ d = 2.46·R_primary·(ρ_primary/ρ_secondary)^(1/3). Requires R > 0 and both densities > 0.
function roche_limit_rigid(R_primary: float, rho_primary: float, rho_secondary: float) -> float {
    if (R_primary <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Primary radius must be positive.");
        c_exit(2);
    };
    if (rho_primary <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Primary density must be positive.");
        c_exit(2);
    };
    if (rho_secondary <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Secondary density must be positive.");
        c_exit(2);
    };
    var inner: float = rho_primary / rho_secondary;
    return 2.46 * R_primary * inner.cubrot();
};

~~ Roche limit in m for a fluid satellite from primary radius R (m) and masses (kg).
~~ d = 2.44·R_primary·(M_primary/M_secondary)^(1/3). Requires R > 0 and both masses > 0.
function roche_limit_fluid(R_primary: float, M_primary: float, M_secondary: float) -> float {
    if (R_primary <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Primary radius must be positive.");
        c_exit(2);
    };
    if (M_primary <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Primary mass must be positive.");
        c_exit(2);
    };
    if (M_secondary <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Secondary mass must be positive.");
        c_exit(2);
    };
    var inner: float = M_primary / M_secondary;
    return 2.44 * R_primary * inner.cubrot();
};

~~ Δv in m/s for a pure inclination change from velocity v (m/s) and inclination change Δi (deg).
~~ Δv = 2v·sin(Δi/2). Requires v >= 0.
function inclination_change_dv(v: float, delta_i_deg: float) -> float {
    if (v < 0.0) {
        c_print_err("MochaLibError (mocha-space): Velocity cannot be negative.");
        c_exit(2);
    };
    return 2.0 * v * (delta_i_deg * DEG_TO_RAD / 2.0).sin(RAD);
};

~~ Classifies orbit by eccentricity e into OrbitType (CIRCULAR, ELLIPTICAL, PARABOLIC, HYPERBOLIC).
~~ Requires e >= 0.
function orbit_type(e: float) -> OrbitType {
    if (e < 0.0) {
        c_print_err("MochaLibError (mocha-space): Eccentricity cannot be negative.");
        c_exit(2);
    };
    if (e < 0.001) { return OrbitType.CIRCULAR; };
    if (e < 1.0)   { return OrbitType.ELLIPTICAL; };
    if (e == 1.0)  { return OrbitType.PARABOLIC; };
    return OrbitType.HYPERBOLIC;
};

// ─── SECTION 2: STELLAR PHYSICS & PHOTOMETRY ─────────────────────────────────

~~ Stefan-Boltzmann law: stellar luminosity in W from radius r (m) and effective temperature t (K).
~~ L = 4π R² σ T⁴. Requires r > 0 and t > 0.
function luminosity_from_radius_temp(r: float, t: float) -> float {
    if (r <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Stellar radius must be positive.");
        c_exit(2);
    };
    if (t <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Effective temperature must be positive.");
        c_exit(2);
    };
    var r2: float = unsafe_mul(r, r);
    var t2: float = unsafe_mul(t, t);
    var t4: float = unsafe_mul(t2, t2);
    var area_term: float = unsafe_mul(4.0 * PI, r2);
    var flux_term: float = unsafe_mul(STEFAN_BOLTZMANN, t4);
    return unsafe_mul(area_term, flux_term);
};

~~ Stellar radius in m from luminosity l (W) and effective temperature t (K).
~~ R = √(L / (4π σ T⁴)). Requires l > 0 and t > 0.
function radius_from_luminosity_temp(l: float, t: float) -> float {
    if (l <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Luminosity must be positive.");
        c_exit(2);
    };
    if (t <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Effective temperature must be positive.");
        c_exit(2);
    };
    var t2: float = unsafe_mul(t, t);
    var t4: float = unsafe_mul(t2, t2);
    var denom: float = unsafe_mul(unsafe_mul(4.0 * PI, STEFAN_BOLTZMANN), t4);
    var radicand: float = unsafe_div(l, denom);
    return radicand.sqrt().real;
};

~~ Effective temperature in K from luminosity l (W) and radius r (m).
~~ T = (L / (4π R² σ))^(1/4). Requires l > 0 and r > 0.
function temp_from_luminosity_radius(l: float, r: float) -> float {
    if (l <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Luminosity must be positive.");
        c_exit(2);
    };
    if (r <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Stellar radius must be positive.");
        c_exit(2);
    };
    var r2: float = unsafe_mul(r, r);
    var denom: float = unsafe_mul(unsafe_mul(4.0 * PI, r2), STEFAN_BOLTZMANN);
    var inner: float = unsafe_div(l, denom);
    return c_pow(inner, 0.25);
};

~~ Wien's displacement law: peak emission wavelength in m from temperature t (K).
~~ λ_max = b / T. Requires t > 0.
function wien_peak_wavelength(t: float) -> float {
    if (t <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Temperature must be positive.");
        c_exit(2);
    };
    return WIEN_B / t;
};

~~ Inverse Wien's law: temperature in K from peak wavelength lambda_max (m).
~~ T = b / λ_max. Requires lambda_max > 0.
function wien_temp_from_wavelength(lambda_max: float) -> float {
    if (lambda_max <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Peak wavelength must be positive.");
        c_exit(2);
    };
    return WIEN_B / lambda_max;
};

~~ Stellar distance in parsecs from parallax angle p_arcsec (arcsec).
~~ d = 1 / p″. Requires p_arcsec > 0.
function parallax_to_distance_pc(p_arcsec: float) -> float {
    if (p_arcsec <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Parallax angle must be positive.");
        c_exit(2);
    };
    return 1.0 / p_arcsec;
};

~~ Parallax angle in arcsec from distance d_pc (parsecs).
~~ p″ = 1 / d. Requires d_pc > 0.
function distance_to_parallax(d_pc: float) -> float {
    if (d_pc <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Distance must be positive.");
        c_exit(2);
    };
    return 1.0 / d_pc;
};

~~ Distance modulus in magnitudes from apparent magnitude m and absolute magnitude M_abs.
~~ μ = m - M. No constraint on magnitudes (negative values valid for bright objects).
function distance_modulus(m: float, M_abs: float) -> float {
    return m - M_abs;
};

~~ Distance in parsecs from distance modulus mu.
~~ d = 10^((μ+5)/5). No constraint on μ (any real value valid).
function distance_from_modulus(mu: float) -> float {
    var exponent: float = (mu + 5.0) / 5.0;
    return c_pow(10.0, exponent);
};

~~ Absolute magnitude from apparent magnitude m and distance d_pc (parsecs).
~~ M = m - 5·log10(d) + 5. Requires d_pc > 0.
function absolute_magnitude(m: float, d_pc: float) -> float {
    if (d_pc <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Distance must be positive.");
        c_exit(2);
    };
    var log_d: float = d_pc.log10().real;
    return m - 5.0 * log_d + 5.0;
};

~~ Apparent magnitude from absolute magnitude M_abs and distance d_pc (parsecs).
~~ m = M + 5·log10(d) - 5. Requires d_pc > 0.
function apparent_magnitude(M_abs: float, d_pc: float) -> float {
    if (d_pc <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Distance must be positive.");
        c_exit(2);
    };
    var log_d: float = d_pc.log10().real;
    return M_abs + 5.0 * log_d - 5.0;
};

~~ Flux ratio F1/F2 from two magnitudes m1 and m2.
~~ F1/F2 = 10^(0.4·(m2-m1)). No constraint (any real magnitudes valid).
function flux_ratio_from_magnitudes(m1: float, m2: float) -> float {
    var exponent: float = 0.4 * (m2 - m1);
    return c_pow(10.0, exponent);
};

~~ Magnitude difference Δm from flux ratio F1/F2.
~~ Δm = -2.5·log10(F1/F2). Requires ratio > 0.
function magnitude_diff_from_flux_ratio(ratio: float) -> float {
    if (ratio <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Flux ratio must be positive.");
        c_exit(2);
    };
    var log_ratio: float = ratio.log10().real;
    return -2.5 * log_ratio;
};

~~ Luminosity in solar units (dimensionless) from absolute luminosity l (W).
~~ No constraint (any real luminosity valid).
function luminosity_to_solar(l: float) -> float {
    return l / LUMINOSITY_SUN;
};

~~ Luminosity in W from solar-unit luminosity l_sun.
~~ No constraint (any real value valid).
function luminosity_from_solar(l_sun: float) -> float {
    return unsafe_mul(l_sun, LUMINOSITY_SUN);
};

~~ Mass-luminosity relation for main sequence stars: L/L_sun ≈ (M/M_sun)^3.5.
~~ Valid roughly 0.5–20 solar masses. Requires mass_solar > 0.
function main_sequence_luminosity(mass_solar: float) -> float {
    if (mass_solar <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Stellar mass must be positive.");
        c_exit(2);
    };
    return c_pow(mass_solar, 3.5);
};

~~ Approximate main sequence lifetime in years from stellar mass in solar units.
~~ t ≈ 10^10 · (M/M_sun) / (L/L_sun). Requires mass_solar > 0.
function main_sequence_lifetime(mass_solar: float) -> float {
    if (mass_solar <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Stellar mass must be positive.");
        c_exit(2);
    };
    var l_solar: float = main_sequence_luminosity(mass_solar);
    return 1.0E10 * (mass_solar / l_solar);
};

~~ Event horizon radius in m for a non-rotating mass (Schwarzschild radius).
~~ r_s = 2GM/c². Requires mass > 0.
function schwarzschild_radius(mass: float) -> float {
    if (mass <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Mass must be positive.");
        c_exit(2);
    };
    var numerator: float = unsafe_mul(unsafe_mul(2.0, G), mass);
    var c2: float = unsafe_mul(SPEED_OF_LIGHT, SPEED_OF_LIGHT);
    return unsafe_div(numerator, c2);
};

~~ Energy of a photon in J at wavelength (m).
~~ E = hc/λ. Requires wavelength > 0.
function photon_energy(wavelength: float) -> float {
    if (wavelength <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Wavelength must be positive.");
        c_exit(2);
    };
    var numerator: float = unsafe_mul(PLANCK_H, SPEED_OF_LIGHT);
    return unsafe_div(numerator, wavelength);
};

// ─── SECTION 3: PLANETARY ATMOSPHERES & HABITABILITY ─────────────────────────

~~ Planetary equilibrium temperature in K from stellar luminosity l (W), orbital distance d (m), and Bond albedo.
~~ T_eq = (L(1-A) / (16π σ D²))^(1/4). Requires l > 0, d > 0, and 0 <= albedo < 1.
function equilibrium_temp(l: float, d: float, albedo: float) -> float {
    if (l <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Stellar luminosity must be positive.");
        c_exit(2);
    };
    if (d <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Orbital distance must be positive.");
        c_exit(2);
    };
    if (albedo < 0.0 || albedo >= 1.0) {
        c_print_err("MochaLibError (mocha-space): Bond albedo must be in [0, 1).");
        c_exit(2);
    };
    var d2: float = unsafe_mul(d, d);
    var denom: float = unsafe_mul(unsafe_mul(16.0 * PI, STEFAN_BOLTZMANN), d2);
    var numer: float = unsafe_mul(l, (1.0 - albedo));
    var inner: float = unsafe_div(numer, denom);
    return c_pow(inner, 0.25);
};

~~ Planetary equilibrium temperature in K from stellar temperature t_star (K), stellar radius r_star (m), orbital distance d (m), and Bond albedo.
~~ T_eq = T_star · √(R_star / (2D)) · (1-A)^(1/4). Requires t_star > 0, r_star > 0, d > 0, and 0 <= albedo < 1.
function equilibrium_temp_from_star(t_star: float, r_star: float, d: float, albedo: float) -> float {
    if (t_star <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Stellar temperature must be positive.");
        c_exit(2);
    };
    if (r_star <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Stellar radius must be positive.");
        c_exit(2);
    };
    if (d <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Orbital distance must be positive.");
        c_exit(2);
    };
    if (albedo < 0.0 || albedo >= 1.0) {
        c_print_err("MochaLibError (mocha-space): Bond albedo must be in [0, 1).");
        c_exit(2);
    };
    var ratio: float = unsafe_div(r_star, unsafe_mul(2.0, d));
    var sqrt_term: float = ratio.sqrt().real;
    var albedo_term: float = c_pow(1.0 - albedo, 0.25);
    return unsafe_mul(unsafe_mul(t_star, sqrt_term), albedo_term);
};

~~ Stellar flux (insolation) in W/m² received at orbital distance d (m) from luminosity l (W).
~~ S = L / (4π D²). Requires l > 0 and d > 0.
function solar_flux_at_distance(l: float, d: float) -> float {
    if (l <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Stellar luminosity must be positive.");
        c_exit(2);
    };
    if (d <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Orbital distance must be positive.");
        c_exit(2);
    };
    var d2: float = unsafe_mul(d, d);
    var denom: float = unsafe_mul(4.0 * PI, d2);
    return unsafe_div(l, denom);
};

~~ Total power absorbed by a planet in W from stellar luminosity l (W), orbital distance d (m), planet radius r_planet (m), and Bond albedo.
~~ P_abs = (1-A) · L · (π R_planet²) / (4π D²). Requires l > 0, d > 0, r_planet > 0, and 0 <= albedo < 1.
function absorbed_power(l: float, d: float, r_planet: float, albedo: float) -> float {
    if (l <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Stellar luminosity must be positive.");
        c_exit(2);
    };
    if (d <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Orbital distance must be positive.");
        c_exit(2);
    };
    if (r_planet <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Planet radius must be positive.");
        c_exit(2);
    };
    if (albedo < 0.0 || albedo >= 1.0) {
        c_print_err("MochaLibError (mocha-space): Bond albedo must be in [0, 1).");
        c_exit(2);
    };
    var flux: float = solar_flux_at_distance(l, d);
    var cross_section: float = unsafe_mul(PI, unsafe_mul(r_planet, r_planet));
    var absorbed_fraction: float = 1.0 - albedo;
    return unsafe_mul(unsafe_mul(flux, cross_section), absorbed_fraction);
};

~~ Atmospheric scale height in m from temperature t (K), molar mass (kg/mol), and surface gravity g (m/s²).
~~ H = RT / (Mg). Requires t > 0, molar_mass > 0, and g > 0.
function scale_height(t: float, molar_mass: float, g: float) -> float {
    if (t <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Temperature must be positive (use Kelvin).");
        c_exit(2);
    };
    if (molar_mass <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Molar mass must be positive.");
        c_exit(2);
    };
    if (g <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Surface gravity must be positive.");
        c_exit(2);
    };
    const R_GAS: float = 8.314462618;
    var numer: float = unsafe_mul(R_GAS, t);
    var denom: float = unsafe_mul(molar_mass, g);
    return unsafe_div(numer, denom);
};

~~ Atmospheric pressure in Pa at altitude h (m) from surface pressure p0 (Pa) and scale height scale_h (m).
~~ P(h) = P0 · e^(-h/H). Requires p0 > 0 and scale_h > 0.
function atmospheric_pressure_at_height(p0: float, h: float, scale_h: float) -> float {
    if (p0 <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Surface pressure must be positive.");
        c_exit(2);
    };
    if (scale_h <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Scale height must be positive.");
        c_exit(2);
    };
    var exponent: float = -(h / scale_h);
    return p0 * c_exp(exponent);
};

~~ Surface gravitational acceleration in m/s² from body mass (kg) and radius (m).
~~ g = GM/r². Requires mass > 0 and radius > 0.
function surface_gravity(mass: float, radius: float) -> float {
    if (mass <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Body mass must be positive.");
        c_exit(2);
    };
    if (radius <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Body radius must be positive.");
        c_exit(2);
    };
    var r2: float = unsafe_mul(radius, radius);
    var gm: float = unsafe_mul(G, mass);
    return unsafe_div(gm, r2);
};

~~ Escape velocity in m/s from body mass (kg) and radius (m).
~~ v_esc = √(2GM/r). Requires mass > 0 and radius > 0.
function escape_velocity_from_mass_radius(mass: float, radius: float) -> float {
    if (mass <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Body mass must be positive.");
        c_exit(2);
    };
    if (radius <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Body radius must be positive.");
        c_exit(2);
    };
    var gm: float = unsafe_mul(G, mass);
    var radicand: float = unsafe_div(unsafe_mul(2.0, gm), radius);
    return radicand.sqrt().real;
};

~~ Simplified Earth-equivalent-insolation habitable zone distance in AU from stellar luminosity l_solar (solar units).
~~ d_HZ = √(L / L_sun). First-pass estimate — for the full Kasting et al. (1993) model, use the temperature-dependent version. Requires l_solar > 0.
function habitable_zone_distance_simple(l_solar: float) -> float {
    if (l_solar <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Stellar luminosity must be positive.");
        c_exit(2);
    };
    return l_solar.sqrt().real;
};

~~ Mean free path of gas molecules in m from temperature temp (K), pressure (Pa), and molecule diameter (m).
~~ λ = kT / (√2 · π · d² · P). Requires temp > 0, pressure > 0, and molecule_diameter > 0.
function mean_free_path(temp: float, pressure: float, molecule_diameter: float) -> float {
    if (temp <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Temperature must be positive (use Kelvin).");
        c_exit(2);
    };
    if (pressure <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Pressure must be positive.");
        c_exit(2);
    };
    if (molecule_diameter <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Molecule diameter must be positive.");
        c_exit(2);
    };
    var d2: float = unsafe_mul(molecule_diameter, molecule_diameter);
    var denom: float = unsafe_mul(unsafe_mul(1.4142135623730951 * PI, d2), pressure);
    var numer: float = unsafe_mul(BOLTZMANN_K, temp);
    return unsafe_div(numer, denom);
};

~~ Jeans escape parameter λ_J — ratio governing atmospheric retention.
~~ Values >> 1 indicate the gas is gravitationally bound (retained); values << 1 indicate rapid thermal escape.
~~ λ_J = (v_esc / v_thermal)². Requires escape_v >= 0 and thermal_v > 0.
function jeans_escape_parameter(escape_v: float, thermal_v: float) -> float {
    if (escape_v < 0.0) {
        c_print_err("MochaLibError (mocha-space): Escape velocity cannot be negative.");
        c_exit(2);
    };
    if (thermal_v <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Thermal velocity must be positive.");
        c_exit(2);
    };
    var ratio: float = unsafe_div(escape_v, thermal_v);
    return unsafe_mul(ratio, ratio);
};

~~ Most probable thermal speed of gas molecules in m/s from temperature (K) and molar mass (kg/mol).
~~ v_thermal = √(2RT/M) (Maxwell-Boltzmann most probable speed). Requires temp > 0 and molar_mass > 0.
function thermal_velocity(temp: float, molar_mass: float) -> float {
    if (temp <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Temperature must be positive (use Kelvin).");
        c_exit(2);
    };
    if (molar_mass <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Molar mass must be positive.");
        c_exit(2);
    };
    const R_GAS: float = 8.314462618;
    var numer: float = unsafe_mul(2.0 * R_GAS, temp);
    var radicand: float = unsafe_div(numer, molar_mass);
    return radicand.sqrt().real;
};

// ─── SECTION 4: CELESTIAL COORDINATES ─────────────────────────────────────────

~~ Local hour angle in degrees from local sidereal time lst (deg) and right ascension ra (deg).
~~ H = LST - RA. Result wrapped to [-180, 180). No input constraints (any angle valid).
function hour_angle(lst: float, ra: float) -> float {
    var h: float = lst - ra;
    while (h < -180.0) { h = h + 360.0; };
    while (h >= 180.0) { h = h - 360.0; };
    return h;
};

~~ Convert equatorial (RA/Dec) to horizontal (Alt/Az) coordinates in degrees.
~~ Azimuth measured from North, through East (0°=N, 90°=E, 180°=S, 270°=W).
~~ Returns (altitude, azimuth). Latitude must be in [-90, 90].
function equatorial_to_horizontal(ra: float, dec: float, lat: float, lst: float) -> (float, 2) {
    if (lat < -90.0 || lat > 90.0) {
        c_print_err("MochaLibError (mocha-space): Latitude must be in [-90, 90] degrees.");
        c_exit(2);
    };
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

~~ Convert horizontal (Alt/Az) to equatorial (RA/Dec) coordinates in degrees.
~~ Azimuth is North-based (0°=N, 90°=E). Returns (ra, dec). Latitude must be in [-90, 90].
function horizontal_to_equatorial(alt: float, az: float, lat: float, lst: float) -> (float, 2) {
    if (lat < -90.0 || lat > 90.0) {
        c_print_err("MochaLibError (mocha-space): Latitude must be in [-90, 90] degrees.");
        c_exit(2);
    };
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

~~ Angular separation in degrees between two celestial coordinates via spherical law of cosines.
~~ Exact for any separation. No input constraints (any RA/Dec valid).
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

~~ Fast small-angle approximation for angular separation in degrees.
~~ γ ≈ √((Δra·cos(dec))² + Δdec²). Valid only for separations under a few degrees — for larger separations use angular_separation.
function angular_separation_small(ra1: float, dec1: float, ra2: float, dec2: float) -> float {
    var d_ra: float = (ra1 - ra2) * DEG_TO_RAD;
    var d_dec: float = dec1 - dec2;
    var dec_avg_r: float = ((dec1 + dec2) / 2.0) * DEG_TO_RAD;
    var ra_term: float = d_ra * dec_avg_r.cos(RAD) * RAD_TO_DEG;
    var radicand: float = ra_term * ra_term + d_dec * d_dec;
    return radicand.sqrt().real;
};

~~ Convert equatorial to ecliptic coordinates in degrees. Returns (ecliptic longitude, ecliptic latitude).
~~ Obliquity in degrees (23.4392911 for J2000).
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

~~ Convert ecliptic to equatorial coordinates in degrees. Returns (right ascension, declination).
~~ Obliquity in degrees.
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

~~ Convert J2000 equatorial coordinates to galactic coordinates in degrees.
~~ Returns (galactic longitude, galactic latitude). No input constraints.
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

~~ Distance in parsecs from parallax angle in milliarcseconds.
~~ d = 1000 / p_mas. Requires p_mas > 0.
function parallax_angle_to_distance(p_mas: float) -> float {
    if (p_mas <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Parallax must be positive.");
        c_exit(2);
    };
    return 1000.0 / p_mas;
};

~~ Total proper motion magnitude in mas/year from pm_ra (assumed already pre-multiplied by cos(dec) — true angle) and pm_dec.
~~ μ_total = √(pm_ra² + pm_dec²). No input constraints.
function proper_motion_total(pm_ra: float, pm_dec: float, dec: float) -> float {
    var radicand: float = pm_ra * pm_ra + pm_dec * pm_dec;
    return radicand.sqrt().real;
};

~~ Total proper motion in mas/year from raw μ_α (not pre-multiplied by cos(dec)) and μ_dec.
~~ μ_total = √((μ_α·cos(dec))² + μ_dec²). No input constraints.
function proper_motion_total_raw(pm_ra_raw: float, pm_dec: float, dec: float) -> float {
    var dec_r: float = dec * DEG_TO_RAD;
    var pm_ra_corrected: float = pm_ra_raw * dec_r.cos(RAD);
    var radicand: float = pm_ra_corrected * pm_ra_corrected + pm_dec * pm_dec;
    return radicand.sqrt().real;
};

~~ Position angle of object 2 relative to object 1 in degrees (0=North, 90=East, counterclockwise from North).
~~ No input constraints.
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

~~ Approximate atmospheric refraction correction in arcminutes from apparent altitude in degrees.
~~ R = cot(alt) — Bennett's simplified low-precision form. Valid only for altitudes above ~15°.
~~ Requires apparent_alt in (0, 90).
function atmospheric_refraction(apparent_alt: float) -> float {
    if (apparent_alt <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Apparent altitude must be positive (formula valid only above horizon).");
        c_exit(2);
    };
    if (apparent_alt >= 90.0) {
        c_print_err("MochaLibError (mocha-space): Apparent altitude must be less than 90 degrees.");
        c_exit(2);
    };
    var alt_r: float = apparent_alt * DEG_TO_RAD;
    var tan_alt: float = alt_r.tan(RAD);
    if (tan_alt <= 0.0) {
        c_print_err("MochaLibError (mocha-space): Apparent altitude too small — refraction formula breaks down near horizon.");
        c_exit(2);
    };
    return 1.0 / tan_alt;
};

~~ Approximate precession correction in degrees over a number of years, using general precession rate.
~~ Not a substitute for rigorous Meeus precession algorithm. Returns (new_ra, new_dec).
~~ Valid only for dec in (-90, 90) — pole is undefined. Recommended for spans under ~100 years.
function precess_ra_dec(ra: float, dec: float, years: float) -> (float, 2) {
    if (dec <= -90.0 || dec >= 90.0) {
        c_print_err("MochaLibError (mocha-space): Declination must be strictly in (-90, 90) degrees for precession.");
        c_exit(2);
    };
    if (abs(years) > 1000.0) {
        c_print_err("MochaLibError (mocha-space): Precession simplification unreliable for spans over 1000 years.");
        c_exit(2);
    };
    var total_arcsec: float = PRECESSION_RATE * years;
    var total_deg: float = total_arcsec * ARCSEC_TO_DEG;
    var dec_r: float = dec * DEG_TO_RAD;

    var cos_dec: float = dec_r.cos(RAD);
    var ra_shift: float = total_deg / cos_dec;

    var new_ra: float = ra + ra_shift;
    while (new_ra < 0.0) { new_ra = new_ra + 360.0; };
    while (new_ra >= 360.0) { new_ra = new_ra - 360.0; };

    return (new_ra, dec);
};

~~ Convert hour-angle units (hours) to degrees. 1h = 15°. No input constraints.
function hours_to_degrees(hours: float) -> float {
    return hours * HOUR_TO_DEG;
};

~~ Convert degrees to hour-angle units (hours). 1° = 1/15 h. No input constraints.
function degrees_to_hours(deg: float) -> float {
    return deg / HOUR_TO_DEG;
};

~~ Convert degrees/arcminutes/arcseconds to decimal degrees. Sign of d determines overall sign.
~~ No input constraints (any real d, m, s valid).
function dms_to_degrees(d: float, m: float, s: float) -> float {
    var sign: float = 1.0;
    if (d < 0.0) {
        sign = -1.0;
    };
    var abs_d: float = abs(d);
    return sign * (abs_d + m / 60.0 + s / 3600.0);
};

~~ Convert decimal degrees to (degrees, arcminutes, arcseconds). Sign carried on degrees component.
~~ No input constraints.
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

~~ Convert hours/minutes/seconds (RA format) to decimal degrees. No input constraints.
function hms_to_degrees(h: float, m: float, s: float) -> float {
    var total_hours: float = h + m / 60.0 + s / 3600.0;
    return total_hours * HOUR_TO_DEG;
};

~~ Convert decimal degrees (RA) to (hours, minutes, seconds). No input constraints.
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

// ─── SECTION 5: TIME SYSTEMS ──────────────────────────────────────────────────

~~ Convert a Gregorian calendar date to Julian Date. day may include a fractional part for time-of-day.
~~ Valid only for Gregorian calendar dates (after 1582-10-15). Requires month in [1, 12] and day in (0, 32).
function julian_date(year: int, month: int, day: float) -> float {
    if (month < 1 || month > 12) {
        c_print_err("MochaLibError (mocha-space): Month must be in [1, 12].");
        c_exit(2);
    };
    if (day <= 0.0 || day >= 32.0) {
        c_print_err("MochaLibError (mocha-space): Day must be in (0, 32) — includes fractional day-of-month.");
        c_exit(2);
    };
    if (year < 1582) {
        c_print_err("MochaLibError (mocha-space): Gregorian calendar only — year must be >= 1582.");
        c_exit(2);
    };
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

~~ Convert Julian Date to Modified Julian Date. MJD = JD - 2400000.5. No constraints.
function julian_date_to_mjd(jd: float) -> float {
    return jd - MJD_OFFSET;
};

~~ Convert Modified Julian Date to Julian Date. No constraints.
function mjd_to_julian_date(mjd: float) -> float {
    return mjd + MJD_OFFSET;
};

~~ Number of Julian centuries (36525 days) elapsed since J2000.0 (JD 2451545.0).
~~ Standard time variable T for astronomical formulas. No constraints.
function j2000_centuries(jd: float) -> float {
    return (jd - JD_J2000) / JULIAN_CENTURY_DAYS;
};

~~ Number of days elapsed since J2000.0 (JD 2451545.0). No constraints.
function j2000_days(jd: float) -> float {
    return jd - JD_J2000;
};

~~ Greenwich Mean Sidereal Time in degrees (0-360) at the given Julian Date.
~~ IAU 1982 polynomial (Meeus / USNO Circular 179), accurate to ~0.1s over modern eras.
~~ Valid for dates within ±200 years of J2000.0 — for very distant epochs, the polynomial drifts.
function gmst_degrees(jd: float) -> float {
    if (abs(jd - JD_J2000) > 73050.0) {
        c_print_err("MochaLibError (mocha-space): GMST polynomial valid only within ±200 years of J2000.0.");
        c_exit(2);
    };
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

~~ Local Sidereal Time in degrees (0-360) from Julian Date jd and observer longitude in degrees (east positive).
~~ No constraints (any real longitude valid; wrapping handles out-of-range).
function lst_degrees(jd: float, longitude: float) -> float {
    var lst: float = gmst_degrees(jd) + longitude;
    while (lst < 0.0) { lst = lst + 360.0; };
    while (lst >= 360.0) { lst = lst - 360.0; };
    return lst;
};

~~ Convert a Unix timestamp (seconds since 1970-01-01 00:00 UTC) to Julian Date.
~~ Negative timestamps (pre-1970) are valid. No constraints.
function unix_to_julian_date(unix_seconds: float) -> float {
    return (unix_seconds / SECONDS_PER_DAY) + JD_UNIX_EPOCH;
};

~~ Convert Julian Date to a Unix timestamp (seconds since 1970-01-01 00:00 UTC).
~~ Negative results (pre-1970) are valid. No constraints.
function julian_date_to_unix(jd: float) -> float {
    return (jd - JD_UNIX_EPOCH) * SECONDS_PER_DAY;
};

~~ Convert a Julian Date in UTC to Terrestrial Time (TT).
~~ Uses fixed offset of 69.184s (37 leap seconds + 32.184s), valid only for 2017-01-01 through the next leap second announcement.
~~ Requires jd_utc in [2457754.5, 2465065.25] (2017 through ~2037).
function utc_to_tt(jd_utc: float) -> float {
    if (jd_utc < 2457754.5) {
        c_print_err("MochaLibError (mocha-space): utc_to_tt valid only for 2017-01-01 onward (JD >= 2457754.5).");
        c_exit(2);
    };
    if (jd_utc > 2465065.25) {
        c_print_err("MochaLibError (mocha-space): utc_to_tt offset may change after a future leap second — results unreliable beyond ~2037.");
        c_exit(2);
    };
    return jd_utc + (TT_MINUS_UTC / SECONDS_PER_DAY);
};

~~ Convert a Julian Date in Terrestrial Time (TT) to UTC. Same validity caveats as utc_to_tt.
function tt_to_utc(jd_tt: float) -> float {
    if (jd_tt < 2457754.5) {
        c_print_err("MochaLibError (mocha-space): tt_to_utc valid only for 2017-01-01 onward (JD >= 2457754.5).");
        c_exit(2);
    };
    if (jd_tt > 2465065.25) {
        c_print_err("MochaLibError (mocha-space): tt_to_utc offset may change after a future leap second — results unreliable beyond ~2037.");
        c_exit(2);
    };
    return jd_tt - (TT_MINUS_UTC / SECONDS_PER_DAY);
};

~~ Convert Julian Date to Besselian epoch (e.g. B1950.0). Used in older star catalogs.
~~ B = 1900.0 + (JD - 2415020.31352)/365.242198781. No constraints.
function besselian_epoch(jd: float) -> float {
    return 1900.0 + (jd - BESSELIAN_EPOCH_JD0) / BESSELIAN_YEAR_DAYS;
};

~~ Convert Besselian epoch to Julian Date. No constraints.
function besselian_epoch_to_jd(b: float) -> float {
    return BESSELIAN_EPOCH_JD0 + (b - 1900.0) * BESSELIAN_YEAR_DAYS;
};

~~ Convert Julian Date to Julian epoch (e.g. J2000.0). Modern star catalogs (post-1984) use Julian epochs.
~~ J = 2000.0 + (JD - 2451545.0)/365.25. No constraints.
function julian_epoch(jd: float) -> float {
    return 2000.0 + (jd - JD_J2000) / 365.25;
};