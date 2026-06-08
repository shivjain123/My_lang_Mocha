from "mocha-bio" import *;

function main(didLoad) -> null {

    // ============================================================
    // TEST 1 — GCS score and severity
    // ============================================================
    // Best possible: E4 V5 M6 = 15 — MILD, no warning
    var gcs_best: GcsSeverity = gcs(GcsEye.SPONTANEOUS, GcsVerbal.ORIENTED, GcsMotor.OBEYS_COMMANDS);
    var gcs_best_score: int = gcs_score(GcsEye.SPONTANEOUS, GcsVerbal.ORIENTED, GcsMotor.OBEYS_COMMANDS);
    print(gcs_best_score, newLine=true);  // 15

    // Moderate: E3 V3 M4 = 10 — MODERATE, should warn
    var gcs_mod: GcsSeverity = gcs(GcsEye.TO_VOICE, GcsVerbal.INAPPROPRIATE, GcsMotor.WITHDRAWAL);
    var gcs_mod_score: int = gcs_score(GcsEye.TO_VOICE, GcsVerbal.INAPPROPRIATE, GcsMotor.WITHDRAWAL);
    print(gcs_mod_score, newLine=true);  // 10

    // Severe: E2 V2 M2 = 6 — SEVERE, should warn intubation
    var gcs_sev: GcsSeverity = gcs(GcsEye.TO_PAIN, GcsVerbal.INCOMPREHENSIBLE, GcsMotor.EXTENSION_POSTURING);
    var gcs_sev_score: int = gcs_score(GcsEye.TO_PAIN, GcsVerbal.INCOMPREHENSIBLE, GcsMotor.EXTENSION_POSTURING);
    print(gcs_sev_score, newLine=true);  // 6

    // Worst: E1 V1 M1 = 3 — SEVERE, should warn brain death
    var gcs_worst: GcsSeverity = gcs(GcsEye.NO_RESPONSE, GcsVerbal.NO_RESPONSE, GcsMotor.NO_RESPONSE);
    var gcs_worst_score: int = gcs_score(GcsEye.NO_RESPONSE, GcsVerbal.NO_RESPONSE, GcsMotor.NO_RESPONSE);
    print(gcs_worst_score, newLine=true);  // 3

    // ============================================================
    // TEST 2 — cerebral perfusion pressure
    // ============================================================
    // Normal: MAP=93, ICP=10 → CPP=83 — should warn > 80
    var cpp_normal: float = cerebral_perfusion_pressure(93.0, 10.0);
    print(cpp_normal, newLine=true);  // 83.0

    // Ischaemic risk: MAP=75, ICP=20 → CPP=55 — should warn ICP > 15 and CPP < 60
    var cpp_low: float = cerebral_perfusion_pressure(75.0, 20.0);
    print(cpp_low, newLine=true);  // 55.0

    // Critical: MAP=50, ICP=15 → CPP=35 — should warn CPP < 40
    var cpp_critical: float = cerebral_perfusion_pressure(50.0, 15.0);
    print(cpp_critical, newLine=true);  // 35.0

    // ============================================================
    // TEST 3 — cerebral blood flow (Fick)
    // ============================================================
    // Normal: CMRO2=3.0, AVDO2=0.06 → CBF = 3.0/0.06 = 50.0 mL/100g/min
    var cbf_normal: float = cerebral_blood_flow(3.0, 0.06);
    print(cbf_normal, newLine=true);  // 50.0

    // Ischaemic: CMRO2=1.2, AVDO2=0.06 → CBF = 20.0 — should warn < 20
    var cbf_ischaemic: float = cerebral_blood_flow(1.2, 0.06);
    print(cbf_ischaemic, newLine=true);  // 20.0

    // Infarction: CMRO2=0.5, AVDO2=0.06 → CBF = 8.33 — should warn < 10
    var cbf_infarct: float = cerebral_blood_flow(0.5, 0.06);
    print(cbf_infarct, newLine=true);  // ~8.33

    // ============================================================
    // TEST 4 — serum osmolality
    // ============================================================
    // Normal: Na=140, glucose=90, BUN=14
    // Osm = 2*140 + 90/18 + 14/2.8 = 280 + 5 + 5 = 290
    var osm_normal: float = serum_osmolality(140.0, 90.0, 14.0);
    print(osm_normal, newLine=true);  // 290.0

    // Hyperosmolar: Na=155, glucose=600, BUN=40
    // Osm = 310 + 33.33 + 14.28 = 357.6 — should warn > 320
    var osm_hyper: float = serum_osmolality(155.0, 600.0, 40.0);
    print(osm_hyper, newLine=true);  // ~357.6

    // ============================================================
    // TEST 5 — osmolar gap
    // ============================================================
    // Normal: measured=292, calculated=290 → gap=2 — no warning
    var gap_normal: float = osmolar_gap(292.0, 290.0);
    print(gap_normal, newLine=true);  // 2.0

    // Elevated: measured=325, calculated=290 → gap=35 — should warn toxic alcohols
    var gap_toxic: float = osmolar_gap(325.0, 290.0);
    print(gap_toxic, newLine=true);  // 35.0

    // Negative gap — should warn
    var gap_negative: float = osmolar_gap(285.0, 290.0);
    print(gap_negative, newLine=true);  // -5.0

    // ============================================================
    // TEST 6 — corrected sodium
    // ============================================================
    // Na=130, glucose=400 → 130 + 0.016*(400-100) = 130 + 4.8 = 134.8
    var na_corrected: float = corrected_sodium(130.0, 400.0);
    print(na_corrected, newLine=true);  // 134.8

    // Na=138, glucose=600 → 138 + 0.016*500 = 138 + 8 = 146.0
    var na_high: float = corrected_sodium(138.0, 600.0);
    print(na_high, newLine=true);  // 146.0

    // glucose <= 100 — should warn correction not indicated
    var na_unnecessary: float = corrected_sodium(138.0, 95.0);
    print(na_unnecessary, newLine=true);  // ~137.92

};