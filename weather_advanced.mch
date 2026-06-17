from "mocha-meteoro" import *;

function main(didLoad) -> null {

    print("=== mocha-metero ADVANCED TEST SUITE ===", newLine=true);
    print("Complex interactions, real soundings, extreme ranges", newLine=true);
    print("", newLine=true);

    // ============================================================
    // ADVANCED 1 — CAPE/CIN FROM REAL TROPICAL SOUNDING
    // ============================================================
    print("ADVANCED 1 — CAPE/CIN (Tropical Sounding)", newLine=true);
    
    // Typical tropical sounding: unstable layer near surface
    var p_levels: float[] = [];
    var t_levels: float[] = [];
    var td_levels: float[] = [];
    
    p_levels.push(1000.0);   t_levels.push(28.0);   td_levels.push(24.0);  // surface: moist
    p_levels.push(950.0);    t_levels.push(26.5);   td_levels.push(22.5);
    p_levels.push(900.0);    t_levels.push(24.0);   td_levels.push(20.0);
    p_levels.push(850.0);    t_levels.push(21.0);   td_levels.push(17.5);
    p_levels.push(800.0);    t_levels.push(17.5);   td_levels.push(14.0);
    p_levels.push(700.0);    t_levels.push(10.0);   td_levels.push(7.0);   // dry aloft
    p_levels.push(600.0);    t_levels.push(1.0);    td_levels.push(-2.0);
    p_levels.push(500.0);    t_levels.push(-10.0);  td_levels.push(-12.0);
    
    var cape_cin_arr: float[] = cape_cin(p_levels, t_levels, td_levels);
    var cape_val: float = cape_cin_arr[0];
    var cin_val: float = cape_cin_arr[1];
    var lfc_mb: float = cape_cin_arr[2];
    var el_mb: float = cape_cin_arr[3];
    
    print("Tropical sounding:", newLine=true);
    print("  CAPE = ", newLine=false);
    print(cape_val, newLine=false);
    print(" J/kg (expect >1500 for tropical)", newLine=true);
    print("  CIN = ", newLine=false);
    print(cin_val, newLine=false);
    print(" J/kg (expect <0, typical -50 to -100)", newLine=true);
    print("  LFC = ", newLine=false);
    print(lfc_mb, newLine=false);
    print(" mb, EL = ", newLine=false);
    print(el_mb, newLine=false);
    print(" mb", newLine=true);
    
    var cape_sev: SevereWeatherRisk = cape_severity(cape_val);
    print("  Severity: ", newLine=false);
    if (cape_val > 2000.0) {
        print("Enhanced/Moderate (supercell capable)", newLine=true);
    };
    print("", newLine=true);

    // ============================================================
    // ADVANCED 2 — SEVERE WEATHER COMPOSITE
    // ============================================================
    print("ADVANCED 2 — COMPOSITE SEVERE WEATHER ASSESSMENT", newLine=true);
    
    // Supercell environment: high CAPE, strong shear, high SRH
    var cape_test: float = 3500.0;
    var srh_test: float = 320.0;
    var shear_test: float = 18.0;  // m/s bulk shear
    var ehi: float = energy_helicity_index(cape_test, srh_test);
    var scp: float = supercell_composite(cape_test, srh_test, shear_test);
    var brn: float = bulk_richardson_number(cape_test, shear_test);
    var brn_type: str = brn_storm_type(brn);
    
    print("CAPE=3500, SRH=320, Shear=18m/s:", newLine=true);
    print("  EHI = ", newLine=false);
    print(ehi, newLine=false);
    print(" (>2 = significant tornado threat)", newLine=true);
    print("  SCP = ", newLine=false);
    print(scp, newLine=false);
    print(" (>8 = moderate supercell)", newLine=true);
    print("  BRN = ", newLine=false);
    print(brn, newLine=false);
    print(" → ", newLine=false);
    print(brn_type, newLine=true);
    print("", newLine=true);

    // ============================================================
    // ADVANCED 3 — LIFTED INDEX vs CAPE CORRELATION
    // ============================================================
    print("ADVANCED 3 — LIFTED INDEX vs CAPE COMPARISON", newLine=true);
    
    // Both should indicate instability but from different reference levels
    var li_vals: float[] = [];
    var li_test_1: float = lifted_index(28.0, 24.0, 1000.0, 15.0);
    var li_test_2: float = lifted_index(25.0, 20.0, 950.0, 10.0);
    var li_test_3: float = lifted_index(22.0, 16.0, 900.0, 5.0);
    
    print("Lifted Index progression (should become more negative aloft):", newLine=true);
    print("  Surface parcel → 500mb: LI = ", newLine=false);
    print(li_test_1, newLine=true);
    print("  950mb parcel → 500mb: LI = ", newLine=false);
    print(li_test_2, newLine=true);
    print("  900mb parcel → 500mb: LI = ", newLine=false);
    print(li_test_3, newLine=true);
    print("", newLine=true);

    // ============================================================
    // ADVANCED 4 — ENSO/IOD/NAO PHASE INTERACTIONS
    // ============================================================
    print("ADVANCED 4 — LARGE-SCALE PATTERN INTERACTIONS", newLine=true);
    
    // El Niño + Positive IOD + Negative NAO scenario
    var oni_strong_el: float = 1.8;
    var dmi_strong_pos: float = 1.2;
    var nao_neg: float = -0.8;
    var sam_pos: float = 0.6;
    
    var enso_phase: ENSOPhase = oni_phase(oni_strong_el);
    var iod_phase_val: IODPhase = iod_phase(dmi_strong_pos);
    
    print("Scenario: Strong El Niño + Positive IOD + Negative NAO + Positive SAM", newLine=true);
    print("  ONI=1.8 → Strong El Niño", newLine=true);
    print("  DMI=1.2 → Strong Positive IOD", newLine=true);
    print("  NAO=-0.8 → Negative phase", newLine=true);
    print("  SAM=0.6 → Positive phase", newLine=true);
    
    var iod_impact: str = iod_monsoon_impact(dmi_strong_pos);
    var nao_impact: str = nao_european_impact(nao_neg);
    var sam_impact: str = sam_sh_impact(sam_pos);
    
    print("  IOD impact: ", newLine=false);
    print(iod_impact, newLine=true);
    print("  NAO impact: ", newLine=false);
    print(nao_impact, newLine=true);
    print("  SAM impact: ", newLine=false);
    print(sam_impact, newLine=true);
    print("", newLine=true);

    // ============================================================
    // ADVANCED 5 — EXTREME TEMPERATURE ANOMALIES
    // ============================================================
    print("ADVANCED 5 — TEMPERATURE ANOMALY EXTREMES", newLine=true);
    
    // Create a 30-year climatology, then check modern obs
    var clim_temps: float[] = [];
    var i: int = 0;
    while (i < 30) {
        clim_temps.push(15.0 + i * 0.2);  // 15 to 21C range
        i = i + 1;
    };
    
    var obs_normal: float = 17.5;
    var obs_warm: float = 25.0;
    var obs_cold: float = 5.0;
    
    var anom_normal: float = temp_anomaly(obs_normal, 18.0);
    var anom_warm: float = temp_anomaly(obs_warm, 18.0);
    var pctl_warm: float = percentile_rank(obs_warm, clim_temps);
    var pctl_cold: float = percentile_rank(obs_cold, clim_temps);
    
    print("30-year climatology: 15-21C", newLine=true);
    print("  Normal obs 17.5C: anomaly = ", newLine=false);
    print(anom_normal, newLine=true);
    print("  Warm obs 25C: anomaly = ", newLine=false);
    print(anom_warm, newLine=false);
    print("C, percentile = ", newLine=false);
    print(pctl_warm, newLine=false);
    print("% (extreme)", newLine=true);
    print("  Cold obs 5C: percentile = ", newLine=false);
    print(pctl_cold, newLine=false);
    print("% (extreme)", newLine=true);
    print("", newLine=true);

    // ============================================================
    // ADVANCED 6 — VISIBILITY-AQI RELATIONSHIP
    // ============================================================
    print("ADVANCED 6 — VISIBILITY DEGRADATION FROM POLLUTION", newLine=true);
    
    // Clear baseline visibility, then add pollution
    var vis_baseline_km: float = 15.0;  // 15km clear day
    var pm25_array: float[] = [];
    pm25_array.push(15.0);   // Good
    pm25_array.push(45.0);   // Moderate
    pm25_array.push(85.0);   // Poor
    pm25_array.push(150.0);  // Severe
    pm25_array.push(250.0);  // Hazardous
    
    var j: int = 0;
    while (j < pm25_array.length) {
        var vis_impaired: float = estimated_visibility_pm25(pm25_array[j], vis_baseline_km);
        var aqi_cat: AQICategory = aqi_category(aqi_pm25_subindex(pm25_array[j]));
        print("PM2.5=", newLine=false);
        print(pm25_array[j], newLine=false);
        print("µg/m³ → Visibility=", newLine=false);
        print(vis_impaired, newLine=false);
        print("km (baseline 15km)", newLine=true);
        j = j + 1;
    };
    print("", newLine=true);

    // ============================================================
    // ADVANCED 7 — CYCLONE DAMAGE SCALING
    // ============================================================
    print("ADVANCED 7 — CYCLONE INTENSITY vs DAMAGE POTENTIAL", newLine=true);
    
    // Wind speed increases, damage scales nonlinearly
    var wind_test_array: float[] = [];
    wind_test_array.push(80.0);    // TD/TS
    wind_test_array.push(120.0);   // Cat 1
    wind_test_array.push(160.0);   // Cat 3
    wind_test_array.push(210.0);   // Cat 5
    
    var k: int = 0;
    while (k < wind_test_array.length) {
        var wind_test_val: float = wind_test_array[k];
        var ss_cat_test: CycloneScale = saffir_simpson_category(wind_test_val);
        var damage_desc: str = saffir_simpson_description(wind_test_val);
        var surge_80: str = surge_risk(960.0, 80.0);    // Weak system
        var surge_120: str = surge_risk(945.0, 120.0);  // Cat 1
        var surge_160: str = surge_risk(930.0, 160.0);  // Cat 3
        var surge_210: str = surge_risk(905.0, 210.0);  // Cat 5
        print("Surge 80kmh/960mb: ", newLine=false);
        print(surge_80, newLine=true);
        print("Surge 120kmh/945mb: ", newLine=false);
        print(surge_120, newLine=true);
        print("Surge 160kmh/930mb: ", newLine=false);
        print(surge_160, newLine=true);
        print("Surge 210kmh/905mb: ", newLine=false);
        print(surge_210, newLine=true);
        k = k + 1;
    };
    print("", newLine=true);

    // ============================================================
    // ADVANCED 8 — MULTI-DAY CLIMATE ACCUMULATION
    // ============================================================
    print("ADVANCED 8 — CLIMATE INDICES OVER 10-DAY PERIOD", newLine=true);
    
    // Simulate a weather event: cold snap, then warm recovery
    var t_max_10day: float[] = [];
    var t_min_10day: float[] = [];
    var precip_10day: float[] = [];
    
    t_max_10day.push(12.0);  t_min_10day.push(5.0);   precip_10day.push(0.0);
    t_max_10day.push(8.0);   t_min_10day.push(-2.0);  precip_10day.push(2.5);
    t_max_10day.push(5.0);   t_min_10day.push(-5.0);  precip_10day.push(5.0);
    t_max_10day.push(10.0);  t_min_10day.push(0.0);   precip_10day.push(1.0);
    t_max_10day.push(18.0);  t_min_10day.push(8.0);   precip_10day.push(0.0);
    t_max_10day.push(22.0);  t_min_10day.push(12.0);  precip_10day.push(0.0);
    t_max_10day.push(25.0);  t_min_10day.push(14.0);  precip_10day.push(0.0);
    t_max_10day.push(23.0);  t_min_10day.push(13.0);  precip_10day.push(3.0);
    t_max_10day.push(20.0);  t_min_10day.push(10.0);  precip_10day.push(8.5);
    t_max_10day.push(16.0);  t_min_10day.push(8.0);   precip_10day.push(0.5);
    
    var hdd_10day: float = accumulated_hdd(t_max_10day, 18.0);
    var cdd_10day: float = accumulated_cdd(t_max_10day, 18.0);
    var frost_10day: int = frost_days(t_min_10day);
    var precip_total: float = 0.0;
    var m: int = 0;
    while (m < precip_10day.length) {
        precip_total = precip_total + precip_10day[m];
        m = m + 1;
    };
    var cdd_days: int = consecutive_dry_days(precip_10day, 0.1);
    var wet_days: int = heavy_precip_days(precip_10day);
    
    print("10-day weather event:", newLine=true);
    print("  HDD = ", newLine=false);
    print(hdd_10day, newLine=false);
    print(" (cold snap impact)", newLine=true);
    print("  CDD = ", newLine=false);
    print(cdd_10day, newLine=false);
    print(" (warming period)", newLine=true);
    print("  Frost days = ", newLine=false);
    print(frost_10day, newLine=true);
    print("  Total precip = ", newLine=false);
    print(precip_total, newLine=false);
    print("mm", newLine=true);
    print("  Consecutive dry days = ", newLine=false);
    print(cdd_days, newLine=true);
    print("  Heavy precip days (>10mm) = ", newLine=false);
    print(wet_days, newLine=true);
    print("", newLine=true);

    // ============================================================
    // ADVANCED 9 — ATMOSPHERIC MIXING & DISPERSION
    // ============================================================
    print("ADVANCED 9 — ATMOSPHERIC MIXING LAYER", newLine=true);
    
    // Morning: surface 18C, inversion base at 300m is 16C → weak mixing
    var md_morning: float = mixing_depth(18.0, 16.0, 300.0);
    var vi_morning: float = ventilation_index(md_morning, 2.0);
    print("Morning (weak): MD=", newLine=false);
    print(md_morning, newLine=false);
    print("m, VI=", newLine=false);
    print(vi_morning, newLine=true);
    
    // Afternoon: surface 28C, inversion base at 1500m is 12C → strong mixing
    var md_afternoon: float = mixing_depth(28.0, 12.0, 1500.0);
    var vi_afternoon: float = ventilation_index(md_afternoon, 8.0);
    print("Afternoon (strong): MD=", newLine=false);
    print(md_afternoon, newLine=false);
    print("m, VI=", newLine=false);
    print(vi_afternoon, newLine=true);
    print("", newLine=true);

    // ============================================================
    // ADVANCED 10 — EXTREME RANGE VALIDATION
    // ============================================================
    print("ADVANCED 10 — EXTREME & EDGE CASES", newLine=true);
    
    // Hottest: 54C (Death Valley record)
    var hot_extreme: float = humidex(54.0, 20.0);
    print("Hottest: T=54C, Td=20C → Humidex=", newLine=false);
    print(hot_extreme, newLine=true);
    
    // Coldest: -89C (Vostok)
    var cold_extreme: float = isa_temp(5000.0);  // Deep stratosphere
    print("ISA temp at very high altitude: ", newLine=false);
    print(cold_extreme, newLine=false);
    print("C", newLine=true);
    
    // Driest: RH=1%
    var dry_extreme: float = dewpoint(40.0, 1.0);
    print("Driest: T=40C, RH=1% → Td=", newLine=false);
    print(dry_extreme, newLine=true);
    
    // Wettest: RH=100%
    var wet_extreme: float = absolute_humidity(40.0, 100.0);
    print("Wettest: T=40C, RH=100% → AH=", newLine=false);
    print(wet_extreme, newLine=false);
    print("g/m³", newLine=true);
    
    // Strongest wind: Cat 5
    var strongest_wind: float = 250.0;
    var cat5_surge: str = surge_risk(880.0, strongest_wind);
    print("Catastrophic Cat 5: Wind=250km/h, Pressure=880mb → Surge: ", newLine=false);
    print(cat5_surge, newLine=true);
    print("", newLine=true);

    print("=== ADVANCED TEST SUITE COMPLETE ===", newLine=true);

};