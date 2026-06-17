from "mocha-bio" import *;

function main(didLoad) -> null {

    // ----- Naegele EDD -----
    // LMP: Jan 1 2024 → EDD should be Oct 8 2024
    var edd: (int, 3) = naegele_edd(1, 1, 2024);
    // edd[0] → edd#0, edd[1] → edd#1, edd[2] → edd#2
    if (edd#0 == 8 && edd#1 == 10 && edd#2 == 2024) {
        print("PASS: naegele_edd(1, 1, 2024) == 8/10/2024", newLine=true);
    } else {
        print("FAIL: naegele_edd(1, 1, 2024) == 8/10/2024", newLine=true);
    };
    print("EDD = ", newLine=false);
    print(edd#0, newLine=false);
    print("/", newLine=false);
    print(edd#1, newLine=false);
    print("/", newLine=false);
    print(edd#2, newLine=true);

    // LMP: June 15 2024 → EDD should be March 22 2025
    var edd2: (int, 3) = naegele_edd(15, 6, 2024);
    if (edd2#0 == 22 && edd2#1 == 3 && edd2#2 == 2025) {
        print("PASS: naegele_edd(15, 6, 2024) == 22/3/2025", newLine=true);
    } else {
        print("FAIL: naegele_edd(15, 6, 2024) == 22/3/2025", newLine=true);
    };
    print("EDD = ", newLine=false);
    print(edd2#0, newLine=false);
    print("/", newLine=false);
    print(edd2#1, newLine=false);
    print("/", newLine=false);
    print(edd2#2, newLine=true);

    // ----- Gestational Age -----
    // LMP Jan 1 2024, current Feb 12 2024 = 41 days = 5 weeks 6 days
    var ga_days: int = gestational_age_days(1, 1, 2024, 12, 2, 2024);
    if (ga_days == 41) {
        print("PASS: gestational_age_days == 41", newLine=true);
    } else {
        print("FAIL: gestational_age_days == 41", newLine=true);
    };
    print("gestational age days = ", newLine=false);
    print(ga_days, newLine=true);

    var ga_wk: (int, 2) = gestational_age_weeks(1, 1, 2024, 12, 2, 2024);
    if (ga_wk#0 == 5 && ga_wk#1 == 6) {
        print("PASS: gestational_age_weeks == 5w6d", newLine=true);
    } else {
        print("FAIL: gestational_age_weeks == 5w6d", newLine=true);
    };
    print("gestational age = ", newLine=false);
    print(ga_wk#0, newLine=false);
    print("w", newLine=false);
    print(ga_wk#1, newLine=false);
    print("d", newLine=true);

    // ----- BMI Fertility Risk -----
    var bfr1: BmiFertilityRisk = bmi_fertility_risk(17.0);
    if (bfr1 == BmiFertilityRisk.UNDERWEIGHT_RISK) {
        print("PASS: bmi_fertility_risk(17.0) == UNDERWEIGHT_RISK", newLine=true);
    } else {
        print("FAIL: bmi_fertility_risk(17.0) == UNDERWEIGHT_RISK", newLine=true);
    };

    var bfr2: BmiFertilityRisk = bmi_fertility_risk(22.0);
    if (bfr2 == BmiFertilityRisk.NORMAL) {
        print("PASS: bmi_fertility_risk(22.0) == NORMAL", newLine=true);
    } else {
        print("FAIL: bmi_fertility_risk(22.0) == NORMAL", newLine=true);
    };

    var bfr3: BmiFertilityRisk = bmi_fertility_risk(27.0);
    if (bfr3 == BmiFertilityRisk.OVERWEIGHT_RISK) {
        print("PASS: bmi_fertility_risk(27.0) == OVERWEIGHT_RISK", newLine=true);
    } else {
        print("FAIL: bmi_fertility_risk(27.0) == OVERWEIGHT_RISK", newLine=true);
    };

    var bfr4: BmiFertilityRisk = bmi_fertility_risk(32.0);
    if (bfr4 == BmiFertilityRisk.OBESE_RISK) {
        print("PASS: bmi_fertility_risk(32.0) == OBESE_RISK", newLine=true);
    } else {
        print("FAIL: bmi_fertility_risk(32.0) == OBESE_RISK", newLine=true);
    };

    // ----- AMH Ovarian Reserve -----
    var amh1: OvarianReserve = amh_ovarian_reserve(0.5);
    if (amh1 == OvarianReserve.LOW) {
        print("PASS: amh_ovarian_reserve(0.5) == LOW", newLine=true);
    } else {
        print("FAIL: amh_ovarian_reserve(0.5) == LOW", newLine=true);
    };

    var amh2: OvarianReserve = amh_ovarian_reserve(2.0);
    if (amh2 == OvarianReserve.NORMAL) {
        print("PASS: amh_ovarian_reserve(2.0) == NORMAL", newLine=true);
    } else {
        print("FAIL: amh_ovarian_reserve(2.0) == NORMAL", newLine=true);
    };

    var amh3: OvarianReserve = amh_ovarian_reserve(5.0);
    if (amh3 == OvarianReserve.HIGH) {
        print("PASS: amh_ovarian_reserve(5.0) == HIGH", newLine=true);
    } else {
        print("FAIL: amh_ovarian_reserve(5.0) == HIGH", newLine=true);
    };

    // ----- Kupperman Index -----
    // All zeros — should be 0
    var ki1: int = kupperman_index(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    if (ki1 == 0) {
        print("PASS: kupperman_index all zeros == 0", newLine=true);
    } else {
        print("FAIL: kupperman_index all zeros == 0", newLine=true);
    };

    // Max score: all 3s = 3*4 + 3*2 + 3*2 + 3*2 + 3*1*7 = 12+6+6+6+21 = 51
    var ki2: int = kupperman_index(3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3);
    if (ki2 == 51) {
        print("PASS: kupperman_index all 3s == 51", newLine=true);
    } else {
        print("FAIL: kupperman_index all 3s == 51", newLine=true);
    };
    print("kupperman max = ", newLine=false);
    print(ki2, newLine=true);

    // Moderate case
    var ki3: int = kupperman_index(2, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0);
    // = 2*4 + 1*2 + 1*2 + 1*2 = 8+2+2+2 = 14
    if (ki3 == 14) {
        print("PASS: kupperman_index moderate == 14", newLine=true);
    } else {
        print("FAIL: kupperman_index moderate == 14", newLine=true);
    };

    // ----- LH Surge -----
    // 28-day cycle: surge on day 14
    var lh1: float = lh_surge_day(28.0);
    if (lh1 == 14.0) {
        print("PASS: lh_surge_day(28) == 14", newLine=true);
    } else {
        print("FAIL: lh_surge_day(28) == 14", newLine=true);
    };

    // 30-day cycle: surge on day 16
    var lh2: float = lh_surge_day(30.0);
    if (lh2 == 16.0) {
        print("PASS: lh_surge_day(30) == 16", newLine=true);
    } else {
        print("FAIL: lh_surge_day(30) == 16", newLine=true);
    };

    // ----- Uterine RI / PI -----
    // RI: S=1.0, D=0.4 → (1.0-0.4)/1.0 = 0.6
    var ri1: float = uterine_ri(1.0, 0.4);
    if (ri1 > 0.59 && ri1 < 0.61) {
        print("PASS: uterine_ri(1.0, 0.4) ~0.6", newLine=true);
    } else {
        print("FAIL: uterine_ri(1.0, 0.4) ~0.6", newLine=true);
    };
    print("uterine RI = ", newLine=false);
    print(ri1, newLine=true);

    // Resistance interpretation: RI=0.6 > 0.58 → ELEVATED
    var ur1: UterineResistance = uterine_resistance(1.0, 0.4);
    if (ur1 == UterineResistance.ELEVATED) {
        print("PASS: uterine_resistance(1.0, 0.4) == ELEVATED", newLine=true);
    } else {
        print("FAIL: uterine_resistance(1.0, 0.4) == ELEVATED", newLine=true);
    };

    // Normal resistance: RI=0.5 → NORMAL
    var ur2: UterineResistance = uterine_resistance(1.0, 0.5);
    if (ur2 == UterineResistance.NORMAL) {
        print("PASS: uterine_resistance(1.0, 0.5) == NORMAL", newLine=true);
    } else {
        print("FAIL: uterine_resistance(1.0, 0.5) == NORMAL", newLine=true);
    };

    // PI: S=1.0, D=0.4, mean=0.7 → (1.0-0.4)/0.7 ~0.857
    var pi1: float = uterine_pi(1.0, 0.4, 0.7);
    if (pi1 > 0.85 && pi1 < 0.87) {
        print("PASS: uterine_pi(1.0, 0.4, 0.7) ~0.857", newLine=true);
    } else {
        print("FAIL: uterine_pi(1.0, 0.4, 0.7) ~0.857", newLine=true);
    };
    print("uterine PI = ", newLine=false);
    print(pi1, newLine=true);

    // ----- Fertility Window -----
    var fw1: float = fertility_window_begin(28.0);
    if (fw1 == 9.0) {
        print("PASS: fertility_window_begin(28) == day 9", newLine=true);
    } else {
        print("FAIL: fertility_window_begin(28) == day 9", newLine=true);
    };

    var fw2: float = fertility_window_peak(28.0);
    if (fw2 == 14.0) {
        print("PASS: fertility_window_peak(28) == day 14", newLine=true);
    } else {
        print("FAIL: fertility_window_peak(28) == day 14", newLine=true);
    };

    // ----- Sperm Analysis -----
    var sc1: SpermConcentration = sperm_concentration(0.0);
    if (sc1 == SpermConcentration.AZOOSPERMIA) {
        print("PASS: sperm_concentration(0) == AZOOSPERMIA", newLine=true);
    } else {
        print("FAIL: sperm_concentration(0) == AZOOSPERMIA", newLine=true);
    };

    var sc2: SpermConcentration = sperm_concentration(8.0);
    if (sc2 == SpermConcentration.OLIGOSPERMIA) {
        print("PASS: sperm_concentration(8) == OLIGOSPERMIA", newLine=true);
    } else {
        print("FAIL: sperm_concentration(8) == OLIGOSPERMIA", newLine=true);
    };

    var sc3: SpermConcentration = sperm_concentration(20.0);
    if (sc3 == SpermConcentration.NORMAL) {
        print("PASS: sperm_concentration(20) == NORMAL", newLine=true);
    } else {
        print("FAIL: sperm_concentration(20) == NORMAL", newLine=true);
    };

    var sm1: SpermMotility = sperm_motility(30.0);
    if (sm1 == SpermMotility.ASTHENOSPERMIA) {
        print("PASS: sperm_motility(30%) == ASTHENOSPERMIA", newLine=true);
    } else {
        print("FAIL: sperm_motility(30%) == ASTHENOSPERMIA", newLine=true);
    };

    var sm2: SpermMotility = sperm_motility(50.0);
    if (sm2 == SpermMotility.NORMAL) {
        print("PASS: sperm_motility(50%) == NORMAL", newLine=true);
    } else {
        print("FAIL: sperm_motility(50%) == NORMAL", newLine=true);
    };

    // ----- Free Testosterone -----
    // Typical male values: total_t=20 nmol/L, shbg=30 nmol/L, albumin=4.3 g/dL
    var ft1: float = free_testosterone(20.0, 30.0, 4.3);
    print("free testosterone = ", newLine=false);
    print(ft1, newLine=true);
    if (ft1 > 0.0) {
        print("PASS: free_testosterone returns positive value", newLine=true);
    } else {
        print("FAIL: free_testosterone returns positive value", newLine=true);
    };

    print("Gynecology tests done.", newLine=true);
};