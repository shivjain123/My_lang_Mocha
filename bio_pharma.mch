from "mocha-bio" import *;

function main(didLoad) -> null {

    // ============================================================
    // TEST 1 — elimination rate constant
    // ============================================================
    // CL=5.0 L/h, Vd=50.0 L → ke = 5/50 = 0.1 h⁻¹
    var ke: float = elimination_rate_constant(5.0, 50.0);
    print(ke, newLine=true);  // 0.1

    // ============================================================
    // TEST 2 — half-life
    // ============================================================
    // ke=0.1 → t½ = 0.693/0.1 = 6.93h
    var t_half: float = half_life(0.1);
    print(t_half, newLine=true);  // ~6.93

    // from CL/Vd directly: CL=5, Vd=50 → same result
    var t_half_2: float = half_life_from_cl_vd(5.0, 50.0);
    print(t_half_2, newLine=true);  // ~6.93

    // ============================================================
    // TEST 3 — volume of distribution
    // ============================================================
    // dose=500mg, C0=10 mg/L → Vd = 500/10 = 50L
    var vd: float = volume_of_distribution(500.0, 10.0);
    print(vd, newLine=true);  // 50.0

    // ============================================================
    // TEST 4 — clearance
    // ============================================================
    // ke=0.1, Vd=50 → CL = 0.1*50 = 5.0 L/h
    var cl: float = clearance(0.1, 50.0);
    print(cl, newLine=true);  // 5.0

    // ============================================================
    // TEST 5 — loading dose
    // ============================================================
    // Vd=50L, target=10 mg/L → LD = 50*10 = 500mg
    var ld: float = loading_dose(50.0, 10.0);
    print(ld, newLine=true);  // 500.0

    // ============================================================
    // TEST 6 — maintenance dose
    // ============================================================
    // CL=5 L/h, target=10 mg/L, tau=8h → MD = 5*10*8 = 400mg
    var md: float = maintenance_dose(5.0, 10.0, 8.0);
    print(md, newLine=true);  // 400.0

    // ============================================================
    // TEST 7 — bioavailability adjusted dose
    // ============================================================
    // Oral F=0.6, intended=100mg → adjusted = 100/0.6 = 166.67mg
    var adj_oral: float = bioavailability_adjusted_dose(100.0, 0.6, RouteOfAdministration.ORAL);
    print(adj_oral, newLine=true);  // ~166.67

    // IV F=1.0 — no adjustment needed
    var adj_iv: float = bioavailability_adjusted_dose(100.0, 1.0, RouteOfAdministration.IV);
    print(adj_iv, newLine=true);  // 100.0

    // IV with F != 1.0 — should warn
    var adj_iv_bad: float = bioavailability_adjusted_dose(100.0, 0.8, RouteOfAdministration.IV);
    print(adj_iv_bad, newLine=true);  // 125.0 with warning

    // ============================================================
    // TEST 8 — concentration at time
    // ============================================================
    // C0=10 mg/L, ke=0.1, t=0 → C = 10 * e^0 = 10.0
    var ct_0: float = concentration_at_time(10.0, 0.1, 0.0);
    print(ct_0, newLine=true);  // 10.0

    // t=6.93 (one half-life) → C ≈ 5.0
    var ct_half: float = concentration_at_time(10.0, 0.1, 6.93);
    print(ct_half, newLine=true);  // ~5.0

    // t=20h → C = 10 * e^(-0.1*20) = 10 * e^(-2) = 10 * 0.1353 = 1.353
    var ct_20: float = concentration_at_time(10.0, 0.1, 20.0);
    print(ct_20, newLine=true);  // ~1.353

    // ============================================================
    // TEST 9 — steady state concentration
    // ============================================================
    // F=1.0, dose=400mg, CL=5 L/h, tau=8h
    // Css = (1.0*400)/(5*8) = 400/40 = 10.0 mg/L
    var css: float = steady_state_concentration(1.0, 400.0, 5.0, 8.0);
    print(css, newLine=true);  // 10.0

    // Oral F=0.6, dose=400mg, CL=5, tau=8
    // Css = (0.6*400)/(5*8) = 240/40 = 6.0 mg/L
    var css_oral: float = steady_state_concentration(0.6, 400.0, 5.0, 8.0);
    print(css_oral, newLine=true);  // 6.0

    // ============================================================
    // TEST 10 — accumulation factor
    // ============================================================
    // ke=0.1, tau=8h → R = 1/(1 - e^(-0.8))
    // e^(-0.8) = 0.4493 → 1 - 0.4493 = 0.5507 → R = 1.816
    var r_normal: float = accumulation_factor(0.1, 8.0);
    print(r_normal, newLine=true);  // ~1.816

    // High accumulation: ke=0.05, tau=4h → ke*tau=0.2
    // e^(-0.2) = 0.8187 → 1-0.8187 = 0.1813 → R = 5.516
    var r_high: float = accumulation_factor(0.05, 4.0);
    print(r_high, newLine=true);  // ~5.516

    // ============================================================
    // TEST 11 — Hill equation effect
    // ============================================================
    // n=1 (simple): C=EC50=5, Emax=100 → E = 100*5/(5+5) = 50.0 (50% by definition)
    var hill_half: float = hill_effect(5.0, 100.0, 5.0, 1.0);
    print(hill_half, newLine=true);  // 50.0

    // C=0 → E=0
    var hill_zero: float = hill_effect(0.0, 100.0, 5.0, 1.0);
    print(hill_zero, newLine=true);  // 0.0

    // C >> EC50: C=50, EC50=5, n=1 → E = 100*50/(5+50) = 5000/55 = 90.9
    var hill_high: float = hill_effect(50.0, 100.0, 5.0, 1.0);
    print(hill_high, newLine=true);  // ~90.9

    // Cooperative n=2: C=EC50=5 → still 50% by definition
    var hill_coop: float = hill_effect(5.0, 100.0, 5.0, 2.0);
    print(hill_coop, newLine=true);  // 50.0

    // ============================================================
    // TEST 12 — Hill equation inverse
    // ============================================================
    // E=50, Emax=100, EC50=5, n=1 → C = 5*(50/50)^1 = 5.0
    var hill_inv_half: float = hill_concentration(50.0, 100.0, 5.0, 1.0);
    print(hill_inv_half, newLine=true);  // 5.0

    // E=90, Emax=100, EC50=5, n=1 → C = 5*(90/10)^1 = 5*9 = 45.0
    var hill_inv_high: float = hill_concentration(90.0, 100.0, 5.0, 1.0);
    print(hill_inv_high, newLine=true);  // 45.0

    // E=90, Emax=100, EC50=5, n=2 → C = 5*(90/10)^0.5 = 5*3 = 15.0
    var hill_inv_coop: float = hill_concentration(90.0, 100.0, 5.0, 2.0);
    print(hill_inv_coop, newLine=true);  // 15.0

    // E >= Emax — should error and exit
    var hill_inv_bad: float = hill_concentration(100.0, 100.0, 5.0, 1.0);
    print(hill_inv_bad, newLine=true);

};