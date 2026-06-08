from "mocha-bio" import *;

function main(didLoad) -> null {

    // ============================================================
    // TEST 1 — ideal body weight
    // ============================================================
    // Male 180cm: 50 + 2.3 * ((180/2.54) - 60) = 50 + 2.3 * 10.866 = 74.99 kg
    var ibw_male: float = ideal_body_weight(180.0, Sex.MALE);
    print(ibw_male, newLine=true);  // ~74.99

    // Female 165cm: 45.5 + 2.3 * ((165/2.54) - 60) = 45.5 + 2.3 * 4.96 = 56.9 kg
    var ibw_female: float = ideal_body_weight(165.0, Sex.FEMALE);
    print(ibw_female, newLine=true);  // ~56.9

    // Below 152.4cm — should warn and return height-based estimate
    var ibw_short: float = ideal_body_weight(148.0, Sex.MALE);
    print(ibw_short, newLine=true);  // 148 * 0.4 = 59.2

    // ============================================================
    // TEST 2 — tidal volume
    // ============================================================
    // IBW = 70kg → 6 * 70 = 420 mL — within normal range
    var tv_normal: float = tidal_volume(70.0);
    print(tv_normal, newLine=true);  // 420.0

    // IBW = 40kg → 6 * 40 = 240 mL — should warn: below 400
    var tv_low: float = tidal_volume(40.0);
    print(tv_low, newLine=true);  // 240.0

    // ============================================================
    // TEST 3 — minute ventilation
    // ============================================================
    // TV = 500mL, RR = 14 → (500 * 14) / 1000 = 7.0 L/min — normal
    var mv_normal: float = minute_ventilation(500.0, 14.0);
    print(mv_normal, newLine=true);  // 7.0

    // TV = 800mL, RR = 20 → 16.0 L/min — should warn: above 10
    var mv_high: float = minute_ventilation(800.0, 20.0);
    print(mv_high, newLine=true);  // 16.0

    // ============================================================
    // TEST 4 — alveolar PO2
    // ============================================================
    // Room air, sea level, normal PaCO2, standard RQ
    // PAO2 = 0.21 * (760 - 47) - (40 / 0.8) = 0.21 * 713 - 50 = 149.73 - 50 = 99.73
    var pao2_room: float = alveolar_po2(0.21, SEA_LEVEL_ATM_PRESSURE, 40.0, STANDARD_RQ);
    print(pao2_room, newLine=true);  // ~99.73

    // Pure O2, sea level
    // PAO2 = 1.0 * (760 - 47) - (40 / 0.8) = 713 - 50 = 663.0
    var pao2_pure: float = alveolar_po2(1.0, SEA_LEVEL_ATM_PRESSURE, 40.0, STANDARD_RQ);
    print(pao2_pure, newLine=true);  // 663.0

    // Denver altitude (~630 mmHg), room air
    // PAO2 = 0.21 * (630 - 47) - 50 = 0.21 * 583 - 50 = 122.43 - 50 = 72.43
    var pao2_denver: float = alveolar_po2(0.21, 630.0, 40.0, STANDARD_RQ);
    print(pao2_denver, newLine=true);  // ~72.43

    // ============================================================
    // TEST 5 — A-a gradient
    // ============================================================
    // Normal young patient: PAO2 ~99.73, PaO2 = 95 → gradient = 4.73 — no warning
    var aa_normal: float = aa_gradient(0.21, SEA_LEVEL_ATM_PRESSURE, 40.0, 95.0, STANDARD_RQ);
    print(aa_normal, newLine=true);  // ~4.73

    // Abnormal: PaO2 = 60 → gradient = ~39.73 — should warn V/Q mismatch
    var aa_abnormal: float = aa_gradient(0.21, SEA_LEVEL_ATM_PRESSURE, 40.0, 60.0, STANDARD_RQ);
    print(aa_abnormal, newLine=true);  // ~39.73

    // ============================================================
    // TEST 6 — FEV1/FVC ratio
    // ============================================================
    // Normal: FEV1=3.5, FVC=4.5 → 3.5/4.5 = 0.778 — no warning
    var fev_normal: float = fev1_fvc_ratio(3.5, 4.5);
    print(fev_normal, newLine=true);  // ~0.778

    // Obstructive: FEV1=1.8, FVC=3.2 → 1.8/3.2 = 0.5625 — should warn < 0.70
    var fev_obstructive: float = fev1_fvc_ratio(1.8, 3.2);
    print(fev_obstructive, newLine=true);  // ~0.5625

    // ============================================================
    // TEST 7 — dead space fraction
    // ============================================================
    // Normal: PaCO2=40, PECO2=28 → (40-28)/40 = 0.3 — no warning
    var vd_normal: float = dead_space_fraction(40.0, 28.0);
    print(vd_normal, newLine=true);  // 0.3

    // ARDS: PaCO2=40, PECO2=10 → (40-10)/40 = 0.75 — should warn > 0.6
    var vd_ards: float = dead_space_fraction(40.0, 10.0);
    print(vd_ards, newLine=true);  // 0.75

    // ============================================================
    // TEST 8 — lung compliance
    // ============================================================
    // Normal: TV=500mL, plateau=25, PEEP=5 → 500/20 = 25 mL/cmH2O — should warn < 40
    var lc_low: float = lung_compliance(500.0, 25.0, 5.0);
    print(lc_low, newLine=true);  // 25.0

    // Better compliance: TV=500mL, plateau=13, PEEP=5 → 500/8 = 62.5 — normal
    var lc_normal: float = lung_compliance(500.0, 13.0, 5.0);
    print(lc_normal, newLine=true);  // 62.5

    // ============================================================
    // TEST 9 — P/F ratio and ARDS severity
    // ============================================================
    // Normal: PaO2=95, FiO2=0.21 → 95/0.21 = 452.4 — NONE
    var pf_normal: float = pf_ratio(95.0, 0.21);
    print(pf_normal, newLine=true);  // ~452.4
    var ards_none: ArdsSeverity = ards_severity(pf_normal);

    // Mild: PaO2=70, FiO2=0.40 → 70/0.40 = 175 — MODERATE
    var pf_moderate: float = pf_ratio(70.0, 0.40);
    print(pf_moderate, newLine=true);  // 175.0
    var ards_mod: ArdsSeverity = ards_severity(pf_moderate);

    // Severe: PaO2=55, FiO2=1.0 → 55/1.0 = 55 — SEVERE
    var pf_severe: float = pf_ratio(55.0, 1.0);
    print(pf_severe, newLine=true);  // 55.0
    var ards_sev: ArdsSeverity = ards_severity(pf_severe);

    // ============================================================
    // TEST 10 — oxygen content
    // ============================================================
    // Normal arterial: Hgb=15, SaO2=0.98, PaO2=95
    // CaO2 = (15 * 1.34 * 0.98) + (0.0031 * 95) = 19.677 + 0.2945 = 19.97
    var cao2_normal: float = oxygen_content(15.0, 0.98, 95.0);
    print(cao2_normal, newLine=true);  // ~19.97

    // Anaemic: Hgb=7, SaO2=0.95, PaO2=80
    // CaO2 = (7 * 1.34 * 0.95) + (0.0031 * 80) = 8.897 + 0.248 = 9.145
    // Should warn: below normal range
    var cao2_anaemic: float = oxygen_content(7.0, 0.95, 80.0);
    print(cao2_anaemic, newLine=true);  // ~9.145

    // Hypoxaemic: SaO2 = 0.85 — should warn < 0.90
    var cao2_hypoxic: float = oxygen_content(15.0, 0.85, 55.0);
    print(cao2_hypoxic, newLine=true);

};