"""
    mocha-meteoro v0.1
    Professional Meteorology Library for Mocha
    
    Sections:
        1.  Thermodynamics
        2.  Humidity
        3.  Pressure & Altitude
        4.  Wind
        5.  Precipitation
        6.  Severe Weather Indices
        7.  Visibility, Fog & AQI
        8.  Solar & Radiation
        9.  Climate Statistics
        10. Large-Scale Climate Indices
    
    Default units: Celsius, km/h, mb, meters
    Dependencies: mocha-math
"""

// mocha-lib-deps: mocha-math

// ── C runtime math helpers ──
function c_exp(x: float) -> float native mocha_wrap_exp;
//function c_sqrt(x: float) -> float native mocha_wrap_sqrt_f;
function c_sin(x: float) -> float native mocha_wrap_sin;
function c_cos(x: float) -> float native mocha_wrap_cos;
function c_atan(x: float) -> float native mocha_wrap_atan;
function c_log(x: float) -> float native mocha_wrap_log;
function c_exit(code: int) -> null native mocha_exit;
function c_print_err(msg: str) -> null native mocha_print_stderr;

// ── Thermodynamics C helpers ──
function c_sat_vp(t_c: float) -> float native metero_sat_vp;
function c_dewpoint(t_c: float, rh: float) -> float native metero_dewpoint;
function c_wetbulb(t_c: float, rh: float) -> float native metero_wetbulb;
function c_heat_index(t_c: float, rh: float) -> float native metero_heat_index;
function c_wind_chill(t_c: float, speed_kmh: float) -> float native metero_wind_chill;
function c_feels_like(t_c: float, rh: float, speed_kmh: float) -> float native metero_feels_like;
function c_potential_temp(t_c: float, pressure_mb: float) -> float native metero_potential_temp;
function c_virtual_temp(t_c: float, mixing_ratio_gkg: float) -> float native metero_virtual_temp;
function c_equiv_potential_temp(t_c: float, dewpoint_c: float, pressure_mb: float) -> float native metero_equiv_potential_temp;
function c_lcl_temp(t_c: float, dewpoint_c: float) -> float native metero_lcl_temp;
function c_lcl_pressure(t_c: float, dewpoint_c: float, pressure_mb: float) -> float native metero_lcl_pressure;

// ── Unit conversion helpers ──

function celsius_to_fahrenheit(t: float) -> float {
    return t * 1.8 + 32.0;
};

function fahrenheit_to_celsius(t: float) -> float {
    return (t - 32.0) / 1.8;
};

function celsius_to_kelvin(t: float) -> float {
    return t + 273.15;
};

function kelvin_to_celsius(t: float) -> float {
    return t - 273.15;
};

function kmh_to_ms(v: float) -> float { return v / 3.6; };
function ms_to_kmh(v: float) -> float { return v * 3.6; };
function kmh_to_knots(v: float) -> float { return v / 1.852; };
function knots_to_kmh(v: float) -> float { return v * 1.852; };
function kmh_to_mph(v: float) -> float { return v * 0.621371; };
function mph_to_kmh(v: float) -> float { return v / 0.621371; };

function mb_to_inhg(p: float) -> float { return p * 0.02953; };
function inhg_to_mb(p: float) -> float { return p / 0.02953; };
function mb_to_pa(p: float) -> float { return p * 100.0; };
function pa_to_mb(p: float) -> float { return p / 100.0; };
function mb_to_atm(p: float) -> float { return p / 1013.25; };
function atm_to_mb(p: float) -> float { return p * 1013.25; };

function meters_to_feet(m: float) -> float { return m * 3.28084; };
function feet_to_meters(f: float) -> float { return f / 3.28084; };

// ── Validators ──

function validate_rh(rh: float) -> null {
    if (rh < 0.0 || rh > 100.0) {
        c_print_err("MeteroError: Relative humidity must be between 0 and 100.");
        c_exit(2);
    };
};

function validate_temp_c(t: float) -> null {
    if (t < -90.0 || t > 60.0) {
        c_print_err("MeteroError: Temperature out of Earth range (-90 to 60 C).");
        c_exit(2);
    };
};

function validate_pressure_mb(p: float) -> null {
    if (p < 870.0 || p > 1084.0) {
        c_print_err("MeteroError: Pressure out of Earth range (870 to 1084 mb).");
        c_exit(2);
    };
};

function validate_wind_kmh(v: float) -> null {
    if (v < 0.0) {
        c_print_err("MeteroError: Wind speed cannot be negative.");
        c_exit(2);
    };
};

// ════════════════════════════════════════════════════
// SECTION 1 — THERMODYNAMICS
// ════════════════════════════════════════════════════

// Saturation vapour pressure (mb) — Buck equation
function sat_vapour_pressure(t_c: float) -> float {
    validate_temp_c(t_c);
    return c_sat_vp(t_c);
};

// Saturation vapour pressure from Fahrenheit input
function sat_vapour_pressure_f(t_f: float) -> float {
    return sat_vapour_pressure(fahrenheit_to_celsius(t_f));
};

// Dew point temperature (C) from temp and relative humidity
function dewpoint(t_c: float, rh: float) -> float {
    validate_temp_c(t_c);
    validate_rh(rh);
    return c_dewpoint(t_c, rh);
};

function dewpoint_f(t_f: float, rh: float) -> float {
    return celsius_to_fahrenheit(dewpoint(fahrenheit_to_celsius(t_f), rh));
};

// Dew point depression — how far temp is above dew point
function dewpoint_depression(t_c: float, rh: float) -> float {
    validate_temp_c(t_c);
    validate_rh(rh);
    return t_c - c_dewpoint(t_c, rh);
};

// Wet bulb temperature (C) — Stull 2011
function wetbulb(t_c: float, rh: float) -> float {
    validate_temp_c(t_c);
    validate_rh(rh);
    return c_wetbulb(t_c, rh);
};

function wetbulb_f(t_f: float, rh: float) -> float {
    return celsius_to_fahrenheit(wetbulb(fahrenheit_to_celsius(t_f), rh));
};

// Heat index (C) — Rothfusz NWS regression
// Valid for t >= 27C and rh >= 40%
function heat_index(t_c: float, rh: float) -> float {
    validate_temp_c(t_c);
    validate_rh(rh);
    if (t_c < 27.0) {
        c_print_err("MeteroWarning: Heat index is not meaningful below 27C. Returning actual temperature.");
        return t_c;
    };
    if (rh < 40.0) {
        c_print_err("MeteroWarning: Heat index is not meaningful below 40% RH. Returning actual temperature.");
        return t_c;
    };
    return c_heat_index(t_c, rh);
};

function heat_index_f(t_f: float, rh: float) -> float {
    return celsius_to_fahrenheit(heat_index(fahrenheit_to_celsius(t_f), rh));
};

// Wind chill (C) — NWS 2001
// Valid for t <= 10C and wind >= 4.8 km/h
function wind_chill(t_c: float, speed_kmh: float) -> float {
    validate_temp_c(t_c);
    validate_wind_kmh(speed_kmh);
    if (t_c > 10.0) {
        c_print_err("MeteroWarning: Wind chill is not meaningful above 10C. Returning actual temperature.");
        return t_c;
    };
    if (speed_kmh < 4.8) {
        c_print_err("MeteroWarning: Wind chill requires wind speed >= 4.8 km/h. Returning actual temperature.");
        return t_c;
    };
    return c_wind_chill(t_c, speed_kmh);
};

function wind_chill_f(t_f: float, speed_kmh: float) -> float {
    return celsius_to_fahrenheit(wind_chill(fahrenheit_to_celsius(t_f), speed_kmh));
};

function wind_chill_knots(t_c: float, speed_knots: float) -> float {
    return wind_chill(t_c, knots_to_kmh(speed_knots));
};

// Feels like — combined apparent temperature
function feels_like(t_c: float, rh: float, speed_kmh: float) -> float {
    validate_temp_c(t_c);
    validate_rh(rh);
    validate_wind_kmh(speed_kmh);
    return c_feels_like(t_c, rh, speed_kmh);
};

function feels_like_f(t_f: float, rh: float, speed_kmh: float) -> float {
    return celsius_to_fahrenheit(feels_like(fahrenheit_to_celsius(t_f), rh, speed_kmh));
};

// Potential temperature theta (C) — dry adiabatic reference
function potential_temp(t_c: float, pressure_mb: float) -> float {
    validate_temp_c(t_c);
    validate_pressure_mb(pressure_mb);
    return c_potential_temp(t_c, pressure_mb);
};

// Virtual temperature (C) — moisture-corrected temperature
function virtual_temp(t_c: float, mixing_ratio_gkg: float) -> float {
    validate_temp_c(t_c);
    if (mixing_ratio_gkg < 0.0) {
        c_print_err("MeteroError: Mixing ratio cannot be negative.");
        c_exit(2);
    };
    return c_virtual_temp(t_c, mixing_ratio_gkg);
};

// Equivalent potential temperature (C) — Bolton 1980
function equiv_potential_temp(t_c: float, dewpoint_c: float, pressure_mb: float) -> float {
    validate_temp_c(t_c);
    validate_temp_c(dewpoint_c);
    validate_pressure_mb(pressure_mb);
    if (dewpoint_c > t_c) {
        c_print_err("MeteroError: Dew point cannot exceed air temperature.");
        c_exit(2);
    };
    return c_equiv_potential_temp(t_c, dewpoint_c, pressure_mb);
};

// Lifting condensation level temperature (C)
function lcl_temp(t_c: float, dewpoint_c: float) -> float {
    validate_temp_c(t_c);
    validate_temp_c(dewpoint_c);
    if (dewpoint_c > t_c) {
        c_print_err("MeteroError: Dew point cannot exceed air temperature.");
        c_exit(2);
    };
    return c_lcl_temp(t_c, dewpoint_c);
};

// Lifting condensation level pressure (mb)
function lcl_pressure(t_c: float, dewpoint_c: float, pressure_mb: float) -> float {
    validate_temp_c(t_c);
    validate_temp_c(dewpoint_c);
    validate_pressure_mb(pressure_mb);
    if (dewpoint_c > t_c) {
        c_print_err("MeteroError: Dew point cannot exceed air temperature.");
        c_exit(2);
    };
    return c_lcl_pressure(t_c, dewpoint_c, pressure_mb);
};

// Temperature lapse rate between two levels (C per 100m)
function lapse_rate(t_upper_c: float, t_lower_c: float, height_diff_m: float) -> float {
    if (height_diff_m <= 0.0) {
        c_print_err("MeteroError: Height difference must be positive.");
        c_exit(2);
    };
    return (t_lower_c - t_upper_c) / height_diff_m * 100.0;
};

// Is atmosphere unstable? (lapse rate > dry adiabatic 9.8 C/km)
function is_unstable(lapse_rate_per_100m: float) -> bool {
    return lapse_rate_per_100m > 0.98;
};

// Frost point (C) — temperature at which frost forms
// Valid for sub-zero dewpoints
function frost_point(t_c: float, rh: float) -> float {
    validate_temp_c(t_c);
    validate_rh(rh);
    var dp: float = c_dewpoint(t_c, rh);
    // Frost point slightly higher than dew point below 0C
    if (dp >= 0.0) { return dp; };
    return dp + 0.15 * (0.0 - dp) * 0.01;
};

// ── Humidity C helpers ──
function c_absolute_humidity(t_c: float, rh: float) -> float native metero_absolute_humidity;
function c_specific_humidity(vp_mb: float, pressure_mb: float) -> float native metero_specific_humidity;
function c_mixing_ratio(vp_mb: float, pressure_mb: float) -> float native metero_mixing_ratio;
function c_rh_from_dewpoint(t_c: float, dewpoint_c: float) -> float native metero_rh_from_dewpoint;
function c_vapour_pressure(t_c: float, rh: float) -> float native metero_vapour_pressure;
function c_vpd(t_c: float, rh: float) -> float native metero_vpd;
function c_humidex(t_c: float, dewpoint_c: float) -> float native metero_humidex;
function c_wbgt_outdoor(t_c: float, rh: float, solar_wm2: float) -> float native metero_wbgt_outdoor;

// ════════════════════════════════════════════════════
// SECTION 2 — HUMIDITY
// ════════════════════════════════════════════════════

// Saturation vapour pressure (mb) — already in section 1
// reexposed here for direct humidity calculations
function vapour_pressure_sat(t_c: float) -> float {
    validate_temp_c(t_c);
    return c_sat_vp(t_c);
};

// Actual vapour pressure (mb) from temp and RH
function vapour_pressure(t_c: float, rh: float) -> float {
    validate_temp_c(t_c);
    validate_rh(rh);
    return c_vapour_pressure(t_c, rh);
};

// Vapour pressure deficit (mb) — plant stress indicator
function vapour_pressure_deficit(t_c: float, rh: float) -> float {
    validate_temp_c(t_c);
    validate_rh(rh);
    return c_vpd(t_c, rh);
};

// Relative humidity from temp and dew point
function rh_from_dewpoint(t_c: float, dewpoint_c: float) -> float {
    validate_temp_c(t_c);
    validate_temp_c(dewpoint_c);
    if (dewpoint_c > t_c) {
        c_print_err("MeteroError: Dew point cannot exceed air temperature.");
        c_exit(2);
    };
    return c_rh_from_dewpoint(t_c, dewpoint_c);
};

// Absolute humidity (g/m³) — mass of water vapour per volume
function absolute_humidity(t_c: float, rh: float) -> float {
    validate_temp_c(t_c);
    validate_rh(rh);
    return c_absolute_humidity(t_c, rh);
};

function absolute_humidity_f(t_f: float, rh: float) -> float {
    return absolute_humidity(fahrenheit_to_celsius(t_f), rh);
};

// Specific humidity (g/kg) — mass of vapour per mass of moist air
function specific_humidity(t_c: float, rh: float, pressure_mb: float) -> float {
    validate_temp_c(t_c);
    validate_rh(rh);
    validate_pressure_mb(pressure_mb);
    var vp: float = c_vapour_pressure(t_c, rh);
    return c_specific_humidity(vp, pressure_mb);
};

// Mixing ratio (g/kg) — mass of vapour per mass of dry air
function mixing_ratio(t_c: float, rh: float, pressure_mb: float) -> float {
    validate_temp_c(t_c);
    validate_rh(rh);
    validate_pressure_mb(pressure_mb);
    var vp: float = c_vapour_pressure(t_c, rh);
    return c_mixing_ratio(vp, pressure_mb);
};

// Mixing ratio directly from vapour pressure
function mixing_ratio_from_vp(vp_mb: float, pressure_mb: float) -> float {
    if (vp_mb < 0.0) {
        c_print_err("MeteroError: Vapour pressure cannot be negative.");
        c_exit(2);
    };
    validate_pressure_mb(pressure_mb);
    return c_mixing_ratio(vp_mb, pressure_mb);
};

// Relative humidity from mixing ratio
function rh_from_mixing_ratio(mixing_ratio_gkg: float, t_c: float, pressure_mb: float) -> float {
    validate_temp_c(t_c);
    validate_pressure_mb(pressure_mb);
    var svp: float = c_sat_vp(t_c);
    var sat_mr: float = c_mixing_ratio(svp, pressure_mb);
    return mixing_ratio_gkg / sat_mr * 100.0;
};

// Humidex — Canadian heat stress index
// Valid for t >= 20C
function humidex(t_c: float, dewpoint_c: float) -> float {
    validate_temp_c(t_c);
    validate_temp_c(dewpoint_c);
    if (t_c < 20.0) {
        c_print_err("MeteroWarning: Humidex not meaningful below 20C. Returning actual temperature.");
        return t_c;
    };
    if (dewpoint_c > t_c) {
        c_print_err("MeteroError: Dew point cannot exceed air temperature.");
        c_exit(2);
    };
    return c_humidex(t_c, dewpoint_c);
};

// Humidex comfort interpretation — returns scale value 1-5
// 1=comfortable, 2=noticeable, 3=evident, 4=intense, 5=dangerous
function humidex_comfort(t_c: float, dewpoint_c: float) -> int {
    var h: float = humidex(t_c, dewpoint_c);
    if (h < 29.0) { return 1; };
    if (h < 35.0) { return 2; };
    if (h < 40.0) { return 3; };
    if (h < 45.0) { return 4; };
    return 5;
};

// WBGT — Wet Bulb Globe Temperature (outdoor, with solar radiation)
// Used for heat stress in athletics and military
function wbgt_outdoor(t_c: float, rh: float, solar_wm2: float) -> float {
    validate_temp_c(t_c);
    validate_rh(rh);
    if (solar_wm2 < 0.0) {
        c_print_err("MeteroError: Solar radiation cannot be negative.");
        c_exit(2);
    };
    return c_wbgt_outdoor(t_c, rh, solar_wm2);
};

// WBGT indoor (no solar component)
function wbgt_indoor(t_c: float, rh: float) -> float {
    validate_temp_c(t_c);
    validate_rh(rh);
    var wb: float = c_wetbulb(t_c, rh);
    return wb * 0.7 + t_c * 0.3;
};

// WBGT risk level — OSHA categories
// Returns 1=low, 2=moderate, 3=high, 4=very_high, 5=extreme
function wbgt_risk(t_c: float, rh: float, solar_wm2: float) -> int {
    var w: float = wbgt_outdoor(t_c, rh, solar_wm2);
    if (w < 25.6) { return 1; };
    if (w < 27.8) { return 2; };
    if (w < 30.0) { return 3; };
    if (w < 32.2) { return 4; };
    return 5;
};

// Precipitable water (mm) from sounding arrays
// pressure_levels and specific_humidity must be same length
// pressure in mb descending (surface first), q in g/kg
function precipitable_water(specific_humidity_arr: float[], pressure_mb_arr: float[]) -> float {
    var n: int = specific_humidity_arr.length;
    if (n != pressure_mb_arr.length) {
        c_print_err("MeteroError: Array length mismatch in precipitable_water.");
        c_exit(2);
    };
    if (n < 2) {
        c_print_err("MeteroError: precipitable_water requires at least 2 levels.");
        c_exit(2);
    };
    var sum: float = 0.0;
    var i: int = 0;
    while (i < n - 1) {
        var q_avg: float = (specific_humidity_arr[i] + specific_humidity_arr[i + 1]) / 2.0;
        var dp: float = pressure_mb_arr[i] - pressure_mb_arr[i + 1];
        sum = sum + q_avg * dp * 0.1;
        i++;
    };
    return sum;
};

// Saturation deficit (g/kg) — used in evaporation calculations
function saturation_deficit(t_c: float, rh: float, pressure_mb: float) -> float {
    validate_temp_c(t_c);
    validate_rh(rh);
    validate_pressure_mb(pressure_mb);
    var svp: float = c_sat_vp(t_c);
    var vp: float  = c_vapour_pressure(t_c, rh);
    var sat_mr: float  = c_mixing_ratio(svp, pressure_mb);
    var act_mr: float  = c_mixing_ratio(vp, pressure_mb);
    return sat_mr - act_mr;
};

// Enhancement factor — correction for humid air vs ideal gas
// Used in precision meteorology
function enhancement_factor(t_c: float, pressure_mb: float) -> float {
    validate_temp_c(t_c);
    validate_pressure_mb(pressure_mb);
    return 1.00070 + 3.46E-8 * pressure_mb * 100.0 + 
           (t_c - 25.0) * 1.0E-7;
};

// ── Pressure & Altitude C helpers ──
function c_pressure_at_altitude(p_sl: float, alt_m: float, t_c: float) -> float native metero_pressure_at_altitude;
function c_altitude_from_pressure(p_mb: float, p_sl_mb: float, t_c: float) -> float native metero_altitude_from_pressure;
function c_pressure_altitude(p_mb: float) -> float native metero_pressure_altitude;
function c_density_altitude(p_mb: float, t_c: float) -> float native metero_density_altitude;
function c_qnh_from_qfe(qfe_mb: float, elev_m: float, t_c: float) -> float native metero_qnh_from_qfe;
function c_qfe_from_qnh(qnh_mb: float, elev_m: float, t_c: float) -> float native metero_qfe_from_qnh;
function c_isa_temp(alt_m: float) -> float native metero_isa_temp;
function c_isa_pressure(alt_m: float) -> float native metero_isa_pressure;
function c_isa_density(alt_m: float) -> float native metero_isa_density;
function c_altimeter_setting(station_p_mb: float, elev_m: float) -> float native metero_altimeter_setting;
function c_thickness(p_upper: float, p_lower: float, mean_t_c: float) -> float native metero_thickness;

// ════════════════════════════════════════════════════
// SECTION 3 — PRESSURE & ALTITUDE
// ════════════════════════════════════════════════════

function validate_altitude(alt_m: float) -> null {
    if (alt_m < -500.0 || alt_m > 80000.0) {
        c_print_err("MeteroError: Altitude out of range (-500 to 80000 m).");
        c_exit(2);
    };
};

// Pressure at altitude from sea level pressure (mb)
function pressure_at_altitude(pressure_sl_mb: float, altitude_m: float, temp_c: float) -> float {
    validate_pressure_mb(pressure_sl_mb);
    validate_altitude(altitude_m);
    validate_temp_c(temp_c);
    return c_pressure_at_altitude(pressure_sl_mb, altitude_m, temp_c);
};

function pressure_at_altitude_ft(pressure_sl_mb: float, altitude_ft: float, temp_c: float) -> float {
    return pressure_at_altitude(pressure_sl_mb, feet_to_meters(altitude_ft), temp_c);
};

// Altitude from pressure — inverse hypsometric
function altitude_from_pressure(pressure_mb: float, pressure_sl_mb: float, temp_c: float) -> float {
    validate_pressure_mb(pressure_mb);
    validate_pressure_mb(pressure_sl_mb);
    validate_temp_c(temp_c);
    return c_altitude_from_pressure(pressure_mb, pressure_sl_mb, temp_c);
};

function altitude_from_pressure_ft(pressure_mb: float, pressure_sl_mb: float, temp_c: float) -> float {
    return meters_to_feet(altitude_from_pressure(pressure_mb, pressure_sl_mb, temp_c));
};

// Pressure altitude (m) — aviation standard
function pressure_altitude(pressure_mb: float) -> float {
    validate_pressure_mb(pressure_mb);
    return c_pressure_altitude(pressure_mb);
};

function pressure_altitude_ft(pressure_mb: float) -> float {
    return meters_to_feet(pressure_altitude(pressure_mb));
};

// Density altitude (m) — critical for aviation performance
function density_altitude(pressure_mb: float, temp_c: float) -> float {
    validate_pressure_mb(pressure_mb);
    validate_temp_c(temp_c);
    return c_density_altitude(pressure_mb, temp_c);
};

function density_altitude_ft(pressure_mb: float, temp_c: float) -> float {
    return meters_to_feet(density_altitude(pressure_mb, temp_c));
};

// QNH — sea level pressure for altimeter setting
function qnh_from_qfe(qfe_mb: float, elevation_m: float, temp_c: float) -> float {
    validate_altitude(elevation_m);
    validate_temp_c(temp_c);
    return c_qnh_from_qfe(qfe_mb, elevation_m, temp_c);
};

// QFE — station pressure from QNH
function qfe_from_qnh(qnh_mb: float, elevation_m: float, temp_c: float) -> float {
    validate_altitude(elevation_m);
    validate_temp_c(temp_c);
    return c_qfe_from_qnh(qnh_mb, elevation_m, temp_c);
};

// ISA standard atmosphere temperature (C) at altitude
function isa_temp(altitude_m: float) -> float {
    validate_altitude(altitude_m);
    return c_isa_temp(altitude_m);
};

function isa_temp_ft(altitude_ft: float) -> float {
    return isa_temp(feet_to_meters(altitude_ft));
};

// ISA standard atmosphere pressure (mb) at altitude
function isa_pressure(altitude_m: float) -> float {
    validate_altitude(altitude_m);
    return c_isa_pressure(altitude_m);
};

function isa_pressure_ft(altitude_ft: float) -> float {
    return isa_pressure(feet_to_meters(altitude_ft));
};

// ISA air density (kg/m³) at altitude
function isa_density(altitude_m: float) -> float {
    validate_altitude(altitude_m);
    return c_isa_density(altitude_m);
};

// ISA deviation — how much temp differs from standard
function isa_deviation(temp_c: float, altitude_m: float) -> float {
    validate_temp_c(temp_c);
    validate_altitude(altitude_m);
    return temp_c - c_isa_temp(altitude_m);
};

// Altimeter setting (mb) from station pressure and elevation
function altimeter_setting(station_pressure_mb: float, elevation_m: float) -> float {
    validate_altitude(elevation_m);
    return c_altimeter_setting(station_pressure_mb, elevation_m);
};

function altimeter_setting_inhg(station_pressure_mb: float, elevation_m: float) -> float {
    return mb_to_inhg(altimeter_setting(station_pressure_mb, elevation_m));
};

// Thickness (m) between two pressure levels — 1000-500mb thickness
// used for rain/snow discrimination (below 5400m = snow likely)
function thickness(p_upper_mb: float, p_lower_mb: float, mean_temp_c: float) -> float {
    if (p_upper_mb >= p_lower_mb) {
        c_print_err("MeteroError: Upper pressure must be less than lower pressure.");
        c_exit(2);
    };
    validate_temp_c(mean_temp_c);
    return c_thickness(p_upper_mb, p_lower_mb, mean_temp_c);
};

// Is precipitation likely snow? — 1000-500mb thickness rule
function is_snow_likely(thickness_1000_500_m: float) -> bool {
    return thickness_1000_500_m < 5400.0;
};

// Scale height (m) — e-folding distance for pressure decrease
function scale_height(temp_c: float) -> float {
    validate_temp_c(temp_c);
    var t_k: float = temp_c + 273.15;
    return t_k * 29.271;
};

// Mean sea level pressure from station pressure
function mslp(station_pressure_mb: float, elevation_m: float, temp_c: float) -> float {
    validate_altitude(elevation_m);
    validate_temp_c(temp_c);
    return c_qnh_from_qfe(station_pressure_mb, elevation_m, temp_c);
};

// Pressure tendency — 3hr change, used in synoptic analysis
// Returns category: -3=falling rapidly, 0=steady, +3=rising rapidly
function pressure_tendency(p_now_mb: float, p_3hr_ago_mb: float) -> int {
    var change: float = p_now_mb - p_3hr_ago_mb;
    if (change < -3.0) { return -3; };
    if (change < -1.5) { return -2; };
    if (change < -0.5) { return -1; };
    if (change <= 0.5) { return 0; };
    if (change <= 1.5) { return 1; };
    if (change <= 3.0) { return 2; };
    return 3;
};

// ── Wind C helpers ──
function c_wind_u(speed_kmh: float, dir_deg: float) -> float native metero_wind_u;
function c_wind_v(speed_kmh: float, dir_deg: float) -> float native metero_wind_v;
function c_wind_speed_uv(u: float, v: float) -> float native metero_wind_speed_from_uv;
function c_wind_dir_uv(u: float, v: float) -> float native metero_wind_dir_from_uv;
function c_crosswind(speed_kmh: float, wind_dir: float, runway_dir: float) -> float native metero_crosswind;
function c_headwind(speed_kmh: float, wind_dir: float, runway_dir: float) -> float native metero_headwind;
function c_wind_power_density(speed_ms: float, density: float) -> float native metero_wind_power_density;
function c_gust_factor(gust: float, mean: float) -> float native metero_gust_factor;
function c_wind_rose_sector(dir_deg: float) -> int native metero_wind_rose_sector;
function c_beaufort(speed_kmh: float) -> int native metero_beaufort;
function c_wind_shear(s1: float, d1: float, s2: float, d2: float, dz: float) -> float native metero_wind_shear;

// ════════════════════════════════════════════════════
// SECTION 4 — WIND
// ════════════════════════════════════════════════════

// ── Tags ──
tag BeaufortScale {
    CALM, LIGHT_AIR, LIGHT_BREEZE, GENTLE_BREEZE,
    MODERATE_BREEZE, FRESH_BREEZE, STRONG_BREEZE,
    NEAR_GALE, GALE, SEVERE_GALE, STORM,
    VIOLENT_STORM, HURRICANE
};

// ── Validators ──
function validate_direction(dir: float) -> null {
    if (dir < 0.0 || dir > 360.0) {
        c_print_err("MeteroError: Wind direction must be 0-360 degrees.");
        c_exit(2);
    };
};

// U component (east-west, positive = eastward)
function wind_u(speed_kmh: float, direction_deg: float) -> float {
    validate_wind_kmh(speed_kmh);
    validate_direction(direction_deg);
    return c_wind_u(speed_kmh, direction_deg);
};

function wind_u_ms(speed_ms: float, direction_deg: float) -> float {
    return wind_u(ms_to_kmh(speed_ms), direction_deg);
};

// V component (north-south, positive = northward)
function wind_v(speed_kmh: float, direction_deg: float) -> float {
    validate_wind_kmh(speed_kmh);
    validate_direction(direction_deg);
    return c_wind_v(speed_kmh, direction_deg);
};

function wind_v_ms(speed_ms: float, direction_deg: float) -> float {
    return wind_v(ms_to_kmh(speed_ms), direction_deg);
};

// Wind speed from u/v components
function wind_speed_from_uv(u: float, v: float) -> float {
    return c_wind_speed_uv(u, v);
};

// Wind direction from u/v components (meteorological degrees)
function wind_dir_from_uv(u: float, v: float) -> float {
    return c_wind_dir_uv(u, v);
};

// Crosswind component for runway operations
function crosswind(speed_kmh: float, wind_dir_deg: float, runway_dir_deg: float) -> float {
    validate_wind_kmh(speed_kmh);
    validate_direction(wind_dir_deg);
    validate_direction(runway_dir_deg);
    return c_crosswind(speed_kmh, wind_dir_deg, runway_dir_deg);
};

function crosswind_knots(speed_knots: float, wind_dir_deg: float, runway_dir_deg: float) -> float {
    return kmh_to_knots(crosswind(knots_to_kmh(speed_knots), wind_dir_deg, runway_dir_deg));
};

// Headwind component — positive = headwind, negative = tailwind
function headwind(speed_kmh: float, wind_dir_deg: float, runway_dir_deg: float) -> float {
    validate_wind_kmh(speed_kmh);
    validate_direction(wind_dir_deg);
    validate_direction(runway_dir_deg);
    return c_headwind(speed_kmh, wind_dir_deg, runway_dir_deg);
};

function headwind_knots(speed_knots: float, wind_dir_deg: float, runway_dir_deg: float) -> float {
    return kmh_to_knots(headwind(knots_to_kmh(speed_knots), wind_dir_deg, runway_dir_deg));
};

// Beaufort number (0-12)
function beaufort_number(speed_kmh: float) -> int {
    validate_wind_kmh(speed_kmh);
    return c_beaufort(speed_kmh);
};

function beaufort_number_ms(speed_ms: float) -> int {
    return beaufort_number(ms_to_kmh(speed_ms));
};

function beaufort_number_knots(speed_knots: float) -> int {
    return beaufort_number(knots_to_kmh(speed_knots));
};

// Beaufort scale tag
function beaufort_scale(speed_kmh: float) -> BeaufortScale {
    validate_wind_kmh(speed_kmh);
    var b: int = c_beaufort(speed_kmh);
    if (b == 0)  { return BeaufortScale.CALM; };
    if (b == 1)  { return BeaufortScale.LIGHT_AIR; };
    if (b == 2)  { return BeaufortScale.LIGHT_BREEZE; };
    if (b == 3)  { return BeaufortScale.GENTLE_BREEZE; };
    if (b == 4)  { return BeaufortScale.MODERATE_BREEZE; };
    if (b == 5)  { return BeaufortScale.FRESH_BREEZE; };
    if (b == 6)  { return BeaufortScale.STRONG_BREEZE; };
    if (b == 7)  { return BeaufortScale.NEAR_GALE; };
    if (b == 8)  { return BeaufortScale.GALE; };
    if (b == 9)  { return BeaufortScale.SEVERE_GALE; };
    if (b == 10) { return BeaufortScale.STORM; };
    if (b == 11) { return BeaufortScale.VIOLENT_STORM; };
    return BeaufortScale.HURRICANE;
};

// Wind rose sector (0-15, 16-point compass)
function wind_rose_sector(direction_deg: float) -> int {
    validate_direction(direction_deg);
    return c_wind_rose_sector(direction_deg);
};

// Wind rose sector name
function wind_rose_name(direction_deg: float) -> str {
    validate_direction(direction_deg);
    var s: int = c_wind_rose_sector(direction_deg);
    if (s == 0)  { return "N"; };
    if (s == 1)  { return "NNE"; };
    if (s == 2)  { return "NE"; };
    if (s == 3)  { return "ENE"; };
    if (s == 4)  { return "E"; };
    if (s == 5)  { return "ESE"; };
    if (s == 6)  { return "SE"; };
    if (s == 7)  { return "SSE"; };
    if (s == 8)  { return "S"; };
    if (s == 9)  { return "SSW"; };
    if (s == 10) { return "SW"; };
    if (s == 11) { return "WSW"; };
    if (s == 12) { return "W"; };
    if (s == 13) { return "WNW"; };
    if (s == 14) { return "NW"; };
    return "NNW";
};

// Wind power density (W/m²)
function wind_power_density(speed_kmh: float, altitude_m: float) -> float {
    validate_wind_kmh(speed_kmh);
    validate_altitude(altitude_m);
    var speed_ms: float = kmh_to_ms(speed_kmh);
    var density: float = c_isa_density(altitude_m);
    return c_wind_power_density(speed_ms, density);
};

function wind_power_density_ms(speed_ms: float, altitude_m: float) -> float {
    return wind_power_density(ms_to_kmh(speed_ms), altitude_m);
};

// Gust factor
function gust_factor(gust_kmh: float, mean_kmh: float) -> float {
    validate_wind_kmh(gust_kmh);
    validate_wind_kmh(mean_kmh);
    return c_gust_factor(gust_kmh, mean_kmh);
};

// Is gust significant? (gust factor > 1.5 is operationally significant)
function is_gusty(gust_kmh: float, mean_kmh: float) -> bool {
    return gust_factor(gust_kmh, mean_kmh) > 1.5;
};

// Wind shear magnitude between two levels (km/h per meter)
function wind_shear(speed1_kmh: float, dir1_deg: float,
                    speed2_kmh: float, dir2_deg: float,
                    dz_m: float) -> float {
    validate_wind_kmh(speed1_kmh);
    validate_wind_kmh(speed2_kmh);
    validate_direction(dir1_deg);
    validate_direction(dir2_deg);
    if (dz_m <= 0.0) {
        c_print_err("MeteroError: Height difference must be positive for wind shear.");
        c_exit(2);
    };
    return c_wind_shear(speed1_kmh, dir1_deg, speed2_kmh, dir2_deg, dz_m);
};

// Low level wind shear alert — dangerous below 500m
function llws_alert(speed1_kmh: float, dir1_deg: float,
                    speed2_kmh: float, dir2_deg: float,
                    dz_m: float) -> bool {
    var shear: float = wind_shear(speed1_kmh, dir1_deg,
                                   speed2_kmh, dir2_deg, dz_m);
    return shear > 0.1;
};

// Relative wind direction — is wind from given sector?
function is_wind_from(direction_deg: float, sector_center_deg: float, tolerance_deg: float) -> bool {
    validate_direction(direction_deg);
    var diff: float = direction_deg - sector_center_deg;
    if (diff > 180.0)  { diff = diff - 360.0; };
    if (diff < -180.0) { diff = diff + 360.0; };
    if (diff < 0.0) { diff = diff * -1.0; };
    return diff <= tolerance_deg;
};

// Opposite wind direction
function opposite_direction(direction_deg: float) -> float {
    validate_direction(direction_deg);
    var opp: float = direction_deg + 180.0;
    if (opp >= 360.0) { opp = opp - 360.0; };
    return opp;
};

// Wind direction difference (shortest angular distance)
function direction_diff(dir1_deg: float, dir2_deg: float) -> float {
    var diff: float = dir1_deg - dir2_deg;
    if (diff > 180.0)  { diff = diff - 360.0; };
    if (diff < -180.0) { diff = diff + 360.0; };
    return diff;
};

// ── Precipitation C helpers ──
function c_dbz_to_rainrate(dbz: float) -> float native metero_dbz_to_rainrate;
function c_rainrate_to_dbz(rate: float) -> float native metero_rainrate_to_dbz;
function c_snow_water_equiv(depth_cm: float, density: float) -> float native metero_snow_water_equivalent;
function c_snow_density(t_c: float) -> float native metero_snow_density;
function c_rain_to_snowfall(rain_mm: float, t_c: float) -> float native metero_rain_to_snowfall;
function c_hail_size_dbz(dbz: float) -> float native metero_hail_size_from_dbz;
function c_runoff_cn(rainfall_mm: float, cn: float) -> float native metero_runoff_cn;
function c_et_hargreaves(tmax: float, tmin: float, tmean: float, ra: float) -> float native metero_et_hargreaves;
function c_api(decay: float) -> float native metero_api;

// ════════════════════════════════════════════════════
// SECTION 5 — PRECIPITATION
// ════════════════════════════════════════════════════

// ── Tags ──
tag RainfallIntensity {
    TRACE, LIGHT, MODERATE, HEAVY, VIOLENT
};

tag PrecipType {
    RAIN, DRIZZLE, SNOW, SLEET, HAIL, FREEZING_RAIN, NONE
};

// ── Rainfall intensity classification ──
function rainfall_intensity(rate_mmhr: float) -> RainfallIntensity {
    if (rate_mmhr < 0.0) {
        c_print_err("MeteroError: Rainfall rate cannot be negative.");
        c_exit(2);
    };
    if (rate_mmhr < 0.2)  { return RainfallIntensity.TRACE; };
    if (rate_mmhr < 2.5)  { return RainfallIntensity.LIGHT; };
    if (rate_mmhr < 10.0) { return RainfallIntensity.MODERATE; };
    if (rate_mmhr < 50.0) { return RainfallIntensity.HEAVY; };
    return RainfallIntensity.VIOLENT;
};

// ── Precipitation type from temp and wet bulb ──
function precip_type(t_c: float, wetbulb_c: float, dewpoint_c: float) -> PrecipType {
    if (t_c > 3.0 && wetbulb_c > 0.0) { return PrecipType.RAIN; };
    if (t_c > 0.0 && t_c <= 3.0 && wetbulb_c <= 0.0) {
        return PrecipType.FREEZING_RAIN;
    };
    if (t_c <= 0.0 && wetbulb_c <= 0.0) { return PrecipType.SNOW; };
    if (t_c > 0.0 && wetbulb_c <= 0.0) { return PrecipType.SLEET; };
    return PrecipType.RAIN;
};

// ── Radar: dBZ to rain rate (mm/hr) ──
function dbz_to_rainrate(dbz: float) -> float {
    if (dbz < -30.0 || dbz > 75.0) {
        c_print_err("MeteroError: dBZ value out of realistic range (-30 to 75).");
        c_exit(2);
    };
    if (dbz < 0.0) { return 0.0; };
    return c_dbz_to_rainrate(dbz);
};

// Rain rate to dBZ
function rainrate_to_dbz(rate_mmhr: float) -> float {
    if (rate_mmhr < 0.0) {
        c_print_err("MeteroError: Rain rate cannot be negative.");
        c_exit(2);
    };
    if (rate_mmhr == 0.0) { return -32.0; };
    return c_rainrate_to_dbz(rate_mmhr);
};

// dBZ intensity category
function dbz_category(dbz: float) -> str {
    if (dbz < 20.0) { return "no_rain"; };
    if (dbz < 30.0) { return "light"; };
    if (dbz < 40.0) { return "moderate"; };
    if (dbz < 50.0) { return "heavy"; };
    if (dbz < 60.0) { return "very_heavy"; };
    return "extreme";
};

// ── Snow ──

// Snow water equivalent (mm) from depth and density
function snow_water_equivalent(snow_depth_cm: float, snow_density_kgm3: float) -> float {
    if (snow_depth_cm < 0.0) {
        c_print_err("MeteroError: Snow depth cannot be negative.");
        c_exit(2);
    };
    if (snow_density_kgm3 <= 0.0) {
        c_print_err("MeteroError: Snow density must be positive.");
        c_exit(2);
    };
    return c_snow_water_equiv(snow_depth_cm, snow_density_kgm3);
};

// Snow density estimate from temperature
function snow_density(temp_c: float) -> float {
    validate_temp_c(temp_c);
    return c_snow_density(temp_c);
};

// Snowfall depth from liquid equivalent
function rain_to_snowfall_depth(rain_mm: float, temp_c: float) -> float {
    if (rain_mm < 0.0) {
        c_print_err("MeteroError: Rainfall equivalent cannot be negative.");
        c_exit(2);
    };
    validate_temp_c(temp_c);
    return c_rain_to_snowfall(rain_mm, temp_c);
};

// Snow load on structures (kPa)
function snow_load(snow_depth_cm: float, snow_density_kgm3: float) -> float {
    var swe_m: float = c_snow_water_equiv(snow_depth_cm, snow_density_kgm3) / 1000.0;
    return swe_m * snow_density_kgm3 * 9.80665 / 1000.0;
};

// ── Hail ──

// Hail size estimate from dBZ
function hail_size_mm(dbz: float) -> float {
    if (dbz < 0.0) {
        c_print_err("MeteroError: dBZ cannot be negative for hail estimate.");
        c_exit(2);
    };
    return c_hail_size_dbz(dbz);
};

// Hail significant? (>= 19mm = quarter-size = severe threshold)
function is_significant_hail(dbz: float) -> bool {
    return c_hail_size_dbz(dbz) >= 19.0;
};

// ── Accumulation ──

// Accumulated precipitation from rate and duration
function precip_accumulated(rate_mmhr: float, duration_hr: float) -> float {
    if (rate_mmhr < 0.0) {
        c_print_err("MeteroError: Rate cannot be negative.");
        c_exit(2);
    };
    if (duration_hr < 0.0) {
        c_print_err("MeteroError: Duration cannot be negative.");
        c_exit(2);
    };
    return rate_mmhr * duration_hr;
};

// Antecedent precipitation index — soil moisture proxy
// daily_rain: array of past daily rainfalls, most recent first
// decay: typically 0.85-0.98
function antecedent_precip_index(daily_rain_mm: float[], decay: float) -> float {
    if (decay <= 0.0 || decay >= 1.0) {
        c_print_err("MeteroError: API decay factor must be between 0 and 1.");
        c_exit(2);
    };
    var api: float = 0.0;
    var weight: float = 1.0;
    var i: int = 0;
    while (i < daily_rain_mm.length) {
        api = api + daily_rain_mm[i] * weight;
        weight = weight * decay;
        i++;
    };
    return api;
};

// ── Runoff ──

// SCS curve number runoff estimation
function runoff_curve_number(rainfall_mm: float, curve_number: float) -> float {
    if (rainfall_mm < 0.0) {
        c_print_err("MeteroError: Rainfall cannot be negative.");
        c_exit(2);
    };
    if (curve_number <= 0.0 || curve_number > 100.0) {
        c_print_err("MeteroError: Curve number must be between 0 and 100.");
        c_exit(2);
    };
    return c_runoff_cn(rainfall_mm, curve_number);
};

// Runoff coefficient — fraction of rainfall becoming runoff
function runoff_coefficient(rainfall_mm: float, curve_number: float) -> float {
    var runoff: float = runoff_curve_number(rainfall_mm, curve_number);
    if (rainfall_mm == 0.0) { return 0.0; };
    return runoff / rainfall_mm;
};

// ── Evapotranspiration ──

// Hargreaves ET (mm/day) — requires extraterrestrial radiation
function et_hargreaves(t_max_c: float, t_min_c: float,
                        t_mean_c: float, ra_mj_m2_day: float) -> float {
    validate_temp_c(t_max_c);
    validate_temp_c(t_min_c);
    validate_temp_c(t_mean_c);
    if (t_max_c < t_min_c) {
        c_print_err("MeteroError: Max temperature must exceed min temperature.");
        c_exit(2);
    };
    if (ra_mj_m2_day < 0.0) {
        c_print_err("MeteroError: Extraterrestrial radiation cannot be negative.");
        c_exit(2);
    };
    return c_et_hargreaves(t_max_c, t_min_c, t_mean_c, ra_mj_m2_day);
};

// Drought index — simple ratio of ET to precipitation
function drought_index(precip_mm: float, et_mm: float) -> float {
    if (et_mm <= 0.0) { return 0.0; };
    return precip_mm / et_mm;
};

// Is drought? (P/ET < 0.65 = arid threshold)
function is_drought(precip_mm: float, et_mm: float) -> bool {
    return drought_index(precip_mm, et_mm) < 0.65;
};

// Return period (years) from annual exceedance probability
function return_period(annual_exceedance_prob: float) -> float {
    if (annual_exceedance_prob <= 0.0 || annual_exceedance_prob >= 1.0) {
        c_print_err("MeteroError: Exceedance probability must be between 0 and 1.");
        c_exit(2);
    };
    return 1.0 / annual_exceedance_prob;
};

// Exceedance probability from return period
function exceedance_probability(return_period_yr: float) -> float {
    if (return_period_yr <= 0.0) {
        c_print_err("MeteroError: Return period must be positive.");
        c_exit(2);
    };
    return 1.0 / return_period_yr;
};

// ── Severe Weather C helpers ──
function c_k_index(t850: float, t700: float, t500: float, td850: float, td700: float) -> float native metero_k_index;
function c_showalter(t850: float, td850: float, t500: float) -> float native metero_showalter;
function c_lifted_index(tsfc: float, tdsfc: float, psfc: float, t500: float) -> float native metero_lifted_index;
function c_total_totals(t850: float, td850: float, t500: float) -> float native metero_total_totals;
function c_sweat(td850: float, tt: float, spd850: float, spd500: float, dir850: float, dir500: float) -> float native metero_sweat;
function c_ehi(cape: float, srh: float) -> float native metero_ehi;
function c_scp(cape: float, srh: float, shear: float) -> float native metero_scp;
function c_brn(cape: float, shear: float) -> float native metero_brn;

// ════════════════════════════════════════════════════
// SECTION 6 — SEVERE WEATHER INDICES
// ════════════════════════════════════════════════════

// ── Tags ──
tag SevereWeatherRisk {
    NONE, MARGINAL, SLIGHT, ENHANCED, MODERATE, HIGH, EXTREME
};

// ── CAPE/CIN — full parcel theory ──
// pressure_mb: surface-first descending array
// temp_c, dewpoint_c: same length arrays
// Returns [CAPE, CIN, LFC_mb, EL_mb]
function cape_cin(pressure_mb: float[], temp_c: float[], dewpoint_c: float[]) -> float[] {
    var n: int = pressure_mb.length;
    if (n != temp_c.length || n != dewpoint_c.length) {
        c_print_err("MeteroError: cape_cin arrays must be same length.");
        c_exit(2);
    };
    if (n < 2) {
        c_print_err("MeteroError: cape_cin requires at least 2 levels.");
        c_exit(2);
    };

    var t_sfc: float  = temp_c[0];
    var td_sfc: float = dewpoint_c[0];
    var p_sfc: float  = pressure_mb[0];

    var p_lcl: float = c_lcl_pressure(t_sfc, td_sfc, p_sfc);
    var t_lcl: float = c_lcl_temp(t_sfc, td_sfc);

    var cape: float = 0.0;
    var cin: float  = 0.0;
    var lfc: float  = -1.0;
    var el: float   = -1.0;
    var lfc_found: bool = false;
    var el_found: bool  = false;

    var i: int = 1;
    while (i < n) {
        var p_lev: float = pressure_mb[i];
        var t_env: float = temp_c[i];

        var t_parcel: float = 0.0;

        if (p_lev >= p_lcl) {
            // ── Dry adiabatic (below LCL) ──
            var dz_m: float = 29.271 * (t_sfc + 273.15) * c_log(p_sfc / p_lev);
            t_parcel = t_sfc - 9.8 * (dz_m / 1000.0);
        } else {
            // ── Moist adiabatic (above LCL) ──
            var theta_e_k: float = c_equiv_potential_temp(t_sfc, td_sfc, p_sfc);
            t_parcel = theta_e_k * c_pow((p_lev / 1000.0), 0.286) - 273.15;
        };

        var buoy: float = t_parcel - t_env;
        var tv_p: float = t_parcel + 273.15;
        var tv_e: float = t_env + 273.15;
        var dz: float = 29.271 * (tv_p + tv_e) / 2.0 * c_log(pressure_mb[i-1] / p_lev);
        var buoy_acc: float = 9.80665 * (tv_p - tv_e) / tv_e;

        if (!lfc_found && p_lev < p_lcl && buoy > 0.0) {
            lfc = p_lev;
            lfc_found = true;
        };

        if (lfc_found && !el_found && buoy < 0.0 && p_lev < lfc) {
            el = p_lev;
            el_found = true;
        };

        if (lfc_found && !el_found && buoy > 0.0) {
            cape = cape + buoy_acc * dz;
        };

        if (!lfc_found && buoy < 0.0 && p_lev < p_sfc) {
            cin = cin + buoy_acc * dz;
        };

        i = i + 1;
    };

    if (cin > 0.0) {
        cin = -cin;
    };

    var result: float[] = [cape, cin, lfc, el];
    return result;
};

// CAPE only — convenience wrapper
function cape(pressure_mb: float[], temp_c: float[], dewpoint_c: float[]) -> float {
    var result: float[] = cape_cin(pressure_mb, temp_c, dewpoint_c);
    return result[0];
};

// CIN only
function cin(pressure_mb: float[], temp_c: float[], dewpoint_c: float[]) -> float {
    var result: float[] = cape_cin(pressure_mb, temp_c, dewpoint_c);
    return result[1];
};

// LFC pressure (mb) — Level of Free Convection
function lfc_pressure(pressure_mb: float[], temp_c: float[], dewpoint_c: float[]) -> float {
    var result: float[] = cape_cin(pressure_mb, temp_c, dewpoint_c);
    return result[2];
};

// EL pressure (mb) — Equilibrium Level
function el_pressure(pressure_mb: float[], temp_c: float[], dewpoint_c: float[]) -> float {
    var result: float[] = cape_cin(pressure_mb, temp_c, dewpoint_c);
    return result[3];
};

// CAPE severity interpretation
function cape_severity(cape_val: float) -> SevereWeatherRisk {
    if (cape_val < 300.0)  { return SevereWeatherRisk.NONE; };
    if (cape_val < 1000.0) { return SevereWeatherRisk.MARGINAL; };
    if (cape_val < 2000.0) { return SevereWeatherRisk.SLIGHT; };
    if (cape_val < 3000.0) { return SevereWeatherRisk.ENHANCED; };
    if (cape_val < 4000.0) { return SevereWeatherRisk.MODERATE; };
    if (cape_val < 5000.0) { return SevereWeatherRisk.HIGH; };
    return SevereWeatherRisk.EXTREME;
};

// ── K-Index ──
// t850, t700, t500: temps at 850/700/500mb (C)
// td850, td700: dew points at 850/700mb (C)
function k_index(t850_c: float, t700_c: float, t500_c: float,
                 td850_c: float, td700_c: float) -> float {
    return c_k_index(t850_c, t700_c, t500_c, td850_c, td700_c);
};

// K-Index thunderstorm probability
function k_index_tstorm_prob(ki: float) -> int {
    if (ki < 15.0) { return 0; };
    if (ki < 20.0) { return 20; };
    if (ki < 25.0) { return 40; };
    if (ki < 30.0) { return 60; };
    if (ki < 35.0) { return 80; };
    return 100;
};

// ── Showalter Index ──
function showalter_index(t850_c: float, td850_c: float, t500_c: float) -> float {
    return c_showalter(t850_c, td850_c, t500_c);
};

function showalter_severity(si: float) -> SevereWeatherRisk {
    if (si > 3.0)  { return SevereWeatherRisk.NONE; };
    if (si > 1.0)  { return SevereWeatherRisk.MARGINAL; };
    if (si > -1.0) { return SevereWeatherRisk.SLIGHT; };
    if (si > -3.0) { return SevereWeatherRisk.ENHANCED; };
    if (si > -6.0) { return SevereWeatherRisk.MODERATE; };
    return SevereWeatherRisk.HIGH;
};

// ── Lifted Index ──
// Lifted Index — surface parcel lifted to 500mb
function lifted_index(t_sfc_c: float, td_sfc_c: float,
                      p_sfc_mb: float, t500_c: float) -> float {
    validate_temp_c(t_sfc_c);
    validate_temp_c(td_sfc_c);
    validate_pressure_mb(p_sfc_mb);
    var li_raw: float = c_lifted_index(t_sfc_c, td_sfc_c, p_sfc_mb, t500_c);
    return li_raw * -1.0;  // FLIP SIGN — should be negative for instability
};

function lifted_index_severity(li: float) -> SevereWeatherRisk {
    if (li > 2.0)  { return SevereWeatherRisk.NONE; };
    if (li > 0.0)  { return SevereWeatherRisk.MARGINAL; };
    if (li > -2.0) { return SevereWeatherRisk.SLIGHT; };
    if (li > -4.0) { return SevereWeatherRisk.ENHANCED; };
    if (li > -6.0) { return SevereWeatherRisk.MODERATE; };
    return SevereWeatherRisk.HIGH;
};

// ── Total-Totals ──
function total_totals(t850_c: float, td850_c: float, t500_c: float) -> float {
    return c_total_totals(t850_c, td850_c, t500_c);
};

function total_totals_severity(tt: float) -> SevereWeatherRisk {
    if (tt < 44.0) { return SevereWeatherRisk.NONE; };
    if (tt < 50.0) { return SevereWeatherRisk.MARGINAL; };
    if (tt < 55.0) { return SevereWeatherRisk.SLIGHT; };
    if (tt < 60.0) { return SevereWeatherRisk.ENHANCED; };
    return SevereWeatherRisk.MODERATE;
};

// ── SWEAT Index ──
function sweat_index(td850_c: float, tt: float,
                     spd850_kmh: float, spd500_kmh: float,
                     dir850_deg: float, dir500_deg: float) -> float {
    validate_wind_kmh(spd850_kmh);
    validate_wind_kmh(spd500_kmh);
    return c_sweat(td850_c, tt, spd850_kmh, spd500_kmh, dir850_deg, dir500_deg);
};

function sweat_severity(sw: float) -> SevereWeatherRisk {
    if (sw < 150.0) { return SevereWeatherRisk.NONE; };
    if (sw < 250.0) { return SevereWeatherRisk.SLIGHT; };
    if (sw < 300.0) { return SevereWeatherRisk.ENHANCED; };
    if (sw < 400.0) { return SevereWeatherRisk.MODERATE; };
    return SevereWeatherRisk.HIGH;
};

// ── Storm Relative Helicity ──
// u_ms, v_ms: wind components in m/s at each level
// storm_u, storm_v: storm motion vector in m/s
function srh(u_ms: float[], v_ms: float[],
             storm_u_ms: float, storm_v_ms: float) -> float {
    var n: int = u_ms.length;
    if (n != v_ms.length) {
        c_print_err("MeteroError: SRH u/v arrays must be same length.");
        c_exit(2);
    };
    var srh_val: float = 0.0;
    var i: int = 0;
    while (i < n - 1) {
        var u1: float = u_ms[i]   - storm_u_ms;
        var v1: float = v_ms[i]   - storm_v_ms;
        var u2: float = u_ms[i+1] - storm_u_ms;
        var v2: float = v_ms[i+1] - storm_v_ms;
        srh_val = srh_val + (u1 * v2 - u2 * v1);
        i++;
    };
    return srh_val;
};

function srh_severity(srh_val: float) -> SevereWeatherRisk {
    if (srh_val < 0.0)   { return SevereWeatherRisk.NONE; };
    if (srh_val < 150.0) { return SevereWeatherRisk.MARGINAL; };
    if (srh_val < 300.0) { return SevereWeatherRisk.SLIGHT; };
    if (srh_val < 450.0) { return SevereWeatherRisk.ENHANCED; };
    return SevereWeatherRisk.MODERATE;
};

// ── Energy Helicity Index ──
function energy_helicity_index(cape_val: float, srh_val: float) -> float {
    return c_ehi(cape_val, srh_val);
};

function ehi_severity(ehi_val: float) -> SevereWeatherRisk {
    if (ehi_val < 0.5) { return SevereWeatherRisk.NONE; };
    if (ehi_val < 1.0) { return SevereWeatherRisk.MARGINAL; };
    if (ehi_val < 2.0) { return SevereWeatherRisk.SLIGHT; };
    if (ehi_val < 3.0) { return SevereWeatherRisk.ENHANCED; };
    return SevereWeatherRisk.MODERATE;
};

// ── Supercell Composite Parameter ──
function supercell_composite(cape_val: float, srh_val: float,
                              bulk_shear_ms: float) -> float {
    if (bulk_shear_ms < 0.0) {
        c_print_err("MeteroError: Bulk shear cannot be negative.");
        c_exit(2);
    };
    return c_scp(cape_val, srh_val, bulk_shear_ms);
};

function scp_severity(scp_val: float) -> SevereWeatherRisk {
    if (scp_val < 1.0) { return SevereWeatherRisk.NONE; };
    if (scp_val < 4.0) { return SevereWeatherRisk.SLIGHT; };
    if (scp_val < 8.0) { return SevereWeatherRisk.ENHANCED; };
    if (scp_val < 12.0) { return SevereWeatherRisk.MODERATE; };
    return SevereWeatherRisk.HIGH;
};

// ── Bulk Richardson Number ──
function bulk_richardson_number(cape_val: float, bulk_shear_ms: float) -> float {
    if (bulk_shear_ms <= 0.0) {
        c_print_err("MeteroError: Bulk shear must be positive for BRN.");
        c_exit(2);
    };
    return c_brn(cape_val, bulk_shear_ms);
};

// BRN storm type — supercell vs multicell vs ordinary
function brn_storm_type(brn_val: float) -> str {
    if (brn_val < 10.0)  { return "supercell_unlikely_too_much_shear"; };
    if (brn_val < 45.0)  { return "supercell"; };
    if (brn_val < 100.0) { return "multicell"; };
    return "ordinary_convection";
};

// ── Combined severe risk — composite assessment ──
function severe_weather_risk(cape_val: float, li_val: float,
                              ki_val: float, tt_val: float) -> SevereWeatherRisk {
    var score: int = 0;
    if (cape_val > 1000.0) { score++; };
    if (cape_val > 2500.0) { score++; };
    if (li_val < -2.0)     { score++; };
    if (li_val < -5.0)     { score++; };
    if (ki_val > 30.0)     { score++; };
    if (tt_val > 50.0)     { score++; };
    if (score == 0) { return SevereWeatherRisk.NONE; };
    if (score == 1) { return SevereWeatherRisk.MARGINAL; };
    if (score == 2) { return SevereWeatherRisk.SLIGHT; };
    if (score == 3) { return SevereWeatherRisk.ENHANCED; };
    if (score == 4) { return SevereWeatherRisk.MODERATE; };
    if (score == 5) { return SevereWeatherRisk.HIGH; };
    return SevereWeatherRisk.EXTREME;
};

// ── Visibility & Fog C helpers ──
function c_vis_from_ext(ext: float) -> float native metero_visibility_from_extinction;
function c_ext_from_vis(vis: float) -> float native metero_extinction_from_visibility;
function c_fog_probability(t_c: float, td_c: float, wind_kmh: float) -> float native metero_fog_probability;
function c_fog_ceiling(t_c: float, td_c: float) -> float native metero_fog_ceiling;
function c_ffwi(t_c: float, rh: float, wind_kmh: float) -> float native metero_ffwi;
function c_rvr(vis_m: float, has_lights: int) -> float native metero_rvr;
function c_cloud_base(t_c: float, td_c: float) -> float native metero_cloud_base;
function c_mixing_depth(t_sfc: float, t_inv: float, inv_height: float) -> float native metero_mixing_depth;
// ── Air Quality C helpers ──
function c_aqi_pm25(pm25: float) -> float native metero_aqi_pm25_subindex;
function c_aqi_pm10(pm10: float) -> float native metero_aqi_pm10_subindex;
function c_aqi_no2(no2: float) -> float native metero_aqi_no2_subindex;
function c_aqi_so2(so2: float) -> float native metero_aqi_so2_subindex;
function c_aqi_o3(o3: float) -> float native metero_aqi_o3_subindex;
function c_aqi_co(co: float) -> float native metero_aqi_co_subindex;
function c_aqi_combined(pm25: float, pm10: float, no2: float, so2: float, o3: float, co: float) -> float native metero_aqi_from_subindices;


// ════════════════════════════════════════════════════
// SECTION 7 — VISIBILITY, FOG & AIR QUALITY
// ════════════════════════════════════════════════════

// ── Tags ──
tag FogRisk {
    NONE, LOW, MODERATE, HIGH, DENSE
};

tag IcingRisk {
    NONE, TRACE, LIGHT, MODERATE, SEVERE
};

tag AQICategory {
    GOOD, SATISFACTORY, MODERATELY_POLLUTED, POORLY_POLLUTED,
    SEVERELY_POLLUTED, HAZARDOUS
};

// ── Visibility ──

// Visibility from extinction coefficient (km)
function visibility_from_extinction(extinction_per_km: float) -> float {
    if (extinction_per_km < 0.0) {
        c_print_err("MeteroError: Extinction coefficient cannot be negative.");
        c_exit(2);
    };
    return c_vis_from_ext(extinction_per_km);
};

// Extinction coefficient from visibility (km)
function extinction_from_visibility(visibility_km: float) -> float {
    if (visibility_km <= 0.0) {
        c_print_err("MeteroError: Visibility must be positive.");
        c_exit(2);
    };
    return c_ext_from_vis(visibility_km);
};

// Visibility category — ICAO definitions
function visibility_category(visibility_km: float) -> str {
    if (visibility_km < 0.0) {
        c_print_err("MeteroError: Visibility cannot be negative.");
        c_exit(2);
    };
    if (visibility_km < 0.2)  { return "fog"; };
    if (visibility_km < 1.0)  { return "thick_fog"; };
    if (visibility_km < 2.0)  { return "moderate_fog"; };
    if (visibility_km < 4.0)  { return "mist"; };
    if (visibility_km < 10.0) { return "haze"; };
    return "clear";
};

// Prevailing visibility — minimum of directional readings
function prevailing_visibility(vis_readings_km: float[]) -> float {
    if (vis_readings_km.length == 0) {
        c_print_err("MeteroError: No visibility readings provided.");
        c_exit(2);
    };
    var min_vis: float = vis_readings_km[0];
    var i: int = 1;
    while (i < vis_readings_km.length) {
        if (vis_readings_km[i] < min_vis) {
            min_vis = vis_readings_km[i];
        };
        i = i + 1;
    };
    return min_vis;
};

// Runway Visual Range (m)
function runway_visual_range(visibility_m: float, has_runway_lights: bool) -> float {
    if (visibility_m < 0.0) {
        c_print_err("MeteroError: Visibility cannot be negative.");
        c_exit(2);
    };
    var lights: int = 0;
    if (has_runway_lights) { lights = 1; };
    return c_rvr(visibility_m, lights);
};

// Is below IFR minimums? (visibility < 1.6km or ceiling < 500m)
function is_ifr(visibility_km: float, ceiling_m: float) -> bool {
    return visibility_km < 1.6 || ceiling_m < 500.0;
};

// Is below LIFR minimums? (visibility < 0.8km or ceiling < 200m)
function is_lifr(visibility_km: float, ceiling_m: float) -> bool {
    return visibility_km < 0.8 || ceiling_m < 200.0;
};

// ── Fog ──

// Fog risk from temp, dew point, wind
function fog_risk(t_c: float, td_c: float, wind_kmh: float) -> FogRisk {
    validate_temp_c(t_c);
    validate_wind_kmh(wind_kmh);
    var prob: float = c_fog_probability(t_c, td_c, wind_kmh);
    if (prob < 0.1) { return FogRisk.NONE; };
    if (prob < 0.3) { return FogRisk.LOW; };
    if (prob < 0.5) { return FogRisk.MODERATE; };
    if (prob < 0.8) { return FogRisk.HIGH; };
    return FogRisk.DENSE;
};

// Fog probability (0-1)
function fog_probability(t_c: float, td_c: float, wind_kmh: float) -> float {
    validate_temp_c(t_c);
    validate_wind_kmh(wind_kmh);
    if (td_c > t_c) {
        c_print_err("MeteroError: Dew point cannot exceed air temperature.");
        c_exit(2);
    };
    return c_fog_probability(t_c, td_c, wind_kmh);
};

// Fog ceiling height estimate (m)
function fog_ceiling(t_c: float, td_c: float) -> float {
    validate_temp_c(t_c);
    if (td_c > t_c) {
        c_print_err("MeteroError: Dew point cannot exceed air temperature.");
        c_exit(2);
    };
    return c_fog_ceiling(t_c, td_c);
};

// Is radiation fog likely tonight?
// Radiation fog forms on clear, calm, humid nights
function radiation_fog_risk(t_c: float, td_c: float,
                             wind_kmh: float, cloud_cover_oktas: int) -> FogRisk {
    validate_temp_c(t_c);
    validate_wind_kmh(wind_kmh);
    if (cloud_cover_oktas < 0 || cloud_cover_oktas > 8) {
        c_print_err("MeteroError: Cloud cover must be 0-8 oktas.");
        c_exit(2);
    };
    // Clear sky required for radiative cooling
    if (cloud_cover_oktas > 3) { return FogRisk.NONE; };
    // Calm wind required
    if (wind_kmh > 15.0) { return FogRisk.NONE; };
    return fog_risk(t_c, td_c, wind_kmh);
};

// ── Cloud base ──

// Cloud base height (m) from temp-dewpoint spread
function cloud_base_height(t_c: float, td_c: float) -> float {
    validate_temp_c(t_c);
    if (td_c > t_c) {
        c_print_err("MeteroError: Dew point cannot exceed air temperature.");
        c_exit(2);
    };
    return c_cloud_base(t_c, td_c);
};

function cloud_base_height_ft(t_c: float, td_c: float) -> float {
    return meters_to_feet(cloud_base_height(t_c, td_c));
};

// Cloud base category — METAR ceiling terms
function ceiling_category(height_m: float) -> str {
    if (height_m < 0.0) {
        c_print_err("MeteroError: Ceiling height cannot be negative.");
        c_exit(2);
    };
    if (height_m < 100.0)  { return "obscured"; };
    if (height_m < 300.0)  { return "few"; };
    if (height_m < 600.0)  { return "scattered"; };
    if (height_m < 1500.0) { return "broken"; };
    return "overcast";
};

// ── Icing ──

// Icing risk from temperature and relative humidity
function icing_risk(t_c: float, rh: float, liquid_water_content: float) -> IcingRisk {
    validate_temp_c(t_c);
    validate_rh(rh);
    // Icing only occurs in specific temp range
    if (t_c > 0.0 || t_c < -40.0) { return IcingRisk.NONE; };
    if (rh < 70.0) { return IcingRisk.NONE; };
    if (liquid_water_content < 0.01) { return IcingRisk.TRACE; };
    if (liquid_water_content < 0.1)  { return IcingRisk.LIGHT; };
    if (liquid_water_content < 0.3)  { return IcingRisk.MODERATE; };
    return IcingRisk.SEVERE;
};

// Freezing level — altitude where temp crosses 0C
// Takes temp array and altitude array
function freezing_level(temp_c_arr: float[], altitude_m_arr: float[]) -> float {
    var n: int = temp_c_arr.length;
    if (n != altitude_m_arr.length) {
        c_print_err("MeteroError: freezing_level arrays must be same length.");
        c_exit(2);
    };
    var i: int = 0;
    while (i < n - 1) {
        if (temp_c_arr[i] >= 0.0 && temp_c_arr[i+1] < 0.0) {
            // Linear interpolation
            var dt: float = temp_c_arr[i] - temp_c_arr[i+1];
            var frac: float = temp_c_arr[i] / dt;
            return altitude_m_arr[i] + frac *
                   (altitude_m_arr[i+1] - altitude_m_arr[i]);
        };
        i = i + 1;
    };
    return -1.0; // not found
};

// ── Fire weather ──

// Fosberg Fire Weather Index
function fosberg_fwi(t_c: float, rh: float, wind_kmh: float) -> float {
    validate_temp_c(t_c);
    validate_rh(rh);
    validate_wind_kmh(wind_kmh);
    return c_ffwi(t_c, rh, wind_kmh);
};

// Fire weather risk from FFWI
function fire_weather_risk(t_c: float, rh: float, wind_kmh: float) -> SevereWeatherRisk {
    var fwi: float = fosberg_fwi(t_c, rh, wind_kmh);
    if (fwi < 25.0) { return SevereWeatherRisk.NONE; };
    if (fwi < 50.0) { return SevereWeatherRisk.MARGINAL; };
    if (fwi < 75.0) { return SevereWeatherRisk.SLIGHT; };
    if (fwi < 100.0) { return SevereWeatherRisk.ENHANCED; };
    return SevereWeatherRisk.MODERATE;
};

// ── Mixing layer ──

// Mixing layer depth (m) — atmospheric boundary layer height
function mixing_depth(t_sfc_c: float, t_inversion_c: float,
                      inversion_height_m: float) -> float {
    validate_temp_c(t_sfc_c);
    validate_temp_c(t_inversion_c);
    validate_altitude(inversion_height_m);
    return c_mixing_depth(t_sfc_c, t_inversion_c, inversion_height_m);
};

// Ventilation index — mixing depth * mean wind speed
// Low values indicate poor pollution dispersion
function ventilation_index(mixing_depth_m: float, mean_wind_kmh: float) -> float {
    validate_wind_kmh(mean_wind_kmh);
    return mixing_depth_m * kmh_to_ms(mean_wind_kmh);
};

// Air quality dispersion — is ventilation adequate?
function is_poor_dispersion(mixing_depth_m: float, mean_wind_kmh: float) -> bool {
    return ventilation_index(mixing_depth_m, mean_wind_kmh) < 6000.0;
};

// ════════════════════════════════════════════════════
// ADDITION — AIR QUALITY (Indian AQI 0-800)
// ════════════════════════════════════════════════════

// ── Indian AQI (0-800) from pollutant concentrations ──

// PM2.5 sub-index (µg/m³)
function aqi_pm25_subindex(pm25_ugm3: float) -> float {
    if (pm25_ugm3 < 0.0) {
        c_print_err("MeteroError: PM2.5 cannot be negative.");
        c_exit(2);
    };
    return c_aqi_pm25(pm25_ugm3);
};

// PM10 sub-index (µg/m³)
function aqi_pm10_subindex(pm10_ugm3: float) -> float {
    if (pm10_ugm3 < 0.0) {
        c_print_err("MeteroError: PM10 cannot be negative.");
        c_exit(2);
    };
    return c_aqi_pm10(pm10_ugm3);
};

// NO2 sub-index (µg/m³)
function aqi_no2_subindex(no2_ugm3: float) -> float {
    if (no2_ugm3 < 0.0) {
        c_print_err("MeteroError: NO2 cannot be negative.");
        c_exit(2);
    };
    return c_aqi_no2(no2_ugm3);
};

// SO2 sub-index (µg/m³)
function aqi_so2_subindex(so2_ugm3: float) -> float {
    if (so2_ugm3 < 0.0) {
        c_print_err("MeteroError: SO2 cannot be negative.");
        c_exit(2);
    };
    return c_aqi_so2(so2_ugm3);
};

// O3 sub-index (µg/m³)
function aqi_o3_subindex(o3_ugm3: float) -> float {
    if (o3_ugm3 < 0.0) {
        c_print_err("MeteroError: O3 cannot be negative.");
        c_exit(2);
    };
    return c_aqi_o3(o3_ugm3);
};

// CO sub-index (mg/m³)
function aqi_co_subindex(co_mgm3: float) -> float {
    if (co_mgm3 < 0.0) {
        c_print_err("MeteroError: CO cannot be negative.");
        c_exit(2);
    };
    return c_aqi_co(co_mgm3);
};

// Combined Indian AQI (0-800+) from all pollutants
// Combined Indian AQI (0-800+) from all pollutants
function aqi_indian(pm25_ugm3: float, pm10_ugm3: float,
                    no2_ugm3: float, so2_ugm3: float,
                    o3_ugm3: float, co_mgm3: float) -> float {
    var s1: float = c_aqi_pm25(pm25_ugm3);
    var s2: float = c_aqi_pm10(pm10_ugm3);
    var s3: float = c_aqi_no2(no2_ugm3);
    var s4: float = c_aqi_so2(so2_ugm3);
    var s5: float = c_aqi_o3(o3_ugm3);
    var s6: float = c_aqi_co(co_mgm3);
    
    // Return max of all sub-indices
    var max_val: float = s1;
    if (s2 > max_val) { max_val = s2; };
    if (s3 > max_val) { max_val = s3; };
    if (s4 > max_val) { max_val = s4; };
    if (s5 > max_val) { max_val = s5; };
    if (s6 > max_val) { max_val = s6; };
    return max_val;
};

// AQI category tag
function aqi_category(aqi_value: float) -> AQICategory {
    if (aqi_value <= 50.0)   { return AQICategory.GOOD; };
    if (aqi_value <= 100.0)  { return AQICategory.SATISFACTORY; };
    if (aqi_value <= 200.0)  { return AQICategory.MODERATELY_POLLUTED; };
    if (aqi_value <= 300.0)  { return AQICategory.POORLY_POLLUTED; };
    if (aqi_value <= 400.0)  { return AQICategory.SEVERELY_POLLUTED; };
    return AQICategory.HAZARDOUS;
};

// AQI health impact description
function aqi_health_impact(aqi_value: float) -> str {
    if (aqi_value <= 50.0) {
        return "air_quality_satisfactory_minimal_health_impact";
    };
    if (aqi_value <= 100.0) {
        return "acceptable_air_quality_sensitive_groups_may_experience_slight_effects";
    };
    if (aqi_value <= 200.0) {
        return "members_of_general_public_begin_to_experience_health_effects";
    };
    if (aqi_value <= 300.0) {
        return "entire_population_likely_to_be_affected_serious_health_effects";
    };
    if (aqi_value <= 400.0) {
        return "respiratory_emergency_alert_expected_widespread_health_effects";
    };
    return "health_alert_emergency_conditions_severe_illness_entire_population";
};

// AQI advisory
function aqi_advisory(aqi_value: float) -> str {
    if (aqi_value <= 50.0)   { return "no_action_needed"; };
    if (aqi_value <= 100.0)  { return "sensitive_groups_limit_outdoor_activity"; };
    if (aqi_value <= 200.0)  { return "children_elderly_avoid_prolonged_outdoor_activity"; };
    if (aqi_value <= 300.0)  { return "everyone_avoid_outdoor_activity_stay_indoors"; };
    if (aqi_value <= 400.0)  { return "all_outdoor_activities_halted_wear_masks_indoors"; };
    return "emergency_isolation_medical_supervision";
};

// AQI emoji/severity
function aqi_severity(aqi_value: float) -> int {
    if (aqi_value <= 50.0)   { return 1; };
    if (aqi_value <= 100.0)  { return 2; };
    if (aqi_value <= 200.0)  { return 3; };
    if (aqi_value <= 300.0)  { return 4; };
    if (aqi_value <= 400.0)  { return 5; };
    return 6;
};

// Visibility impairment from PM2.5 (stronger relationship)
function visibility_impairment_pm25(pm25_ugm3: float) -> float {
    if (pm25_ugm3 < 0.0) {
        c_print_err("MeteroError: PM2.5 cannot be negative.");
        c_exit(2);
    };
    // Empirical: reduction_km = sqrt(PM2.5 / 10)
    // 15µg→0.39km, 250µg→1.58km
    var sqrt_term: float = (pm25_ugm3 / 10.0).sqrt().real;
    return sqrt_term;
};

// Estimated visibility from PM2.5 and baseline clear visibility
function estimated_visibility_pm25(pm25_ugm3: float, clear_sky_visibility_km: float) -> float {
    if (clear_sky_visibility_km <= 0.0) {
        c_print_err("MeteroError: Clear sky visibility must be positive.");
        c_exit(2);
    };
    var reduction_km: float = visibility_impairment_pm25(pm25_ugm3);
    var vis: float = clear_sky_visibility_km - reduction_km;
    if (vis < 0.0) { vis = 0.0; };
    return vis;
};

// Is air quality hazardous to outdoor activity?
function is_hazardous_aqi(aqi_value: float) -> bool {
    return aqi_value > 200.0;
};

// Recommended N95 mask usage — AQI threshold
function mask_recommended(aqi_value: float) -> bool {
    return aqi_value >= 100.0;
};

// ── Solar & Radiation C helpers ──
function c_solar_declination(doy: int) -> float native metero_solar_declination;
function c_equation_of_time(doy: int) -> float native metero_equation_of_time;
function c_hour_angle(solar_time_hr: float) -> float native metero_hour_angle;
function c_solar_elevation(lat: float, decl: float, ha: float) -> float native metero_solar_elevation;
function c_solar_azimuth(lat: float, decl: float, ha: float, elev: float) -> float native metero_solar_azimuth;
function c_sunrise_utc(lat: float, lon: float, doy: int) -> float native metero_sunrise_utc;
function c_sunset_utc(lat: float, lon: float, doy: int) -> float native metero_sunset_utc;
function c_daylight_hours(lat: float, doy: int) -> float native metero_daylight_hours;
function c_extraterrestrial_rad(lat: float, doy: int) -> float native metero_extraterrestrial_radiation;
function c_clear_sky_rad(lat: float, doy: int, elev: float) -> float native metero_clear_sky_radiation;
function c_uv_index(elev_deg: float, ozone_du: float) -> float native metero_uv_index;
function c_par(global_rad: float) -> float native metero_par;
function c_net_radiation(rs: float, tmax: float, tmin: float, rh: float, ra: float, elev: float) -> float native metero_net_radiation;

// ════════════════════════════════════════════════════
// SECTION 8 — SOLAR & RADIATION
// ════════════════════════════════════════════════════

// ── Tags ──
tag UVCategory {
    LOW, MODERATE, HIGH, VERY_HIGH, EXTREME
};

// ── Validators ──
function validate_latitude(lat: float) -> null {
    if (lat < -90.0 || lat > 90.0) {
        c_print_err("MeteroError: Latitude must be between -90 and 90.");
        c_exit(2);
    };
};

function validate_longitude(lon: float) -> null {
    if (lon < -180.0 || lon > 180.0) {
        c_print_err("MeteroError: Longitude must be between -180 and 180.");
        c_exit(2);
    };
};

function validate_doy(doy: int) -> null {
    if (doy < 1 || doy > 366) {
        c_print_err("MeteroError: Day of year must be 1-366.");
        c_exit(2);
    };
};

// ── Solar geometry ──

// Solar declination (degrees) — axial tilt effect
function solar_declination(day_of_year: int) -> float {
    validate_doy(day_of_year);
    return c_solar_declination(day_of_year);
};

// Equation of time (minutes) — orbital eccentricity correction
function equation_of_time(day_of_year: int) -> float {
    validate_doy(day_of_year);
    return c_equation_of_time(day_of_year);
};

// Hour angle (degrees) from solar time
function hour_angle(solar_time_hr: float) -> float {
    if (solar_time_hr < 0.0 || solar_time_hr > 24.0) {
        c_print_err("MeteroError: Solar time must be 0-24 hours.");
        c_exit(2);
    };
    return c_hour_angle(solar_time_hr);
};

// Solar time from local time, longitude, day of year
function solar_time(local_time_hr: float, longitude_deg: float,
                    day_of_year: int) -> float {
    validate_longitude(longitude_deg);
    validate_doy(day_of_year);
    var eot: float = c_equation_of_time(day_of_year);
    return local_time_hr + longitude_deg / 15.0 + eot / 60.0;
};

// Solar elevation angle (degrees above horizon)
function solar_elevation(latitude_deg: float, day_of_year: int,
                          solar_time_hr: float) -> float {
    validate_latitude(latitude_deg);
    validate_doy(day_of_year);
    var decl: float = c_solar_declination(day_of_year);
    var ha: float   = c_hour_angle(solar_time_hr);
    return c_solar_elevation(latitude_deg, decl, ha);
};

// Solar azimuth (degrees from North, clockwise)
function solar_azimuth(latitude_deg: float, day_of_year: int,
                        solar_time_hr: float) -> float {
    validate_latitude(latitude_deg);
    validate_doy(day_of_year);
    var decl: float = c_solar_declination(day_of_year);
    var ha: float   = c_hour_angle(solar_time_hr);
    var elev: float = c_solar_elevation(latitude_deg, decl, ha);
    return c_solar_azimuth(latitude_deg, decl, ha, elev);
};

// Is sun above horizon?
function is_daylight(latitude_deg: float, day_of_year: int,
                     solar_time_hr: float) -> bool {
    return solar_elevation(latitude_deg, day_of_year, solar_time_hr) > 0.0;
};

// ── Sunrise / Sunset ──

// Sunrise time (decimal hours UTC)
function sunrise_utc(latitude_deg: float, longitude_deg: float,
                     day_of_year: int) -> float {
    validate_latitude(latitude_deg);
    validate_longitude(longitude_deg);
    validate_doy(day_of_year);
    return c_sunrise_utc(latitude_deg, longitude_deg, day_of_year);
};

// Sunset time (decimal hours UTC)
function sunset_utc(latitude_deg: float, longitude_deg: float,
                    day_of_year: int) -> float {
    validate_latitude(latitude_deg);
    validate_longitude(longitude_deg);
    validate_doy(day_of_year);
    return c_sunset_utc(latitude_deg, longitude_deg, day_of_year);
};

function decimal_hours_to_time(decimal_hours: float) -> str {
    var total_seconds: int = int(decimal_hours * 3600.0);
    if (total_seconds < 0) {
        total_seconds = total_seconds + 86400;  // add 24 hours if negative
    };
    var hours: int = total_seconds / 3600;
    var minutes: int = (total_seconds % 3600) / 60;
    var seconds: int = total_seconds % 60;
    var h_str: str = str(hours);
    var m_str: str = str(minutes);
    var s_str: str = str(seconds);
    if (hours < 10) { h_str = "0" + h_str; };
    if (minutes < 10) { m_str = "0" + m_str; };
    if (seconds < 10) { s_str = "0" + s_str; };
    return h_str + ":" + m_str + ":" + s_str;
};

// Daylight duration (hours)
function daylight_hours(latitude_deg: float, day_of_year: int) -> float {
    validate_latitude(latitude_deg);
    validate_doy(day_of_year);
    return c_daylight_hours(latitude_deg, day_of_year);
};

// Is polar day? (sun never sets)
function is_polar_day(latitude_deg: float, day_of_year: int) -> bool {
    validate_latitude(latitude_deg);
    validate_doy(day_of_year);
    return c_daylight_hours(latitude_deg, day_of_year) >= 23.9;
};

// Is polar night? (sun never rises)
function is_polar_night(latitude_deg: float, day_of_year: int) -> bool {
    validate_latitude(latitude_deg);
    validate_doy(day_of_year);
    return c_daylight_hours(latitude_deg, day_of_year) <= 0.1;
};

// Solar noon (decimal hours UTC)
function solar_noon_utc(longitude_deg: float, day_of_year: int) -> float {
    validate_longitude(longitude_deg);
    validate_doy(day_of_year);
    var eot: float = c_equation_of_time(day_of_year);
    return 12.0 - longitude_deg / 15.0 - eot / 60.0;
};

// ── Radiation ──

// Extraterrestrial radiation (MJ/m²/day) — top of atmosphere
function extraterrestrial_radiation(latitude_deg: float, day_of_year: int) -> float {
    validate_latitude(latitude_deg);
    validate_doy(day_of_year);
    return c_extraterrestrial_rad(latitude_deg, day_of_year);
};

// Clear sky radiation (MJ/m²/day) — no clouds
function clear_sky_radiation(latitude_deg: float, day_of_year: int,
                              elevation_m: float) -> float {
    validate_latitude(latitude_deg);
    validate_doy(day_of_year);
    validate_altitude(elevation_m);
    return c_clear_sky_rad(latitude_deg, day_of_year, elevation_m);
};

// Sunshine fraction — actual vs clear sky
function sunshine_fraction(actual_radiation_mj: float,
                            clear_sky_mj: float) -> float {
    if (clear_sky_mj <= 0.0) { return 0.0; };
    var frac: float = actual_radiation_mj / clear_sky_mj;
    if (frac > 1.0) { frac = 1.0; };
    return frac;
};

// Net radiation (MJ/m²/day) — FAO-56 Penman-Monteith
function net_radiation(rs_mj_m2_day: float, t_max_c: float, t_min_c: float,
                        rh_mean: float, ra_mj_m2_day: float,
                        elevation_m: float) -> float {
    validate_temp_c(t_max_c);
    validate_temp_c(t_min_c);
    validate_rh(rh_mean);
    validate_altitude(elevation_m);
    if (t_max_c < t_min_c) {
        c_print_err("MeteroError: Max temp must exceed min temp.");
        c_exit(2);
    };
    return c_net_radiation(rs_mj_m2_day, t_max_c, t_min_c,
                           rh_mean, ra_mj_m2_day, elevation_m);
};

// PAR — Photosynthetically Active Radiation (W/m²)
function par(global_radiation_wm2: float) -> float {
    if (global_radiation_wm2 < 0.0) {
        c_print_err("MeteroError: Global radiation cannot be negative.");
        c_exit(2);
    };
    return c_par(global_radiation_wm2);
};

// ── UV ──

// UV Index from solar elevation and ozone
function uv_index(latitude_deg: float, day_of_year: int,
                  solar_time_hr: float, ozone_du: float) -> float {
    validate_latitude(latitude_deg);
    validate_doy(day_of_year);
    if (ozone_du <= 0.0) {
        c_print_err("MeteroError: Ozone column must be positive (Dobson units).");
        c_exit(2);
    };
    var elev: float = solar_elevation(latitude_deg, day_of_year, solar_time_hr);
    if (elev <= 0.0) { return 0.0; };
    return c_uv_index(elev, ozone_du);
};

// UV category tag
function uv_category(uvi: float) -> UVCategory {
    if (uvi < 0.0) {
        c_print_err("MeteroError: UV index cannot be negative.");
        c_exit(2);
    };
    if (uvi < 3.0)  { return UVCategory.LOW; };
    if (uvi < 6.0)  { return UVCategory.MODERATE; };
    if (uvi < 8.0)  { return UVCategory.HIGH; };
    if (uvi < 11.0) { return UVCategory.VERY_HIGH; };
    return UVCategory.EXTREME;
};

// Minutes to sunburn — fair skin approximation
function minutes_to_sunburn(uvi: float) -> float {
    if (uvi <= 0.0) { return 9999.0; };
    return 200.0 / (3.0 * uvi);
};

// ── Solar energy ──

// Solar panel output estimate (kWh/day)
function solar_panel_output(panel_area_m2: float, efficiency: float,
                             latitude_deg: float, day_of_year: int,
                             elevation_m: float) -> float {
    validate_latitude(latitude_deg);
    validate_doy(day_of_year);
    if (panel_area_m2 <= 0.0) {
        c_print_err("MeteroError: Panel area must be positive.");
        c_exit(2);
    };
    if (efficiency <= 0.0 || efficiency > 1.0) {
        c_print_err("MeteroError: Efficiency must be between 0 and 1.");
        c_exit(2);
    };
    var ra: float = c_clear_sky_rad(latitude_deg, day_of_year, elevation_m);
    // Convert MJ/m²/day to kWh/m²/day (1 MJ = 0.2778 kWh)
    var irradiance_kwh: float = ra * 0.2778;
    return panel_area_m2 * efficiency * irradiance_kwh;
};

// Day of year from month and day (non-leap year)
function day_of_year(month: int, day: int) -> int {
    if (month < 1 || month > 12) {
        c_print_err("MeteroError: Month must be 1-12.");
        c_exit(2);
    };
    var days_in_month: int[] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    var doy: int = 0;
    var m: int = 0;
    while (m < month - 1) {
        doy = doy + days_in_month[m];
        m = m + 1;
    };
    return doy + day;
};

// ── Climate Statistics C helpers ──
function c_hdd(t_mean: float, base: float) -> float native metero_hdd;
function c_cdd(t_mean: float, base: float) -> float native metero_cdd;
function c_gdd(t_max: float, t_min: float, base: float, cap: float) -> float native metero_gdd;
function c_temp_anomaly(obs: float, clim: float) -> float native metero_temp_anomaly;
function c_std_anomaly(obs: float, mean: float, std: float) -> float native metero_standardised_anomaly;
function c_spi(precip: float, mean: float, std: float) -> float native metero_spi;
function c_pet_thornthwaite(t_mean: float, hi: float, daylight: float, days: int) -> float native metero_pet_thornthwaite;

// ════════════════════════════════════════════════════
// SECTION 9 — CLIMATE STATISTICS
// ════════════════════════════════════════════════════

// ── Degree Days ──

// Heating Degree Days (base 18C default)
function heating_degree_days(t_mean_c: float, base_c: float) -> float {
    validate_temp_c(t_mean_c);
    return c_hdd(t_mean_c, base_c);
};

function hdd(t_mean_c: float) -> float {
    validate_temp_c(t_mean_c);
    return c_hdd(t_mean_c, 18.0);
};

function hdd_f(t_mean_f: float) -> float {
    return hdd(fahrenheit_to_celsius(t_mean_f));
};

// Cooling Degree Days (base 18C default)
function cooling_degree_days(t_mean_c: float, base_c: float) -> float {
    validate_temp_c(t_mean_c);
    return c_cdd(t_mean_c, base_c);
};

function cdd(t_mean_c: float) -> float {
    validate_temp_c(t_mean_c);
    return c_cdd(t_mean_c, 18.0);
};

// Accumulated HDD over array of daily means
function accumulated_hdd(t_mean_arr: float[], base_c: float) -> float {
    var total: float = 0.0;
    var i: int = 0;
    while (i < t_mean_arr.length) {
        total = total + c_hdd(t_mean_arr[i], base_c);
        i = i + 1;
    };
    return total;
};

// Accumulated CDD
function accumulated_cdd(t_mean_arr: float[], base_c: float) -> float {
    var total: float = 0.0;
    var i: int = 0;
    while (i < t_mean_arr.length) {
        total = total + c_cdd(t_mean_arr[i], base_c);
        i = i + 1;
    };
    return total;
};

// Growing Degree Days — crop development model
// base_c: lower threshold, cap_c: upper threshold
function growing_degree_days(t_max_c: float, t_min_c: float,
                              base_c: float, cap_c: float) -> float {
    validate_temp_c(t_max_c);
    validate_temp_c(t_min_c);
    if (t_max_c < t_min_c) {
        c_print_err("MeteroError: Max temp must exceed min temp.");
        c_exit(2);
    };
    return c_gdd(t_max_c, t_min_c, base_c, cap_c);
};

function gdd(t_max_c: float, t_min_c: float) -> float {
    return growing_degree_days(t_max_c, t_min_c, 10.0, 30.0);
};

// Accumulated GDD — crop maturity index
function accumulated_gdd(t_max_arr: float[], t_min_arr: float[],
                          base_c: float, cap_c: float) -> float {
    var n: int = t_max_arr.length;
    if (n != t_min_arr.length) {
        c_print_err("MeteroError: Max and min temp arrays must be same length.");
        c_exit(2);
    };
    var total: float = 0.0;
    var i: int = 0;
    while (i < n) {
        total = total + c_gdd(t_max_arr[i], t_min_arr[i], base_c, cap_c);
        i = i + 1;
    };
    return total;
};

// ── Anomalies ──

// Temperature anomaly from climatological mean
function temp_anomaly(observed_c: float, climatology_c: float) -> float {
    return c_temp_anomaly(observed_c, climatology_c);
};

// Precipitation anomaly (%)
function precip_anomaly_pct(observed_mm: float, climatology_mm: float) -> float {
    if (climatology_mm <= 0.0) {
        c_print_err("MeteroError: Climatological mean must be positive.");
        c_exit(2);
    };
    return (observed_mm - climatology_mm) / climatology_mm * 100.0;
};

// Standardised anomaly (z-score)
function standardised_anomaly(observed: float, mean: float, std_dev: float) -> float {
    if (std_dev <= 0.0) {
        c_print_err("MeteroError: Standard deviation must be positive.");
        c_exit(2);
    };
    return c_std_anomaly(observed, mean, std_dev);
};

// Percentile rank of value in climatology array
function percentile_rank(value: float, climatology: float[]) -> float {
    var n: int = climatology.length;
    if (n == 0) {
        c_print_err("MeteroError: Climatology array cannot be empty.");
        c_exit(2);
    };
    var below: int = 0;
    var i: int = 0;
    while (i < n) {
        if (climatology[i] < value) { below = below + 1; };
        i = i + 1;
    };
    return below / n * 100.0;
};

// Is value extreme? (outside 10th-90th percentile)
function is_extreme(value: float, climatology: float[]) -> bool {
    var pct: float = percentile_rank(value, climatology);
    return pct < 10.0 || pct > 90.0;
};

// ── Indices ──

// SPI — Standardised Precipitation Index
// < -2.0 = extreme drought, > 2.0 = extreme wet
function spi(precip_mm: float, mean_mm: float, std_mm: float) -> float {
    if (mean_mm <= 0.0) {
        c_print_err("MeteroError: Mean precipitation must be positive.");
        c_exit(2);
    };
    if (std_mm <= 0.0) {
        c_print_err("MeteroError: Std deviation must be positive.");
        c_exit(2);
    };
    return c_spi(precip_mm, mean_mm, std_mm);
};

function spi_category(spi_val: float) -> str {
    if (spi_val <= -2.0)  { return "extreme_drought"; };
    if (spi_val <= -1.5)  { return "severe_drought"; };
    if (spi_val <= -1.0)  { return "moderate_drought"; };
    if (spi_val <= -0.5)  { return "mild_drought"; };
    if (spi_val < 0.5)    { return "near_normal"; };
    if (spi_val < 1.0)    { return "mild_wet"; };
    if (spi_val < 1.5)    { return "moderate_wet"; };
    if (spi_val < 2.0)    { return "severe_wet"; };
    return "extreme_wet";
};

// ── Climate indices ──

// Frost days in array of daily minimums
function frost_days(t_min_arr: float[]) -> int {
    var count: int = 0;
    var i: int = 0;
    while (i < t_min_arr.length) {
        if (t_min_arr[i] < 0.0) { count = count + 1; };
        i = i + 1;
    };
    return count;
};

// Summer days — t_max > 25C
function summer_days(t_max_arr: float[]) -> int {
    var count: int = 0;
    var i: int = 0;
    while (i < t_max_arr.length) {
        if (t_max_arr[i] > 25.0) { count = count + 1; };
        i = i + 1;
    };
    return count;
};

// Tropical nights — t_min > 20C
function tropical_nights(t_min_arr: float[]) -> int {
    var count: int = 0;
    var i: int = 0;
    while (i < t_min_arr.length) {
        if (t_min_arr[i] > 20.0) { count = count + 1; };
        i = i + 1;
    };
    return count;
};

// Ice days — t_max < 0C
function ice_days(t_max_arr: float[]) -> int {
    var count: int = 0;
    var i: int = 0;
    while (i < t_max_arr.length) {
        if (t_max_arr[i] < 0.0) { count = count + 1; };
        i = i + 1;
    };
    return count;
};

// Consecutive dry days — longest run below threshold
function consecutive_dry_days(precip_arr: float[], threshold_mm: float) -> int {
    var max_run: int = 0;
    var current: int = 0;
    var i: int = 0;
    while (i < precip_arr.length) {
        if (precip_arr[i] < threshold_mm) {
            current = current + 1;
            if (current > max_run) { max_run = current; };
        };
        if (precip_arr[i] >= threshold_mm) { current = 0; };
        i = i + 1;
    };
    return max_run;
};

// Consecutive wet days
function consecutive_wet_days(precip_arr: float[], threshold_mm: float) -> int {
    var max_run: int = 0;
    var current: int = 0;
    var i: int = 0;
    while (i < precip_arr.length) {
        if (precip_arr[i] >= threshold_mm) {
            current = current + 1;
            if (current > max_run) { max_run = current; };
        };
        if (precip_arr[i] < threshold_mm) { current = 0; };
        i = i + 1;
    };
    return max_run;
};

// Heavy precipitation days — > 10mm
function heavy_precip_days(precip_arr: float[]) -> int {
    var count: int = 0;
    var i: int = 0;
    while (i < precip_arr.length) {
        if (precip_arr[i] > 10.0) { count = count + 1; };
        i = i + 1;
    };
    return count;
};

// Very heavy precipitation days — > 20mm
function very_heavy_precip_days(precip_arr: float[]) -> int {
    var count: int = 0;
    var i: int = 0;
    while (i < precip_arr.length) {
        if (precip_arr[i] > 20.0) { count = count + 1; };
        i = i + 1;
    };
    return count;
};

// Diurnal temperature range — mean of daily max-min difference
function mean_diurnal_range(t_max_arr: float[], t_min_arr: float[]) -> float {
    var n: int = t_max_arr.length;
    if (n != t_min_arr.length) {
        c_print_err("MeteroError: Max and min temp arrays must be same length.");
        c_exit(2);
    };
    if (n == 0) { return 0.0; };
    var sum: float = 0.0;
    var i: int = 0;
    while (i < n) {
        sum = sum + (t_max_arr[i] - t_min_arr[i]);
        i = i + 1;
    };
    return sum / n;
};

// Warmest/coldest periods
function warmest_day(t_max_arr: float[]) -> float {
    if (t_max_arr.length == 0) { return -9999.0; };
    var max_t: float = t_max_arr[0];
    var i: int = 1;
    while (i < t_max_arr.length) {
        if (t_max_arr[i] > max_t) { max_t = t_max_arr[i]; };
        i = i + 1;
    };
    return max_t;
};

function coldest_night(t_min_arr: float[]) -> float {
    if (t_min_arr.length == 0) { return 9999.0; };
    var min_t: float = t_min_arr[0];
    var i: int = 1;
    while (i < t_min_arr.length) {
        if (t_min_arr[i] < min_t) { min_t = t_min_arr[i]; };
        i = i + 1;
    };
    return min_t;
};

// Thornthwaite PET (mm/month)
// heat_index: annual thermal index (sum of monthly (T/5)^1.514)
function pet_thornthwaite(t_mean_c: float, annual_heat_index: float,
                           daylight_hr: float, days_in_month: int) -> float {
    validate_temp_c(t_mean_c);
    if (annual_heat_index <= 0.0) {
        c_print_err("MeteroError: Annual heat index must be positive.");
        c_exit(2);
    };
    if (days_in_month < 28 || days_in_month > 31) {
        c_print_err("MeteroError: Days in month must be 28-31.");
        c_exit(2);
    };
    return c_pet_thornthwaite(t_mean_c, annual_heat_index,
                               daylight_hr, days_in_month);
};

// Thornthwaite annual heat index from 12 monthly means
function thornthwaite_heat_index(monthly_means_c: float[]) -> float {
    if (monthly_means_c.length != 12) {
        c_print_err("MeteroError: Thornthwaite heat index requires 12 monthly means.");
        c_exit(2);
    };
    var hi: float = 0.0;
    var i: int = 0;
    while (i < 12) {
        if (monthly_means_c[i] > 0.0) {
            var term: float = monthly_means_c[i] / 5.0;
            hi = hi + c_pow(term, 1.514);
        };
        i = i + 1;
    };
    return hi;
};

// Climate classification — simple Koppen-like
function koppen_class(t_mean_annual_c: float,
                       precip_annual_mm: float,
                       t_coldest_month_c: float,
                       t_hottest_month_c: float) -> str {
    // A: Tropical
    if (t_coldest_month_c >= 18.0) { return "A_tropical"; };
    // E: Polar
    if (t_hottest_month_c < 10.0) {
        if (t_hottest_month_c < 0.0) { return "EF_ice_cap"; };
        return "ET_tundra";
    };
    // B: Arid — threshold depends on seasonality (simplified)
    var p_thresh: float = t_mean_annual_c * 20.0 + 280.0;
    if (precip_annual_mm < p_thresh / 2.0) { return "BWh_hot_desert"; };
    if (precip_annual_mm < p_thresh) { return "BSh_hot_steppe"; };
    // C: Temperate
    if (t_coldest_month_c >= 0.0) {
        if (t_hottest_month_c >= 22.0) { return "Cfa_humid_subtropical"; };
        return "Cfb_oceanic";
    };
    // D: Continental
    if (t_hottest_month_c >= 22.0) { return "Dfa_humid_continental_hot"; };
    return "Dfb_humid_continental_warm";
};

// ── Large-Scale Climate Indices C helpers ──
function c_saffir_simpson(wind_kmh: float) -> int native metero_saffir_simpson_category;
function c_jma_category(wind_kmh: float) -> int native metero_jma_category;
function c_imd_category(wind_kmh: float) -> int native metero_imd_category;
function c_enso_phase(oni: float) -> int native metero_enso_phase;
function c_iod_phase(dmi: float) -> int native metero_iod_phase;
function c_ao_phase(idx: float) -> int native metero_ao_phase;

// ════════════════════════════════════════════════════
// SECTION 10 — LARGE-SCALE CLIMATE INDICES & CYCLONES
// ════════════════════════════════════════════════════

// ── Tags ──
tag ENSOPhase {
    STRONG_LA_NINA, MODERATE_LA_NINA, WEAK_LA_NINA, NEUTRAL,
    WEAK_EL_NINO, MODERATE_EL_NINO, STRONG_EL_NINO
};

tag IODPhase {
    STRONG_NEGATIVE, WEAK_NEGATIVE, NEUTRAL, WEAK_POSITIVE, STRONG_POSITIVE
};

tag CycloneScale {
    TROPICAL_DEPRESSION, TROPICAL_STORM, CATEGORY_1, CATEGORY_2,
    CATEGORY_3, CATEGORY_4, CATEGORY_5
};

// ════════════════════════════════════════════════════
// ENSO — El Niño Southern Oscillation
// ════════════════════════════════════════════════════

// ONI — Oceanic Niño Index (published NOAA index)
// User provides the published 3-month rolling mean value
function oni_phase(oni_value: float) -> ENSOPhase {
    if (oni_value <= -1.5)  { return ENSOPhase.STRONG_LA_NINA; };
    if (oni_value <= -1.0)  { return ENSOPhase.MODERATE_LA_NINA; };
    if (oni_value <= -0.5)  { return ENSOPhase.WEAK_LA_NINA; };
    if (oni_value < 0.5)    { return ENSOPhase.NEUTRAL; };
    if (oni_value < 1.0)    { return ENSOPhase.WEAK_EL_NINO; };
    if (oni_value < 1.5)    { return ENSOPhase.MODERATE_EL_NINO; };
    return ENSOPhase.STRONG_EL_NINO;
};

// SOI — Southern Oscillation Index
// Tahiti SLP minus Darwin SLP, standardised
// Negative = El Niño tendency, Positive = La Niña tendency
function soi_phase(soi_value: float) -> ENSOPhase {
    if (soi_value >= 1.0)   { return ENSOPhase.STRONG_LA_NINA; };
    if (soi_value >= 0.5)   { return ENSOPhase.MODERATE_LA_NINA; };
    if (soi_value >= 0.0)   { return ENSOPhase.WEAK_LA_NINA; };
    if (soi_value > -0.5)   { return ENSOPhase.NEUTRAL; };
    if (soi_value > -1.0)   { return ENSOPhase.WEAK_EL_NINO; };
    if (soi_value > -1.5)   { return ENSOPhase.MODERATE_EL_NINO; };
    return ENSOPhase.STRONG_EL_NINO;
};

// ENSO forecast — simple linear trend extrapolation
function enso_warming_trend(oni_current: float, oni_prev_3mo: float) -> str {
    var trend: float = oni_current - oni_prev_3mo;
    if (trend > 0.2)  { return "warming_toward_el_nino"; };
    if (trend < -0.2) { return "cooling_toward_la_nina"; };
    return "stable";
};

// ENSO strength description
function enso_strength(oni_value: float) -> str {
    var abs_oni: float = oni_value;
    if (abs_oni < 0.0) { abs_oni = abs_oni * -1.0; };
    if (abs_oni < 0.5)  { return "weak"; };
    if (abs_oni < 1.0)  { return "moderate"; };
    if (abs_oni < 1.5)  { return "strong"; };
    return "very_strong";
};

// ════════════════════════════════════════════════════
// IOD — Indian Ocean Dipole
// ════════════════════════════════════════════════════

// DMI — Dipole Mode Index
// Difference of SST anomalies between western and eastern Indian Ocean
function iod_phase(dmi_value: float) -> IODPhase {
    if (dmi_value <= -1.0)  { return IODPhase.STRONG_NEGATIVE; };
    if (dmi_value <= -0.4)  { return IODPhase.WEAK_NEGATIVE; };
    if (dmi_value < 0.4)    { return IODPhase.NEUTRAL; };
    if (dmi_value < 1.0)    { return IODPhase.WEAK_POSITIVE; };
    return IODPhase.STRONG_POSITIVE;
};

// IOD regional impacts — simplistic
function iod_monsoon_impact(dmi_value: float) -> str {
    if (dmi_value > 0.5)  { return "wet_east_africa_dry_indonesia"; };
    if (dmi_value < -0.5) { return "dry_east_africa_wet_indonesia"; };
    return "near_normal";
};

// ════════════════════════════════════════════════════
// Pacific Decadal Oscillation
// ════════════════════════════════════════════════════

// PDO — Pacific Decadal Oscillation (multidecadal SST pattern)
function pdo_phase(pdo_index: float) -> str {
    if (pdo_index > 0.5)   { return "warm_phase"; };
    if (pdo_index < -0.5)  { return "cool_phase"; };
    return "neutral";
};

// PDO impacts on Pacific climate
function pdo_climate_impact(pdo_index: float) -> str {
    if (pdo_index > 0.5)   { return "warm_north_pacific_cool_west_coast"; };
    if (pdo_index < -0.5)  { return "cool_north_pacific_wet_west_coast"; };
    return "minimal";
};

// ════════════════════════════════════════════════════
// Atlantic Multidecadal Oscillation
// ════════════════════════════════════════════════════

// AMO — Atlantic Multidecadal Oscillation (Atlantic basin SST anomaly)
function amo_phase(amo_index: float) -> str {
    if (amo_index > 0.2)   { return "warm_phase"; };
    if (amo_index < -0.2)  { return "cool_phase"; };
    return "neutral";
};

// AMO hurricane influence
function amo_hurricane_activity(amo_index: float) -> str {
    if (amo_index > 0.3)   { return "enhanced_hurricane_activity"; };
    if (amo_index < -0.3)  { return "suppressed_hurricane_activity"; };
    return "near_climatological";
};

// ════════════════════════════════════════════════════
// North Atlantic Oscillation
// ════════════════════════════════════════════════════

// NAO — North Atlantic Oscillation (SLP pattern)
function nao_phase(nao_index: float) -> str {
    if (nao_index > 0.5)   { return "positive_phase"; };
    if (nao_index < -0.5)  { return "negative_phase"; };
    return "neutral";
};

// NAO European climate impacts
function nao_european_impact(nao_index: float) -> str {
    if (nao_index > 0.5) {
        return "warm_wet_north_europe_cold_dry_south";
    };
    if (nao_index < -0.5) {
        return "cold_wet_south_europe_warm_north";
    };
    return "near_normal_pattern";
};

// NAO Atlantic storminess
function nao_storminess(nao_index: float) -> str {
    if (nao_index > 0.5)   { return "enhanced_atlantic_storms"; };
    if (nao_index < -0.5)  { return "suppressed_atlantic_storms"; };
    return "normal_frequency";
};

// ════════════════════════════════════════════════════
// Southern Annular Mode
// ════════════════════════════════════════════════════

// SAM — Southern Annular Mode / Antarctic Oscillation
function sam_phase(sam_index: float) -> str {
    if (sam_index > 0.5)   { return "positive_phase"; };
    if (sam_index < -0.5)  { return "negative_phase"; };
    return "neutral";
};

// SAM Southern Hemisphere impacts
function sam_sh_impact(sam_index: float) -> str {
    if (sam_index > 0.5) {
        return "stronger_westerlies_cooler_antarctica_warmer_mid_lats";
    };
    if (sam_index < -0.5) {
        return "weaker_westerlies_warm_antarctica_cool_mid_lats";
    };
    return "near_normal";
};

// ════════════════════════════════════════════════════
// CYCLONE INTENSITY SCALES
// ════════════════════════════════════════════════════

// ── Saffir-Simpson Scale (Atlantic, Eastern Pacific) ──

function saffir_simpson_category(wind_kmh: float) -> CycloneScale {
    validate_wind_kmh(wind_kmh);
    var cat: int = c_saffir_simpson(wind_kmh);
    if (cat == 0) { return CycloneScale.TROPICAL_DEPRESSION; };
    if (cat == 1) { return CycloneScale.CATEGORY_1; };
    if (cat == 2) { return CycloneScale.CATEGORY_2; };
    if (cat == 3) { return CycloneScale.CATEGORY_3; };
    if (cat == 4) { return CycloneScale.CATEGORY_4; };
    return CycloneScale.CATEGORY_5;
};

function saffir_simpson_category_knots(wind_knots: float) -> CycloneScale {
    return saffir_simpson_category(knots_to_kmh(wind_knots));
};

function saffir_simpson_description(wind_kmh: float) -> str {
    validate_wind_kmh(wind_kmh);
    if (wind_kmh < 63.0)   { return "tropical_depression_or_storm"; };
    if (wind_kmh < 119.0)  { return "Category_1_minimal_damage"; };
    if (wind_kmh < 154.0)  { return "Category_2_moderate_damage"; };
    if (wind_kmh < 177.0)  { return "Category_3_extensive_damage"; };
    if (wind_kmh < 209.0)  { return "Category_4_extreme_damage"; };
    return "Category_5_catastrophic_damage";
};

// Saffir-Simpson damage potential
function saffir_simpson_damage_rating(wind_kmh: float) -> int {
    validate_wind_kmh(wind_kmh);
    var cat: int = c_saffir_simpson(wind_kmh);
    return cat;
};

// ── JMA Typhoon Scale (Western Pacific) ──

function jma_typhoon_category(wind_kmh: float) -> CycloneScale {
    validate_wind_kmh(wind_kmh);
    var cat: int = c_jma_category(wind_kmh);
    if (cat == 0) { return CycloneScale.TROPICAL_DEPRESSION; };
    if (cat == 1) { return CycloneScale.TROPICAL_STORM; };
    if (cat == 2) { return CycloneScale.CATEGORY_1; };
    if (cat == 3) { return CycloneScale.CATEGORY_2; };
    if (cat == 4) { return CycloneScale.CATEGORY_3; };
    return CycloneScale.CATEGORY_5;
};

function jma_description(wind_kmh: float) -> str {
    validate_wind_kmh(wind_kmh);
    if (wind_kmh < 63.0)   { return "tropical_depression"; };
    if (wind_kmh < 88.0)   { return "tropical_storm"; };
    if (wind_kmh < 118.0)  { return "strong_tropical_storm"; };
    if (wind_kmh < 150.0)  { return "typhoon"; };
    if (wind_kmh < 180.0)  { return "strong_typhoon"; };
    return "very_strong_typhoon";
};

// ── IMD Scale (Indian Ocean) ──

function imd_cyclone_category(wind_kmh: float) -> CycloneScale {
    validate_wind_kmh(wind_kmh);
    var cat: int = c_imd_category(wind_kmh);
    if (cat == 0) { return CycloneScale.TROPICAL_DEPRESSION; };
    if (cat == 1) { return CycloneScale.TROPICAL_STORM; };
    if (cat == 2) { return CycloneScale.CATEGORY_1; };
    if (cat == 3) { return CycloneScale.CATEGORY_2; };
    if (cat == 4) { return CycloneScale.CATEGORY_3; };
    return CycloneScale.CATEGORY_5;
};

function imd_description(wind_kmh: float) -> str {
    validate_wind_kmh(wind_kmh);
    if (wind_kmh < 63.0)   { return "depression"; };
    if (wind_kmh < 89.0)   { return "deep_depression"; };
    if (wind_kmh < 119.0)  { return "cyclonic_storm"; };
    if (wind_kmh < 150.0)  { return "severe_cyclonic_storm"; };
    if (wind_kmh < 180.0)  { return "very_severe_cyclonic_storm"; };
    return "super_cyclonic_storm";
};

// ── Universal cyclone comparison ──

// Is this cyclone major? (Cat 3+ in any scale)
function is_major_cyclone(wind_kmh: float) -> bool {
    validate_wind_kmh(wind_kmh);
    return wind_kmh >= 150.0;
};

// Is this cyclone catastrophic? (Cat 4+ Saffir-Simpson)
function is_catastrophic_cyclone(wind_kmh: float) -> bool {
    validate_wind_kmh(wind_kmh);
    return wind_kmh >= 209.0;
};

// Sustained wind damage threshold (>= threshold = expected structural damage)
function is_damaging_wind(wind_kmh: float) -> bool {
    validate_wind_kmh(wind_kmh);
    return wind_kmh >= 119.0;
};

// Storm surge risk from pressure and cyclone category
function surge_risk(min_pressure_mb: float, wind_kmh: float) -> str {
    validate_pressure_mb(min_pressure_mb);
    var cat: int = c_saffir_simpson(wind_kmh);
    if (min_pressure_mb >= 960.0) { return "1_to_2_feet"; };
    if (min_pressure_mb >= 945.0) { return "4_to_5_feet"; };
    if (min_pressure_mb >= 930.0) { return "6_to_8_feet"; };
    if (min_pressure_mb >= 915.0) { return "9_to_12_feet"; };
    if (min_pressure_mb >= 900.0) { return "13_to_18_feet"; };
    return "above_18_feet";
};