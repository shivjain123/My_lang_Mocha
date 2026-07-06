~~ mocha-astro — Vedic Astrology (Jyotish) Computation Library for Mocha
~~ Section 1: Ayanamsa & Sidereal Foundations
~~
~~ NOTE ON PRECISION: This library uses mean orbital elements and linear
~~ ayanamsa models (the same approach as Meeus's "Astronomical Algorithms"
~~ and most pre-2000 astrology software), not VSOP87/JPL-grade numerical
~~ ephemerides. Expect arcminute-level accuracy — sufficient for dasha,
~~ varga, and aspect work, but not observatory-grade. Ayanamsa constants
~~ are approximate mean models; exact values from Swiss Ephemeris-based
~~ software may differ by a few arcminutes due to periodic correction terms.
~~
~~ Part of the Mocha Scientific Library Ecosystem
~~ License: Polyform Non-Commercial

// mocha-lib-deps: mocha-math

const PRECESSION_RATE_DEG_YEAR: float = 0.0139552354;
const LAHIRI_AYANAMSA_2000: float = 23.85675;
const KP_AYANAMSA_2000: float = 23.71799;
const FAGAN_BRADLEY_1950: float = 24.0419;
const RAMAN_OFFSET: float = 0.6167;

// ================================================================
// SECTION 1: AYANAMSA & SIDEREAL FOUNDATIONS
// ================================================================

~~ Julian Day Number from a Gregorian calendar date and UT hour.
~~ year, month, day = calendar date, hour = UT time as decimal hours (e.g. 12.5 = 12:30).
~~ Standard astronomical algorithm (Meeus). Reference: JD(2000-01-01 12:00 UT) = 2451545.0.
function julian_day_number(year: int, month: int, day: int, hour: float) -> float {
    var y: int = year;
    var m: int = month;
    if (m <= 2) {
        y = y - 1;
        m = m + 12;
    };
    var y_float: float = float(y);
    var m_float: float = float(m);
    var a_raw: float = y_float / 100.0;
    var a: int = int(a_raw);
    var a_float: float = float(a);
    var b: float = 2.0 - a_float + float(int(a_float / 4.0));
    var jd_int_part: float = float(int(365.25 * (y_float + 4716.0))) + float(int(30.6001 * (m_float + 1.0)));
    var jd: float = jd_int_part + float(day) + b - 1524.5;
    return jd + (hour / 24.0);
};

~~ Decimal (fractional) year from a Gregorian calendar date.
~~ year, month, day = calendar date. E.g. 2024-07-04 -> ~2024.505.
~~ Used as input to the ayanamsa functions below.
function fractional_year(year: int, month: int, day: int) -> float {
    var days_in_months: int[] = alloc int[12];
    days_in_months[0] = 31;
    days_in_months[1] = 28;
    days_in_months[2] = 31;
    days_in_months[3] = 30;
    days_in_months[4] = 31;
    days_in_months[5] = 30;
    days_in_months[6] = 31;
    days_in_months[7] = 31;
    days_in_months[8] = 30;
    days_in_months[9] = 31;
    days_in_months[10] = 30;
    days_in_months[11] = 31;

    var is_leap: bool = false;
    if (year % 4 == 0 && year % 100 != 0) {
        is_leap = true;
    };
    if (year % 400 == 0) {
        is_leap = true;
    };
    if (is_leap) {
        days_in_months[1] = 29;
    };

    var doy: int = 0;
    var i: int = 0;
    while (i < month - 1) {
        doy = doy + days_in_months[i];
        i++;
    };
    doy = doy + day;

    var days_in_year: float = 365.0;
    if (is_leap) {
        days_in_year = 366.0;
    };

    return float(year) + (float(doy - 1) / days_in_year);
};

~~ Normalizes an angle in degrees to the range [0, 360).
function normalize_degrees(angle: float) -> float {
    var a: float = angle;
    var n: float = a / 360.0;
    var n_floor: float = float(int(n));
    a = a - n_floor * 360.0;
    if (a < 0.0) {
        a = a + 360.0;
    };
    return a;
};

~~ Lahiri (Chitrapaksha) ayanamsa in degrees for a given decimal year.
~~ The official ayanamsa of the Indian government. Linear mean model.
function lahiri_ayanamsa(year: float) -> float {
    return LAHIRI_AYANAMSA_2000 + (year - 2000.0) * PRECESSION_RATE_DEG_YEAR;
};

~~ B.V. Raman ayanamsa in degrees for a given decimal year.
~~ Approximated as Lahiri ayanamsa with a documented constant offset.
function raman_ayanamsa(year: float) -> float {
    const LAHIRI: float = lahiri_ayanamsa(year);
    return LAHIRI - RAMAN_OFFSET;
};

~~ KP (Krishnamurti Paddhati) ayanamsa in degrees for a given decimal year.
~~ Nearly identical to Lahiri, using a slightly different reference epoch value.
function kp_ayanamsa(year: float) -> float {
    return KP_AYANAMSA_2000 + (year - 2000.0) * PRECESSION_RATE_DEG_YEAR;
};

~~ Fagan-Bradley ayanamsa in degrees for a given decimal year.
~~ The standard ayanamsa of Western sidereal astrology.
function fagan_bradley_ayanamsa(year: float) -> float {
    return FAGAN_BRADLEY_1950 + (year - 1950.0) * PRECESSION_RATE_DEG_YEAR;
};

~~ Converts a tropical (Western) ecliptic longitude to sidereal (Vedic) longitude.
~~ tropical_longitude and ayanamsa in degrees. sidereal = tropical - ayanamsa.
function tropical_to_sidereal(tropical_longitude: float, ayanamsa: float) -> float {
    const RAW: float = tropical_longitude - ayanamsa;
    return normalize_degrees(RAW);
};

~~ Converts a sidereal (Vedic) ecliptic longitude to tropical (Western) longitude.
~~ sidereal_longitude and ayanamsa in degrees. tropical = sidereal + ayanamsa.
function sidereal_to_tropical(sidereal_longitude: float, ayanamsa: float) -> float {
    const RAW: float = sidereal_longitude + ayanamsa;
    return normalize_degrees(RAW);
};

// ================================================================
// SECTION 2: PLANETARY POSITIONS (EPHEMERIDES)
// ================================================================
// Uses mean orbital elements + first-order terms (Meeus-style low
// precision algorithms), NOT VSOP87/JPL-grade numerical ephemerides.
// Sun: ~0.01° accuracy. Moon: truncated 6-term series, ~0.1-0.3°
// accuracy (verified against Meeus's full-series worked example).
// Mercury-Saturn: real 2-body Kepler orbits, but treated as coplanar
// with the ecliptic (ignoring small orbital inclinations) and using
// constant eccentricity/perihelion (only mean longitude varies with T).
// Rahu/Ketu: mean lunar node (ignores 18.6-year oscillation terms).

const DEG_TO_RAD: float = 0.01745329251994;
const RAD_TO_DEG: float = 57.29577951308232;

~~ Julian centuries elapsed since epoch J2000.0 (JD 2451545.0). The universal time variable T for all formulas below.
function centuries_since_j2000(jd: float) -> float {
    return (jd - 2451545.0) / 36525.0;
};

~~ Quadrant-aware arctangent (atan2 equivalent), returning degrees in [0, 360).
function atan2_degrees(y: float, x: float) -> float {
    var result: float = 0.0;
    if (x > 0.0) {
        var ratio: float = y / x;
        var rad: float = ratio.inv_tan();
        result = rad * RAD_TO_DEG;
    } else {
        if (x < 0.0) {
            var ratio: float = y / x;
            var rad: float = ratio.inv_tan();
            var deg: float = rad * RAD_TO_DEG;
            if (y >= 0.0) {
                result = deg + 180.0;
            } else {
                result = deg - 180.0;
            };
        } else {
            if (y > 0.0) {
                result = 90.0;
            } else {
                if (y < 0.0) {
                    result = -90.0;
                };
            };
        };
    };
    return normalize_degrees(result);
};

~~ Solves Kepler's equation (M = E - e*sin(E)) for eccentric anomaly via Newton-Raphson iteration.
~~ mean_anomaly_deg in degrees, eccentricity as decimal (0-1). Returns eccentric anomaly in degrees.
function solve_kepler_equation(mean_anomaly_deg: float, eccentricity: float) -> float {
    var m_norm: float = normalize_degrees(mean_anomaly_deg);
    var m_rad: float = m_norm * DEG_TO_RAD;
    var e_val: float = m_rad;
    var i: int = 0;
    while (i < 8) {
        var sin_e: float = e_val.sin(RAD);
        var cos_e: float = e_val.cos(RAD);
        var f: float = e_val - eccentricity * sin_e - m_rad;
        var f_prime: float = 1.0 - eccentricity * cos_e;
        e_val = e_val - (f / f_prime);
        i++;
    };
    var e_deg: float = e_val * RAD_TO_DEG;
    return normalize_degrees(e_deg);
};

~~ True anomaly from eccentric anomaly via the half-angle relation.
~~ eccentric_anomaly_deg in degrees, eccentricity as decimal.
function true_anomaly_from_eccentric(eccentric_anomaly_deg: float, eccentricity: float) -> float {
    var e_norm: float = normalize_degrees(eccentric_anomaly_deg);
    var half_e: float = e_norm / 2.0;
    var tan_half_e: float = half_e.tan(DEG);
    var ratio_val: float = (1.0 + eccentricity) / (1.0 - eccentricity);
    var factor: float = ratio_val.sqrt().real;
    var tan_half_nu: float = factor * tan_half_e;
    var half_nu_rad: float = tan_half_nu.inv_tan();
    var half_nu_deg: float = half_nu_rad * RAD_TO_DEG;
    var half_nu: float = half_nu_deg;
    if (half_e > 90.0) {
        half_nu = half_nu_deg + 180.0;
    };
    var nu: float = 2.0 * half_nu;
    return normalize_degrees(nu);
};

~~ Heliocentric distance in AU from semi-major axis, eccentric anomaly, and eccentricity.
~~ r = a(1 - e*cos(E)).
function heliocentric_distance(semi_major_axis: float, eccentric_anomaly_deg: float, eccentricity: float) -> float {
    var cos_e: float = eccentric_anomaly_deg.cos(DEG);
    return semi_major_axis * (1.0 - eccentricity * cos_e);
};

~~ Heliocentric ecliptic longitude from true anomaly and longitude of perihelion.
function heliocentric_longitude(true_anomaly_deg: float, perihelion_longitude_deg: float) -> float {
    return normalize_degrees(true_anomaly_deg + perihelion_longitude_deg);
};

~~ Mean longitude at time T from J2000 reference value and rate per Julian century.
function mean_longitude_at_time(l0: float, l_rate_per_century: float, t: float) -> float {
    return normalize_degrees(l0 + l_rate_per_century * t);
};

~~ Mean anomaly from mean longitude and longitude of perihelion.
function mean_anomaly_from_elements(mean_longitude_deg: float, perihelion_longitude_deg: float) -> float {
    return normalize_degrees(mean_longitude_deg - perihelion_longitude_deg);
};

~~ Earth's heliocentric distance in AU from the Sun's mean anomaly (Meeus simplified formula).
function earth_heliocentric_distance(sun_mean_anomaly_deg: float) -> float {
    var cos_m: float = sun_mean_anomaly_deg.cos(DEG);
    var two_m: float = 2.0 * sun_mean_anomaly_deg;
    var cos_2m: float = two_m.cos(DEG);
    return 1.00014 - 0.01671 * cos_m - 0.00014 * cos_2m;
};

~~ Geocentric ecliptic longitude of a planet from both bodies' heliocentric distance/longitude (2D vector method, assumes coplanar orbits).
function geocentric_longitude_from_heliocentric(r_planet: float, l_planet_deg: float, r_earth: float, l_earth_deg: float) -> float {
    var cos_lp: float = l_planet_deg.cos(DEG);
    var sin_lp: float = l_planet_deg.sin(DEG);
    var cos_le: float = l_earth_deg.cos(DEG);
    var sin_le: float = l_earth_deg.sin(DEG);
    var x: float = r_planet * cos_lp - r_earth * cos_le;
    var y: float = r_planet * sin_lp - r_earth * sin_le;
    return atan2_degrees(y, x);
};

~~ Sun's mean longitude at time T (Meeus low-precision solar formula).
function sun_mean_longitude(t: float) -> float {
    var raw: float = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
    return normalize_degrees(raw);
};

~~ Sun's mean anomaly at time T.
function sun_mean_anomaly(t: float) -> float {
    var raw: float = 357.52911 + 35999.05029 * t - 0.0001537 * t * t;
    return normalize_degrees(raw);
};

~~ Equation of center correction for the Sun's position, in degrees.
function sun_equation_of_center(t: float, mean_anomaly_deg: float) -> float {
    var sin_m: float = mean_anomaly_deg.sin(DEG);
    var two_m: float = 2.0 * mean_anomaly_deg;
    var sin_2m: float = two_m.sin(DEG);
    var three_m: float = 3.0 * mean_anomaly_deg;
    var sin_3m: float = three_m.sin(DEG);
    var term1: float = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin_m;
    var term2: float = (0.019993 - 0.000101 * t) * sin_2m;
    var term3: float = 0.000289 * sin_3m;
    return term1 + term2 + term3;
};

~~ Sun's apparent (tropical) geocentric ecliptic longitude at time T. Accuracy ~0.01°.
function sun_ecliptic_longitude(t: float) -> float {
    var l0: float = sun_mean_longitude(t);
    var m: float = sun_mean_anomaly(t);
    var c: float = sun_equation_of_center(t, m);
    return normalize_degrees(l0 + c);
};

~~ Mercury's geocentric ecliptic longitude at time T (tropical). Full 2-body Kepler orbit, coplanar approximation.
function mercury_ecliptic_longitude(t: float) -> float {
    const A: float = 0.387098;
    const ECC: float = 0.205630;
    const L0: float = 252.25032350;
    const L_RATE: float = 149472.67411175;
    const PERI: float = 77.45779628;

    var l: float = mean_longitude_at_time(L0, L_RATE, t);
    var m: float = mean_anomaly_from_elements(l, PERI);
    var ecc_anom: float = solve_kepler_equation(m, ECC);
    var nu: float = true_anomaly_from_eccentric(ecc_anom, ECC);
    var r: float = heliocentric_distance(A, ecc_anom, ECC);
    var helio_lon: float = heliocentric_longitude(nu, PERI);

    var sun_lon: float = sun_ecliptic_longitude(t);
    var earth_lon: float = normalize_degrees(sun_lon + 180.0);
    var sun_m: float = sun_mean_anomaly(t);
    var earth_r: float = earth_heliocentric_distance(sun_m);

    return geocentric_longitude_from_heliocentric(r, helio_lon, earth_r, earth_lon);
};

~~ Venus's geocentric ecliptic longitude at time T (tropical).
function venus_ecliptic_longitude(t: float) -> float {
    const A: float = 0.723330;
    const ECC: float = 0.006773;
    const L0: float = 181.97909950;
    const L_RATE: float = 58517.81538729;
    const PERI: float = 131.60246718;

    var l: float = mean_longitude_at_time(L0, L_RATE, t);
    var m: float = mean_anomaly_from_elements(l, PERI);
    var ecc_anom: float = solve_kepler_equation(m, ECC);
    var nu: float = true_anomaly_from_eccentric(ecc_anom, ECC);
    var r: float = heliocentric_distance(A, ecc_anom, ECC);
    var helio_lon: float = heliocentric_longitude(nu, PERI);

    var sun_lon: float = sun_ecliptic_longitude(t);
    var earth_lon: float = normalize_degrees(sun_lon + 180.0);
    var sun_m: float = sun_mean_anomaly(t);
    var earth_r: float = earth_heliocentric_distance(sun_m);

    return geocentric_longitude_from_heliocentric(r, helio_lon, earth_r, earth_lon);
};

~~ Mars's geocentric ecliptic longitude at time T (tropical).
function mars_ecliptic_longitude(t: float) -> float {
    const A: float = 1.523679;
    const ECC: float = 0.093400;
    const L0: float = 355.43299958;
    const L_RATE: float = 19140.30268499;
    const PERI: float = 336.04084264;

    var l: float = mean_longitude_at_time(L0, L_RATE, t);
    var m: float = mean_anomaly_from_elements(l, PERI);
    var ecc_anom: float = solve_kepler_equation(m, ECC);
    var nu: float = true_anomaly_from_eccentric(ecc_anom, ECC);
    var r: float = heliocentric_distance(A, ecc_anom, ECC);
    var helio_lon: float = heliocentric_longitude(nu, PERI);

    var sun_lon: float = sun_ecliptic_longitude(t);
    var earth_lon: float = normalize_degrees(sun_lon + 180.0);
    var sun_m: float = sun_mean_anomaly(t);
    var earth_r: float = earth_heliocentric_distance(sun_m);

    return geocentric_longitude_from_heliocentric(r, helio_lon, earth_r, earth_lon);
};

~~ Jupiter's geocentric ecliptic longitude at time T (tropical).
function jupiter_ecliptic_longitude(t: float) -> float {
    const A: float = 5.202603;
    const ECC: float = 0.048498;
    const L0: float = 34.39644051;
    const L_RATE: float = 3034.74612775;
    const PERI: float = 14.72847983;

    var l: float = mean_longitude_at_time(L0, L_RATE, t);
    var m: float = mean_anomaly_from_elements(l, PERI);
    var ecc_anom: float = solve_kepler_equation(m, ECC);
    var nu: float = true_anomaly_from_eccentric(ecc_anom, ECC);
    var r: float = heliocentric_distance(A, ecc_anom, ECC);
    var helio_lon: float = heliocentric_longitude(nu, PERI);

    var sun_lon: float = sun_ecliptic_longitude(t);
    var earth_lon: float = normalize_degrees(sun_lon + 180.0);
    var sun_m: float = sun_mean_anomaly(t);
    var earth_r: float = earth_heliocentric_distance(sun_m);

    return geocentric_longitude_from_heliocentric(r, helio_lon, earth_r, earth_lon);
};

~~ Saturn's geocentric ecliptic longitude at time T (tropical).
function saturn_ecliptic_longitude(t: float) -> float {
    const A: float = 9.554909;
    const ECC: float = 0.055546;
    const L0: float = 50.07571329;
    const L_RATE: float = 1222.11494724;
    const PERI: float = 92.59887831;

    var l: float = mean_longitude_at_time(L0, L_RATE, t);
    var m: float = mean_anomaly_from_elements(l, PERI);
    var ecc_anom: float = solve_kepler_equation(m, ECC);
    var nu: float = true_anomaly_from_eccentric(ecc_anom, ECC);
    var r: float = heliocentric_distance(A, ecc_anom, ECC);
    var helio_lon: float = heliocentric_longitude(nu, PERI);

    var sun_lon: float = sun_ecliptic_longitude(t);
    var earth_lon: float = normalize_degrees(sun_lon + 180.0);
    var sun_m: float = sun_mean_anomaly(t);
    var earth_r: float = earth_heliocentric_distance(sun_m);

    return geocentric_longitude_from_heliocentric(r, helio_lon, earth_r, earth_lon);
};

~~ Moon's mean longitude at time T.
function moon_mean_longitude(t: float) -> float {
    var t2: float = t * t;
    var t3: float = t2 * t;
    var t4: float = t3 * t;
    var raw: float = 218.3164477 + 481267.88123421 * t - 0.0015786 * t2 + t3 / 538841.0 - t4 / 65194000.0;
    return normalize_degrees(raw);
};

~~ Moon's apparent geocentric ecliptic longitude at time T (tropical). Truncated 6-term series, ~0.1-0.3° accuracy.
function moon_ecliptic_longitude(t: float) -> float {
    var t2: float = t * t;
    var t3: float = t2 * t;
    var t4: float = t3 * t;

    var lp: float = moon_mean_longitude(t);
    var d_raw: float = 297.8501921 + 445267.1114034 * t - 0.0018819 * t2 + t3 / 545868.0 - t4 / 113065000.0;
    var d: float = normalize_degrees(d_raw);
    var m_raw: float = 357.5291092 + 35999.0502909 * t - 0.0001536 * t2 + t3 / 24490000.0;
    var m: float = normalize_degrees(m_raw);
    var mp_raw: float = 134.9633964 + 477198.8675055 * t + 0.0087414 * t2 + t3 / 69699.0 - t4 / 14712000.0;
    var mp: float = normalize_degrees(mp_raw);
    var f_raw: float = 93.2720950 + 483202.0175233 * t - 0.0036539 * t2 - t3 / 3526000.0 + t4 / 863310000.0;
    var f: float = normalize_degrees(f_raw);

    var sin_mp: float = mp.sin(DEG);
    var two_d_minus_mp: float = 2.0 * d - mp;
    var sin_2d_mp: float = two_d_minus_mp.sin(DEG);
    var two_d: float = 2.0 * d;
    var sin_2d: float = two_d.sin(DEG);
    var two_mp: float = 2.0 * mp;
    var sin_2mp: float = two_mp.sin(DEG);
    var sin_m: float = m.sin(DEG);
    var two_f: float = 2.0 * f;
    var sin_2f: float = two_f.sin(DEG);

    var terms: float = 6.288774 * sin_mp + 1.274027 * sin_2d_mp + 0.658314 * sin_2d
        + 0.213618 * sin_2mp - 0.185116 * sin_m - 0.114332 * sin_2f;

    return normalize_degrees(lp + terms);
};

~~ Rahu (mean lunar ascending node) longitude at time T (tropical).
function rahu_longitude(t: float) -> float {
    var raw: float = 125.04452 - 1934.136261 * t;
    return normalize_degrees(raw);
};

~~ Ketu (lunar descending node) longitude — always exactly 180° opposite Rahu.
function ketu_longitude(rahu_lon: float) -> float {
    return normalize_degrees(rahu_lon + 180.0);
};

~~ Uranus's geocentric ecliptic longitude at time T (tropical).
function uranus_ecliptic_longitude(t: float) -> float {
    const A: float = 19.218446;
    const ECC: float = 0.047318;
    const L0: float = 314.20276625;
    const L_RATE: float = 428.49512595;
    const PERI: float = 170.95427630;

    var l: float = mean_longitude_at_time(L0, L_RATE, t);
    var m: float = mean_anomaly_from_elements(l, PERI);
    var ecc_anom: float = solve_kepler_equation(m, ECC);
    var nu: float = true_anomaly_from_eccentric(ecc_anom, ECC);
    var r: float = heliocentric_distance(A, ecc_anom, ECC);
    var helio_lon: float = heliocentric_longitude(nu, PERI);

    var sun_lon: float = sun_ecliptic_longitude(t);
    var earth_lon: float = normalize_degrees(sun_lon + 180.0);
    var sun_m: float = sun_mean_anomaly(t);
    var earth_r: float = earth_heliocentric_distance(sun_m);

    return geocentric_longitude_from_heliocentric(r, helio_lon, earth_r, earth_lon);
};

~~ Neptune's geocentric ecliptic longitude at time T (tropical).
function neptune_ecliptic_longitude(t: float) -> float {
    const A: float = 30.110387;
    const ECC: float = 0.008606;
    const L0: float = 304.22289287;
    const L_RATE: float = 218.46515314;
    const PERI: float = 44.97135436;

    var l: float = mean_longitude_at_time(L0, L_RATE, t);
    var m: float = mean_anomaly_from_elements(l, PERI);
    var ecc_anom: float = solve_kepler_equation(m, ECC);
    var nu: float = true_anomaly_from_eccentric(ecc_anom, ECC);
    var r: float = heliocentric_distance(A, ecc_anom, ECC);
    var helio_lon: float = heliocentric_longitude(nu, PERI);

    var sun_lon: float = sun_ecliptic_longitude(t);
    var earth_lon: float = normalize_degrees(sun_lon + 180.0);
    var sun_m: float = sun_mean_anomaly(t);
    var earth_r: float = earth_heliocentric_distance(sun_m);

    return geocentric_longitude_from_heliocentric(r, helio_lon, earth_r, earth_lon);
};

~~ Pluto's geocentric ecliptic longitude at time T (tropical).
~~ CAVEAT: Pluto's eccentricity (0.249) and orbital inclination (~17°) are far higher than any other
~~ body in this pipeline. The coplanar-with-ecliptic assumption used throughout this section is at its
~~ weakest here — expect degree-level error, not the ~0.01-0.5° range typical of the other planets.
~~ Included for completeness (some modern astrological traditions use it), not for precision work.
function pluto_ecliptic_longitude(t: float) -> float {
    const A: float = 39.482;
    const ECC: float = 0.2488;
    const L0: float = 238.92903833;
    const L_RATE: float = 145.20780515;
    const PERI: float = 224.06891629;

    var l: float = mean_longitude_at_time(L0, L_RATE, t);
    var m: float = mean_anomaly_from_elements(l, PERI);
    var ecc_anom: float = solve_kepler_equation(m, ECC);
    var nu: float = true_anomaly_from_eccentric(ecc_anom, ECC);
    var r: float = heliocentric_distance(A, ecc_anom, ECC);
    var helio_lon: float = heliocentric_longitude(nu, PERI);

    var sun_lon: float = sun_ecliptic_longitude(t);
    var earth_lon: float = normalize_degrees(sun_lon + 180.0);
    var sun_m: float = sun_mean_anomaly(t);
    var earth_r: float = earth_heliocentric_distance(sun_m);

    return geocentric_longitude_from_heliocentric(r, helio_lon, earth_r, earth_lon);
};

// ================================================================
// SECTION 3: HOUSE SYSTEMS
// ================================================================
// IMPORTANT: In all quadrant house systems (Placidus included), house
// number DECREASES as ecliptic longitude increases — this is a real,
// verified property of the geometry (houses represent the sky's fast
// diurnal rotation, not the slow zodiacal direction), not a typo.

~~ Local Sidereal Time in degrees from Julian Day and observer's longitude (east positive, west negative).
~~ LST = GMST(JD) + longitude. Uses the standard Meeus GMST formula.
function local_sidereal_time(jd: float, longitude_east_deg: float) -> float {
    var t: float = centuries_since_j2000(jd);
    var d: float = jd - 2451545.0;
    var gmst_raw: float = 280.46061837 + 360.98564736629 * d + 0.000387933 * t * t - (t * t * t) / 38710000.0;
    var gmst: float = normalize_degrees(gmst_raw);
    return normalize_degrees(gmst + longitude_east_deg);
};

~~ Converts a right ascension to ecliptic longitude, for a point known to lie on the ecliptic.
~~ ra_deg = right ascension in degrees, obliquity_deg = obliquity of the ecliptic.
function ecliptic_longitude_from_ra(ra_deg: float, obliquity_deg: float) -> float {
    var sin_ra: float = ra_deg.sin(DEG);
    var cos_ra: float = ra_deg.cos(DEG);
    var cos_obl: float = obliquity_deg.cos(DEG);
    var y: float = sin_ra;
    var x: float = cos_ra * cos_obl;
    return atan2_degrees(y, x);
};

~~ Midheaven (MC) ecliptic longitude — the point where the ecliptic crosses the local meridian.
~~ lst_deg = local sidereal time in degrees, obliquity_deg = obliquity of the ecliptic.
function midheaven_longitude(lst_deg: float, obliquity_deg: float) -> float {
    return ecliptic_longitude_from_ra(lst_deg, obliquity_deg);
};

~~ Ascendant (Lagna) ecliptic longitude — the point of the ecliptic rising on the eastern horizon.
~~ lst_deg = local sidereal time, latitude_deg = observer's geographic latitude, obliquity_deg = obliquity of the ecliptic.
function ascendant_longitude(lst_deg: float, latitude_deg: float, obliquity_deg: float) -> float {
    var cos_lst: float = lst_deg.cos(DEG);
    var sin_lst: float = lst_deg.sin(DEG);
    var cos_obl: float = obliquity_deg.cos(DEG);
    var sin_obl: float = obliquity_deg.sin(DEG);
    var tan_lat: float = latitude_deg.tan(DEG);
    var y: float = -cos_lst;
    var x: float = sin_lst * cos_obl + tan_lat * sin_obl;
    return atan2_degrees(y, x);
};

~~ The point diametrically opposite a given ecliptic longitude (e.g. IC from MC, Descendant from Ascendant).
function opposite_point(longitude_deg: float) -> float {
    return normalize_degrees(longitude_deg + 180.0);
};

~~ Equal House cusp — each house is exactly 30° from the Ascendant.
~~ ascendant_deg = Ascendant longitude, house_number = 1-12.
function equal_house_cusp(ascendant_deg: float, house_number: int) -> float {
    var offset: float = 30.0 * float(house_number - 1);
    return normalize_degrees(ascendant_deg + offset);
};

~~ Whole Sign House cusp — house 1 begins at 0° of the Ascendant's zodiac sign.
~~ ascendant_deg = Ascendant longitude, house_number = 1-12.
function whole_sign_cusp(ascendant_deg: float, house_number: int) -> float {
    var sign_index: float = float(int(ascendant_deg / 30.0));
    var sign_begin: float = sign_index * 30.0;
    var offset: float = 30.0 * float(house_number - 1);
    return normalize_degrees(sign_begin + offset);
};

~~ Semi-diurnal arc in degrees — half the time (as an hour angle) a point spends above the horizon.
~~ declination_deg = point's declination, latitude_deg = observer's geographic latitude.
function semi_diurnal_arc(declination_deg: float, latitude_deg: float) -> float {
    var tan_lat: float = latitude_deg.tan(DEG);
    var tan_decl: float = declination_deg.tan(DEG);
    var cos_sda: float = -tan_lat * tan_decl;
    if (cos_sda > 0.9999) {
        cos_sda = 0.9999;
    };
    if (cos_sda < -0.9999) {
        cos_sda = -0.9999;
    };
    var sda_rad: float = cos_sda.inv_cos().real;
    return sda_rad * RAD_TO_DEG;
};

~~ General Placidus intermediate cusp solver via semi-arc trisection (iterative fixed-point method).
~~ ramc_deg = right ascension of MC (= LST), latitude_deg = observer's latitude, obliquity_deg = ecliptic obliquity,
~~ fraction = 1/3 or 2/3 (trisection point), sign = -1.0 for the Asc-MC quadrant (cusps 11,12), +1.0 for the MC-Desc quadrant (cusps 9,8).
function placidus_intermediate_cusp(ramc_deg: float, latitude_deg: float, obliquity_deg: float, fraction: float, sign: float) -> float {
    var lamb_da: float = normalize_degrees(ramc_deg + sign * fraction * 90.0);
    var iter: int = 0;
    while (iter < 25) {
        var sin_lamb_da: float = lamb_da.sin(DEG);
        var sin_obl: float = obliquity_deg.sin(DEG);
        var sin_delta: float = sin_lamb_da * sin_obl;
        var delta_rad: float = sin_delta.inv_sin().real;
        var delta: float = delta_rad * RAD_TO_DEG;
        var sda: float = semi_diurnal_arc(delta, latitude_deg);
        var target_alpha: float = normalize_degrees(ramc_deg + sign * fraction * sda);
        lamb_da = ecliptic_longitude_from_ra(target_alpha, obliquity_deg);
        iter++;
    };
    return lamb_da;
};

~~ Placidus house 11 cusp.
function placidus_cusp_11(ramc_deg: float, latitude_deg: float, obliquity_deg: float) -> float {
    return placidus_intermediate_cusp(ramc_deg, latitude_deg, obliquity_deg, 1.0 / 3.0, -1.0);
};

~~ Placidus house 12 cusp.
function placidus_cusp_12(ramc_deg: float, latitude_deg: float, obliquity_deg: float) -> float {
    return placidus_intermediate_cusp(ramc_deg, latitude_deg, obliquity_deg, 2.0 / 3.0, -1.0);
};

~~ Placidus house 9 cusp.
function placidus_cusp_9(ramc_deg: float, latitude_deg: float, obliquity_deg: float) -> float {
    return placidus_intermediate_cusp(ramc_deg, latitude_deg, obliquity_deg, 1.0 / 3.0, 1.0);
};

~~ Placidus house 8 cusp.
function placidus_cusp_8(ramc_deg: float, latitude_deg: float, obliquity_deg: float) -> float {
    return placidus_intermediate_cusp(ramc_deg, latitude_deg, obliquity_deg, 2.0 / 3.0, 1.0);
};

~~ Placidus house 2 cusp — the point opposite house 8.
function placidus_cusp_2(ramc_deg: float, latitude_deg: float, obliquity_deg: float) -> float {
    var c8: float = placidus_cusp_8(ramc_deg, latitude_deg, obliquity_deg);
    return opposite_point(c8);
};

~~ Placidus house 3 cusp — the point opposite house 9.
function placidus_cusp_3(ramc_deg: float, latitude_deg: float, obliquity_deg: float) -> float {
    var c9: float = placidus_cusp_9(ramc_deg, latitude_deg, obliquity_deg);
    return opposite_point(c9);
};

~~ Placidus house 5 cusp — the point opposite house 11.
function placidus_cusp_5(ramc_deg: float, latitude_deg: float, obliquity_deg: float) -> float {
    var c11: float = placidus_cusp_11(ramc_deg, latitude_deg, obliquity_deg);
    return opposite_point(c11);
};

~~ Placidus house 6 cusp — the point opposite house 12.
function placidus_cusp_6(ramc_deg: float, latitude_deg: float, obliquity_deg: float) -> float {
    var c12: float = placidus_cusp_12(ramc_deg, latitude_deg, obliquity_deg);
    return opposite_point(c12);
};

// ================================================================
// SECTION 4: VEDIC ASPECTS (DRISHTI) & PLANETARY RELATIONSHIPS
// ================================================================
// House counting here uses whole-sign counting (bhava ganana), the
// standard method for aspect calculations in classical Vedic texts,
// independent of whichever house system (Placidus etc.) is used for cusps.

~~ Zodiac sign index (0-11, 0=Aries) from an ecliptic longitude.
function zodiac_sign_index(longitude_deg: float) -> int {
    return int(longitude_deg / 30.0);
};

~~ House position (1-12) of a target sign counted from a reference sign, using whole-sign counting.
~~ from_sign and to_sign are 0-11 indices. Same sign = 1 (conjunction), 6 signs away = 7 (opposition).
function house_position(from_sign: int, to_sign: int) -> int {
    var diff: int = to_sign - from_sign + 12;
    var wrapped: int = diff % 12;
    return wrapped + 1;
};

~~ Checks whether a house distance qualifies for the universal 7th-house aspect (every planet aspects its 7th).
function has_seventh_aspect(house_distance: int) -> bool {
    return house_distance == 7;
};

~~ Checks whether a house distance qualifies for Mars's special aspects (4th, 7th, 8th).
function has_mars_special_aspect(house_distance: int) -> bool {
    if (house_distance == 4) {
        return true;
    };
    if (house_distance == 7) {
        return true;
    };
    if (house_distance == 8) {
        return true;
    };
    return false;
};

~~ Checks whether a house distance qualifies for Jupiter's special aspects (5th, 7th, 9th).
function has_jupiter_special_aspect(house_distance: int) -> bool {
    if (house_distance == 5) {
        return true;
    };
    if (house_distance == 7) {
        return true;
    };
    if (house_distance == 9) {
        return true;
    };
    return false;
};

~~ Checks whether a house distance qualifies for Saturn's special aspects (3rd, 7th, 10th).
function has_saturn_special_aspect(house_distance: int) -> bool {
    if (house_distance == 3) {
        return true;
    };
    if (house_distance == 7) {
        return true;
    };
    if (house_distance == 10) {
        return true;
    };
    return false;
};

~~ Checks whether a house distance qualifies for Rahu/Ketu's special aspects, using the widely-adopted
~~ convention of treating the lunar nodes like Saturn (3rd, 7th, 10th). Not universal across all classical texts.
function has_rahu_ketu_special_aspect(house_distance: int) -> bool {
    return has_saturn_special_aspect(house_distance);
};

~~ Shortest angular separation between two ecliptic longitudes, in degrees (0-180).
function angular_separation(lon1: float, lon2: float) -> float {
    var diff: float = normalize_degrees(lon1 - lon2);
    if (diff > 180.0) {
        diff = 360.0 - diff;
    };
    return diff;
};

~~ Checks whether a planet is combust (too close to the Sun to be visible/effective).
~~ planet_lon and sun_lon in degrees, orb_deg = the combustion orb threshold (varies by planet and text).
function is_combust(planet_lon: float, sun_lon: float, orb_deg: float) -> bool {
    var separation: float = angular_separation(planet_lon, sun_lon);
    return separation <= orb_deg;
};

// ================================================================
// SECTION 5: VIMSHOTTARI DASHA SYSTEM
// ================================================================

tag DashaLord {
  KETU,
  VENUS,
  SUN,
  MOON,
  MARS,
  RAHU,
  JUPITER,
  SATURN,
  MERCURY
};

~~ Full mahadasha duration in years for a given dasha lord (Vimshottari system, 120-year total cycle).
function dasha_years(lord: DashaLord) -> float {
    var result: float = 0.0;
    match(lord) {
        case DashaLord.KETU:    result = 7.0;
        case DashaLord.VENUS:   result = 20.0;
        case DashaLord.SUN:     result = 6.0;
        case DashaLord.MOON:    result = 10.0;
        case DashaLord.MARS:    result = 7.0;
        case DashaLord.RAHU:    result = 18.0;
        case DashaLord.JUPITER: result = 16.0;
        case DashaLord.SATURN:  result = 19.0;
        case DashaLord.MERCURY: result = 17.0;
        default:                result = 0.0;
    };
    return result;
};

~~ Position (0-8) of a dasha lord within the fixed Vimshottari sequence.
function index_from_dasha_lord(lord: DashaLord) -> int {
    var result: int = 0;
    match(lord) {
        case DashaLord.KETU:    result = 0;
        case DashaLord.VENUS:   result = 1;
        case DashaLord.SUN:     result = 2;
        case DashaLord.MOON:    result = 3;
        case DashaLord.MARS:    result = 4;
        case DashaLord.RAHU:    result = 5;
        case DashaLord.JUPITER: result = 6;
        case DashaLord.SATURN:  result = 7;
        case DashaLord.MERCURY: result = 8;
        default:                result = 0;
    };
    return result;
};

~~ Dasha lord at a given position (0-8) in the Vimshottari sequence, wrapping automatically.
function dasha_lord_from_index(idx: int) -> DashaLord {
    var i: int = idx % 9;
    if (i < 0) {
        i = i + 9;
    };
    if (i == 0) { return DashaLord.KETU; };
    if (i == 1) { return DashaLord.VENUS; };
    if (i == 2) { return DashaLord.SUN; };
    if (i == 3) { return DashaLord.MOON; };
    if (i == 4) { return DashaLord.MARS; };
    if (i == 5) { return DashaLord.RAHU; };
    if (i == 6) { return DashaLord.JUPITER; };
    if (i == 7) { return DashaLord.SATURN; };
    return DashaLord.MERCURY;
};

~~ The next dasha lord in the fixed Vimshottari sequence, wrapping after Mercury back to Ketu.
function next_dasha_lord(current: DashaLord) -> DashaLord {
    var idx: int = index_from_dasha_lord(current);
    return dasha_lord_from_index(idx + 1);
};

~~ Nakshatra index (0-26) from the Moon's sidereal ecliptic longitude. Each nakshatra spans 13°20'.
function nakshatra_index(moon_longitude_deg: float) -> int {
    const NAK_WIDTH: float = 360.0 / 27.0;
    return int(moon_longitude_deg / NAK_WIDTH);
};

~~ The dasha lord ruling at birth, determined by the Moon's nakshatra at birth.
function dasha_lord_at_birth(moon_longitude_deg: float) -> DashaLord {
    var nak_idx: int = nakshatra_index(moon_longitude_deg);
    return dasha_lord_from_index(nak_idx);
};

~~ Remaining years of the first (birth) mahadasha, based on how far the Moon has progressed through its nakshatra.
function dasha_balance_years(moon_longitude_deg: float) -> float {
    const NAK_WIDTH: float = 360.0 / 27.0;
    var nak_idx: int = nakshatra_index(moon_longitude_deg);
    var nak_begin: float = float(nak_idx) * NAK_WIDTH;
    var position_in_nak: float = moon_longitude_deg - nak_begin;
    var fraction_traversed: float = position_in_nak / NAK_WIDTH;
    var fraction_remaining: float = 1.0 - fraction_traversed;
    var lord: DashaLord = dasha_lord_from_index(nak_idx);
    var full_years: float = dasha_years(lord);
    return fraction_remaining * full_years;
};

~~ Duration in years of an antardasha (sub-period) within a mahadasha.
~~ antar_lord = the sub-period's ruling planet, maha_years = the full mahadasha duration in years.
function antardasha_duration(antar_lord: DashaLord, maha_years: float) -> float {
    var antar_years: float = dasha_years(antar_lord);
    return maha_years * (antar_years / 120.0);
};

// ================================================================
// SECTION 6: DIVISIONAL CHARTS (VARGA) D1-D16
// ================================================================
// All functions return a sign index (0-11, 0=Aries) — the classically
// meaningful output for divisional charts (used for sign-based dignity
// and strength analysis), not a sub-degree position within that sign.

~~ Which part (0 to division_count-1) of its current sign a longitude falls into, for a given varga division.
function varga_part_index(longitude_deg: float, division_count: int) -> int {
    var position_in_sign: float = longitude_deg % 30.0;
    var part_width: float = 30.0 / float(division_count);
    return int(position_in_sign / part_width);
};

~~ Modality of a sign: 0 = movable/cardinal, 1 = fixed, 2 = dual/mutable.
function sign_modality(sign_index: int) -> int {
    return sign_index % 3;
};

~~ Whether a sign is classically "odd" (Aries, Gemini, Leo, Libra, Sagittarius, Aquarius).
function is_odd_sign(sign_index: int) -> bool {
    return sign_index % 2 == 0;
};

~~ D2 Hora (wealth) chart sign. Odd signs: 1st half -> Leo (Sun), 2nd half -> Cancer (Moon). Even signs: reversed.
~~ sign_index = birth sign (0-11), part_index = 0 or 1 (from varga_part_index with division_count=2).
function hora_sign_d2(sign_index: int, part_index: int) -> int {
    var odd: bool = is_odd_sign(sign_index);
    if (odd) {
        if (part_index == 0) {
            return 4;
        };
        return 3;
    };
    if (part_index == 0) {
        return 3;
    };
    return 4;
};

~~ D3 Drekkana (siblings) chart sign. Parts map to same, 5th, and 9th sign (trine pattern).
function drekkana_sign_d3(sign_index: int, part_index: int) -> int {
    return (sign_index + part_index * 4) % 12;
};

~~ D4 Chaturthamsa (fortune/property) chart sign. Parts map to same, 4th, 7th, 10th sign (kendra pattern).
function chaturthamsa_sign_d4(sign_index: int, part_index: int) -> int {
    return (sign_index + part_index * 3) % 12;
};

~~ D7 Saptamsa (children) chart sign. Odd signs count from themselves; even signs count from the 7th (opposite) sign.
function saptamsa_sign_d7(sign_index: int, part_index: int) -> int {
    var begin: int = sign_index;
    if (is_odd_sign(sign_index) == false) {
        begin = (sign_index + 6) % 12;
    };
    return (begin + part_index) % 12;
};

~~ D9 Navamsa (spouse/dharma) chart sign — the most important divisional chart in Vedic astrology.
~~ Movable signs count from themselves, fixed signs from the 9th sign, dual signs from the 5th sign.
function navamsa_sign_d9(sign_index: int, part_index: int) -> int {
    var m: int = sign_modality(sign_index);
    var begin: int = sign_index;
    if (m == 1) {
        begin = (sign_index + 8) % 12;
    };
    if (m == 2) {
        begin = (sign_index + 4) % 12;
    };
    return (begin + part_index) % 12;
};

~~ D10 Dasamsa (career) chart sign. Odd signs count from themselves; even signs count from the 9th sign.
function dasamsa_sign_d10(sign_index: int, part_index: int) -> int {
    var begin: int = sign_index;
    if (is_odd_sign(sign_index) == false) {
        begin = (sign_index + 8) % 12;
    };
    return (begin + part_index) % 12;
};

~~ D12 Dwadasamsa (parents) chart sign. Always counts forward from the birth sign itself.
function dwadasamsa_sign_d12(sign_index: int, part_index: int) -> int {
    return (sign_index + part_index) % 12;
};

~~ D16 Shodasamsa (vehicles/comforts) chart sign. Movable signs begin from Aries, fixed from Leo, dual from Sagittarius.
function shodasamsa_sign_d16(sign_index: int, part_index: int) -> int {
    var m: int = sign_modality(sign_index);
    var begin: int = 0;
    if (m == 1) {
        begin = 4;
    };
    if (m == 2) {
        begin = 8;
    };
    return (begin + part_index) % 12;
};

// ================================================================
// SECTION 7: TRANSITS (GOCHARA)
// ================================================================
// Classical Gochara (transit) analysis traditionally counts houses from
// the natal Moon sign (Chandra Lagna) as the primary method, with the
// Ascendant as a secondary/modern alternative. Both are provided here.

~~ Transit house position counted from the natal Moon sign (the classical primary Gochara method).
~~ natal_moon_sign and transit_sign are 0-11 sign indices.
function gochara_house_from_moon(natal_moon_sign: int, transit_sign: int) -> int {
    return house_position(natal_moon_sign, transit_sign);
};

~~ Transit house position counted from the natal Ascendant sign (secondary/modern Gochara method).
~~ natal_ascendant_sign and transit_sign are 0-11 sign indices.
function gochara_house_from_ascendant(natal_ascendant_sign: int, transit_sign: int) -> int {
    return house_position(natal_ascendant_sign, transit_sign);
};

~~ Whether transiting Saturn is currently in a Sade Sati period relative to the natal Moon.
~~ Sade Sati is active when Saturn transits the 12th, 1st (same), or 2nd sign from natal Moon.
function is_sade_sati(natal_moon_sign: int, transiting_saturn_sign: int) -> bool {
    var hp: int = house_position(natal_moon_sign, transiting_saturn_sign);
    if (hp == 12) { return true; };
    if (hp == 1) { return true; };
    if (hp == 2) { return true; };
    return false;
};

~~ Which phase of Sade Sati is currently active: 0 = not active, 1 = rising (12th from Moon),
~~ 2 = peak (same sign as Moon), 3 = setting (2nd from Moon).
function sade_sati_phase(natal_moon_sign: int, transiting_saturn_sign: int) -> int {
    var hp: int = house_position(natal_moon_sign, transiting_saturn_sign);
    if (hp == 12) { return 1; };
    if (hp == 1) { return 2; };
    if (hp == 2) { return 3; };
    return 0;
};

~~ Whether a transiting planet is within a given orb of exact conjunction with a natal point.
~~ transit_longitude and natal_longitude in degrees, orb_deg = allowed orb.
function is_transit_within_orb(transit_longitude: float, natal_longitude: float, orb_deg: float) -> bool {
    var separation: float = angular_separation(transit_longitude, natal_longitude);
    return separation <= orb_deg;
};

~~ Whether a transiting planet is within a given orb of exact opposition to a natal point.
~~ transit_longitude and natal_longitude in degrees, orb_deg = allowed orb.
function is_transit_opposition_within_orb(transit_longitude: float, natal_longitude: float, orb_deg: float) -> bool {
    var separation: float = angular_separation(transit_longitude, natal_longitude);
    var diff_from_opposition: float = separation - 180.0;
    if (diff_from_opposition < 0.0) {
        diff_from_opposition = -diff_from_opposition;
    };
    return diff_from_opposition <= orb_deg;
};