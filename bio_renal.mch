from "mocha-bio" import *;

function main(didLoad) -> null {

    // ============================================================
    // TEST 1 — CKD-EPI GFR stage and value
    // ============================================================
    // Young healthy female: cr=0.8, age=25 → expect G1 (>= 90)
    var gfr_g1: CkdStage = ckd_epi_gfr(0.8, 25.0, Sex.FEMALE);
    var gfr_g1_val: float = ckd_epi_gfr_value(0.8, 25.0, Sex.FEMALE);
    print(gfr_g1_val, newLine=true);  // ~100+

    // Middle aged male: cr=1.4, age=55 → expect G2 (60-89)
    var gfr_g2: CkdStage = ckd_epi_gfr(1.4, 55.0, Sex.MALE);
    var gfr_g2_val: float = ckd_epi_gfr_value(1.4, 55.0, Sex.MALE);
    print(gfr_g2_val, newLine=true);  // ~60-89

    // G3a: cr=1.8, age=60, male → expect G3A warning
    var gfr_g3a: CkdStage = ckd_epi_gfr(1.8, 60.0, Sex.MALE);
    var gfr_g3a_val: float = ckd_epi_gfr_value(1.8, 60.0, Sex.MALE);
    print(gfr_g3a_val, newLine=true);  // ~45-59

    // G3b: cr=2.5, age=65, male → expect G3B warning
    var gfr_g3b: CkdStage = ckd_epi_gfr(2.5, 65.0, Sex.MALE);
    var gfr_g3b_val: float = ckd_epi_gfr_value(2.5, 65.0, Sex.MALE);
    print(gfr_g3b_val, newLine=true);  // ~30-44

    // G4: cr=3.5, age=70, male → expect G4 warning
    var gfr_g4: CkdStage = ckd_epi_gfr(3.5, 70.0, Sex.MALE);
    var gfr_g4_val: float = ckd_epi_gfr_value(3.5, 70.0, Sex.MALE);
    print(gfr_g4_val, newLine=true);  // ~15-29

    // G5: cr=8.0, age=70, male → expect G5 warning
    var gfr_g5: CkdStage = ckd_epi_gfr(8.0, 70.0, Sex.MALE);
    var gfr_g5_val: float = ckd_epi_gfr_value(8.0, 70.0, Sex.MALE);
    print(gfr_g5_val, newLine=true);  // < 15

    // ============================================================
    // TEST 2 — Cockcroft-Gault
    // ============================================================
    // Normal male: age=40, weight=80kg, cr=1.0
    // CrCl = ((140-40)*80) / (72*1.0) = 8000/72 = 111.1
    var cg_normal: float = cockcroft_gault(40.0, 80.0, 1.0, Sex.MALE);
    print(cg_normal, newLine=true);  // ~111.1

    // Female same params: 111.1 * 0.85 = 94.4
    var cg_female: float = cockcroft_gault(40.0, 80.0, 1.0, Sex.FEMALE);
    print(cg_female, newLine=true);  // ~94.4

    // Severe impairment: age=75, weight=60kg, cr=4.0, male
    // CrCl = ((140-75)*60) / (72*4.0) = 3900/288 = 13.5 — should warn < 15
    var cg_severe: float = cockcroft_gault(75.0, 60.0, 4.0, Sex.MALE);
    print(cg_severe, newLine=true);  // ~13.5

    // ============================================================
    // TEST 3 — BUN/creatinine ratio
    // ============================================================
    // Normal: BUN=14, cr=1.0 → ratio=14 — no warning
    var bun_cr_normal: float = bun_creatinine_ratio(14.0, 1.0);
    print(bun_cr_normal, newLine=true);  // 14.0

    // Prerenal: BUN=42, cr=1.4 → ratio=30 — should warn > 20
    var bun_cr_prerenal: float = bun_creatinine_ratio(42.0, 1.4);
    print(bun_cr_prerenal, newLine=true);  // 30.0

    // Intrinsic: BUN=12, cr=2.0 → ratio=6 — should warn < 10
    var bun_cr_intrinsic: float = bun_creatinine_ratio(12.0, 2.0);
    print(bun_cr_intrinsic, newLine=true);  // 6.0

    // ============================================================
    // TEST 4 — FENa
    // ============================================================
    // Prerenal: urine_na=10, serum_cr=2.0, serum_na=140, urine_cr=80
    // FENa = (10*2.0)/(140*80)*100 = 20/11200*100 = 0.18% → PRERENAL
    var fena_pre_val: float = fena_value(10.0, 2.0, 140.0, 80.0);
    print(fena_pre_val, newLine=true);  // ~0.18
    var fena_pre: AkiLikelihood = fena(10.0, 2.0, 140.0, 80.0);

    // Intrinsic: urine_na=60, serum_cr=2.0, serum_na=140, urine_cr=40
    // FENa = (60*2.0)/(140*40)*100 = 120/5600*100 = 2.14% → INTRINSIC
    var fena_int_val: float = fena_value(60.0, 2.0, 140.0, 40.0);
    print(fena_int_val, newLine=true);  // ~2.14
    var fena_int: AkiLikelihood = fena(60.0, 2.0, 140.0, 40.0);

    // Indeterminate: urine_na=25, serum_cr=2.0, serum_na=140, urine_cr=60
    // FENa = (25*2.0)/(140*60)*100 = 50/8400*100 = 0.595% → hmm borderline
    var fena_ind_val: float = fena_value(25.0, 2.0, 140.0, 60.0);
    print(fena_ind_val, newLine=true);
    var fena_ind: AkiLikelihood = fena(25.0, 2.0, 140.0, 60.0);

    // ============================================================
    // TEST 5 — FEUrea
    // ============================================================
    // Prerenal: urine_urea=400, serum_cr=2.0, serum_urea=40, urine_cr=80
    // FEUrea = (400*2.0)/(40*80)*100 = 800/3200*100 = 25% → PRERENAL
    var feurea_pre_val: float = feurea_value(400.0, 2.0, 40.0, 80.0);
    print(feurea_pre_val, newLine=true);  // 25.0
    var feurea_pre: AkiLikelihood = feurea(400.0, 2.0, 40.0, 80.0);

    // Intrinsic: urine_urea=200, serum_cr=2.0, serum_urea=40, urine_cr=80
    // FEUrea = (200*2.0)/(40*80)*100 = 400/3200*100 = 12.5% → PRERENAL still
    // Push higher: urine_urea=600, serum_urea=30
    // FEUrea = (600*2.0)/(30*80)*100 = 1200/2400*100 = 50% → INTRINSIC
    var feurea_int_val: float = feurea_value(600.0, 2.0, 30.0, 80.0);
    print(feurea_int_val, newLine=true);  // 50.0
    var feurea_int: AkiLikelihood = feurea(600.0, 2.0, 30.0, 80.0);

};