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