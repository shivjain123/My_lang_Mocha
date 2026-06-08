from "mocha-bio" import *;

function main(didLoad) -> null {

    // ============================================================
    // TEST 1 — SVR (normal range)
    // ============================================================
    // MAP = 93, CVP = 5, CO = 5.0 L/min
    // Expected: ((93 - 5) / 5.0) * 80 = 1408.0  → warning: above 1200
    var svr_val: float = svr(93.0, 5.0, 5.0);
    print(svr_val, newLine=true);  // 1408.0

    // Low CO shock scenario — SVR should spike
    // MAP = 60, CVP = 8, CO = 2.0
    // Expected: ((60 - 8) / 2.0) * 80 = 2080.0
    var svr_shock: float = svr(60.0, 8.0, 2.0);
    print(svr_shock, newLine=true);  // 2080.0

    // ============================================================
    // TEST 2 — QTc Bazett
    // ============================================================
    // QT = 400ms, HR = 60 bpm → RR = 1.0s → QTc = 400 / sqrt(1.0) = 400.0
    var qtc_normal: float = qtc_bazett(400.0, 60.0, Sex.MALE);
    print(qtc_normal, newLine=true);  // 400.0 — no warning

    // QT = 400ms, HR = 100 bpm → RR = 0.6s → QTc = 400 / sqrt(0.6) ≈ 516.4
    // Should warn: > 440ms MALE threshold AND > 500ms torsades risk
    var qtc_prolonged: float = qtc_bazett(400.0, 100.0, Sex.MALE);
    print(qtc_prolonged, newLine=true);  // ~516.4

    // FEMALE threshold test — QTc = 455ms should warn for MALE, not FEMALE
    // QT = 352ms, HR = 60 → QTc = 352.0
    var qtc_FEMALE: float = qtc_bazett(352.0, 60.0, Sex.FEMALE);
    print(qtc_FEMALE, newLine=true);  // 352.0 — no warning

    // ============================================================
    // TEST 3 — Shock index
    // ============================================================
    // Normal: HR=70, SBP=120 → 70/120 ≈ 0.583
    var si_normal: float = shock_index(70.0, 120.0);
    print(si_normal, newLine=true);  // ~0.583 — no warning

    // Compromised: HR=110, SBP=100 → 1.1 → should warn >1.0
    var si_compromised: float = shock_index(110.0, 100.0);
    print(si_compromised, newLine=true);  // 1.1

    // Critical: HR=140, SBP=90 → ~1.556 → should warn >1.4
    var si_critical: float = shock_index(140.0, 90.0);
    print(si_critical, newLine=true);  // ~1.556

    // ============================================================
    // TEST 4 — VO2 max (Fick)
    // ============================================================
    // CO = 5.0 L/min, CaO2 = 20.0, CvO2 = 15.0 → diff = 5.0
    // Expected: 5.0 * 10.0 * 5.0 = 250.0 mL O2/min
    // Should warn: a-vO2 diff < 4.0? No, 5.0 is fine
    var vo2_rest: float = vo2_max_fick(5.0, 20.0, 15.0);
    print(vo2_rest, newLine=true);  // 250.0

    // Peak exercise: CO = 20.0, CaO2 = 20.0, CvO2 = 5.0 → diff = 15.0
    // Expected: 20.0 * 10.0 * 15.0 = 3000.0 mL O2/min
    var vo2_peak: float = vo2_max_fick(20.0, 20.0, 5.0);
    print(vo2_peak, newLine=true);  // 3000.0

    // ============================================================
    // TEST 5 — Framingham risk
    // ============================================================
    // Low risk male: age=35, TC=180, HDL=55, SBP=115, nonsmoker, no BP treatment
    // Expect: low single digits %
    var fr_low: float = framingham_risk(
        35.0, Sex.MALE,
        180.0, 55.0, 115.0,
        false,
        SmokingStatus.NON_SMOKER
    );
    print(fr_low, newLine=true);

    // High risk male: age=60, TC=280, HDL=30, SBP=160, smoker, no BP treatment
    // Expect: > 20% → should trigger high risk warning
    var fr_high: float = framingham_risk(
        60.0, Sex.MALE,
        280.0, 30.0, 160.0,
        false,
        SmokingStatus.SMOKER
    );
    print(fr_high, newLine=true);

    // Female intermediate: age=55, TC=240, HDL=45, SBP=140, nonsmoker, no BP treatment
    // Expect: ~2.6% (verified against MDCalc)
    var fr_mid: float = framingham_risk(
        55.0, Sex.FEMALE,
        240.0, 45.0, 140.0,
        false,
        SmokingStatus.NON_SMOKER
    );
    print(fr_mid, newLine=true);

    // ============================================================
    // TEST 6 — guard / error cases
    // ============================================================
    // CVP >= MAP — should warn but not exit
    var svr_bad: float = svr(60.0, 65.0, 5.0);
    print(svr_bad, newLine=true);

    // cvo2 >= cao2 — should warn but not exit
    var vo2_bad: float = vo2_max_fick(5.0, 12.0, 15.0);
    print(vo2_bad, newLine=true);

    // Age out of Framingham range — should warn but continue
    var fr_age: float = framingham_risk(
        25.0, Sex.MALE,
        200.0, 50.0, 120.0,
        false,
        SmokingStatus.NON_SMOKER
    );
    print(fr_age, newLine=true);
};