from "mocha-meteoro" import *;

function main(didLoad) -> null {

    print("=== mocha-metero STRESS TEST (Edge Cases & Cross-Checks) ===", newLine=true);
    print("", newLine=true);

    // ============================================================
    // STRESS 1 — THERMODYNAMICS CONSISTENCY
    // ============================================================
    print("STRESS 1 — THERMODYNAMICS CONSISTENCY", newLine=true);
    
    // If we know Td and T, we can back-calculate RH
    // Then recalculate Td from that RH — should match original
    var t: float = 25.0;
    var td_orig: float = 15.0;
    var rh_calc: float = rh_from_dewpoint(t, td_orig);
    var td_recalc: float = dewpoint(t, rh_calc);
    print("T=25C, Td=15C → RH=", newLine=true);
    print(rh_calc, newLine=true);
    print("% → Td_recalc=", newLine=true);
    print(td_recalc, newLine=true);
    print(" (expect ≈15C)", newLine=true);
    
    // Humidex should always be >= T
    var t_humid: float = 30.0;
    var td_humid: float = 25.0;
    var h: float = humidex(t_humid, td_humid);
    print("T=30C, Td=25C: Humidex=", newLine=true);
    print(h, newLine=true);
    if (h >= t_humid) {
        print(" ✓ (>= T as expected)", newLine=true);
    };
    if (h < t_humid) {
        print(" ✗ ERROR: Humidex < T!", newLine=true);
    };
    
    // Feels like should be between wind chill and heat index bounds
    var fl: float = feels_like(t_humid, 70.0, 15.0);
    print("Feels Like=", newLine=true);
    print(fl, newLine=true);
    print(" (check reasonableness)", newLine=true);
    print("", newLine=true);

    // ============================================================
    // STRESS 2 — PRESSURE/ALTITUDE INVERSIONS
    // ============================================================
    print("STRESS 2 — PRESSURE/ALTITUDE CONSISTENCY", newLine=true);
    
    // Forward and backward should match: P(h) then h(P) → h
    var h_orig: float = 500.0;
    var t_std: float = 15.0;
    var p_calc: float = pressure_at_altitude(1013.25, h_orig, t_std);
    var h_recalc: float = altitude_from_pressure(p_calc, 1013.25, t_std);
    print("Altitude 2500m → P=", newLine=true);
    print(p_calc, newLine=true);
    print("mb → h_recalc=", newLine=true);
    print(h_recalc, newLine=true);
    print(" (expect ≈2500)", newLine=true);
    
    // Density altitude should be >= pressure altitude for warm temps
    var p_alt: float = pressure_altitude(950.0);
    var da: float = density_altitude(950.0, 25.0);
    print("PA=", newLine=true);
    print(p_alt, newLine=true);
    print("m, DA=", newLine=true);
    print(da, newLine=true);
    if (da >= p_alt) {
        print(" ✓ (DA >= PA as expected for warm)", newLine=true);
    };
    print("", newLine=true);

    // ============================================================
    // STRESS 3 — WIND COMPONENT CONSISTENCY
    // ============================================================
    print("STRESS 3 — WIND COMPONENTS (decomposition & recomposition)", newLine=true);
    
    // Decompose wind, then recompose → should match original
    var speed_orig: float = 20.0;
    var dir_orig: float = 225.0;  // SW
    var u: float = wind_u(speed_orig, dir_orig);
    var v: float = wind_v(speed_orig, dir_orig);
    var speed_recalc: float = wind_speed_from_uv(u, v);
    var dir_recalc: float = wind_dir_from_uv(u, v);
    print("Wind 20 km/h from 225° → u=", newLine=true);
    print(u, newLine=true);
    print(" v=", newLine=true);
    print(v, newLine=true);
    print(" → speed=", newLine=true);
    print(speed_recalc, newLine=true);
    print(" dir=", newLine=true);
    print(dir_recalc, newLine=true);
    print(" (expect 20, 225)", newLine=true);
    
    // Opposite wind direction
    var opp_dir: float = opposite_direction(45.0);
    print("Opposite of 45° = ", newLine=true);
    print(opp_dir, newLine=true);
    print(" (expect 225°)", newLine=true);
    print("", newLine=true);

    // ============================================================
    // STRESS 4 — PRECIPITATION MASS BALANCE
    // ============================================================
    print("STRESS 4 — PRECIPITATION (Snow water equiv consistency)", newLine=true);
    
    // Rain → Snow → Back to water equiv should match original
    var rain_mm: float = 50.0;
    var temp_snow: float = -8.0;
    var snow_depth: float = rain_to_snowfall_depth(rain_mm, temp_snow);
    var density_est: float = snow_density(temp_snow);
    var swe_back: float = snow_water_equivalent(snow_depth, density_est);
    print("50mm rain @ -8C → ", newLine=true);
    print(snow_depth, newLine=true);
    print(" cm snow @ density=", newLine=true);
    print(density_est, newLine=true);
    print(" kg/m³ → SWE=", newLine=true);
    print(swe_back, newLine=true);
    print("mm (expect ≈50)", newLine=true);
    print("", newLine=true);

    // ============================================================
    // STRESS 5 — SOLAR GEOMETRY SYMMETRY
    // ============================================================
    print("STRESS 5 — SOLAR GEOMETRY (Equinox symmetry)", newLine=true);
    
    // At equinox, sunrise/sunset should be symmetric around solar noon
    var lat_eq: float = 0.0;  // Equator
    var lon_test: float = 0.0;
    var doy_vernal: int = 80;  // ~March 21
    var sunrise_eq: float = sunrise_utc(lat_eq, lon_test, doy_vernal);
    var sunset_eq: float = sunset_utc(lat_eq, lon_test, doy_vernal);
    var solar_noon: float = solar_noon_utc(lon_test, doy_vernal);
    var time_before_noon: float = solar_noon - sunrise_eq;
    var time_after_noon: float = sunset_eq - solar_noon;
    print("Vernal equinox at equator: sunrise=", newLine=true);
    print(sunrise_eq, newLine=true);
    print(" noon=", newLine=true);
    print(solar_noon, newLine=true);
    print(" sunset=", newLine=true);
    print(sunset_eq, newLine=true);
    print("Time before noon=", newLine=true);
    print(time_before_noon, newLine=true);
    print(" after=", newLine=true);
    print(time_after_noon, newLine=true);
    print(" (expect ≈equal)", newLine=true);
    
    // Daylight hours at equinox should ≈12h
    var dl_eq: float = daylight_hours(lat_eq, doy_vernal);
    print("Daylight hours: ", newLine=true);
    print(dl_eq, newLine=true);
    print("h (expect ≈12)", newLine=true);
    print("", newLine=true);

    // ============================================================
    // STRESS 6 — AQI SUB-INDEX MONOTONICITY
    // ============================================================
    print("STRESS 6 — AQI (Monotonicity & Max function)", newLine=true);
    
    // AQI sub-indices should be monotonically increasing with pollutant
    var aqi_pm25_low: float = aqi_pm25_subindex(20.0);
    var aqi_pm25_mid: float = aqi_pm25_subindex(60.0);
    var aqi_pm25_high: float = aqi_pm25_subindex(150.0);
    print("PM2.5: 20µg=", newLine=true);
    print(aqi_pm25_low, newLine=true);
    print(" 60µg=", newLine=true);
    print(aqi_pm25_mid, newLine=true);
    print(" 150µg=", newLine=true);
    print(aqi_pm25_high, newLine=true);
    if (aqi_pm25_low < aqi_pm25_mid && aqi_pm25_mid < aqi_pm25_high) {
        print(" ✓ (monotonic)", newLine=true);
    };
    
    // AQI should equal max of all sub-indices
    var test_pm25: float = 100.0;
    var test_pm10: float = 80.0;
    var test_no2: float = 50.0;
    var test_so2: float = 40.0;
    var test_o3: float = 70.0;
    var test_co: float = 2.5;
    var aqi_test: float = aqi_indian(test_pm25, test_pm10, test_no2, test_so2, test_o3, test_co);
    var sub_pm25: float = aqi_pm25_subindex(test_pm25);
    print("Composite AQI=", newLine=true);
    print(aqi_test, newLine=true);
    print(" vs PM2.5 sub=", newLine=true);
    print(sub_pm25, newLine=true);
    print(" (AQI should be max)", newLine=true);
    print("", newLine=true);

    // ============================================================
    // STRESS 7 — CLIMATE STATS ACCUMULATION
    // ============================================================
    print("STRESS 7 — CLIMATE STATS (Array accumulation)", newLine=true);
    
    // Accumulate HDD over 5 days, should match manual sum
    var t_array: float[] = [];
    t_array.push(15.0);  // HDD=3
    t_array.push(16.0);  // HDD=2
    t_array.push(12.0);  // HDD=6
    t_array.push(18.0);  // HDD=0
    t_array.push(14.0);  // HDD=4
    var hdd_accum: float = accumulated_hdd(t_array, 18.0);
    print("HDD sum over [15,16,12,18,14]C = ", newLine=true);
    print(hdd_accum, newLine=true);
    print(" (expect 3+2+6+0+4=15)", newLine=true);
    
    // Frost days count
    var t_frost: float[] = [];
    t_frost.push(-2.0);  // frost
    t_frost.push(1.0);   // no frost
    t_frost.push(-5.0);  // frost
    t_frost.push(3.0);   // no frost
    t_frost.push(0.0);   // frost
    var frost_count: int = frost_days(t_frost);
    print("Frost days in [-2,1,-5,3,0]: ", newLine=true);
    print(frost_count, newLine=true);
    print(" (expect 2)", newLine=true);
    print("", newLine=true);

   // ============================================================
    // STRESS 8 — CYCLONE SCALE CONSISTENCY
    // ============================================================
    print("STRESS 8 — CYCLONE SCALES (Cross-system consistency)", newLine=true);
    
    // Same wind speed across three scales
    var test_wind: float = 130.0;  // Should be Cat1-2 range
    var ss: CycloneScale = saffir_simpson_category(test_wind);
    var jma: CycloneScale = jma_typhoon_category(test_wind);
    var imd: CycloneScale = imd_cyclone_category(test_wind);
    print("Wind 130 km/h: S-S category, JMA category, IMD category", newLine=true);
    print("(should be roughly equivalent severity)", newLine=true);
    print("", newLine=true);

    // ============================================================
    // STRESS 9 — BOUNDARY CONDITIONS
    // ============================================================
    print("STRESS 9 — BOUNDARY CONDITIONS", newLine=true);
    
    // Zero humidity edge case
    var td_zero: float = dewpoint(25.0, 1.0);  // Very dry
    print("T=25C, RH=1%: Td=", newLine=true);
    print(td_zero, newLine=true);
    print(" (should be << 25)", newLine=true);
    
    // 100% humidity (saturation)
    var td_sat: float = dewpoint(25.0, 100.0);
    print("T=25C, RH=100%: Td=", newLine=true);
    print(td_sat, newLine=true);
    print(" (expect ≈25)", newLine=true);
    
    // Freezing point transitions
    var ice_day_count: int = ice_days([-5.0, -1.0, 0.0, 1.0, -2.0]);
    print("Ice days (Tmax<0) in [-5,-1,0,1,-2]: ", newLine=true);
    print(ice_day_count, newLine=true);
    print(" (expect 3)", newLine=true);
    print("", newLine=true);

    print("=== STRESS TEST COMPLETE ===", newLine=true);

};