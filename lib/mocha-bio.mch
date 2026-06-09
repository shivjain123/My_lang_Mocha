// mocha-lib-deps: mocha-math
"""
    mocha-bio v0.1 — Mocha Biology Library
    Sections:=
    1. Cardiovascular
"""

//FFI Wrappers
function c_print_err(msg: str) -> null native mocha_print_stderr;
function c_exit(code: int) -> null native mocha_exit;
function c_sqrt(x: float) -> float native mocha_wrap_sqrt_f;
function c_exp(x: float) -> float native mocha_wrap_exp;

"""  ========================
     CONSTANTS
     ========================  """

const SYSTOLIC_MIN: float = 50.0;
const SYSTOLIC_MAX: float = 300.0;
const DIASTOLIC_MIN: float = 20.0;
const DIASTOLIC_MAX: float = 200.0;
const HR_MIN: float = 20.0;
const HR_MAX: float = 300.0;
const SV_MIN: float = 10.0;
const SV_MAX: float = 200.0;
const EF_MIN: float = 0.0;
const EF_MAX: float = 100.0;
const WEIGHT_MIN: float = 1.0;
const WEIGHT_MAX: float = 500.0;
const HEIGHT_MIN: float = 30.0;
const HEIGHT_MAX: float = 250.0;
const AORTIC_DISSECTION_RISK_THRESHOLD: float = 2.75;

"""  ========================
     VALIDATORS
     ========================  """

function validate_systolic(systolic: float) -> null {
    if (systolic < SYSTOLIC_MIN || systolic > SYSTOLIC_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): systolic pressure out of physiological range (50-300 mmHg).");
    };
};

function validate_diastolic(diastolic: float) -> null {
    if (diastolic < DIASTOLIC_MIN || diastolic > DIASTOLIC_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): diastolic pressure out of physiological range (20-200 mmHg).");
    };
};

function validate_heart_rate(hr: float) -> null {
    if (hr < HR_MIN || hr > HR_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): heart rate out of physiological range (20-300 bpm).");
    };
};

function validate_stroke_volume(sv: float) -> null {
    if (sv < SV_MIN || sv > SV_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): stroke volume out of physiological range (10-200 mL).");
    };
};

function validate_ejection_fraction(ef: float) -> null {
    if (ef < EF_MIN || ef > EF_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): ejection fraction out of physiological range (0-100%).");
    };
};

function validate_bsa_inputs(weight_kg: float, height_cm: float) -> null {
    if (weight_kg < WEIGHT_MIN || weight_kg > WEIGHT_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): weight out of physiological range (1-500 kg).");
    };
    if (height_cm < HEIGHT_MIN || height_cm > HEIGHT_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): height out of physiological range (30-250 cm).");
    };
};

"""  ========================
     CARDIOVASCULAR FORMULAE
     ========================  """

~~ MAP = diastolic + (1/3 * pulse_pressure)
~~ Normal range: 70-100 mmHg
function mean_arterial_pressure(systolic: float, diastolic: float) -> float {
    validate_systolic(systolic);
    validate_diastolic(diastolic);
    if (diastolic >= systolic) {
        c_print_err("MochaBioWarning (mocha-bio): diastolic >= systolic is physiologically impossible.");
    };
    return diastolic + ((systolic - diastolic) / 3.0);
};

~~ Pulse pressure = systolic - diastolic
~~ Normal range: 40 mmHg
~~ > 60 mmHg suggests aortic stiffness
function pulse_pressure(systolic: float, diastolic: float) -> float {
    validate_systolic(systolic);
    validate_diastolic(diastolic);
    if (diastolic >= systolic) {
        c_print_err("MochaBioWarning (mocha-bio): diastolic >= systolic is physiologically impossible.");
    };
    var pp: float = systolic - diastolic;
    if (pp > 60.0) {
        c_print_err("MochaBioWarning (mocha-bio): pulse pressure > 60 mmHg suggests aortic stiffness.");
    };
    return pp;
};

~~ Cardiac output = heart_rate * stroke_volume / 1000
~~ Result in L/min
~~ Normal range: 4-8 L/min
function cardiac_output(heart_rate: float, stroke_volume: float) -> float {
    validate_heart_rate(heart_rate);
    validate_stroke_volume(stroke_volume);
    var co: float = (heart_rate * stroke_volume) / 1000.0;
    if (co < 4.0 || co > 8.0) {
        c_print_err("MochaBioWarning (mocha-bio): cardiac output outside normal range (4-8 L/min).");
    };
    return co;
};

~~ Cardiac index = cardiac_output / body_surface_area
~~ Result in L/min/m²
~~ Normal range: 2.5-4.0 L/min/m²
function cardiac_index(cardiac_output: float, body_surface_area: float) -> float {
    if (body_surface_area <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): body_surface_area must be positive.");
        c_exit(2);
        return 0.0;
    };
    var ci: float = cardiac_output / body_surface_area;
    if (ci < 2.5 || ci > 4.0) {
        c_print_err("MochaBioWarning (mocha-bio): cardiac index outside normal range (2.5-4.0 L/min/m²).");
    };
    return ci;
};

~~ Ejection fraction = (stroke_volume / end_diastolic_volume) * 100
~~ Result in %
~~ Normal: >= 55%
~~ Reduced: < 40%
function ejection_fraction(stroke_volume: float, end_diastolic_volume: float) -> float {
    validate_stroke_volume(stroke_volume);
    if (end_diastolic_volume <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): end_diastolic_volume must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (stroke_volume > end_diastolic_volume) {
        c_print_err("MochaBioWarning (mocha-bio): stroke_volume cannot exceed end_diastolic_volume.");
    };
    var ef: float = (stroke_volume / end_diastolic_volume) * 100.0;
    validate_ejection_fraction(ef);
    if (ef < 40.0) {
        c_print_err("MochaBioWarning (mocha-bio): ejection fraction < 40% indicates reduced cardiac function.");
    };
    return ef;
};

~~ Stroke volume = end_diastolic_volume - end_systolic_volume
~~ Result in mL
function stroke_volume(end_diastolic: float, end_systolic: float) -> float {
    if (end_diastolic <= 0.0 || end_systolic <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): volumes must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (end_systolic >= end_diastolic) {
        c_print_err("MochaBioWarning (mocha-bio): end_systolic >= end_diastolic is physiologically impossible.");
    };
    var sv: float = end_diastolic - end_systolic;
    validate_stroke_volume(sv);
    return sv;
};

~~ Body surface area — Mosteller formula
~~ BSA = sqrt((weight_kg * height_cm) / 3600)
~~ Result in m²
function body_surface_area(weight_kg: float, height_cm: float) -> float {
    validate_bsa_inputs(weight_kg, height_cm);
    return c_sqrt((weight_kg * height_cm) / 3600.0);
};

~~ Rate pressure product = heart_rate * systolic
~~ Indicator of myocardial oxygen demand
~~ > 20000 indicates high cardiac stress
function rate_pressure_product(heart_rate: float, systolic: float) -> float {
    validate_heart_rate(heart_rate);
    validate_systolic(systolic);
    var rpp: float = heart_rate * systolic;
    if (rpp > 20000.0) {
        c_print_err("MochaBioWarning (mocha-bio): rate pressure product > 20000 indicates high myocardial oxygen demand.");
    };
    return rpp;
};

~~ Aortic size index = aortic_diameter_cm / body_surface_area
~~ Result in cm/m²
~~ > 2.75 cm/m² indicates high risk of aortic dissection
function aortic_size_index(aortic_diameter_cm: float, body_surface_area: float) -> float {
    if (aortic_diameter_cm <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): aortic_diameter_cm must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (body_surface_area <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): body_surface_area must be positive.");
        c_exit(2);
        return 0.0;
    };
    var asi: float = aortic_diameter_cm / body_surface_area;
    if (asi > AORTIC_DISSECTION_RISK_THRESHOLD) {
        c_print_err("MochaBioWarning (mocha-bio): aortic size index > 2.75 cm/m² indicates high risk of aortic dissection.");
    };
    return asi;
};

"""  ========================
     TAGS
     ========================  """

tag Sex {
    MALE,
    FEMALE
};

tag SmokingStatus {
    SMOKER,
    NON_SMOKER
};

"""  ========================
     CARDIOVASCULAR FORMULAE (continued)
     ========================  """

~~ Systemic vascular resistance = ((MAP - CVP) / cardiac_output) * 80
~~ Result in dynes·s/cm⁵
~~ Normal range: 800–1200 dynes·s/cm⁵
~~ CVP (central venous pressure) normal range: 2–8 mmHg
function svr(map: float, cvp: float, cardiac_output: float) -> float {
    if (cvp < 0.0 || cvp > 20.0) {
        c_print_err("MochaBioWarning (mocha-bio): CVP out of physiological range (0-20 mmHg).");
    };
    if (cardiac_output <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): cardiac_output must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (cvp >= map) {
        c_print_err("MochaBioWarning (mocha-bio): CVP >= MAP is physiologically impossible.");
    };
    var result: float = ((map - cvp) / cardiac_output) * 80.0;
    if (result < 800.0 || result > 1200.0) {
        c_print_err("MochaBioWarning (mocha-bio): SVR outside normal range (800-1200 dynes·s/cm⁵).");
    };
    return result;
};

~~ QTc (Bazett) = QT_ms / sqrt(RR_s)
~~ where RR_s = 60.0 / heart_rate (in seconds)
~~ Result in ms
~~ Normal: < 440 ms (male), < 460 ms (female)
~~ > 500 ms: high risk of torsades de pointes
function qtc_bazett(qt_ms: float, heart_rate: float, sex: Sex) -> float {
    validate_heart_rate(heart_rate);
    if (qt_ms <= 0.0 || qt_ms > 800.0) {
        c_print_err("MochaBioWarning (mocha-bio): QT interval out of physiological range (0-800 ms).");
    };
    var rr_s: float = 60.0 / heart_rate;
    var qtc: float = qt_ms / c_sqrt(rr_s);
    var threshold: float = 440.0;
    if (sex == Sex.FEMALE) {
        threshold = 460.0;
    };
    if (qtc > threshold) {
        c_print_err("MochaBioWarning (mocha-bio): QTc exceeds sex-specific normal threshold (>440ms male, >460ms female).");
    };
    if (qtc > 500.0) {
        c_print_err("MochaBioWarning (mocha-bio): QTc > 500 ms — high risk of torsades de pointes.");
    };
    return qtc;
};

~~ Shock index = heart_rate / systolic_pressure
~~ Normal: 0.5–0.7
~~ > 1.0: significant haemodynamic compromise
~~ > 1.4: critical — consider immediate intervention
function shock_index(heart_rate: float, systolic: float) -> float {
    validate_heart_rate(heart_rate);
    validate_systolic(systolic);
    if (systolic <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): systolic must be positive.");
        c_exit(2);
        return 0.0;
    };
    var si: float = heart_rate / systolic;
    if (si > 1.4) {
        c_print_err("MochaBioWarning (mocha-bio): shock index > 1.4 — critical haemodynamic compromise.");
    } else if (si > 1.0) {
        c_print_err("MochaBioWarning (mocha-bio): shock index > 1.0 — significant haemodynamic compromise.");
    };
    return si;
};

~~ VO2 max (Fick) = cardiac_output * (cao2 - cvo2)
~~ cao2: arterial oxygen content (mL O₂ / dL blood)
~~ cvo2: mixed venous oxygen content (mL O₂ / dL blood)
~~ cardiac_output in L/min → multiply by 10 to convert dL
~~ Result in mL O₂/min
~~ Normal a-vO₂ difference at rest: 4–6 mL O₂/dL
~~ At peak exercise: up to 15–16 mL O₂/dL
function vo2_max_fick(cardiac_output: float, cao2: float, cvo2: float) -> float {
    if (cardiac_output <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): cardiac_output must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (cao2 <= 0.0 || cvo2 < 0.0) {
        c_print_err("MochaBioError (mocha-bio): oxygen content values must be non-negative.");
        c_exit(2);
        return 0.0;
    };
    if (cvo2 >= cao2) {
        c_print_err("MochaBioWarning (mocha-bio): venous O₂ content >= arterial — physiologically impossible.");
    };
    var av_diff: float = cao2 - cvo2;
    if (av_diff < 4.0 || av_diff > 16.0) {
        c_print_err("MochaBioWarning (mocha-bio): a-vO₂ difference outside expected range (4-16 mL O₂/dL).");
    };
    // cardiac_output is L/min, multiply by 10 to get dL/min
    return cardiac_output * 10.0 * av_diff;
};

~~ Framingham 10-year Hard CHD risk (D'Agostino et al.)
~~ Uses natural log of inputs — do NOT pass pre-logged values
~~ total_cholesterol, hdl_cholesterol in mg/dL
~~ systolic in mmHg, age in years (valid range: 30–79)
~~ bp_treated: true if patient is on BP medication
~~ Non-diabetic patients only — excludes angina pectoris history
~~ Returns risk as a percentage (0.0–100.0)
function framingham_risk(
    age: float,
    sex: Sex,
    total_cholesterol: float,
    hdl_cholesterol: float,
    systolic: float,
    bp_treated: bool,
    smoking: SmokingStatus
) -> float {
    if (age < 30.0 || age > 79.0) {
        c_print_err("MochaBioWarning (mocha-bio): Framingham Hard CHD equation validated for ages 30-79 only.");
    };
    if (total_cholesterol <= 0.0 || hdl_cholesterol <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): cholesterol values must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (hdl_cholesterol >= total_cholesterol) {
        c_print_err("MochaBioWarning (mocha-bio): HDL >= total cholesterol is physiologically implausible.");
    };
    validate_systolic(systolic);

    var smoke_flag: float = 0.0;
    if (smoking == SmokingStatus.SMOKER) {
        smoke_flag = 1.0;
    };
    var bp_flag: float = 0.0;
    if (bp_treated) {
        bp_flag = 1.0;
    };

    var ln_age: float = age.log().real;
    var ln_tc: float = total_cholesterol.log().real;
    var ln_hdl: float = hdl_cholesterol.log().real;
    var ln_sbp: float = systolic.log().real;

    var l: float = 0.0;
    var risk: float = 0.0;

    if (sex == Sex.MALE) {
        var ln_age_smoke: float = ln_age;
        if (age > 70.0) {
            ln_age_smoke = (70.0).log().real;
        };
        l = (52.00961  * ln_age)
          + (20.014077 * ln_tc)
          - (0.905964  * ln_hdl)
          + (1.305784  * ln_sbp)
          + (0.241549  * bp_flag)
          + (12.096316 * smoke_flag)
          - (4.605038  * ln_age * ln_tc)
          - (2.84367   * ln_age_smoke * smoke_flag)
          - (2.93323   * ln_age * ln_age)
          - 172.300168;
        risk = (1.0 - c_pow(0.9402, c_exp(l))) * 100.0;
    } else {
        var ln_age_smoke: float = ln_age;
        if (age > 78.0) {
            ln_age_smoke = (78.0).log().real;
        };
        l = (31.764001 * ln_age)
          + (22.465206 * ln_tc)
          - (1.187731  * ln_hdl)
          + (2.552905  * ln_sbp)
          + (0.420251  * bp_flag)
          + (13.07543  * smoke_flag)
          - (5.060998  * ln_age * ln_tc)
          - (2.996945  * ln_age_smoke * smoke_flag)
          - 146.5933061;
        risk = (1.0 - c_pow(0.98767, c_exp(l))) * 100.0;
    };

    if (risk > 20.0) {
        c_print_err("MochaBioWarning (mocha-bio): Framingham 10-year Hard CHD risk > 20% — high risk category.");
    } else if (risk > 10.0) {
        c_print_err("MochaBioWarning (mocha-bio): Framingham 10-year Hard CHD risk 10-20% — intermediate risk category.");
    };
    return risk;
};

"""  ========================
     PULMONARY CONSTANTS
     ========================  """

const SEA_LEVEL_ATM_PRESSURE: float = 760.0;
const STANDARD_RQ: float = 0.8;
const WATER_VAPOUR_PRESSURE: float = 47.0;
const RR_MIN: float = 4.0;
const RR_MAX: float = 60.0;
const FIO2_MIN: float = 0.21;
const FIO2_MAX: float = 1.0;
const HGB_MIN: float = 1.0;
const HGB_MAX: float = 25.0;

"""  ========================
     PULMONARY VALIDATORS
     ========================  """

function validate_respiratory_rate(rr: float) -> null {
    if (rr < RR_MIN || rr > RR_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): respiratory rate out of physiological range (4-60 breaths/min).");
    };
};

function validate_fio2(fio2: float) -> null {
    if (fio2 < FIO2_MIN || fio2 > FIO2_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): FiO2 out of range (0.21-1.0). Room air = 0.21, pure O2 = 1.0.");
    };
};

function validate_hgb(hgb: float) -> null {
    if (hgb < HGB_MIN || hgb > HGB_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): haemoglobin out of physiological range (1-25 g/dL).");
    };
};

"""  ========================
     PULMONARY TAGS
     ========================  """

tag ArdsSeverity {
    MILD,
    MODERATE,
    SEVERE,
    NONE
};

"""  ========================
     PULMONARY FORMULAE
     ========================  """

~~ Ideal body weight (Devine formula)
~~ Male:   IBW = 50.0 + 2.3 * ((height_cm / 2.54) - 60)
~~ Female: IBW = 45.5 + 2.3 * ((height_cm / 2.54) - 60)
~~ Result in kg
~~ Valid for height > 152.4 cm (5 feet) — below this IBW = actual weight
function ideal_body_weight(height_cm: float, sex: Sex) -> float {
    if (height_cm < HEIGHT_MIN || height_cm > HEIGHT_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): height out of physiological range (30-250 cm).");
    };
    if (height_cm < 152.4) {
        c_print_err("MochaBioWarning (mocha-bio): IBW Devine formula not valid below 152.4 cm — returning height-based estimate.");
        return height_cm * 0.4;
    };
    var height_in: float = height_cm / 2.54;
    var inches_over: float = height_in - 60.0;
    if (sex == Sex.MALE) {
        return 50.0 + (2.3 * inches_over);
    } else {
        return 45.5 + (2.3 * inches_over);
    };
};

~~ Tidal volume = 6-8 mL/kg IBW (lung protective ventilation)
~~ Uses 6 mL/kg — ARDSnet lower limit, safest default
~~ Result in mL
~~ Normal spontaneous tidal volume: 400-600 mL
function tidal_volume(ibw_kg: float) -> float {
    if (ibw_kg <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): ibw_kg must be positive.");
        c_exit(2);
        return 0.0;
    };
    var tv: float = 6.0 * ibw_kg;
    if (tv < 400.0 || tv > 600.0) {
        c_print_err("MochaBioWarning (mocha-bio): tidal volume outside normal spontaneous range (400-600 mL).");
    };
    return tv;
};

~~ Minute ventilation = tidal_volume * respiratory_rate
~~ Result in L/min
~~ Normal range: 5-10 L/min
function minute_ventilation(tidal_volume_ml: float, respiratory_rate: float) -> float {
    validate_respiratory_rate(respiratory_rate);
    if (tidal_volume_ml <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): tidal_volume_ml must be positive.");
        c_exit(2);
        return 0.0;
    };
    var mv: float = (tidal_volume_ml * respiratory_rate) / 1000.0;
    if (mv < 5.0 || mv > 10.0) {
        c_print_err("MochaBioWarning (mocha-bio): minute ventilation outside normal range (5-10 L/min).");
    };
    return mv;
};

~~ Alveolar partial pressure of oxygen
~~ PAO2 = FiO2 * (Patm - PH2O) - (PaCO2 / RQ)
~~ PH2O = 47 mmHg at body temperature (constant)
~~ Result in mmHg
~~ Exposed standalone — useful independently of A-a gradient
function alveolar_po2(fio2: float, patm: float, paco2: float, rq: float) -> float {
    validate_fio2(fio2);
    if (patm < 400.0 || patm > 800.0) {
        c_print_err("MochaBioWarning (mocha-bio): atmospheric pressure out of expected range (400-800 mmHg).");
    };
    if (paco2 <= 0.0 || paco2 > 100.0) {
        c_print_err("MochaBioWarning (mocha-bio): PaCO2 out of physiological range (0-100 mmHg).");
    };
    if (rq <= 0.0 || rq > 1.5) {
        c_print_err("MochaBioWarning (mocha-bio): respiratory quotient out of expected range (0-1.5).");
    };
    return (fio2 * (patm - WATER_VAPOUR_PRESSURE)) - (paco2 / rq);
};

~~ Alveolar-arterial oxygen gradient
~~ A-a gradient = PAO2 - PaO2
~~ Normal range: increases with age — roughly (age / 4) mmHg
~~ > 15 mmHg on room air suggests V/Q mismatch or shunt
function aa_gradient(fio2: float, patm: float, paco2: float, pao2: float, rq: float) -> float {
    if (pao2 <= 0.0 || pao2 > 700.0) {
        c_print_err("MochaBioWarning (mocha-bio): PaO2 out of physiological range (0-700 mmHg).");
    };
    var pa_o2: float = alveolar_po2(fio2, patm, paco2, rq);
    var gradient: float = pa_o2 - pao2;
    if (gradient < 0.0) {
        c_print_err("MochaBioWarning (mocha-bio): negative A-a gradient — check inputs, PaO2 cannot exceed PAO2.");
    };
    if (gradient > 15.0) {
        c_print_err("MochaBioWarning (mocha-bio): A-a gradient > 15 mmHg suggests V/Q mismatch or intrapulmonary shunt.");
    };
    return gradient;
};

~~ FEV1/FVC ratio
~~ FEV1: forced expiratory volume in 1 second (L)
~~ FVC: forced vital capacity (L)
~~ < 0.70 suggests obstructive pattern (asthma, COPD)
~~ >= 0.70 with reduced FVC suggests restrictive pattern
function fev1_fvc_ratio(fev1: float, fvc: float) -> float {
    if (fev1 <= 0.0 || fvc <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): FEV1 and FVC must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (fev1 > fvc) {
        c_print_err("MochaBioWarning (mocha-bio): FEV1 > FVC is physiologically impossible.");
    };
    var ratio: float = fev1 / fvc;
    if (ratio < 0.70) {
        c_print_err("MochaBioWarning (mocha-bio): FEV1/FVC < 0.70 suggests obstructive pattern.");
    };
    return ratio;
};

~~ Dead space fraction (Bohr equation)
~~ Vd/Vt = (PaCO2 - PECO2) / PaCO2
~~ PaCO2: arterial CO2 (mmHg)
~~ PECO2: mixed expired CO2 (mmHg)
~~ Normal: 0.2-0.35 (20-35% of tidal volume is dead space)
~~ > 0.6 associated with poor outcomes in ARDS
function dead_space_fraction(paco2: float, peco2: float) -> float {
    if (paco2 <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): PaCO2 must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (peco2 < 0.0 || peco2 > paco2) {
        c_print_err("MochaBioWarning (mocha-bio): PECO2 must be between 0 and PaCO2.");
    };
    var vd_vt: float = (paco2 - peco2) / paco2;
    if (vd_vt < 0.2 || vd_vt > 0.35) {
        c_print_err("MochaBioWarning (mocha-bio): dead space fraction outside normal range (0.20-0.35).");
    };
    if (vd_vt > 0.6) {
        c_print_err("MochaBioWarning (mocha-bio): dead space fraction > 0.6 — associated with poor outcomes in ARDS.");
    };
    return vd_vt;
};

~~ Static lung compliance
~~ C = tidal_volume / (plateau_pressure - peep)
~~ Result in mL/cmH2O
~~ Normal: 60-100 mL/cmH2O
~~ < 40 mL/cmH2O suggests stiff lungs (ARDS, pulmonary fibrosis)
function lung_compliance(tidal_volume_ml: float, plateau_pressure: float, peep: float) -> float {
    if (tidal_volume_ml <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): tidal_volume_ml must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (peep < 0.0 || plateau_pressure <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): pressures must be non-negative and plateau_pressure must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (peep >= plateau_pressure) {
        c_print_err("MochaBioWarning (mocha-bio): PEEP >= plateau pressure is physiologically impossible.");
    };
    var driving_pressure: float = plateau_pressure - peep;
    var compliance: float = tidal_volume_ml / driving_pressure;
    if (compliance < 60.0 || compliance > 100.0) {
        c_print_err("MochaBioWarning (mocha-bio): lung compliance outside normal range (60-100 mL/cmH2O).");
    };
    if (compliance < 40.0) {
        c_print_err("MochaBioWarning (mocha-bio): lung compliance < 40 mL/cmH2O — suggests ARDS or pulmonary fibrosis.");
    };
    return compliance;
};

~~ PaO2/FiO2 ratio (P/F ratio)
~~ Result in mmHg
~~ Normal > 300
function pf_ratio(pao2: float, fio2: float) -> float {
    if (pao2 <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): PaO2 must be positive.");
        c_exit(2);
        return 0.0;
    };
    validate_fio2(fio2);
    if (fio2 <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): FiO2 must be positive.");
        c_exit(2);
        return 0.0;
    };
    return pao2 / fio2;
};

~~ ARDS severity classifier — Berlin criteria
~~ Pass result of pf_ratio() directly
~~ > 300: no ARDS
~~ 200-300: mild
~~ 100-200: moderate
~~ < 100: severe
function ards_severity(pf: float) -> ArdsSeverity {
    if (pf <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): P/F ratio must be positive.");
        c_exit(2);
        return ArdsSeverity.NONE;
    };
    if (pf < 100.0) {
        c_print_err("MochaBioWarning (mocha-bio): P/F ratio < 100 — severe ARDS.");
        return ArdsSeverity.SEVERE;
    } else if (pf < 200.0) {
        c_print_err("MochaBioWarning (mocha-bio): P/F ratio 100-200 — moderate ARDS.");
        return ArdsSeverity.MODERATE;
    } else if (pf < 300.0) {
        c_print_err("MochaBioWarning (mocha-bio): P/F ratio 200-300 — mild ARDS.");
        return ArdsSeverity.MILD;
    };
    return ArdsSeverity.NONE;
};

~~ Oxygen content of blood (CaO2)
~~ CaO2 = (Hgb * 1.34 * SaO2) + (0.0031 * PaO2)
~~ Hgb in g/dL, SaO2 as fraction (0.0-1.0), PaO2 in mmHg
~~ Result in mL O2/dL blood
~~ 1.34 = Hüfner constant (O2 carrying capacity per gram Hgb)
~~ 0.0031 = dissolved O2 coefficient
~~ Normal arterial: ~20 mL O2/dL
function oxygen_content(hgb: float, sao2: float, pao2: float) -> float {
    validate_hgb(hgb);
    if (sao2 < 0.0 || sao2 > 1.0) {
        c_print_err("MochaBioWarning (mocha-bio): SaO2 must be a fraction between 0.0 and 1.0.");
    };
    if (pao2 <= 0.0 || pao2 > 700.0) {
        c_print_err("MochaBioWarning (mocha-bio): PaO2 out of physiological range (0-700 mmHg).");
    };
    if (sao2 < 0.90) {
        c_print_err("MochaBioWarning (mocha-bio): SaO2 < 0.90 indicates significant hypoxaemia.");
    };
    var bound_o2: float = hgb * 1.34 * sao2;
    var dissolved_o2: float = 0.0031 * pao2;
    var cao2: float = bound_o2 + dissolved_o2;
    if (cao2 < 16.0 || cao2 > 22.0) {
        c_print_err("MochaBioWarning (mocha-bio): oxygen content outside normal arterial range (16-22 mL O2/dL).");
    };
    return cao2;
};

"""  ========================
     NEUROLOGY CONSTANTS
     ========================  """

const ICP_MAX_NORMAL: float = 15.0;
const CPP_MIN_NORMAL: float = 60.0;
const CPP_MAX_NORMAL: float = 80.0;
const NA_MIN: float = 100.0;
const NA_MAX: float = 180.0;
const GLUCOSE_MIN: float = 20.0;
const GLUCOSE_MAX: float = 800.0;
const BUN_MIN: float = 0.0;
const BUN_MAX: float = 200.0;
const OSMOLALITY_MIN: float = 275.0;
const OSMOLALITY_MAX: float = 295.0;
const AVDO2_MIN: float = 0.04;
const AVDO2_MAX: float = 0.09;

"""  ========================
     NEUROLOGY VALIDATORS
     ========================  """

function validate_sodium(na: float) -> null {
    if (na < NA_MIN || na > NA_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): sodium out of physiological range (100-180 mEq/L).");
    };
};

function validate_glucose(glucose: float) -> null {
    if (glucose < GLUCOSE_MIN || glucose > GLUCOSE_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): glucose out of physiological range (20-800 mg/dL).");
    };
};

function validate_icp(icp: float) -> null {
    if (icp < 0.0 || icp > 100.0) {
        c_print_err("MochaBioWarning (mocha-bio): ICP out of physiological range (0-100 mmHg).");
    };
};

"""  ========================
     NEUROLOGY TAGS
     ========================  """

tag GcsEye {
    NO_RESPONSE,
    TO_PAIN,
    TO_VOICE,
    SPONTANEOUS
};

tag GcsVerbal {
    NO_RESPONSE,
    INCOMPREHENSIBLE,
    INAPPROPRIATE,
    CONFUSED,
    ORIENTED
};

tag GcsMotor {
    NO_RESPONSE,
    EXTENSION_POSTURING,
    FLEXION_POSTURING,
    WITHDRAWAL,
    LOCALISING,
    OBEYS_COMMANDS
};

tag GcsSeverity {
    SEVERE,
    MODERATE,
    MILD
};

"""  ========================
     NEUROLOGY FORMULAE
     ========================  """

~~ Internal helpers — convert GCS Tag components to integer scores
function gcs_eye_score(eye: GcsEye) -> int {
    match(eye) {
        case GcsEye.NO_RESPONSE: return 1;
        case GcsEye.TO_PAIN:     return 2;
        case GcsEye.TO_VOICE:    return 3;
        case GcsEye.SPONTANEOUS: return 4;
        default:                 return 1;
    };
};

function gcs_verbal_score(verbal: GcsVerbal) -> int {
    match(verbal) {
        case GcsVerbal.NO_RESPONSE:      return 1;
        case GcsVerbal.INCOMPREHENSIBLE: return 2;
        case GcsVerbal.INAPPROPRIATE:    return 3;
        case GcsVerbal.CONFUSED:         return 4;
        case GcsVerbal.ORIENTED:         return 5;
        default:                         return 1;
    };
};

function gcs_motor_score(motor: GcsMotor) -> int {
    match(motor) {
        case GcsMotor.NO_RESPONSE:         return 1;
        case GcsMotor.EXTENSION_POSTURING: return 2;
        case GcsMotor.FLEXION_POSTURING:   return 3;
        case GcsMotor.WITHDRAWAL:          return 4;
        case GcsMotor.LOCALISING:          return 5;
        case GcsMotor.OBEYS_COMMANDS:      return 6;
        default:                           return 1;
    };
};

~~ Glasgow Coma Scale
~~ Total score 3–15
~~ Severe: 3–8, Moderate: 9–12, Mild: 13–15
~~ Score of 3 = no response in any component — deep coma or death
~~ Score of 8 or below = unable to protect airway — intubation threshold
function gcs(eye: GcsEye, verbal: GcsVerbal, motor: GcsMotor) -> GcsSeverity {
    var total: int = gcs_eye_score(eye) + gcs_verbal_score(verbal) + gcs_motor_score(motor);
    if (total <= 8) {
        if (total == 3) {
            c_print_err("MochaBioWarning (mocha-bio): GCS 3 — no response in all components, deep coma or brain death.");
        } else {
            c_print_err("MochaBioWarning (mocha-bio): GCS <= 8 — unable to protect airway, consider intubation.");
        };
        return GcsSeverity.SEVERE;
    } else if (total <= 12) {
        c_print_err("MochaBioWarning (mocha-bio): GCS 9-12 — moderate impairment, close monitoring required.");
        return GcsSeverity.MODERATE;
    };
    return GcsSeverity.MILD;
};

~~ GCS total score — returns raw int if caller needs the number
function gcs_score(eye: GcsEye, verbal: GcsVerbal, motor: GcsMotor) -> int {
    return gcs_eye_score(eye) + gcs_verbal_score(verbal) + gcs_motor_score(motor);
};

~~ Cerebral perfusion pressure
~~ CPP = MAP - ICP
~~ Result in mmHg
~~ Normal: 60–80 mmHg
~~ < 60 mmHg: cerebral ischaemia risk
~~ < 40 mmHg: severe — incompatible with consciousness
function cerebral_perfusion_pressure(map: float, icp: float) -> float {
    validate_icp(icp);
    if (icp > ICP_MAX_NORMAL) {
        c_print_err("MochaBioWarning (mocha-bio): ICP > 15 mmHg — intracranial hypertension.");
    };
    if (icp >= map) {
        c_print_err("MochaBioWarning (mocha-bio): ICP >= MAP — cerebral perfusion is critically compromised.");
    };
    var cpp: float = map - icp;
    if (cpp < 40.0) {
        c_print_err("MochaBioWarning (mocha-bio): CPP < 40 mmHg — severe, incompatible with consciousness.");
    } else if (cpp < CPP_MIN_NORMAL) {
        c_print_err("MochaBioWarning (mocha-bio): CPP < 60 mmHg — cerebral ischaemia risk.");
    } else if (cpp > CPP_MAX_NORMAL) {
        c_print_err("MochaBioWarning (mocha-bio): CPP > 80 mmHg — may indicate loss of cerebral autoregulation.");
    };
    return cpp;
};

~~ Cerebral blood flow (Fick principle)
~~ CBF = CMRO2 / AVDO2
~~ CMRO2: cerebral metabolic rate of O2 in mL O2/100g/min
~~ AVDO2: arteriovenous O2 difference in mL O2/100mL blood
~~ Result in mL/100g/min
~~ Normal CBF: 50–60 mL/100g/min
~~ < 20 mL/100g/min: ischaemic threshold
~~ < 10 mL/100g/min: infarction threshold
function cerebral_blood_flow(cmro2: float, avdo2: float) -> float {
    if (cmro2 <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): CMRO2 must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (avdo2 <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): AVDO2 must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (avdo2 < AVDO2_MIN || avdo2 > AVDO2_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): AVDO2 outside normal range (4-9 mL O2/100mL).");
    };
    var cbf: float = cmro2 / avdo2;
    if (cbf < 10.0) {
        c_print_err("MochaBioWarning (mocha-bio): CBF < 10 mL/100g/min — infarction threshold.");
    } else if (cbf < 20.0) {
        c_print_err("MochaBioWarning (mocha-bio): CBF < 20 mL/100g/min — ischaemic threshold.");
    } else if (cbf < 50.0 || cbf > 60.0) {
        c_print_err("MochaBioWarning (mocha-bio): CBF outside normal range (50-60 mL/100g/min).");
    };
    return cbf;
};

~~ Serum osmolality
~~ Osm = 2*Na + glucose/18 + BUN/2.8
~~ Na in mEq/L, glucose in mg/dL, BUN in mg/dL
~~ Result in mOsm/kg
~~ Normal: 275–295 mOsm/kg
~~ > 320 mOsm/kg: hyperosmolar state
function serum_osmolality(na: float, glucose: float, bun: float) -> float {
    validate_sodium(na);
    validate_glucose(glucose);
    if (bun < BUN_MIN || bun > BUN_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): BUN out of physiological range (0-200 mg/dL).");
    };
    var osm: float = (2.0 * na) + (glucose / 18.0) + (bun / 2.8);
    if (osm < OSMOLALITY_MIN || osm > OSMOLALITY_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): serum osmolality outside normal range (275-295 mOsm/kg).");
    };
    if (osm > 320.0) {
        c_print_err("MochaBioWarning (mocha-bio): serum osmolality > 320 mOsm/kg — hyperosmolar state.");
    };
    return osm;
};

~~ Osmolar gap
~~ Gap = measured_osm - calculated_osm
~~ calculated_osm should be from serum_osmolality()
~~ Normal: < 10 mOsm/kg
~~ > 10 mOsm/kg: suggests unmeasured osmoles — toxic alcohols, mannitol
function osmolar_gap(measured_osm: float, calculated_osm: float) -> float {
    if (measured_osm <= 0.0 || calculated_osm <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): osmolality values must be positive.");
        c_exit(2);
        return 0.0;
    };
    var gap: float = measured_osm - calculated_osm;
    if (gap > 10.0) {
        c_print_err("MochaBioWarning (mocha-bio): osmolar gap > 10 mOsm/kg — suggests toxic alcohols or unmeasured osmoles.");
    };
    if (gap < 0.0) {
        c_print_err("MochaBioWarning (mocha-bio): negative osmolar gap — verify measured and calculated osmolality inputs.");
    };
    return gap;
};

~~ Corrected sodium for hyperglycaemia
~~ Corrected Na = Na + 0.016 * (glucose - 100)
~~ Na in mEq/L, glucose in mg/dL
~~ Accounts for osmotic shift of water out of cells in hyperglycaemia
~~ Each 100 mg/dL rise in glucose above normal drops Na by ~1.6 mEq/L
function corrected_sodium(na: float, glucose: float) -> float {
    validate_sodium(na);
    validate_glucose(glucose);
    if (glucose <= 100.0) {
        c_print_err("MochaBioWarning (mocha-bio): glucose <= 100 mg/dL — sodium correction not indicated.");
    };
    var corrected: float = na + (0.016 * (glucose - 100.0));
    validate_sodium(corrected);
    return corrected;
};

"""  ========================
     RENAL CONSTANTS
     ========================  """

const CREATININE_MIN: float = 0.1;
const CREATININE_MAX: float = 20.0;
const POTASSIUM_MIN: float = 1.0;
const POTASSIUM_MAX: float = 9.0;
const FENA_PRERENAL_THRESHOLD: float = 1.0;
const FENA_INTRINSIC_THRESHOLD: float = 2.0;
const FEUREA_PRERENAL_THRESHOLD: float = 35.0;
const BUN_CR_PRERENAL_THRESHOLD: float = 20.0;

"""  ========================
     RENAL VALIDATORS
     ========================  """

function validate_creatinine(cr: float) -> null {
    if (cr < CREATININE_MIN || cr > CREATININE_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): creatinine out of physiological range (0.1-20 mg/dL).");
    };
};

function validate_potassium(k: float) -> null {
    if (k < POTASSIUM_MIN || k > POTASSIUM_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): potassium out of physiological range (1.0-9.0 mEq/L).");
    };
};

"""  ========================
     RENAL TAGS
     ========================  """

tag CkdStage {
    G1,
    G2,
    G3A,
    G3B,
    G4,
    G5
};

tag AkiLikelihood {
    PRERENAL,
    INTRINSIC,
    INDETERMINATE
};

"""  ========================
     RENAL FORMULAE
     ========================  """

~~ CKD-EPI GFR (2021 — no race coefficient)
~~ Serum creatinine in mg/dL, age in years
~~ Result in mL/min/1.73m²
~~ G1: >= 90, G2: 60-89, G3a: 45-59, G3b: 30-44, G4: 15-29, G5: < 15
function ckd_epi_gfr(serum_cr: float, age: float, sex: Sex) -> CkdStage {
    validate_creatinine(serum_cr);
    if (age < 18.0 || age > 120.0) {
        c_print_err("MochaBioWarning (mocha-bio): CKD-EPI validated for adults >= 18 years only.");
    };
    if (serum_cr <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): serum creatinine must be positive.");
        c_exit(2);
        return CkdStage.G5;
    };

    // 2021 CKD-EPI coefficients
    var kappa: float = 0.7;
    var alpha: float = -0.241;
    if (sex == Sex.MALE) {
        kappa = 0.9;
        alpha = -0.302;
    };

    var cr_kappa: float = serum_cr / kappa;
    var min_term: float = cr_kappa;
    if (min_term > 1.0) {
        min_term = 1.0;
    };
    var max_term: float = cr_kappa;
    if (max_term < 1.0) {
        max_term = 1.0;
    };

    var gfr: float = 142.0
        * c_pow(min_term, alpha)
        * c_pow(max_term, -1.200)
        * c_pow(0.9938, age);

    if (sex == Sex.FEMALE) {
        gfr = gfr * 1.012;
    };

    if (gfr >= 90.0) {
        return CkdStage.G1;
    } else if (gfr >= 60.0) {
        return CkdStage.G2;
    } else if (gfr >= 45.0) {
        c_print_err("MochaBioWarning (mocha-bio): GFR 45-59 mL/min/1.73m² — CKD stage G3a, mildly to moderately decreased.");
        return CkdStage.G3A;
    } else if (gfr >= 30.0) {
        c_print_err("MochaBioWarning (mocha-bio): GFR 30-44 mL/min/1.73m² — CKD stage G3b, moderately to severely decreased.");
        return CkdStage.G3B;
    } else if (gfr >= 15.0) {
        c_print_err("MochaBioWarning (mocha-bio): GFR 15-29 mL/min/1.73m² — CKD stage G4, severely decreased.");
        return CkdStage.G4;
    };
    c_print_err("MochaBioWarning (mocha-bio): GFR < 15 mL/min/1.73m² — CKD stage G5, kidney failure.");
    return CkdStage.G5;
};

~~ CKD-EPI GFR raw value — returns float if caller needs the number
~~ Same inputs as ckd_epi_gfr()
function ckd_epi_gfr_value(serum_cr: float, age: float, sex: Sex) -> float {
    validate_creatinine(serum_cr);
    if (age < 18.0 || age > 120.0) {
        c_print_err("MochaBioWarning (mocha-bio): CKD-EPI validated for adults >= 18 years only.");
    };
    if (serum_cr <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): serum creatinine must be positive.");
        c_exit(2);
        return 0.0;
    };

    var kappa: float = 0.7;
    var alpha: float = -0.241;
    if (sex == Sex.MALE) {
        kappa = 0.9;
        alpha = -0.302;
    };

    var cr_kappa: float = serum_cr / kappa;
    var min_term: float = cr_kappa;
    if (min_term > 1.0) {
        min_term = 1.0;
    };
    var max_term: float = cr_kappa;
    if (max_term < 1.0) {
        max_term = 1.0;
    };

    var gfr: float = 142.0
        * c_pow(min_term, alpha)
        * c_pow(max_term, -1.200)
        * c_pow(0.9938, age);

    if (sex == Sex.FEMALE) {
        gfr = gfr * 1.012;
    };
    return gfr;
};

~~ Cockcroft-Gault creatinine clearance
~~ CrCl = ((140 - age) * weight_kg) / (72 * serum_cr)
~~ Multiply by 0.85 for females
~~ Result in mL/min
~~ Used for drug dosing — not interchangeable with CKD-EPI GFR
function cockcroft_gault(age: float, weight_kg: float, serum_cr: float, sex: Sex) -> float {
    validate_creatinine(serum_cr);
    if (age < 18.0 || age > 120.0) {
        c_print_err("MochaBioWarning (mocha-bio): Cockcroft-Gault validated for adults >= 18 years only.");
    };
    if (weight_kg < WEIGHT_MIN || weight_kg > WEIGHT_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): weight out of physiological range (1-500 kg).");
    };
    if (serum_cr <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): serum creatinine must be positive.");
        c_exit(2);
        return 0.0;
    };
    var crcl: float = ((140.0 - age) * weight_kg) / (72.0 * serum_cr);
    if (sex == Sex.FEMALE) {
        crcl = crcl * 0.85;
    };
    if (crcl < 0.0) {
        c_print_err("MochaBioWarning (mocha-bio): negative CrCl — age may exceed physiological range for this formula.");
    };
    if (crcl < 15.0) {
        c_print_err("MochaBioWarning (mocha-bio): CrCl < 15 mL/min — severe renal impairment, drug dosing requires specialist review.");
    } else if (crcl < 30.0) {
        c_print_err("MochaBioWarning (mocha-bio): CrCl < 30 mL/min — moderate-severe renal impairment, adjust drug doses.");
    };
    return crcl;
};

~~ BUN/creatinine ratio
~~ Both in mg/dL
~~ Normal: 10-20
~~ > 20: prerenal (dehydration, GI bleeding, high protein intake)
~~ < 10: intrinsic renal disease, liver failure, low protein intake
function bun_creatinine_ratio(bun: float, serum_cr: float) -> float {
    validate_creatinine(serum_cr);
    if (bun < BUN_MIN || bun > BUN_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): BUN out of physiological range (0-200 mg/dL).");
    };
    if (serum_cr <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): serum creatinine must be positive.");
        c_exit(2);
        return 0.0;
    };
    var ratio: float = bun / serum_cr;
    if (ratio > BUN_CR_PRERENAL_THRESHOLD) {
        c_print_err("MochaBioWarning (mocha-bio): BUN/creatinine > 20 — suggests prerenal cause (dehydration, GI bleeding).");
    } else if (ratio < 10.0) {
        c_print_err("MochaBioWarning (mocha-bio): BUN/creatinine < 10 — suggests intrinsic renal disease or liver failure.");
    };
    return ratio;
};

~~ Fractional excretion of sodium (FENa)
~~ FENa = (urine_na * serum_cr) / (serum_na * urine_cr) * 100
~~ All sodium in mEq/L, creatinine in mg/dL
~~ Result in %
~~ < 1%: prerenal AKI (kidneys conserving sodium)
~~ > 2%: intrinsic renal AKI (tubular damage)
~~ 1-2%: indeterminate
~~ Unreliable in patients on diuretics — use FEUrea instead
function fena(urine_na: float, serum_cr: float, serum_na: float, urine_cr: float) -> AkiLikelihood {
    validate_sodium(serum_na);
    validate_creatinine(serum_cr);
    if (urine_na <= 0.0 || urine_cr <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): urine values must be positive.");
        c_exit(2);
        return AkiLikelihood.INDETERMINATE;
    };
    if (serum_na <= 0.0 || serum_cr <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): serum values must be positive.");
        c_exit(2);
        return AkiLikelihood.INDETERMINATE;
    };
    var fe: float = ((urine_na * serum_cr) / (serum_na * urine_cr)) * 100.0;
    if (fe < FENA_PRERENAL_THRESHOLD) {
        return AkiLikelihood.PRERENAL;
    } else if (fe > FENA_INTRINSIC_THRESHOLD) {
        c_print_err("MochaBioWarning (mocha-bio): FENa > 2% — suggests intrinsic renal AKI (tubular damage).");
        return AkiLikelihood.INTRINSIC;
    };
    return AkiLikelihood.INDETERMINATE;
};

~~ FENa raw value — returns float if caller needs the number
function fena_value(urine_na: float, serum_cr: float, serum_na: float, urine_cr: float) -> float {
    if (urine_na <= 0.0 || urine_cr <= 0.0 || serum_na <= 0.0 || serum_cr <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): all values must be positive.");
        c_exit(2);
        return 0.0;
    };
    return ((urine_na * serum_cr) / (serum_na * urine_cr)) * 100.0;
};

~~ Fractional excretion of urea (FEUrea)
~~ FEUrea = (urine_urea * serum_cr) / (serum_urea * urine_cr) * 100
~~ All urea in mg/dL, creatinine in mg/dL
~~ Result in %
~~ < 35%: prerenal AKI
~~ >= 35%: intrinsic renal AKI
~~ Use when patient is on diuretics — FENa unreliable in that context
function feurea(urine_urea: float, serum_cr: float, serum_urea: float, urine_cr: float) -> AkiLikelihood {
    validate_creatinine(serum_cr);
    if (urine_urea <= 0.0 || serum_urea <= 0.0 || urine_cr <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): all values must be positive.");
        c_exit(2);
        return AkiLikelihood.INDETERMINATE;
    };
    if (serum_cr <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): serum creatinine must be positive.");
        c_exit(2);
        return AkiLikelihood.INDETERMINATE;
    };
    var fe: float = ((urine_urea * serum_cr) / (serum_urea * urine_cr)) * 100.0;
    if (fe < FEUREA_PRERENAL_THRESHOLD) {
        return AkiLikelihood.PRERENAL;
    };
    c_print_err("MochaBioWarning (mocha-bio): FEUrea >= 35% — suggests intrinsic renal AKI.");
    return AkiLikelihood.INTRINSIC;
};

~~ FEUrea raw value — returns float if caller needs the number
function feurea_value(urine_urea: float, serum_cr: float, serum_urea: float, urine_cr: float) -> float {
    if (urine_urea <= 0.0 || serum_urea <= 0.0 || urine_cr <= 0.0 || serum_cr <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): all values must be positive.");
        c_exit(2);
        return 0.0;
    };
    return ((urine_urea * serum_cr) / (serum_urea * urine_cr)) * 100.0;
};

"""  ========================
     ENDOCRINE CONSTANTS
     ========================  """

// BMI is intentionally excluded from mocha-bio.
// It was designed to describe populations, not individuals, and systematically
// misclassifies muscular, tall, and short individuals. Use BAI, RFM, or
// waist-to-height ratio instead for individual body composition assessment.

const WAIST_MIN: float = 40.0;
const WAIST_MAX: float = 200.0;
const HIP_MIN: float = 50.0;
const HIP_MAX: float = 200.0;
const HBA1C_MIN: float = 3.0;
const HBA1C_MAX: float = 20.0;
const INSULIN_MIN: float = 0.5;
const INSULIN_MAX: float = 300.0;
const CALCIUM_MIN: float = 5.0;
const CALCIUM_MAX: float = 15.0;
const ALBUMIN_MIN: float = 1.0;
const ALBUMIN_MAX: float = 6.0;

"""  ========================
     ENDOCRINE VALIDATORS
     ========================  """

function validate_waist(waist_cm: float) -> null {
    if (waist_cm < WAIST_MIN || waist_cm > WAIST_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): waist circumference out of physiological range (40-200 cm).");
    };
};

function validate_hip(hip_cm: float) -> null {
    if (hip_cm < HIP_MIN || hip_cm > HIP_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): hip circumference out of physiological range (50-200 cm).");
    };
};

function validate_hba1c(hba1c: float) -> null {
    if (hba1c < HBA1C_MIN || hba1c > HBA1C_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): HbA1c out of physiological range (3-20%).");
    };
};

function validate_calcium(calcium: float) -> null {
    if (calcium < CALCIUM_MIN || calcium > CALCIUM_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): calcium out of physiological range (5-15 mg/dL).");
    };
};

function validate_albumin(albumin: float) -> null {
    if (albumin < ALBUMIN_MIN || albumin > ALBUMIN_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): albumin out of physiological range (1-6 g/dL).");
    };
};

"""  ========================
     ENDOCRINE TAGS
     ========================  """

tag ActivityLevel {
    SEDENTARY,
    LIGHT,
    MODERATE,
    ACTIVE,
    VERY_ACTIVE
};

tag WaistHeightRisk {
    LOW,
    MODERATE,
    HIGH,
    VERY_HIGH
};

"""  ========================
     ENDOCRINE FORMULAE
     ========================  """

~~ Body adiposity index (BAI)
~~ BAI = (hip_cm / height_cm^1.5) - 18
~~ Estimates body fat % directly
~~ Normal: ~21-33% women, ~8-21% men
~~ More accurate than BMI for estimating adiposity
function body_adiposity_index(hip_cm: float, height_cm: float) -> float {
    validate_hip(hip_cm);
    if (height_cm < HEIGHT_MIN || height_cm > HEIGHT_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): height out of physiological range (30-250 cm).");
    };
    if (hip_cm <= 0.0 || height_cm <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): measurements must be positive.");
        c_exit(2);
        return 0.0;
    };
    // convert to metres first, then height_m^1.5 = height_m * sqrt(height_m)
    var height_m: float = height_cm / 100.0;
    var height_1_5: float = height_m * c_sqrt(height_m);
    return (hip_cm / height_1_5) - 18.0;
};

~~ Ponderal index
~~ PI = weight_kg / (height_m^3)
~~ Less sensitive to height extremes than BMI
~~ Normal range: 11-15 kg/m³
function ponderal_index(weight_kg: float, height_cm: float) -> float {
    if (weight_kg < WEIGHT_MIN || weight_kg > WEIGHT_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): weight out of physiological range (1-500 kg).");
    };
    if (height_cm < HEIGHT_MIN || height_cm > HEIGHT_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): height out of physiological range (30-250 cm).");
    };
    if (height_cm <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): height must be positive.");
        c_exit(2);
        return 0.0;
    };
    var height_m: float = height_cm / 100.0;
    var height_m3: float = height_m * height_m * height_m;
    var pi: float = weight_kg / height_m3;
    if (pi < 11.0 || pi > 15.0) {
        c_print_err("MochaBioWarning (mocha-bio): ponderal index outside normal range (11-15 kg/m³).");
    };
    return pi;
};

~~ Waist-to-height ratio
~~ WHtR = waist_cm / height_cm
~~ One of the strongest individual predictors of cardiometabolic risk
~~ < 0.4: low
~~ 0.4-0.5: moderate
~~ 0.5-0.6: high
~~ > 0.6: very high
function waist_height_ratio(waist_cm: float, height_cm: float) -> WaistHeightRisk {
    validate_waist(waist_cm);
    if (height_cm < HEIGHT_MIN || height_cm > HEIGHT_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): height out of physiological range (30-250 cm).");
    };
    if (height_cm <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): height must be positive.");
        c_exit(2);
        return WaistHeightRisk.VERY_HIGH;
    };
    var ratio: float = waist_cm / height_cm;
    if (ratio < 0.4) {
        return WaistHeightRisk.LOW;
    } else if (ratio < 0.5) {
        return WaistHeightRisk.MODERATE;
    } else if (ratio < 0.6) {
        c_print_err("MochaBioWarning (mocha-bio): waist-to-height ratio 0.5-0.6 — high cardiometabolic risk.");
        return WaistHeightRisk.HIGH;
    };
    c_print_err("MochaBioWarning (mocha-bio): waist-to-height ratio > 0.6 — very high cardiometabolic risk.");
    return WaistHeightRisk.VERY_HIGH;
};

~~ Waist-to-height ratio raw value
function waist_height_ratio_value(waist_cm: float, height_cm: float) -> float {
    validate_waist(waist_cm);
    if (height_cm <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): height must be positive.");
        c_exit(2);
        return 0.0;
    };
    return waist_cm / height_cm;
};

~~ Relative fat mass (RFM) — Woolcott & Bergman 2018
~~ Male:   RFM = 64 - (20 * height_cm / waist_cm)
~~ Female: RFM = 76 - (20 * height_cm / waist_cm)
~~ Result in % body fat
~~ Designed specifically to replace BMI for individual assessment
~~ Normal: ~6-24% men, ~14-36% women
function relative_fat_mass(height_cm: float, waist_cm: float, sex: Sex) -> float {
    validate_waist(waist_cm);
    if (height_cm < HEIGHT_MIN || height_cm > HEIGHT_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): height out of physiological range (30-250 cm).");
    };
    if (waist_cm <= 0.0 || height_cm <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): measurements must be positive.");
        c_exit(2);
        return 0.0;
    };
    var rfm: float = 0.0;
    if (sex == Sex.MALE) {
        rfm = 64.0 - (20.0 * (height_cm / waist_cm));
        if (rfm < 6.0 || rfm > 24.0) {
            c_print_err("MochaBioWarning (mocha-bio): RFM outside normal range for males (6-24%).");
        };
    } else {
        rfm = 76.0 - (20.0 * (height_cm / waist_cm));
        if (rfm < 14.0 || rfm > 36.0) {
            c_print_err("MochaBioWarning (mocha-bio): RFM outside normal range for females (14-36%).");
        };
    };
    return rfm;
};

~~ Basal metabolic rate — Mifflin-St Jeor equation
~~ Male:   BMR = (10 * weight_kg) + (6.25 * height_cm) - (5 * age) + 5
~~ Female: BMR = (10 * weight_kg) + (6.25 * height_cm) - (5 * age) - 161
~~ Result in kcal/day
~~ Most accurate BMR formula for general population
function basal_metabolic_rate(weight_kg: float, height_cm: float, age: float, sex: Sex) -> float {
    if (weight_kg < WEIGHT_MIN || weight_kg > WEIGHT_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): weight out of physiological range (1-500 kg).");
    };
    if (height_cm < HEIGHT_MIN || height_cm > HEIGHT_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): height out of physiological range (30-250 cm).");
    };
    if (age < 18.0 || age > 120.0) {
        c_print_err("MochaBioWarning (mocha-bio): age out of expected range for Mifflin-St Jeor (18-120 years).");
    };
    var bmr: float = (10.0 * weight_kg) + (6.25 * height_cm) - (5.0 * age);
    if (sex == Sex.MALE) {
        bmr = bmr + 5.0;
    } else {
        bmr = bmr - 161.0;
    };
    return bmr;
};

~~ Total daily energy expenditure
~~ TDEE = BMR * activity_multiplier
~~ Result in kcal/day
~~ Sedentary: 1.2, Light: 1.375, Moderate: 1.55, Active: 1.725, Very active: 1.9
function total_daily_energy_expenditure(bmr: float, activity: ActivityLevel) -> float {
    if (bmr <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): BMR must be positive.");
        c_exit(2);
        return 0.0;
    };
    var multiplier: float = 1.2;
    match(activity) {
        case ActivityLevel.SEDENTARY:   multiplier = 1.2;
        case ActivityLevel.LIGHT:       multiplier = 1.375;
        case ActivityLevel.MODERATE:    multiplier = 1.55;
        case ActivityLevel.ACTIVE:      multiplier = 1.725;
        case ActivityLevel.VERY_ACTIVE: multiplier = 1.9;
        default:                        multiplier = 1.2;
    };
    return bmr * multiplier;
};

~~ HbA1c to estimated average glucose (eAG)
~~ eAG = (HbA1c * 28.7) - 46.7
~~ HbA1c in %, result in mg/dL
~~ Normal HbA1c: < 5.7%
~~ Prediabetes: 5.7-6.4%
~~ Diabetes: >= 6.5%
function hba1c_to_eag(hba1c: float) -> float {
    validate_hba1c(hba1c);
    if (hba1c >= 6.5) {
        c_print_err("MochaBioWarning (mocha-bio): HbA1c >= 6.5% — diagnostic threshold for diabetes.");
    } else if (hba1c >= 5.7) {
        c_print_err("MochaBioWarning (mocha-bio): HbA1c 5.7-6.4% — prediabetes range.");
    };
    return (hba1c * 28.7) - 46.7;
};

~~ HOMA-IR — homeostatic model assessment of insulin resistance
~~ HOMA-IR = (fasting_glucose_mg_dl * fasting_insulin_uU_ml) / 405
~~ Normal: < 1.0 (insulin sensitive)
~~ > 1.9: early insulin resistance
~~ > 2.9: significant insulin resistance
function homa_ir(fasting_glucose: float, fasting_insulin: float) -> float {
    validate_glucose(fasting_glucose);
    if (fasting_insulin < INSULIN_MIN || fasting_insulin > INSULIN_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): fasting insulin out of physiological range (0.5-300 uU/mL).");
    };
    if (fasting_glucose <= 0.0 || fasting_insulin <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): glucose and insulin must be positive.");
        c_exit(2);
        return 0.0;
    };
    var ir: float = (fasting_glucose * fasting_insulin) / 405.0;
    if (ir > 2.9) {
        c_print_err("MochaBioWarning (mocha-bio): HOMA-IR > 2.9 — significant insulin resistance.");
    } else if (ir > 1.9) {
        c_print_err("MochaBioWarning (mocha-bio): HOMA-IR > 1.9 — early insulin resistance.");
    };
    return ir;
};

~~ Corrected calcium for hypoalbuminaemia
~~ Corrected Ca = measured_calcium + 0.8 * (4.0 - albumin)
~~ Calcium in mg/dL, albumin in g/dL
~~ Normal corrected calcium: 8.5-10.5 mg/dL
~~ Hypoalbuminaemia falsely lowers measured calcium
function corrected_calcium(measured_calcium: float, albumin: float) -> float {
    validate_calcium(measured_calcium);
    validate_albumin(albumin);
    var corrected: float = measured_calcium + (0.8 * (4.0 - albumin));
    if (corrected < 8.5 || corrected > 10.5) {
        c_print_err("MochaBioWarning (mocha-bio): corrected calcium outside normal range (8.5-10.5 mg/dL).");
    };
    if (corrected > 12.0) {
        c_print_err("MochaBioWarning (mocha-bio): corrected calcium > 12.0 mg/dL — severe hypercalcaemia.");
    } else if (corrected < 7.0) {
        c_print_err("MochaBioWarning (mocha-bio): corrected calcium < 7.0 mg/dL — severe hypocalcaemia.");
    };
    return corrected;
};

~~ Free water deficit
~~ FWD = body_water_fraction * weight_kg * (sodium / 140.0 - 1.0)
~~ Body water fraction: 0.6 male, 0.5 female
~~ Result in litres
~~ Used in hypernatraemia management to estimate free water replacement
~~ > 5L: severe deficit
function free_water_deficit(weight_kg: float, sodium: float, sex: Sex) -> float {
    if (weight_kg < WEIGHT_MIN || weight_kg > WEIGHT_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): weight out of physiological range (1-500 kg).");
    };
    validate_sodium(sodium);
    if (sodium <= 140.0) {
        c_print_err("MochaBioWarning (mocha-bio): sodium <= 140 mEq/L — free water deficit formula only applies in hypernatraemia.");
    };
    var fraction: float = 0.5;
    if (sex == Sex.MALE) {
        fraction = 0.6;
    };
    var fwd: float = fraction * weight_kg * ((sodium / 140.0) - 1.0);
    if (fwd > 5.0) {
        c_print_err("MochaBioWarning (mocha-bio): free water deficit > 5L — severe hypernatraemia, replace slowly to avoid cerebral oedema.");
    };
    return fwd;
};

"""  ========================
     PHARMACOKINETICS CONSTANTS
     ========================  """

const LN2: float = 0.693147;
const F_MIN: float = 0.0;
const F_MAX: float = 1.0;
const CONCENTRATION_MIN: float = 0.0;
const VD_MIN: float = 0.0;
const CL_MIN: float = 0.0;
const HILL_N_MIN: float = 0.1;
const HILL_N_MAX: float = 10.0;

"""  ========================
     PHARMACOKINETICS VALIDATORS
     ========================  """

function validate_concentration(c: float) -> null {
    if (c < CONCENTRATION_MIN) {
        c_print_err("MochaBioWarning (mocha-bio): concentration cannot be negative.");
    };
};

function validate_bioavailability(f: float) -> null {
    if (f <= F_MIN || f > F_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): bioavailability must be between 0.0 (exclusive) and 1.0.");
    };
};

function validate_vd(vd: float) -> null {
    if (vd <= VD_MIN) {
        c_print_err("MochaBioError (mocha-bio): volume of distribution must be positive.");
    };
};

function validate_clearance(cl: float) -> null {
    if (cl <= CL_MIN) {
        c_print_err("MochaBioError (mocha-bio): clearance must be positive.");
    };
};

"""  ========================
     PHARMACOKINETICS TAGS
     ========================  """

tag RouteOfAdministration {
    IV,
    ORAL,
    SUBCUTANEOUS,
    INTRAMUSCULAR
};

"""  ========================
     PHARMACOKINETICS FORMULAE
     ========================  """

~~ Elimination rate constant
~~ ke = CL / Vd
~~ CL in L/h, Vd in L
~~ Result in h⁻¹
~~ Describes the fraction of Vd cleared per unit time
function elimination_rate_constant(cl: float, vd: float) -> float {
    validate_clearance(cl);
    validate_vd(vd);
    if (cl <= 0.0 || vd <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): CL and Vd must be positive.");
        c_exit(2);
        return 0.0;
    };
    return cl / vd;
};

~~ Half-life
~~ t½ = ln(2) / ke = 0.693 / ke
~~ ke in h⁻¹, result in hours
~~ Time for plasma concentration to halve
function half_life(ke: float) -> float {
    if (ke <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): elimination rate constant must be positive.");
        c_exit(2);
        return 0.0;
    };
    return LN2 / ke;
};

~~ Half-life from CL and Vd directly
~~ t½ = (ln(2) * Vd) / CL
~~ Convenience function — avoids caller computing ke manually
function half_life_from_cl_vd(cl: float, vd: float) -> float {
    validate_clearance(cl);
    validate_vd(vd);
    if (cl <= 0.0 || vd <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): CL and Vd must be positive.");
        c_exit(2);
        return 0.0;
    };
    return (LN2 * vd) / cl;
};

~~ Volume of distribution
~~ Vd = dose / C0
~~ dose in mg, C0 in mg/L (initial plasma concentration after IV bolus)
~~ Result in L
~~ Apparent volume into which drug distributes
function volume_of_distribution(dose_mg: float, c0: float) -> float {
    if (dose_mg <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): dose must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (c0 <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): initial concentration must be positive.");
        c_exit(2);
        return 0.0;
    };
    return dose_mg / c0;
};

~~ Clearance
~~ CL = ke * Vd
~~ ke in h⁻¹, Vd in L
~~ Result in L/h
~~ Volume of plasma cleared of drug per unit time
function clearance(ke: float, vd: float) -> float {
    if (ke <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): elimination rate constant must be positive.");
        c_exit(2);
        return 0.0;
    };
    validate_vd(vd);
    if (vd <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): Vd must be positive.");
        c_exit(2);
        return 0.0;
    };
    return ke * vd;
};

~~ Loading dose
~~ LD = Vd * target_concentration
~~ Vd in L, target_concentration in mg/L
~~ Result in mg
~~ Dose required to immediately achieve target plasma concentration
function loading_dose(vd: float, target_concentration: float) -> float {
    validate_vd(vd);
    validate_concentration(target_concentration);
    if (vd <= 0.0 || target_concentration <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): Vd and target concentration must be positive.");
        c_exit(2);
        return 0.0;
    };
    return vd * target_concentration;
};

~~ Maintenance dose
~~ MD = CL * target_concentration * tau
~~ CL in L/h, target_concentration in mg/L, tau (dosing interval) in hours
~~ Result in mg
~~ Dose required to maintain target steady state concentration
function maintenance_dose(cl: float, target_concentration: float, tau: float) -> float {
    validate_clearance(cl);
    validate_concentration(target_concentration);
    if (cl <= 0.0 || target_concentration <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): CL and target concentration must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (tau <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): dosing interval must be positive.");
        c_exit(2);
        return 0.0;
    };
    return cl * target_concentration * tau;
};

~~ Bioavailability-adjusted dose
~~ Adjusted dose = intended_dose / F
~~ F: bioavailability fraction (0.0-1.0)
~~ IV route: F = 1.0 by definition
~~ Oral/other routes: F < 1.0 due to first-pass and absorption losses
function bioavailability_adjusted_dose(
    intended_dose: float,
    f: float,
    route: RouteOfAdministration
) -> float {
    if (intended_dose <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): intended dose must be positive.");
        c_exit(2);
        return 0.0;
    };
    validate_bioavailability(f);
    if (f <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): bioavailability must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (route == RouteOfAdministration.IV && f != 1.0) {
        c_print_err("MochaBioWarning (mocha-bio): IV route has bioavailability of 1.0 by definition.");
    };
    return intended_dose / f;
};

~~ One-compartment concentration at time t
~~ C(t) = C0 * e^(-ke * t)
~~ C0 in mg/L, ke in h⁻¹, t in hours
~~ Result in mg/L
~~ Assumes instantaneous distribution (IV bolus)
function concentration_at_time(c0: float, ke: float, t: float) -> float {
    validate_concentration(c0);
    if (c0 <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): initial concentration must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (ke <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): elimination rate constant must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (t < 0.0) {
        c_print_err("MochaBioError (mocha-bio): time cannot be negative.");
        c_exit(2);
        return 0.0;
    };
    return c0 * c_exp(0.0 - (ke * t));
};

~~ Steady state concentration
~~ Css = (F * dose) / (CL * tau)
~~ F: bioavailability, dose in mg, CL in L/h, tau in hours
~~ Result in mg/L
~~ Average plasma concentration at steady state
~~ Reached after ~4-5 half-lives
function steady_state_concentration(f: float, dose_mg: float, cl: float, tau: float) -> float {
    validate_bioavailability(f);
    if (dose_mg <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): dose must be positive.");
        c_exit(2);
        return 0.0;
    };
    validate_clearance(cl);
    if (cl <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): clearance must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (tau <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): dosing interval must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (f <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): bioavailability must be positive.");
        c_exit(2);
        return 0.0;
    };
    return (f * dose_mg) / (cl * tau);
};

~~ Accumulation factor
~~ R = 1 / (1 - e^(-ke * tau))
~~ ke in h⁻¹, tau (dosing interval) in hours
~~ Dimensionless — predicts ratio of steady state to first dose concentration
~~ R = 1: no accumulation (tau >> t½)
~~ R >> 1: significant accumulation (tau << t½)
function accumulation_factor(ke: float, tau: float) -> float {
    if (ke <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): elimination rate constant must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (tau <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): dosing interval must be positive.");
        c_exit(2);
        return 0.0;
    };
    var denom: float = 1.0 - c_exp(0.0 - (ke * tau));
    if (denom <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): accumulation factor denominator <= 0 — check ke and tau values.");
        c_exit(2);
        return 0.0;
    };
    var r: float = 1.0 / denom;
    if (r > 10.0) {
        c_print_err("MochaBioWarning (mocha-bio): accumulation factor > 10 — significant drug accumulation expected.");
    };
    return r;
};

~~ Hill equation (Emax model)
~~ E = Emax * C^n / (EC50^n + C^n)
~~ Emax: maximum effect (same units as E)
~~ C: drug concentration in mg/L
~~ EC50: concentration producing 50% Emax in mg/L
~~ n: Hill coefficient (dimensionless)
~~   n = 1: hyperbolic (simple binding)
~~   n > 1: sigmoidal (cooperative binding)
~~   n < 1: shallow curve (heterogeneous receptors)
~~ Result in same units as Emax
function hill_effect(c: float, emax: float, ec50: float, n: float) -> float {
    validate_concentration(c);
    if (emax <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): Emax must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (ec50 <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): EC50 must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (n < HILL_N_MIN || n > HILL_N_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): Hill coefficient outside expected range (0.1-10).");
    };
    if (n <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): Hill coefficient must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (c == 0.0) {
        return 0.0;
    };
    var cn: float = c_pow(c, n);
    var ec50n: float = c_pow(ec50, n);
    return emax * cn / (ec50n + cn);
};

~~ Hill equation inverse — concentration to achieve target effect
~~ C = EC50 * (E / (Emax - E))^(1/n)
~~ E must be strictly between 0 and Emax
~~ Result in mg/L
function hill_concentration(e: float, emax: float, ec50: float, n: float) -> float {
    if (emax <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): Emax must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (e <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): target effect must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (e >= emax) {
        c_print_err("MochaBioError (mocha-bio): target effect must be strictly less than Emax — Emax is an asymptote, never reached.");
        c_exit(2);
        return 0.0;
    };
    if (ec50 <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): EC50 must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (n <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): Hill coefficient must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (n < HILL_N_MIN || n > HILL_N_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): Hill coefficient outside expected range (0.1-10).");
    };
    var ratio: float = e / (emax - e);
    return ec50 * c_pow(ratio, 1.0 / n);
};

"""  ========================
     HEMATOLOGY CONSTANTS
     ========================  """

const RBC_MIN: float = 1.0;
const RBC_MAX: float = 8.0;
const WBC_MIN: float = 0.1;
const WBC_MAX: float = 100.0;
const HCT_MIN: float = 5.0;
const HCT_MAX: float = 65.0;
const RETIC_MIN: float = 0.0;
const RETIC_MAX: float = 20.0;
const IRON_MIN: float = 10.0;
const IRON_MAX: float = 300.0;
const TIBC_MIN: float = 100.0;
const TIBC_MAX: float = 500.0;
const NORMAL_HCT_MALE: float = 45.0;
const NORMAL_HCT_FEMALE: float = 41.0;

"""  ========================
     HEMATOLOGY VALIDATORS
     ========================  """

function validate_rbc(rbc: float) -> null {
    if (rbc < RBC_MIN || rbc > RBC_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): RBC count out of physiological range (1-8 x10⁶/µL).");
    };
};

function validate_wbc(wbc: float) -> null {
    if (wbc < WBC_MIN || wbc > WBC_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): WBC count out of physiological range (0.1-100 x10³/µL).");
    };
};

function validate_hematocrit(hct: float) -> null {
    if (hct < HCT_MIN || hct > HCT_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): hematocrit out of physiological range (5-65%).");
    };
};

function validate_retic(retic: float) -> null {
    if (retic < RETIC_MIN || retic > RETIC_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): reticulocyte percentage out of physiological range (0-20%).");
    };
};

"""  ========================
     HEMATOLOGY TAGS
     ========================  """

tag AnaemiaType {
    MICROCYTIC,
    NORMOCYTIC,
    MACROCYTIC
};

tag NeutropeniaGrade {
    NONE,
    MILD,
    MODERATE,
    SEVERE
};

"""  ========================
     HEMATOLOGY FORMULAE
     ========================  """

~~ Mean corpuscular volume (MCV)
~~ MCV = (hematocrit * 10) / RBC_count
~~ Hematocrit in %, RBC in x10⁶/µL
~~ Result in fL (femtolitres)
~~ Normal: 80-100 fL
~~ < 80: microcytic (iron deficiency, thalassaemia)
~~ > 100: macrocytic (B12/folate deficiency)
function mcv(hematocrit: float, rbc: float) -> AnaemiaType {
    validate_hematocrit(hematocrit);
    validate_rbc(rbc);
    if (rbc <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): RBC count must be positive.");
        c_exit(2);
        return AnaemiaType.NORMOCYTIC;
    };
    var result: float = (hematocrit * 10.0) / rbc;
    if (result < 80.0) {
        c_print_err("MochaBioWarning (mocha-bio): MCV < 80 fL — microcytic anaemia (consider iron deficiency, thalassaemia).");
        return AnaemiaType.MICROCYTIC;
    } else if (result > 100.0) {
        c_print_err("MochaBioWarning (mocha-bio): MCV > 100 fL — macrocytic anaemia (consider B12/folate deficiency).");
        return AnaemiaType.MACROCYTIC;
    };
    return AnaemiaType.NORMOCYTIC;
};

~~ MCV raw value
function mcv_value(hematocrit: float, rbc: float) -> float {
    validate_hematocrit(hematocrit);
    validate_rbc(rbc);
    if (rbc <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): RBC count must be positive.");
        c_exit(2);
        return 0.0;
    };
    return (hematocrit * 10.0) / rbc;
};

~~ Mean corpuscular haemoglobin (MCH)
~~ MCH = (Hgb * 10) / RBC_count
~~ Hgb in g/dL, RBC in x10⁶/µL
~~ Result in pg (picograms)
~~ Normal: 27-33 pg
function mch(hgb: float, rbc: float) -> float {
    validate_hgb(hgb);
    validate_rbc(rbc);
    if (rbc <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): RBC count must be positive.");
        c_exit(2);
        return 0.0;
    };
    var result: float = (hgb * 10.0) / rbc;
    if (result < 27.0 || result > 33.0) {
        c_print_err("MochaBioWarning (mocha-bio): MCH outside normal range (27-33 pg).");
    };
    return result;
};

~~ Mean corpuscular haemoglobin concentration (MCHC)
~~ MCHC = (Hgb / hematocrit) * 100
~~ Hgb in g/dL, hematocrit in %
~~ Result in g/dL
~~ Normal: 32-36 g/dL
~~ < 32: hypochromic (iron deficiency)
~~ > 36: hyperchromic (spherocytosis, severe dehydration)
function mchc(hgb: float, hematocrit: float) -> float {
    validate_hgb(hgb);
    validate_hematocrit(hematocrit);
    if (hematocrit <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): hematocrit must be positive.");
        c_exit(2);
        return 0.0;
    };
    var result: float = (hgb / hematocrit) * 100.0;
    if (result < 32.0) {
        c_print_err("MochaBioWarning (mocha-bio): MCHC < 32 g/dL — hypochromic (consider iron deficiency).");
    } else if (result > 36.0) {
        c_print_err("MochaBioWarning (mocha-bio): MCHC > 36 g/dL — hyperchromic (consider spherocytosis).");
    };
    return result;
};

~~ Corrected reticulocyte count
~~ Corrected retic% = retic% * (hematocrit / normal_hct)
~~ Normal Hct: 45% male, 41% female
~~ Corrects for dilutional effect of anaemia on reticulocyte percentage
~~ Normal corrected retic: 1-2%
function corrected_reticulocyte(retic_pct: float, hematocrit: float, sex: Sex) -> float {
    validate_retic(retic_pct);
    validate_hematocrit(hematocrit);
    var normal_hct: float = NORMAL_HCT_FEMALE;
    if (sex == Sex.MALE) {
        normal_hct = NORMAL_HCT_MALE;
    };
    var corrected: float = retic_pct * (hematocrit / normal_hct);
    if (corrected < 1.0 || corrected > 2.0) {
        c_print_err("MochaBioWarning (mocha-bio): corrected reticulocyte count outside normal range (1-2%).");
    };
    return corrected;
};

~~ Reticulocyte production index (RPI)
~~ RPI = corrected_retic / maturation_factor
~~ Maturation factor derived internally from hematocrit:
~~   Hct >= 36%: 1.0, Hct 26-35%: 1.5, Hct 16-25%: 2.0, Hct < 16%: 2.5
~~ RPI < 2: hypoproliferative (bone marrow not responding)
~~ RPI >= 2: adequate response (haemolysis or blood loss)
function reticulocyte_production_index(retic_pct: float, hematocrit: float, sex: Sex) -> float {
    validate_retic(retic_pct);
    validate_hematocrit(hematocrit);
    var corrected: float = corrected_reticulocyte(retic_pct, hematocrit, sex);
    var maturation_factor: float = 1.0;
    if (hematocrit < 16.0) {
        maturation_factor = 2.5;
    } else if (hematocrit < 26.0) {
        maturation_factor = 2.0;
    } else if (hematocrit < 36.0) {
        maturation_factor = 1.5;
    };
    var rpi: float = corrected / maturation_factor;
    if (rpi < 2.0) {
        c_print_err("MochaBioWarning (mocha-bio): RPI < 2 — hypoproliferative anaemia, bone marrow not responding adequately.");
    } else {
        c_print_err("MochaBioWarning (mocha-bio): RPI >= 2 — adequate marrow response, consider haemolysis or blood loss.");
    };
    return rpi;
};

~~ Blood volume estimation (Nadler equation)
~~ Male:   BV = (0.3669 * height_m^3) + (0.03219 * weight_kg) + 0.6041
~~ Female: BV = (0.3561 * height_m^3) + (0.03308 * weight_kg) + 0.1833
~~ Result in litres
~~ Normal: ~5L male, ~4L female
function blood_volume(height_cm: float, weight_kg: float, sex: Sex) -> float {
    if (height_cm < HEIGHT_MIN || height_cm > HEIGHT_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): height out of physiological range (30-250 cm).");
    };
    if (weight_kg < WEIGHT_MIN || weight_kg > WEIGHT_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): weight out of physiological range (1-500 kg).");
    };
    if (height_cm <= 0.0 || weight_kg <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): height and weight must be positive.");
        c_exit(2);
        return 0.0;
    };
    var height_m: float = height_cm / 100.0;
    var height_m3: float = height_m * height_m * height_m;
    var bv: float = 0.0;
    if (sex == Sex.MALE) {
        bv = (0.3669 * height_m3) + (0.03219 * weight_kg) + 0.6041;
    } else {
        bv = (0.3561 * height_m3) + (0.03308 * weight_kg) + 0.1833;
    };
    if (bv < 3.0 || bv > 8.0) {
        c_print_err("MochaBioWarning (mocha-bio): blood volume outside expected range (3-8 L).");
    };
    return bv;
};

~~ Absolute neutrophil count (ANC)
~~ ANC = WBC * (neutrophils_pct + bands_pct) / 100
~~ WBC in x10³/µL, percentages 0-100
~~ Result in x10³/µL
~~ Normal: >= 1.5 x10³/µL
~~ Mild neutropenia: 1.0-1.5
~~ Moderate: 0.5-1.0
~~ Severe: < 0.5 — high infection risk
function anc(wbc: float, neutrophils_pct: float, bands_pct: float) -> NeutropeniaGrade {
    validate_wbc(wbc);
    if (neutrophils_pct < 0.0 || neutrophils_pct > 100.0) {
        c_print_err("MochaBioWarning (mocha-bio): neutrophil percentage out of range (0-100%).");
    };
    if (bands_pct < 0.0 || bands_pct > 100.0) {
        c_print_err("MochaBioWarning (mocha-bio): bands percentage out of range (0-100%).");
    };
    if ((neutrophils_pct + bands_pct) > 100.0) {
        c_print_err("MochaBioWarning (mocha-bio): neutrophils + bands exceeds 100%.");
    };
    var result: float = wbc * (neutrophils_pct + bands_pct) / 100.0;
    if (result < 0.5) {
        c_print_err("MochaBioWarning (mocha-bio): ANC < 0.5 x10³/µL — severe neutropenia, high infection risk.");
        return NeutropeniaGrade.SEVERE;
    } else if (result < 1.0) {
        c_print_err("MochaBioWarning (mocha-bio): ANC 0.5-1.0 x10³/µL — moderate neutropenia.");
        return NeutropeniaGrade.MODERATE;
    } else if (result < 1.5) {
        c_print_err("MochaBioWarning (mocha-bio): ANC 1.0-1.5 x10³/µL — mild neutropenia.");
        return NeutropeniaGrade.MILD;
    };
    return NeutropeniaGrade.NONE;
};

~~ ANC raw value
function anc_value(wbc: float, neutrophils_pct: float, bands_pct: float) -> float {
    validate_wbc(wbc);
    if (wbc <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): WBC must be positive.");
        c_exit(2);
        return 0.0;
    };
    return wbc * (neutrophils_pct + bands_pct) / 100.0;
};

~~ Transferrin saturation
~~ Tsat = (serum_iron / TIBC) * 100
~~ Both in µg/dL, result in %
~~ Normal: 20-50%
~~ < 20%: iron deficiency
~~ > 50%: iron overload (haemochromatosis)
function transferrin_saturation(serum_iron: float, tibc: float) -> float {
    if (serum_iron < IRON_MIN || serum_iron > IRON_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): serum iron out of physiological range (10-300 µg/dL).");
    };
    if (tibc < TIBC_MIN || tibc > TIBC_MAX) {
        c_print_err("MochaBioWarning (mocha-bio): TIBC out of physiological range (100-500 µg/dL).");
    };
    if (tibc <= 0.0) {
        c_print_err("MochaBioError (mocha-bio): TIBC must be positive.");
        c_exit(2);
        return 0.0;
    };
    if (serum_iron > tibc) {
        c_print_err("MochaBioWarning (mocha-bio): serum iron > TIBC is physiologically implausible.");
    };
    var tsat: float = (serum_iron / tibc) * 100.0;
    if (tsat < 20.0) {
        c_print_err("MochaBioWarning (mocha-bio): transferrin saturation < 20% — iron deficiency.");
    } else if (tsat > 50.0) {
        c_print_err("MochaBioWarning (mocha-bio): transferrin saturation > 50% — iron overload, consider haemochromatosis.");
    };
    return tsat;
};