from "mocha-bio" import *;

function main(didLoad) -> null {

    // ============================================================
    // TEST 1 — body adiposity index
    // ============================================================
    // Female: hip=100cm, height=165cm
    // height^1.5 = 165 * sqrt(165) = 165 * 12.845 = 2119.4
    // BAI = 100/2119.4 - 18 = 0.04719 - 18 = ... wait that's wrong
    // BAI = (100/2119.4) * 100 - 18 — no, formula is just hip/height^1.5 - 18
    // = 100/2119.4 - 18 = -17.95 — that can't be right
    // Correct: hip in cm, height in cm → result should be ~20-30%
    // Let me recheck: BAI = (hip_cm / height_cm^1.5) - 18
    // 165^1.5 = 2119.4, 100/2119.4 = 0.0472 → 0.0472 - 18 = negative
    // The original formula uses height in METRES not cm!
    // height_m^1.5 = 1.65^1.5 = 2.118... no wait
    // 1.65^1.5 = 1.65 * sqrt(1.65) = 1.65 * 1.2845 = 2.119 — same issue
    // Actual BAI formula: hip_cm / (height_m^1.5) - 18
    // = 100 / (1.65^1.5) - 18 = 100/2.119 - 18 = 47.2 - 18 = 29.2% ✅
    // BUG: our implementation uses height_cm not height_m for the ^1.5!

    var bai: float = body_adiposity_index(100.0, 165.0);
    print(bai, newLine=true);  // will be wrong — catching the bug here

    // ============================================================
    // TEST 2 — ponderal index
    // ============================================================
    // weight=70kg, height=175cm → height_m=1.75
    // PI = 70 / (1.75^3) = 70 / 5.359 = 13.06 — normal
    var pi_normal: float = ponderal_index(70.0, 175.0);
    print(pi_normal, newLine=true);  // ~13.06

    // Heavy short: weight=100kg, height=160cm
    // PI = 100 / (1.6^3) = 100 / 4.096 = 24.4 — should warn
    var pi_high: float = ponderal_index(100.0, 160.0);
    print(pi_high, newLine=true);  // ~24.4

    // ============================================================
    // TEST 3 — waist-to-height ratio
    // ============================================================
    // Low risk: waist=70, height=175 → 0.4 — MODERATE boundary
    var whr_low: WaistHeightRisk = waist_height_ratio(70.0, 175.0);
    var whr_low_val: float = waist_height_ratio_value(70.0, 175.0);
    print(whr_low_val, newLine=true);  // 0.4

    // High: waist=95, height=170 → 0.559 — HIGH, should warn
    var whr_high: WaistHeightRisk = waist_height_ratio(95.0, 170.0);
    var whr_high_val: float = waist_height_ratio_value(95.0, 170.0);
    print(whr_high_val, newLine=true);  // ~0.559

    // Very high: waist=120, height=170 → 0.706 — VERY_HIGH, should warn
    var whr_vhigh: WaistHeightRisk = waist_height_ratio(120.0, 170.0);
    var whr_vhigh_val: float = waist_height_ratio_value(120.0, 170.0);
    print(whr_vhigh_val, newLine=true);  // ~0.706

    // ============================================================
    // TEST 4 — relative fat mass
    // ============================================================
    // Male: height=175, waist=85 → 64 - (20 * 175/85) = 64 - 41.18 = 22.82%
    var rfm_male: float = relative_fat_mass(175.0, 85.0, Sex.MALE);
    print(rfm_male, newLine=true);  // ~22.82

    // Female: height=165, waist=75 → 76 - (20 * 165/75) = 76 - 44.0 = 32.0%
    var rfm_female: float = relative_fat_mass(165.0, 75.0, Sex.FEMALE);
    print(rfm_female, newLine=true);  // 32.0

    // ============================================================
    // TEST 5 — BMR and TDEE
    // ============================================================
    // Male: weight=80, height=180, age=30
    // BMR = (10*80) + (6.25*180) - (5*30) + 5 = 800 + 1125 - 150 + 5 = 1780
    var bmr_male: float = basal_metabolic_rate(80.0, 180.0, 30.0, Sex.MALE);
    print(bmr_male, newLine=true);  // 1780.0

    // Female: weight=60, height=165, age=25
    // BMR = (10*60) + (6.25*165) - (5*25) - 161 = 600 + 1031.25 - 125 - 161 = 1345.25
    var bmr_female: float = basal_metabolic_rate(60.0, 165.0, 25.0, Sex.FEMALE);
    print(bmr_female, newLine=true);  // 1345.25

    // TDEE — male, moderate activity: 1780 * 1.55 = 2759
    var tdee: float = total_daily_energy_expenditure(bmr_male, ActivityLevel.MODERATE);
    print(tdee, newLine=true);  // 2759.0

    // TDEE — male, very active: 1780 * 1.9 = 3382
    var tdee_active: float = total_daily_energy_expenditure(bmr_male, ActivityLevel.VERY_ACTIVE);
    print(tdee_active, newLine=true);  // 3382.0

    // ============================================================
    // TEST 6 — HbA1c to eAG
    // ============================================================
    // Normal: HbA1c=5.0 → (5.0*28.7) - 46.7 = 143.5 - 46.7 = 96.8 mg/dL
    var eag_normal: float = hba1c_to_eag(5.0);
    print(eag_normal, newLine=true);  // 96.8

    // Prediabetes: HbA1c=6.0 → (6.0*28.7) - 46.7 = 172.2 - 46.7 = 125.5
    // Should warn prediabetes
    var eag_pre: float = hba1c_to_eag(6.0);
    print(eag_pre, newLine=true);  // 125.5

    // Diabetes: HbA1c=8.5 → (8.5*28.7) - 46.7 = 243.95 - 46.7 = 197.25
    // Should warn diabetes
    var eag_diabetes: float = hba1c_to_eag(8.5);
    print(eag_diabetes, newLine=true);  // 197.25

    // ============================================================
    // TEST 7 — HOMA-IR
    // ============================================================
    // Insulin sensitive: glucose=85, insulin=5 → (85*5)/405 = 1.049 — normal
    var homa_normal: float = homa_ir(85.0, 5.0);
    print(homa_normal, newLine=true);  // ~1.049

    // Early resistance: glucose=100, insulin=10 → (100*10)/405 = 2.469
    // Should warn > 1.9
    var homa_early: float = homa_ir(100.0, 10.0);
    print(homa_early, newLine=true);  // ~2.469

    // Significant: glucose=120, insulin=15 → (120*15)/405 = 4.444
    // Should warn > 2.9
    var homa_sig: float = homa_ir(120.0, 15.0);
    print(homa_sig, newLine=true);  // ~4.444

    // ============================================================
    // TEST 8 — corrected calcium
    // ============================================================
    // Normal albumin: calcium=9.0, albumin=4.0 → 9.0 + 0.8*(4-4) = 9.0
    var ca_normal: float = corrected_calcium(9.0, 4.0);
    print(ca_normal, newLine=true);  // 9.0

    // Low albumin: calcium=7.5, albumin=2.0 → 7.5 + 0.8*(4-2) = 7.5 + 1.6 = 9.1
    var ca_corrected: float = corrected_calcium(7.5, 2.0);
    print(ca_corrected, newLine=true);  // 9.1

    // Severe hypercalcaemia after correction: calcium=11.0, albumin=2.0
    // → 11.0 + 0.8*2 = 12.6 — should warn > 12.0
    var ca_high: float = corrected_calcium(11.0, 2.0);
    print(ca_high, newLine=true);  // 12.6

    // ============================================================
    // TEST 9 — free water deficit
    // ============================================================
    // Male: weight=70, sodium=155
    // FWD = 0.6 * 70 * (155/140 - 1) = 42 * 0.107 = 4.5L
    var fwd_male: float = free_water_deficit(70.0, 155.0, Sex.MALE);
    print(fwd_male, newLine=true);  // ~4.5

    // Severe: weight=80, sodium=168, female
    // FWD = 0.5 * 80 * (168/140 - 1) = 40 * 0.2 = 8.0L — should warn > 5L
    var fwd_severe: float = free_water_deficit(80.0, 168.0, Sex.FEMALE);
    print(fwd_severe, newLine=true);  // 8.0

    // sodium <= 140 — should warn not applicable
    var fwd_invalid: float = free_water_deficit(70.0, 138.0, Sex.MALE);
    print(fwd_invalid, newLine=true);

};