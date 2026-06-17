from "mocha-meteoro" import *;

function main(didLoad) -> null {

    // ============================================================
    // SECTION 1 — THERMODYNAMICS
    // ============================================================
    print("=== SECTION 1 — THERMODYNAMICS ===", newLine=true);
    
    var t: float = 32.0;
    var rh: float = 65.0;
    var wind: float = 12.0;
    
    var hi: float = heat_index(t, rh);
    print("Temp: 32C, RH: 65%, Wind: 12 km/h", newLine=true);
    print("Heat Index: ", newLine=true);
    print(hi, newLine=true);
    
    var dewpt: float = dewpoint(t, rh);
    print("Dew Point: ", newLine=true);
    print(dewpt, newLine=true);
    
    var fl: float = feels_like(t, rh, wind);
    print("Feels Like: ", newLine=true);
    print(fl, newLine=true);
    print("", newLine=true);

    // ============================================================
    // SECTION 2 — HUMIDITY
    // ============================================================
    print("=== SECTION 2 — HUMIDITY ===", newLine=true);
    
    var vpd: float = vapour_pressure_deficit(t, rh);
    print("VPD: ", newLine=true);
    print(vpd, newLine=true);
    
    var ah: float = absolute_humidity(t, rh);
    print("Absolute Humidity: ", newLine=true);
    print(ah, newLine=true);
    
    var humidex_val: float = humidex(t, dewpt);
    print("Humidex: ", newLine=true);
    print(humidex_val, newLine=true);
    print("", newLine=true);

    // ============================================================
    // SECTION 3 — PRESSURE & ALTITUDE
    // ============================================================
    print("=== SECTION 3 — PRESSURE & ALTITUDE ===", newLine=true);
    
    var elevation: float = 1000.0;
    var p_sl: float = 1013.25;
    
    var p_at_alt: float = pressure_at_altitude(p_sl, elevation, t);
    print("Pressure at 1000m: ", newLine=true);
    print(p_at_alt, newLine=true);
    
    var da: float = density_altitude(p_at_alt, t);
    print("Density Altitude: ", newLine=true);
    print(da, newLine=true);
    
    var isa_t: float = isa_temp(elevation);
    print("ISA Temp at 1000m: ", newLine=true);
    print(isa_t, newLine=true);
    print("", newLine=true);

    // ============================================================
    // SECTION 4 — WIND
    // ============================================================
    print("=== SECTION 4 — WIND ===", newLine=true);
    
    var wind_dir: float = 180.0;
    var beaufort: int = beaufort_number(wind);
    print("Beaufort Scale: ", newLine=true);
    print(beaufort, newLine=true);
    
    var runway_dir: float = 270.0;
    var xwind: float = crosswind(wind, wind_dir, runway_dir);
    print("Crosswind on RWY 270°: ", newLine=true);
    print(xwind, newLine=true);
    
    var hwind: float = headwind(wind, wind_dir, runway_dir);
    print("Headwind: ", newLine=true);
    print(hwind, newLine=true);
    print("", newLine=true);

    // ============================================================
    // SECTION 5 — PRECIPITATION
    // ============================================================
    print("=== SECTION 5 — PRECIPITATION ===", newLine=true);
    
    var rain_rate: float = 15.0;
    var rain_intensity: RainfallIntensity = rainfall_intensity(rain_rate);
    print("Rain Rate: 15.0 mm/hr = heavy rainfall", newLine=true);
    
    var t_low: float = -5.0;
    var snow_equiv: float = rain_to_snowfall_depth(10.0, t_low);
    print("10mm rain at -5C → ", newLine=true);
    print(snow_equiv, newLine=true);
    print(" cm snow", newLine=true);
    print("", newLine=true);

    // ============================================================
    // SECTION 6 — SEVERE WEATHER
    // ============================================================
    print("=== SECTION 6 — SEVERE WEATHER INDICES ===", newLine=true);
    
    var li: float = lifted_index(t, dewpt, p_sl, 20.0);
    print("Lifted Index: ", newLine=true);
    print(li, newLine=true);
    
    var ki: float = k_index(25.0, 20.0, 15.0, 20.0, 18.0);
    print("K-Index: ", newLine=true);
    print(ki, newLine=true);
    
    var tt: float = total_totals(25.0, 20.0, 15.0);
    print("Total-Totals: ", newLine=true);
    print(tt, newLine=true);
    print("", newLine=true);

    // ============================================================
    // SECTION 7 — VISIBILITY, FOG & AIR QUALITY
    // ============================================================
    print("=== SECTION 7 — VISIBILITY, FOG & AIR QUALITY ===", newLine=true);
    
    var cloud_base: float = cloud_base_height(t, dewpt);
    print("Cloud Base: ", newLine=true);
    print(cloud_base, newLine=true);
    
    var fog_prob: float = fog_probability(t, dewpt, wind);
    print("Fog Probability: ", newLine=true);
    print(fog_prob, newLine=true);
    
    var pm25: float = 85.0;
    var aqi: float = aqi_indian(pm25, 120.0, 45.0, 25.0, 55.0, 1.2);
    print("Indian AQI: ", newLine=true);
    print(aqi, newLine=true);
    print("PM2.5: 85 µg/m³ (unhealthy)", newLine=true);
    print("", newLine=true);

    // ============================================================
    // SECTION 8 — SOLAR & RADIATION
    // ============================================================
    print("=== SECTION 8 — SOLAR & RADIATION ===", newLine=true);
    
    var lat: float = 28.6;
    var lon: float = 77.2;
    var doy: int = day_of_year(6, 17);
    
    var sunrise: float = sunrise_utc(lat, lon, doy);
    print("Sunrise (Delhi): ", newLine=true);
    print(sunrise, newLine=true);
    
    var sunset: float = sunset_utc(lat, lon, doy);
    print("Sunset: ", newLine=true);
    print(sunset, newLine=true);
    
    var daylight: float = daylight_hours(lat, doy);
    print("Daylight Hours: ", newLine=true);
    print(daylight, newLine=true);
    
    var uvi: float = uv_index(lat, doy, 12.0, 300.0);
    print("UV Index at noon: ", newLine=true);
    print(uvi, newLine=true);
    print("", newLine=true);

    // ============================================================
    // SECTION 9 — CLIMATE STATISTICS
    // ============================================================
    print("=== SECTION 9 — CLIMATE STATISTICS ===", newLine=true);
    
    var t_mean: float = 25.0;
    var hdd_val: float = hdd(15.0);
    print("HDD (base 18C) for 15C: ", newLine=true);
    print(hdd_val, newLine=true);
    
    var cdd_val: float = cdd(t_mean);
    print("CDD (base 18C) for 25C: ", newLine=true);
    print(cdd_val, newLine=true);
    
    var gdd_val: float = gdd(30.0, 20.0);
    print("GDD (base 10C, cap 30C): ", newLine=true);
    print(gdd_val, newLine=true);
    print("", newLine=true);

    // ============================================================
    // SECTION 10 — LARGE-SCALE INDICES & CYCLONES
    // ============================================================
    print("=== SECTION 10 — LARGE-SCALE INDICES & CYCLONES ===", newLine=true);
    
    var oni: float = 1.2;
    var enso_cat: ENSOPhase = oni_phase(oni);
    print("ONI: 1.2 → Moderate El Niño", newLine=true);
    
    var dmi: float = 0.65;
    var iod_cat: IODPhase = iod_phase(dmi);
    print("DMI: 0.65 → Positive IOD phase", newLine=true);
    
    var wind_cyclone: float = 165.0;
    var ss_cat: CycloneScale = saffir_simpson_category(wind_cyclone);
    print("Cyclone 165 km/h:", newLine=true);
    print("  Saffir-Simpson: Category 2", newLine=true);
    
    var jma_cat: CycloneScale = jma_typhoon_category(wind_cyclone);
    print("  JMA: Strong Typhoon", newLine=true);
    
    var imd_cat: CycloneScale = imd_cyclone_category(wind_cyclone);
    print("  IMD: Very Severe Cyclonic Storm", newLine=true);
    print("", newLine=true);

    print("=== All Tests Complete ===", newLine=true);
};