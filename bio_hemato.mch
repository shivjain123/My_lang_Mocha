from "mocha-bio" import *;

function main(didLoad) -> null {

    // ============================================================
    // TEST 1 — MCV
    // ============================================================
    // Normal: Hct=45%, RBC=5.0 → MCV = (45*10)/5 = 90 fL — NORMOCYTIC
    var mcv_normal: AnaemiaType = mcv(45.0, 5.0);
    var mcv_normal_val: float = mcv_value(45.0, 5.0);
    print(mcv_normal_val, newLine=true);  // 90.0

    // Microcytic: Hct=30%, RBC=5.5 → MCV = 300/5.5 = 54.5 — should warn
    var mcv_micro: AnaemiaType = mcv(30.0, 5.5);
    var mcv_micro_val: float = mcv_value(30.0, 5.5);
    print(mcv_micro_val, newLine=true);  // ~54.5

    // Macrocytic: Hct=38%, RBC=3.0 → MCV = 380/3 = 126.7 — should warn
    var mcv_macro: AnaemiaType = mcv(38.0, 3.0);
    var mcv_macro_val: float = mcv_value(38.0, 3.0);
    print(mcv_macro_val, newLine=true);  // ~126.7

    // ============================================================
    // TEST 2 — MCH
    // ============================================================
    // Normal: Hgb=14, RBC=5.0 → MCH = 140/5 = 28.0 pg
    var mch_normal: float = mch(14.0, 5.0);
    print(mch_normal, newLine=true);  // 28.0

    // Low: Hgb=8, RBC=5.5 → MCH = 80/5.5 = 14.5 — should warn
    var mch_low: float = mch(8.0, 5.5);
    print(mch_low, newLine=true);  // ~14.5

    // ============================================================
    // TEST 3 — MCHC
    // ============================================================
    // Normal: Hgb=14, Hct=42 → MCHC = (14/42)*100 = 33.3 g/dL
    var mchc_normal: float = mchc(14.0, 42.0);
    print(mchc_normal, newLine=true);  // ~33.3

    // Hypochromic: Hgb=8, Hct=35 → MCHC = (8/35)*100 = 22.9 — should warn
    var mchc_low: float = mchc(8.0, 35.0);
    print(mchc_low, newLine=true);  // ~22.9

    // Hyperchromic: Hgb=18, Hct=42 → MCHC = (18/42)*100 = 42.9 — should warn
    var mchc_high: float = mchc(18.0, 42.0);
    print(mchc_high, newLine=true);  // ~42.9

    // ============================================================
    // TEST 4 — corrected reticulocyte
    // ============================================================
    // Male, Hct=45 (normal), retic=1.5% → corrected = 1.5*(45/45) = 1.5 — normal
    var retic_normal: float = corrected_reticulocyte(1.5, 45.0, Sex.MALE);
    print(retic_normal, newLine=true);  // 1.5

    // Male anaemic, Hct=25, retic=4% → corrected = 4*(25/45) = 2.22 — should warn > 2
    var retic_anaemic: float = corrected_reticulocyte(4.0, 25.0, Sex.MALE);
    print(retic_anaemic, newLine=true);  // ~2.22

    // Female, Hct=20, retic=2% → corrected = 2*(20/41) = 0.976 — should warn < 1
    var retic_low: float = corrected_reticulocyte(2.0, 20.0, Sex.FEMALE);
    print(retic_low, newLine=true);  // ~0.976

    // ============================================================
    // TEST 5 — reticulocyte production index
    // ============================================================
    // Male, Hct=40 (maturation=1.0), retic=1.5%
    // corrected = 1.5*(40/45) = 1.333, RPI = 1.333/1.0 = 1.333 — hypoproliferative
    var rpi_hypo: float = reticulocyte_production_index(1.5, 40.0, Sex.MALE);
    print(rpi_hypo, newLine=true);  // ~1.333

    // Male, Hct=25 (maturation=1.5), retic=8%
    // corrected = 8*(25/45) = 4.444, RPI = 4.444/1.5 = 2.963 — adequate response
    var rpi_adequate: float = reticulocyte_production_index(8.0, 25.0, Sex.MALE);
    print(rpi_adequate, newLine=true);  // ~2.963

    // ============================================================
    // TEST 6 — blood volume
    // ============================================================
    // Male: height=175cm, weight=75kg
    // height_m=1.75, height_m3=5.359
    // BV = (0.3669*5.359) + (0.03219*75) + 0.6041
    //    = 1.966 + 2.414 + 0.604 = 4.984L
    var bv_male: float = blood_volume(175.0, 75.0, Sex.MALE);
    print(bv_male, newLine=true);  // ~4.984

    // Female: height=165cm, weight=60kg
    // height_m=1.65, height_m3=4.492
    // BV = (0.3561*4.492) + (0.03308*60) + 0.1833
    //    = 1.600 + 1.985 + 0.183 = 3.768L
    var bv_female: float = blood_volume(165.0, 60.0, Sex.FEMALE);
    print(bv_female, newLine=true);  // ~3.768

    // ============================================================
    // TEST 7 — ANC
    // ============================================================
    // Normal: WBC=7.0, neutrophils=65%, bands=3%
    // ANC = 7.0 * 68/100 = 4.76 — NONE
    var anc_normal: NeutropeniaGrade = anc(7.0, 65.0, 3.0);
    var anc_normal_val: float = anc_value(7.0, 65.0, 3.0);
    print(anc_normal_val, newLine=true);  // 4.76

    // Mild: WBC=2.0, neutrophils=60%, bands=5%
    // ANC = 2.0 * 65/100 = 1.3 — MILD
    var anc_mild: NeutropeniaGrade = anc(2.0, 60.0, 5.0);
    var anc_mild_val: float = anc_value(2.0, 60.0, 5.0);
    print(anc_mild_val, newLine=true);  // 1.3

    // Moderate: WBC=1.5, neutrophils=50%, bands=5%
    // ANC = 1.5 * 55/100 = 0.825 — MODERATE
    var anc_mod: NeutropeniaGrade = anc(1.5, 50.0, 5.0);
    var anc_mod_val: float = anc_value(1.5, 50.0, 5.0);
    print(anc_mod_val, newLine=true);  // 0.825

    // Severe: WBC=0.8, neutrophils=40%, bands=5%
    // ANC = 0.8 * 45/100 = 0.36 — SEVERE
    var anc_sev: NeutropeniaGrade = anc(0.8, 40.0, 5.0);
    var anc_sev_val: float = anc_value(0.8, 40.0, 5.0);
    print(anc_sev_val, newLine=true);  // 0.36

    // ============================================================
    // TEST 8 — transferrin saturation
    // ============================================================
    // Normal: iron=100, TIBC=300 → 100/300*100 = 33.3%
    var tsat_normal: float = transferrin_saturation(100.0, 300.0);
    print(tsat_normal, newLine=true);  // ~33.3

    // Iron deficiency: iron=40, TIBC=400 → 40/400*100 = 10% — should warn
    var tsat_low: float = transferrin_saturation(40.0, 400.0);
    print(tsat_low, newLine=true);  // 10.0

    // Overload: iron=200, TIBC=250 → 200/250*100 = 80% — should warn
    var tsat_high: float = transferrin_saturation(200.0, 250.0);
    print(tsat_high, newLine=true);  // 80.0
};