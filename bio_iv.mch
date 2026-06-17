from "mocha-bio" import *;

function main(didLoad) -> null {

    // ----- Basic Rate / Volume / Time -----

    // drip_rate_gtt_min: 500mL over 4hr, drop factor 20
    // = (500 * 20) / (4 * 60) = 10000 / 240 = 41.666...
    var drip1: float = drip_rate_gtt_min(500.0, 4.0, 20.0);
    if (drip1 > 41.6 && drip1 < 41.8) {
        print("PASS: drip_rate_gtt_min(500mL, 4hr, 20gtt) ~41.67 gtt/min", newLine=true);
    } else {
        print("FAIL: drip_rate_gtt_min(500mL, 4hr, 20gtt) ~41.67 gtt/min", newLine=true);
    };
    print("drip rate = ", newLine=false);
    print(drip1, newLine=true);

    // microdrip: 100mL over 1hr, drop factor 60
    // = (100 * 60) / (1 * 60) = 100 gtt/min
    var drip2: float = drip_rate_gtt_min(100.0, 1.0, 60.0);
    if (drip2 == 100.0) {
        print("PASS: drip_rate_gtt_min microdrip == 100 gtt/min", newLine=true);
    } else {
        print("FAIL: drip_rate_gtt_min microdrip == 100 gtt/min", newLine=true);
    };

    // infusion_time_hr: 1000mL at 125 mL/hr = 8hr
    var time1: float = infusion_time_hr(1_000.0, 125.0);
    if (time1 == 8.0) {
        print("PASS: infusion_time_hr(1000mL, 125mL/hr) == 8.0hr", newLine=true);
    } else {
        print("FAIL: infusion_time_hr(1000mL, 125mL/hr) == 8.0hr", newLine=true);
    };
    print("infusion time = ", newLine=false);
    print(time1, newLine=true);

    // volume_to_infuse: 100 mL/hr over 6hr = 600mL
    var vol1: float = volume_to_infuse(100.0, 6.0);
    if (vol1 == 600.0) {
        print("PASS: volume_to_infuse(100mL/hr, 6hr) == 600mL", newLine=true);
    } else {
        print("FAIL: volume_to_infuse(100mL/hr, 6hr) == 600mL", newLine=true);
    };

    // ----- Weight-Based Dosing -----

    // mcg_kg_min_to_ml_hr: norepinephrine 0.1 mcg/kg/min, 70kg, 4000 mcg/mL (4mg/250mL)
    // = (0.1 * 70 * 60) / 4000 = 420 / 4000 = 0.105 mL/hr
    var rate1: float = mcg_kg_min_to_ml_hr(0.1, 70.0, 4_000.0);
    if (rate1 > 0.104 && rate1 < 0.106) {
        print("PASS: mcg_kg_min_to_ml_hr(0.1, 70kg, 4000mcg/mL) ~0.105 mL/hr", newLine=true);
    } else {
        print("FAIL: mcg_kg_min_to_ml_hr(0.1, 70kg, 4000mcg/mL) ~0.105 mL/hr", newLine=true);
    };
    print("norepi rate = ", newLine=false);
    print(rate1, newLine=true);

    // ml_hr_to_mcg_kg_min: reverse of above — 0.105 mL/hr → ~0.1 mcg/kg/min
    var dose1: float = ml_hr_to_mcg_kg_min(0.105, 70.0, 4_000.0);
    if (dose1 > 0.099 && dose1 < 0.101) {
        print("PASS: ml_hr_to_mcg_kg_min(0.105, 70kg, 4000) ~0.1 mcg/kg/min", newLine=true);
    } else {
        print("FAIL: ml_hr_to_mcg_kg_min(0.105, 70kg, 4000) ~0.1 mcg/kg/min", newLine=true);
    };
    print("dose back-calc = ", newLine=false);
    print(dose1, newLine=true);

    // mg_hr_to_ml_hr: morphine 2 mg/hr, concentration 1 mg/mL = 2 mL/hr
    var rate2: float = mg_hr_to_ml_hr(2.0, 1.0);
    if (rate2 == 2.0) {
        print("PASS: mg_hr_to_ml_hr(2mg/hr, 1mg/mL) == 2.0 mL/hr", newLine=true);
    } else {
        print("FAIL: mg_hr_to_ml_hr(2mg/hr, 1mg/mL) == 2.0 mL/hr", newLine=true);
    };

    // ml_hr_to_mg_hr: reverse — 2 mL/hr at 1 mg/mL = 2 mg/hr
    var dose2: float = ml_hr_to_mg_hr(2.0, 1.0);
    if (dose2 == 2.0) {
        print("PASS: ml_hr_to_mg_hr(2mL/hr, 1mg/mL) == 2.0 mg/hr", newLine=true);
    } else {
        print("FAIL: ml_hr_to_mg_hr(2mL/hr, 1mg/mL) == 2.0 mg/hr", newLine=true);
    };

    // ----- Bolus -----

    // bolus_rate_ml_hr: 100mL over 30min = (100/30)*60 = 200 mL/hr
    var bolus1: float = bolus_rate_ml_hr(100.0, 30.0);
    if (bolus1 > 199.9 && bolus1 < 200.1) {
        print("PASS: bolus_rate_ml_hr(100mL, 30min) == 200 mL/hr", newLine=true);
    } else {
        print("FAIL: bolus_rate_ml_hr(100mL, 30min) == 200 mL/hr", newLine=true);
    };
    print("bolus rate = ", newLine=false);
    print(bolus1, newLine=true);

    // bolus 500mL over 60min = 500 mL/hr
    var bolus2: float = bolus_rate_ml_hr(500.0, 60.0);
    if (bolus2 > 499.9 && bolus2 < 500.1) {
        print("PASS: bolus_rate_ml_hr(500mL, 60min) == 500 mL/hr", newLine=true);
    } else {
        print("FAIL: bolus_rate_ml_hr(500mL, 60min) == 500 mL/hr", newLine=true);
    };

    // ----- Units/hr (heparin) -----

    // units_hr_to_ml_hr: heparin 1000 units/hr, concentration 25000 units/250mL = 100 units/mL
    // = 1000 / 100 = 10 mL/hr
    var hep1: float = units_hr_to_ml_hr(1_000.0, 100.0);
    if (hep1 == 10.0) {
        print("PASS: units_hr_to_ml_hr(1000u/hr, 100u/mL) == 10 mL/hr", newLine=true);
    } else {
        print("FAIL: units_hr_to_ml_hr(1000u/hr, 100u/mL) == 10 mL/hr", newLine=true);
    };
    print("heparin rate = ", newLine=false);
    print(hep1, newLine=true);

    // ml_hr_to_units_hr: reverse — 10 mL/hr at 100 units/mL = 1000 units/hr
    var hep2: float = ml_hr_to_units_hr(10.0, 100.0);
    if (hep2 == 1_000.0) {
        print("PASS: ml_hr_to_units_hr(10mL/hr, 100u/mL) == 1000 units/hr", newLine=true);
    } else {
        print("FAIL: ml_hr_to_units_hr(10mL/hr, 100u/mL) == 1000 units/hr", newLine=true);
    };

    print("IV Therapy tests done.", newLine=true);
};