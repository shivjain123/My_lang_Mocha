// mocha-finance — Finance & Economics Library for Mocha
//
// Sections:
//   1. Time Value of Money
//   2. Annuities & Loans
//   3. Capital Budgeting
//   4. Bonds
//   5. Equity Valuation
//   6. Risk & Portfolio
//   7. Options
//   8. Financial Ratios
//   9. Macroeconomics
//  10. Environmental Finance
//
// Part of the Mocha Scientific Library Ecosystem
// License: Apache 2.0

// mocha-lib-deps: mocha-math, mocha-stats

local function c_print_err(msg: str) -> null native mocha_print_stderr;
local function c_exit(code: int) -> null native mocha_exit;
local function c_exp(x: float) -> float native mocha_wrap_exp;

// Conventions: all rates are decimals (0.05 = 5%). "Per period" rates match the
// payment period (monthly loan: annual rate / 12). Cash-flow arrays start at t = 0.

// ================================================================
// INTERNAL VALIDATION HELPERS
// ================================================================

~~ Validates a rate is above -100% (so that 1 + rate stays positive).
local function validate_rate(rate: float, name: str) -> float {
    if (rate <= -1.0) {
        c_print_err("MochaLibError (mocha-finance): " + name + " must be greater than -1.0 (-100%).");
        c_exit(2);
    };
    return rate;
};

~~ Validates a value is positive.
local function validate_positive(x: float, name: str) -> float {
    if (x <= 0.0) {
        c_print_err("MochaLibError (mocha-finance): " + name + " must be positive.");
        c_exit(2);
    };
    return x;
};

~~ Validates a value is non-negative.
local function validate_non_negative(x: float, name: str) -> float {
    if (x < 0.0) {
        c_print_err("MochaLibError (mocha-finance): " + name + " cannot be negative.");
        c_exit(2);
    };
    return x;
};

// ================================================================
// SECTION 1: TIME VALUE OF MONEY
// ================================================================

~~ Simple interest earned (no compounding). I = P * r * t.
~~ principal >= 0, annual_rate as decimal (> -1), years >= 0.
function simple_interest(principal: float, annual_rate: float, years: float) -> float {
    validate_non_negative(principal, "Principal");
    validate_rate(annual_rate, "Annual rate");
    validate_non_negative(years, "Years");
    return principal * annual_rate * years;
};

~~ Future value after compounding once per period. FV = PV * (1 + r)^n.
~~ pv >= 0, rate_per_period > -1, periods >= 0 (may be fractional).
function future_value(pv: float, rate_per_period: float, periods: float) -> float {
    validate_non_negative(pv, "Present value");
    validate_rate(rate_per_period, "Rate per period");
    validate_non_negative(periods, "Periods");
    const GROWTH: float = float(c_pow(1.0 + rate_per_period, periods));
    return pv * GROWTH;
};

~~ Present value of an amount received in the future. PV = FV / (1 + r)^n.
~~ fv >= 0, rate_per_period > -1, periods >= 0 (may be fractional).
function present_value(fv: float, rate_per_period: float, periods: float) -> float {
    validate_non_negative(fv, "Future value");
    validate_rate(rate_per_period, "Rate per period");
    validate_non_negative(periods, "Periods");
    const GROWTH: float = float(c_pow(1.0 + rate_per_period, periods));
    return fv / GROWTH;
};

~~ Final amount with a nominal annual rate compounded m times a year.
~~ A = P * (1 + r/m)^(m*t). principal >= 0, annual_rate > -m, years >= 0, compounds_per_year >= 1.
function compound_amount(principal: float, annual_rate: float, years: float, compounds_per_year: int) -> float {
    validate_non_negative(principal, "Principal");
    validate_non_negative(years, "Years");
    if (compounds_per_year < 1) {
        c_print_err("MochaLibError (mocha-finance): Compounds per year must be at least 1.");
        c_exit(2);
    };
    const M: float = float(compounds_per_year);
    const PERIODIC: float = annual_rate / M;
    validate_rate(PERIODIC, "Rate per compounding period");
    const GROWTH: float = float(c_pow(1.0 + PERIODIC, M * years));
    return principal * GROWTH;
};

~~ Effective annual rate (EAR) from a nominal annual rate. EAR = (1 + r/m)^m - 1.
~~ compounds_per_year >= 1, nominal_rate > -m.
function effective_annual_rate(nominal_rate: float, compounds_per_year: int) -> float {
    if (compounds_per_year < 1) {
        c_print_err("MochaLibError (mocha-finance): Compounds per year must be at least 1.");
        c_exit(2);
    };
    const M: float = float(compounds_per_year);
    const PERIODIC: float = nominal_rate / M;
    validate_rate(PERIODIC, "Rate per compounding period");
    return float(c_pow(1.0 + PERIODIC, M)) - 1.0;
};

~~ Nominal annual rate that gives a target effective annual rate. r = m * ((1 + EAR)^(1/m) - 1).
~~ effective_rate > -1, compounds_per_year >= 1.
function nominal_rate_from_effective(effective_rate: float, compounds_per_year: int) -> float {
    validate_rate(effective_rate, "Effective rate");
    if (compounds_per_year < 1) {
        c_print_err("MochaLibError (mocha-finance): Compounds per year must be at least 1.");
        c_exit(2);
    };
    const M: float = float(compounds_per_year);
    const ROOT: float = float(c_pow(1.0 + effective_rate, 1.0 / M));
    return M * (ROOT - 1.0);
};

~~ Final amount with continuous compounding. A = P * e^(r*t).
~~ principal >= 0, years >= 0. Errors if |r*t| > 700 (e^700 overflows double precision).
function continuous_compound_amount(principal: float, annual_rate: float, years: float) -> float {
    validate_non_negative(principal, "Principal");
    validate_non_negative(years, "Years");
    const EXPONENT: float = annual_rate * years;
    if (EXPONENT > 700.0 || EXPONENT < -700.0) {
        c_print_err("MochaLibError (mocha-finance): Exponent out of safe range — rate × years exceeds ±700, result would overflow.");
        c_exit(2);
    };
    const GROWTH: float = float(c_exp(EXPONENT));
    return principal * GROWTH;
};

~~ Effective annual rate equivalent to a continuously compounded rate. EAR = e^r - 1.
~~ Errors if |continuous_rate| > 700.
function effective_rate_from_continuous(continuous_rate: float) -> float {
    if (continuous_rate > 700.0 || continuous_rate < -700.0) {
        c_print_err("MochaLibError (mocha-finance): Continuous rate out of safe range (±700).");
        c_exit(2);
    };
    return float(c_exp(continuous_rate)) - 1.0;
};

~~ Continuously compounded rate equivalent to an effective annual rate. r = ln(1 + EAR).
~~ effective_rate > -1.
function continuous_rate_from_effective(effective_rate: float) -> float {
    validate_rate(effective_rate, "Effective rate");
    const GROWTH: float = 1.0 + effective_rate;
    return GROWTH.log().real;
};

~~ Exact doubling time in years at an effective annual rate. t = ln(2) / ln(1 + r).
~~ annual_rate > 0.
function doubling_time(annual_rate: float) -> float {
    validate_positive(annual_rate, "Annual rate");
    const LN2: float = 2.0.log().real;
    const GROWTH: float = 1.0 + annual_rate;
    return LN2 / GROWTH.log().real;
};

~~ Rule of 72 — quick approximation of doubling time in years.
~~ rate_percent is a PERCENT (6 means 6%), > 0. Accurate to about 1 year for rates of 6-10%.
function rule_of_72(rate_percent: float) -> float {
    validate_positive(rate_percent, "Rate percent");
    return 72.0 / rate_percent;
};

~~ Real interest rate after inflation (exact Fisher equation). real = (1 + nominal) / (1 + inflation) - 1.
~~ nominal_rate > -1, inflation_rate > -1.
function real_interest_rate(nominal_rate: float, inflation_rate: float) -> float {
    validate_rate(nominal_rate, "Nominal rate");
    validate_rate(inflation_rate, "Inflation rate");
    return (1.0 + nominal_rate) / (1.0 + inflation_rate) - 1.0;
};

~~ Value in today's money of an amount received in the future, after inflation.
~~ amount >= 0, inflation_rate > -1, years >= 0.
function inflation_adjusted_value(amount: float, inflation_rate: float, years: float) -> float {
    validate_non_negative(amount, "Amount");
    validate_rate(inflation_rate, "Inflation rate");
    validate_non_negative(years, "Years");
    const GROWTH: float = float(c_pow(1.0 + inflation_rate, years));
    return amount / GROWTH;
};

~~ Compound annual growth rate between two values. CAGR = (end/begin)^(1/years) - 1.
~~ begin_value > 0, end_value >= 0, years > 0.
function cagr(begin_value: float, end_value: float, years: float) -> float {
    validate_positive(begin_value, "Beginning value");
    validate_non_negative(end_value, "Ending value");
    validate_positive(years, "Years");
    const RATIO: float = end_value / begin_value;
    return float(c_pow(RATIO, 1.0 / years)) - 1.0;
};

// ================================================================
// SECTION 2: ANNUITIES & LOANS
// ================================================================
// An annuity is a series of equal payments at the end of each period (ordinary annuity),
// or at the start of each period (annuity due, at_start = true).

~~ Present value of a stream of equal payments.
~~ payment >= 0, rate_per_period > -1, n_periods >= 1, at_start = true for an annuity due.
function annuity_present_value(payment: float, rate_per_period: float, n_periods: int, at_start: bool) -> float {
    validate_non_negative(payment, "Payment");
    validate_rate(rate_per_period, "Rate per period");
    if (n_periods < 1) {
        c_print_err("MochaLibError (mocha-finance): Number of periods must be at least 1.");
        c_exit(2);
    };
    var pv: float = 0.0;
    if (rate_per_period == 0.0) {
        pv = payment * float(n_periods);
    } else {
        const DISCOUNT: float = 1.0 / float(c_pow(1.0 + rate_per_period, float(n_periods)));
        pv = payment * (1.0 - DISCOUNT) / rate_per_period;
    };
    if (at_start) {
        pv = pv * (1.0 + rate_per_period);
    };
    return pv;
};

~~ Future value of a stream of equal payments.
~~ payment >= 0, rate_per_period > -1, n_periods >= 1, at_start = true for an annuity due.
function annuity_future_value(payment: float, rate_per_period: float, n_periods: int, at_start: bool) -> float {
    validate_non_negative(payment, "Payment");
    validate_rate(rate_per_period, "Rate per period");
    if (n_periods < 1) {
        c_print_err("MochaLibError (mocha-finance): Number of periods must be at least 1.");
        c_exit(2);
    };
    var fv: float = 0.0;
    if (rate_per_period == 0.0) {
        fv = payment * float(n_periods);
    } else {
        const GROWTH: float = float(c_pow(1.0 + rate_per_period, float(n_periods)));
        fv = payment * (GROWTH - 1.0) / rate_per_period;
    };
    if (at_start) {
        fv = fv * (1.0 + rate_per_period);
    };
    return fv;
};

~~ Present value of a payment that continues forever. PV = payment / r.
~~ payment >= 0, rate_per_period > 0.
function perpetuity_present_value(payment: float, rate_per_period: float) -> float {
    validate_non_negative(payment, "Payment");
    validate_positive(rate_per_period, "Rate per period");
    return payment / rate_per_period;
};

~~ Present value of a payment that grows at a constant rate forever. PV = first_payment / (r - g).
~~ first_payment >= 0, rate_per_period > growth_rate (otherwise the value is infinite).
function growing_perpetuity_present_value(first_payment: float, rate_per_period: float, growth_rate: float) -> float {
    validate_non_negative(first_payment, "First payment");
    validate_positive(rate_per_period, "Rate per period");
    if (rate_per_period <= growth_rate) {
        c_print_err("MochaLibError (mocha-finance): Rate must be greater than the growth rate (otherwise the present value is infinite).");
        c_exit(2);
    };
    return first_payment / (rate_per_period - growth_rate);
};

~~ Fixed payment that repays a loan over n equal periods. pmt = P*r / (1 - (1 + r)^-n).
~~ principal >= 0, rate_per_period >= 0 (monthly loan: annual rate / 12), n_periods >= 1.
function loan_payment(principal: float, rate_per_period: float, n_periods: int) -> float {
    validate_non_negative(principal, "Principal");
    validate_non_negative(rate_per_period, "Rate per period");
    if (n_periods < 1) {
        c_print_err("MochaLibError (mocha-finance): Number of periods must be at least 1.");
        c_exit(2);
    };
    if (rate_per_period == 0.0) {
        return principal / float(n_periods);
    };
    const DISCOUNT: float = 1.0 / float(c_pow(1.0 + rate_per_period, float(n_periods)));
    return (principal * rate_per_period) / (1.0 - DISCOUNT);
};

~~ Remaining loan balance after a number of payments have been made.
~~ principal >= 0, rate_per_period >= 0, n_periods >= 1, payments_made in [0, n_periods].
function loan_balance(principal: float, rate_per_period: float, n_periods: int, payments_made: int) -> float {
    if (payments_made < 0 || payments_made > n_periods) {
        c_print_err("MochaLibError (mocha-finance): Payments made must be between 0 and the number of periods.");
        c_exit(2);
    };
    const PMT: float = loan_payment(principal, rate_per_period, n_periods);
    var balance: float = 0.0;
    if (rate_per_period == 0.0) {
        balance = principal - PMT * float(payments_made);
    } else {
        const GROWTH: float = float(c_pow(1.0 + rate_per_period, float(payments_made)));
        balance = principal * GROWTH - PMT * (GROWTH - 1.0) / rate_per_period;
    };
    if (balance < 0.0) {
        balance = 0.0;
    };
    return balance;
};

~~ Interest part of a single loan payment. Interest = rate * balance before that payment.
~~ payment_number in [1, n_periods].
function loan_interest_in_payment(principal: float, rate_per_period: float, n_periods: int, payment_number: int) -> float {
    if (payment_number < 1 || payment_number > n_periods) {
        c_print_err("MochaLibError (mocha-finance): Payment number must be between 1 and the number of periods.");
        c_exit(2);
    };
    const BEFORE: float = loan_balance(principal, rate_per_period, n_periods, payment_number - 1);
    return BEFORE * rate_per_period;
};

~~ Principal (loan repayment) part of a single loan payment. principal part = payment - interest part.
~~ payment_number in [1, n_periods].
function loan_principal_in_payment(principal: float, rate_per_period: float, n_periods: int, payment_number: int) -> float {
    const PMT: float = loan_payment(principal, rate_per_period, n_periods);
    const INTEREST: float = loan_interest_in_payment(principal, rate_per_period, n_periods, payment_number);
    return PMT - INTEREST;
};

~~ Total interest paid over the whole life of a loan. Interest = pmt * n - principal.
function total_interest_paid(principal: float, rate_per_period: float, n_periods: int) -> float {
    const PMT: float = loan_payment(principal, rate_per_period, n_periods);
    return PMT * float(n_periods) - principal;
};

~~ Number of payments needed to repay a loan with a given payment (may be fractional; round up).
~~ n = -ln(1 - P*r/pmt) / ln(1 + r). principal > 0, payment > 0, rate_per_period >= 0.
~~ Errors if payment <= principal * rate (the loan would never be repaid).
function number_of_payments(principal: float, rate_per_period: float, payment: float) -> float {
    validate_positive(principal, "Principal");
    validate_positive(payment, "Payment");
    validate_non_negative(rate_per_period, "Rate per period");
    if (rate_per_period == 0.0) {
        return principal / payment;
    };
    const INTEREST_ONLY: float = principal * rate_per_period;
    if (payment <= INTEREST_ONLY) {
        c_print_err("MochaLibError (mocha-finance): Payment does not cover the interest — the loan can never be repaid.");
        c_exit(2);
    };
    const INNER: float = 1.0 - INTEREST_ONLY / payment;
    const GROWTH: float = 1.0 + rate_per_period;
    return (0.0 - INNER.log().real) / GROWTH.log().real;
};

// ================================================================
// SECTION 3: CAPITAL BUDGETING
// ================================================================
// Cash-flow arrays: element 0 is the flow at time 0 (usually the negative initial
// investment), element 1 is one period later, and so on.

~~ Net present value of a series of cash flows. NPV = Σ cash_flow[t] / (1 + r)^t.
~~ cash_flows must be non-empty, rate > -1.
function net_present_value(rate: float, cash_flows: float[]) -> float {
    validate_rate(rate, "Discount rate");
    var n: int = cash_flows.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-finance): Cash flow array cannot be empty.");
        c_exit(2);
    };
    var total: float = 0.0;
    var discount: float = 1.0;
    var step: float = 1.0 + rate;
    var t: int = 0;
    while (t < n) {
        total = total + cash_flows[t] / discount;
        discount = discount * step;
        t++;
    };
    return total;
};

~~ Internal rate of return — the discount rate at which NPV is zero (found by bisection).
~~ Needs at least one negative and one positive cash flow. Searches from -99% to +1000%.
~~ Errors if NPV has the same sign at both ends. If several rates give zero NPV, returns one of them.
function internal_rate_of_return(cash_flows: float[]) -> float {
    var n: int = cash_flows.length;
    if (n < 2) {
        c_print_err("MochaLibError (mocha-finance): IRR needs at least 2 cash flows.");
        c_exit(2);
    };
    var has_negative: bool = false;
    var has_positive: bool = false;
    var i: int = 0;
    while (i < n) {
        if (cash_flows[i] < 0.0) { has_negative = true; };
        if (cash_flows[i] > 0.0) { has_positive = true; };
        i++;
    };
    if (!has_negative || !has_positive) {
        c_print_err("MochaLibError (mocha-finance): IRR needs at least one negative and one positive cash flow.");
        c_exit(2);
    };
    var lo: float = -0.99;
    var hi: float = 10.0;
    var npv_lo: float = net_present_value(lo, cash_flows);
    var npv_hi: float = net_present_value(hi, cash_flows);
    if (npv_lo == 0.0) { return lo; };
    if (npv_hi == 0.0) { return hi; };
    if ((npv_lo > 0.0 && npv_hi > 0.0) || (npv_lo < 0.0 && npv_hi < 0.0)) {
        c_print_err("MochaLibError (mocha-finance): No IRR found between -99% and +1000% (NPV has the same sign at both ends).");
        c_exit(2);
    };
    var iter: int = 0;
    while (iter < 200) {
        var mid: float = (lo + hi) / 2.0;
        var npv_mid: float = net_present_value(mid, cash_flows);
        if (npv_mid == 0.0) {
            return mid;
        };
        if ((npv_mid > 0.0 && npv_lo > 0.0) || (npv_mid < 0.0 && npv_lo < 0.0)) {
            lo = mid;
            npv_lo = npv_mid;
        } else {
            hi = mid;
        };
        if (hi - lo < 1E-10) {
            break;
        };
        iter++;
    };
    return (lo + hi) / 2.0;
};

~~ Payback period in periods, with linear interpolation inside the recovery period.
~~ Returns -1.0 if the investment is never recovered. cash_flows must be non-empty.
function payback_period(cash_flows: float[]) -> float {
    var n: int = cash_flows.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-finance): Cash flow array cannot be empty.");
        c_exit(2);
    };
    var cumulative: float = 0.0;
    var t: int = 0;
    while (t < n) {
        var previous: float = cumulative;
        cumulative = cumulative + cash_flows[t];
        if (cumulative >= 0.0) {
            if (t == 0) {
                return 0.0;
            };
            return float(t - 1) + (0.0 - previous) / cash_flows[t];
        };
        t++;
    };
    return -1.0;
};

~~ Discounted payback period — like payback_period, but each flow is first discounted at the given rate.
~~ Returns -1.0 if never recovered. rate > -1, cash_flows must be non-empty.
function discounted_payback_period(rate: float, cash_flows: float[]) -> float {
    validate_rate(rate, "Discount rate");
    var n: int = cash_flows.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-finance): Cash flow array cannot be empty.");
        c_exit(2);
    };
    var cumulative: float = 0.0;
    var discount: float = 1.0;
    var step: float = 1.0 + rate;
    var t: int = 0;
    while (t < n) {
        var previous: float = cumulative;
        var discounted: float = cash_flows[t] / discount;
        cumulative = cumulative + discounted;
        if (cumulative >= 0.0) {
            if (t == 0) {
                return 0.0;
            };
            return float(t - 1) + (0.0 - previous) / discounted;
        };
        discount = discount * step;
        t++;
    };
    return -1.0;
};

~~ Profitability index = present value of future cash flows / initial investment.
~~ Above 1.0 means the project creates value. cash_flows[0] must be negative (the investment).
function profitability_index(rate: float, cash_flows: float[]) -> float {
    if (cash_flows.length < 2) {
        c_print_err("MochaLibError (mocha-finance): Profitability index needs at least 2 cash flows.");
        c_exit(2);
    };
    if (cash_flows[0] >= 0.0) {
        c_print_err("MochaLibError (mocha-finance): The first cash flow must be negative (the initial investment).");
        c_exit(2);
    };
    const INITIAL: float = 0.0 - cash_flows[0];
    const NPV: float = net_present_value(rate, cash_flows);
    return (NPV + INITIAL) / INITIAL;
};

~~ Modified internal rate of return (MIRR). Outflows are discounted at finance_rate, inflows are
~~ compounded forward at reinvest_rate, so it always has one answer.
~~ MIRR = (FV of inflows / PV of outflows)^(1/n) - 1, n = number of periods (length - 1).
~~ Needs at least one negative and one positive cash flow; both rates > -1.
function modified_internal_rate_of_return(cash_flows: float[], finance_rate: float, reinvest_rate: float) -> float {
    validate_rate(finance_rate, "Finance rate");
    validate_rate(reinvest_rate, "Reinvestment rate");
    var count: int = cash_flows.length;
    if (count < 2) {
        c_print_err("MochaLibError (mocha-finance): MIRR needs at least 2 cash flows.");
        c_exit(2);
    };
    var periods: int = count - 1;
    var pv_outflows: float = 0.0;
    var fv_inflows: float = 0.0;
    var t: int = 0;
    while (t < count) {
        if (cash_flows[t] < 0.0) {
            const OUT_DISCOUNT: float = float(c_pow(1.0 + finance_rate, float(t)));
            pv_outflows = pv_outflows + (0.0 - cash_flows[t]) / OUT_DISCOUNT;
        };
        if (cash_flows[t] > 0.0) {
            const IN_GROWTH: float = float(c_pow(1.0 + reinvest_rate, float(periods - t)));
            fv_inflows = fv_inflows + cash_flows[t] * IN_GROWTH;
        };
        t++;
    };
    if (pv_outflows <= 0.0 || fv_inflows <= 0.0) {
        c_print_err("MochaLibError (mocha-finance): MIRR needs at least one negative and one positive cash flow.");
        c_exit(2);
    };
    const RATIO: float = fv_inflows / pv_outflows;
    return float(c_pow(RATIO, 1.0 / float(periods))) - 1.0;
};

// ================================================================
// SECTION 4: BONDS
// ================================================================
// Rates and periods use the same unit. For a semi-annual bond, pass the half-year
// coupon rate, the half-year yield and twice the number of years.

~~ Validates a number of periods is at least 1.
local function validate_period_count(n_periods: int) -> int {
    if (n_periods < 1) {
        c_print_err("MochaLibError (mocha-finance): Number of periods must be at least 1.");
        c_exit(2);
    };
    return n_periods;
};

~~ Validates a value is in [0, 1].
local function validate_proportion(p: float, name: str) -> float {
    if (p < 0.0 || p > 1.0) {
        c_print_err("MochaLibError (mocha-finance): " + name + " must be in [0, 1].");
        c_exit(2);
    };
    return p;
};

~~ Price of a zero-coupon bond. P = face / (1 + y)^n.
~~ face_value > 0, yield_per_period > -1, n_periods >= 1.
function zero_coupon_price(face_value: float, yield_per_period: float, n_periods: int) -> float {
    validate_positive(face_value, "Face value");
    validate_rate(yield_per_period, "Yield per period");
    validate_period_count(n_periods);
    const GROWTH: float = float(c_pow(1.0 + yield_per_period, float(n_periods)));
    return face_value / GROWTH;
};

~~ Price of a coupon bond: present value of the coupons plus present value of the face value.
~~ coupon_rate = coupon per period as a fraction of face value (3% per half-year = 0.03).
~~ face_value > 0, coupon_rate >= 0, yield_per_period > -1, n_periods >= 1.
function bond_price(face_value: float, coupon_rate: float, yield_per_period: float, n_periods: int) -> float {
    validate_positive(face_value, "Face value");
    validate_non_negative(coupon_rate, "Coupon rate");
    validate_rate(yield_per_period, "Yield per period");
    validate_period_count(n_periods);
    const COUPON: float = face_value * coupon_rate;
    const DISCOUNT: float = 1.0 / float(c_pow(1.0 + yield_per_period, float(n_periods)));
    var coupons_pv: float = 0.0;
    if (yield_per_period == 0.0) {
        coupons_pv = COUPON * float(n_periods);
    } else {
        coupons_pv = COUPON * (1.0 - DISCOUNT) / yield_per_period;
    };
    return coupons_pv + face_value * DISCOUNT;
};

~~ Current yield = annual coupon payment / market price.
~~ annual_coupon >= 0, price > 0.
function current_yield(annual_coupon: float, price: float) -> float {
    validate_non_negative(annual_coupon, "Annual coupon");
    validate_positive(price, "Price");
    return annual_coupon / price;
};

~~ Yield to maturity per period (found by bisection), the yield that makes bond_price equal the market price.
~~ Searches 0% to 500% per period. Errors if the price is above the sum of all payments (negative yield,
~~ not supported) or too low for a yield under 500%.
function yield_to_maturity(price: float, face_value: float, coupon_rate: float, n_periods: int) -> float {
    validate_positive(price, "Price");
    validate_positive(face_value, "Face value");
    validate_non_negative(coupon_rate, "Coupon rate");
    validate_period_count(n_periods);
    var lo: float = 0.0;
    var hi: float = 5.0;
    const PRICE_AT_ZERO: float = bond_price(face_value, coupon_rate, 0.0, n_periods);
    if (price > PRICE_AT_ZERO) {
        c_print_err("MochaLibError (mocha-finance): Price is above the total of all payments — the yield would be negative, which is not supported.");
        c_exit(2);
    };
    const PRICE_AT_HIGH: float = bond_price(face_value, coupon_rate, hi, n_periods);
    if (price < PRICE_AT_HIGH) {
        c_print_err("MochaLibError (mocha-finance): Price is too low — the yield would be above 500% per period.");
        c_exit(2);
    };
    var iter: int = 0;
    while (iter < 200) {
        var mid: float = (lo + hi) / 2.0;
        var price_mid: float = bond_price(face_value, coupon_rate, mid, n_periods);
        if (price_mid > price) {
            lo = mid;
        } else {
            hi = mid;
        };
        if (hi - lo < 1E-10) {
            break;
        };
        iter++;
    };
    return (lo + hi) / 2.0;
};

~~ Macaulay duration in periods: the average time to receive the bond's cash flows, weighted by present value.
~~ Same arguments as bond_price.
function macaulay_duration(face_value: float, coupon_rate: float, yield_per_period: float, n_periods: int) -> float {
    validate_positive(face_value, "Face value");
    validate_non_negative(coupon_rate, "Coupon rate");
    validate_rate(yield_per_period, "Yield per period");
    validate_period_count(n_periods);
    const COUPON: float = face_value * coupon_rate;
    const STEP: float = 1.0 + yield_per_period;
    var discount: float = 1.0;
    var price: float = 0.0;
    var weighted: float = 0.0;
    var t: int = 1;
    while (t <= n_periods) {
        discount = discount * STEP;
        var cash: float = COUPON;
        if (t == n_periods) {
            cash = cash + face_value;
        };
        var pv: float = cash / discount;
        price = price + pv;
        weighted = weighted + float(t) * pv;
        t++;
    };
    return weighted / price;
};

~~ Modified duration in periods = Macaulay duration / (1 + y). Approximate % price change per 1.00 change in yield.
~~ Same arguments as bond_price.
function modified_duration(face_value: float, coupon_rate: float, yield_per_period: float, n_periods: int) -> float {
    const MAC: float = macaulay_duration(face_value, coupon_rate, yield_per_period, n_periods);
    return MAC / (1.0 + yield_per_period);
};

~~ Convexity of a bond (in periods squared): how much its duration changes as yields move.
~~ Same arguments as bond_price.
function bond_convexity(face_value: float, coupon_rate: float, yield_per_period: float, n_periods: int) -> float {
    validate_positive(face_value, "Face value");
    validate_non_negative(coupon_rate, "Coupon rate");
    validate_rate(yield_per_period, "Yield per period");
    validate_period_count(n_periods);
    const COUPON: float = face_value * coupon_rate;
    const STEP: float = 1.0 + yield_per_period;
    var discount: float = 1.0;
    var price: float = 0.0;
    var weighted: float = 0.0;
    var t: int = 1;
    while (t <= n_periods) {
        discount = discount * STEP;
        var cash: float = COUPON;
        if (t == n_periods) {
            cash = cash + face_value;
        };
        var pv: float = cash / discount;
        price = price + pv;
        weighted = weighted + float(t * (t + 1)) * pv;
        t++;
    };
    return weighted / (price * STEP * STEP);
};

~~ Estimated fractional price change for a yield change, using duration and convexity.
~~ change ≈ -D_mod * dy + 0.5 * convexity * dy². yield_change as a decimal (0.01 = +1 point).
function bond_price_change_estimate(mod_duration: float, convexity: float, yield_change: float) -> float {
    return (0.0 - mod_duration) * yield_change + 0.5 * convexity * yield_change * yield_change;
};

// ================================================================
// SECTION 5: EQUITY VALUATION
// ================================================================

~~ Stock price from the Gordon growth model. P = D1 / (r - g).
~~ next_dividend >= 0, required_return > growth_rate, required_return > 0.
function gordon_growth_price(next_dividend: float, required_return: float, growth_rate: float) -> float {
    return growing_perpetuity_present_value(next_dividend, required_return, growth_rate);
};

~~ Multi-stage dividend discount value: explicit dividends for years 1..n, then a Gordon terminal value.
~~ dividends[0] is the dividend at the end of year 1. terminal_growth applies after the last listed dividend.
~~ required_return > terminal_growth, both > -1, dividends non-empty.
function dividend_discount_value(required_return: float, dividends: float[], terminal_growth: float) -> float {
    validate_rate(required_return, "Required return");
    validate_rate(terminal_growth, "Terminal growth");
    if (required_return <= terminal_growth) {
        c_print_err("MochaLibError (mocha-finance): Required return must be greater than the terminal growth rate.");
        c_exit(2);
    };
    var n: int = dividends.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-finance): Dividend array cannot be empty.");
        c_exit(2);
    };
    const STEP: float = 1.0 + required_return;
    var discount: float = 1.0;
    var total: float = 0.0;
    var t: int = 0;
    while (t < n) {
        discount = discount * STEP;
        total = total + dividends[t] / discount;
        t++;
    };
    const TERMINAL: float = dividends[n - 1] * (1.0 + terminal_growth) / (required_return - terminal_growth);
    return total + TERMINAL / discount;
};

~~ Expected return from the capital asset pricing model. E[R] = rf + beta * (market_return - rf).
~~ risk_free_rate > -1, market_return > -1. Beta may be any value.
function capm_expected_return(risk_free_rate: float, beta: float, market_return: float) -> float {
    validate_rate(risk_free_rate, "Risk-free rate");
    validate_rate(market_return, "Market return");
    return risk_free_rate + beta * (market_return - risk_free_rate);
};

~~ Weighted average cost of capital. WACC = E/V * Re + D/V * Rd * (1 - tax).
~~ equity_value >= 0, debt_value >= 0, both not zero; tax_rate in [0, 1].
function wacc(equity_value: float, debt_value: float, cost_of_equity: float, cost_of_debt: float, tax_rate: float) -> float {
    validate_non_negative(equity_value, "Equity value");
    validate_non_negative(debt_value, "Debt value");
    validate_proportion(tax_rate, "Tax rate");
    const TOTAL: float = equity_value + debt_value;
    validate_positive(TOTAL, "Total capital (equity + debt)");
    const E_WEIGHT: float = equity_value / TOTAL;
    const D_WEIGHT: float = debt_value / TOTAL;
    return E_WEIGHT * cost_of_equity + D_WEIGHT * cost_of_debt * (1.0 - tax_rate);
};

~~ Dividend yield = annual dividend per share / price. annual_dividend >= 0, price > 0.
function dividend_yield(annual_dividend: float, price: float) -> float {
    validate_non_negative(annual_dividend, "Annual dividend");
    validate_positive(price, "Price");
    return annual_dividend / price;
};

~~ Earnings yield = earnings per share / price (inverse of P/E). price > 0; EPS may be negative.
function earnings_yield(eps: float, price: float) -> float {
    validate_positive(price, "Price");
    return eps / price;
};

~~ Price-to-earnings ratio. price > 0, eps > 0 (undefined for zero or negative earnings).
function price_to_earnings_ratio(price: float, eps: float) -> float {
    validate_positive(price, "Price");
    validate_positive(eps, "Earnings per share");
    return price / eps;
};

~~ Dividend payout ratio = dividends per share / earnings per share. dividends >= 0, eps > 0.
function payout_ratio(dividends_per_share: float, eps: float) -> float {
    validate_non_negative(dividends_per_share, "Dividends per share");
    validate_positive(eps, "Earnings per share");
    return dividends_per_share / eps;
};

~~ Sustainable growth rate = return on equity * retention ratio. retention_ratio in [0, 1].
function sustainable_growth_rate(return_on_equity: float, retention_ratio: float) -> float {
    validate_proportion(retention_ratio, "Retention ratio");
    return return_on_equity * retention_ratio;
};

// ================================================================
// SECTION 6: RISK & PORTFOLIO
// ================================================================
// Return series are arrays of per-period returns as decimals (0.02 = +2%).
// Volatility and covariance use the sample formulas (divide by n - 1).

~~ Simple return between two prices. R = end / begin - 1. begin_price > 0, end_price >= 0.
function simple_return(begin_price: float, end_price: float) -> float {
    validate_positive(begin_price, "Beginning price");
    validate_non_negative(end_price, "Ending price");
    return end_price / begin_price - 1.0;
};

~~ Logarithmic (continuously compounded) return between two prices. R = ln(end / begin). Both prices > 0.
function log_return(begin_price: float, end_price: float) -> float {
    validate_positive(begin_price, "Beginning price");
    validate_positive(end_price, "Ending price");
    const RATIO: float = end_price / begin_price;
    return RATIO.log().real;
};

~~ Mean of a return series. Requires a non-empty array.
function mean_return(returns: float[]) -> float {
    var n: int = returns.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-finance): Return array cannot be empty.");
        c_exit(2);
    };
    var total: float = 0.0;
    var i: int = 0;
    while (i < n) {
        total = total + returns[i];
        i++;
    };
    return total / float(n);
};

~~ Sample covariance of two return series. Same length, at least 2 observations.
function return_covariance(a: float[], b: float[]) -> float {
    var n: int = a.length;
    if (n != b.length) {
        c_print_err("MochaLibError (mocha-finance): Return series must have the same length.");
        c_exit(2);
    };
    if (n < 2) {
        c_print_err("MochaLibError (mocha-finance): Covariance needs at least 2 observations.");
        c_exit(2);
    };
    const MEAN_A: float = mean_return(a);
    const MEAN_B: float = mean_return(b);
    var total: float = 0.0;
    var i: int = 0;
    while (i < n) {
        total = total + (a[i] - MEAN_A) * (b[i] - MEAN_B);
        i++;
    };
    return total / float(n - 1);
};

~~ Volatility (sample standard deviation) of a return series, per period. At least 2 observations.
function return_volatility(returns: float[]) -> float {
    if (returns.length < 2) {
        c_print_err("MochaLibError (mocha-finance): Volatility needs at least 2 observations.");
        c_exit(2);
    };
    const VARIANCE: float = return_covariance(returns, returns);
    return VARIANCE.sqrt().real;
};

~~ Annualized volatility from a per-period volatility. vol * sqrt(periods per year).
~~ volatility >= 0, periods_per_year >= 1 (12 for monthly, 252 for daily trading days).
function annualize_volatility(volatility: float, periods_per_year: int) -> float {
    validate_non_negative(volatility, "Volatility");
    validate_period_count(periods_per_year);
    const PERIODS: float = float(periods_per_year);
    const ROOT: float = PERIODS.sqrt().real;
    return volatility * ROOT;
};

~~ Sharpe ratio = (mean return - risk-free rate) / volatility. All per the same period. volatility > 0.
function sharpe_ratio(mean_return_value: float, risk_free_rate: float, volatility: float) -> float {
    validate_positive(volatility, "Volatility");
    return (mean_return_value - risk_free_rate) / volatility;
};

~~ Correlation of two return series, in [-1, 1]. Errors if either series has zero volatility.
function return_correlation(a: float[], b: float[]) -> float {
    const SD_A: float = return_volatility(a);
    const SD_B: float = return_volatility(b);
    if (SD_A <= 0.0 || SD_B <= 0.0) {
        c_print_err("MochaLibError (mocha-finance): Correlation undefined — a return series has zero volatility.");
        c_exit(2);
    };
    return return_covariance(a, b) / (SD_A * SD_B);
};

~~ Beta of an asset against the market = covariance(asset, market) / variance(market).
~~ Same length, at least 2 observations, market returns must vary.
function beta_from_returns(asset_returns: float[], market_returns: float[]) -> float {
    const MARKET_VARIANCE: float = return_covariance(market_returns, market_returns);
    if (MARKET_VARIANCE <= 0.0) {
        c_print_err("MochaLibError (mocha-finance): Beta undefined — market returns have zero variance.");
        c_exit(2);
    };
    return return_covariance(asset_returns, market_returns) / MARKET_VARIANCE;
};

~~ Jensen's alpha = portfolio return - CAPM expected return. Positive means it beat the market-adjusted benchmark.
function jensens_alpha(portfolio_return: float, risk_free_rate: float, beta: float, market_return: float) -> float {
    const EXPECTED: float = capm_expected_return(risk_free_rate, beta, market_return);
    return portfolio_return - EXPECTED;
};

~~ Expected return of a two-asset portfolio. weight1 in [0, 1] (the other asset gets 1 - weight1).
function two_asset_return(weight1: float, return1: float, return2: float) -> float {
    validate_proportion(weight1, "Weight of asset 1");
    return weight1 * return1 + (1.0 - weight1) * return2;
};

~~ Volatility of a two-asset portfolio. weight1 in [0, 1], vol1 >= 0, vol2 >= 0, correlation in [-1, 1].
function two_asset_volatility(weight1: float, vol1: float, vol2: float, correlation: float) -> float {
    validate_proportion(weight1, "Weight of asset 1");
    validate_non_negative(vol1, "Volatility of asset 1");
    validate_non_negative(vol2, "Volatility of asset 2");
    if (correlation < -1.0 || correlation > 1.0) {
        c_print_err("MochaLibError (mocha-finance): Correlation must be in [-1, 1].");
        c_exit(2);
    };
    const WEIGHT2: float = 1.0 - weight1;
    var variance: float = weight1 * weight1 * vol1 * vol1 + WEIGHT2 * WEIGHT2 * vol2 * vol2 + 2.0 * weight1 * WEIGHT2 * correlation * vol1 * vol2;
    if (variance < 0.0) {
        variance = 0.0;
    };
    return variance.sqrt().real;
};

~~ Parametric (normal) value at risk: the loss not expected to be exceeded at a confidence level.
~~ VaR = value * (z * volatility - mean_return). Pass z_score yourself: 1.645 for 95%, 2.326 for 99%.
~~ portfolio_value > 0, volatility >= 0, z_score > 0. Never returns less than 0.
function parametric_var(portfolio_value: float, mean_return_value: float, volatility: float, z_score: float) -> float {
    validate_positive(portfolio_value, "Portfolio value");
    validate_non_negative(volatility, "Volatility");
    validate_positive(z_score, "Z-score");
    var loss: float = portfolio_value * (z_score * volatility - mean_return_value);
    if (loss < 0.0) {
        loss = 0.0;
    };
    return loss;
};

~~ Maximum drawdown: the largest fall from a peak to a later low, as a fraction (0.25 = -25%).
~~ prices = chronological array of prices, at least 2, all > 0.
function max_drawdown(prices: float[]) -> float {
    var n: int = prices.length;
    if (n < 2) {
        c_print_err("MochaLibError (mocha-finance): Max drawdown needs at least 2 prices.");
        c_exit(2);
    };
    var peak: float = prices[0];
    var worst: float = 0.0;
    var i: int = 0;
    while (i < n) {
        if (prices[i] <= 0.0) {
            c_print_err("MochaLibError (mocha-finance): Prices must be positive.");
            c_exit(2);
        };
        if (prices[i] > peak) {
            peak = prices[i];
        };
        var drawdown: float = (peak - prices[i]) / peak;
        if (drawdown > worst) {
            worst = drawdown;
        };
        i++;
    };
    return worst;
};

// ================================================================
// SECTION 7: OPTIONS
// ================================================================
// Black-Scholes prices European options on a stock that pays no dividends.
// rate = continuously compounded risk-free rate (decimal), volatility = annual (0.2 = 20%),
// years = time to expiry. is_call = true for a call, false for a put.
// Greeks are raw derivatives: vega and rho are per 1.00 change (divide by 100 for per
// percentage point), theta is per year (divide by 365 for per day).

~~ Standard normal cumulative distribution function (via erf).
local function std_normal_cdf(x: float) -> float {
    const SCALED: float = x / 1.4142135623730951;
    const ERF_VALUE: float = SCALED.erf();
    return 0.5 * (1.0 + ERF_VALUE);
};

~~ Standard normal probability density function.
local function std_normal_pdf(x: float) -> float {
    return 0.3989422804014327 * float(c_exp(0.0 - 0.5 * x * x));
};

~~ Validates the inputs shared by all Black-Scholes functions.
local function validate_option_inputs(spot: float, strike: float, volatility: float, years: float) -> null {
    validate_positive(spot, "Spot price");
    validate_positive(strike, "Strike price");
    validate_positive(volatility, "Volatility");
    validate_positive(years, "Years to expiry");
};

~~ The Black-Scholes d1 term: (ln(S/K) + (r + vol²/2) * T) / (vol * sqrt(T)).
local function bs_d1(spot: float, strike: float, rate: float, volatility: float, years: float) -> float {
    const RATIO: float = spot / strike;
    const LN_RATIO: float = RATIO.log().real;
    const ROOT_T: float = years.sqrt().real;
    return (LN_RATIO + (rate + 0.5 * volatility * volatility) * years) / (volatility * ROOT_T);
};

~~ Black-Scholes price of a European call. C = S*N(d1) - K*e^(-rT)*N(d2).
~~ spot > 0, strike > 0, volatility > 0, years > 0; rate may be any value. No dividends.
function black_scholes_call(spot: float, strike: float, rate: float, volatility: float, years: float) -> float {
    validate_option_inputs(spot, strike, volatility, years);
    const D1: float = bs_d1(spot, strike, rate, volatility, years);
    const ROOT_T: float = years.sqrt().real;
    const D2: float = D1 - volatility * ROOT_T;
    const DISCOUNT: float = float(c_exp(0.0 - rate * years));
    return spot * std_normal_cdf(D1) - strike * DISCOUNT * std_normal_cdf(D2);
};

~~ Black-Scholes price of a European put. P = K*e^(-rT)*N(-d2) - S*N(-d1).
~~ Same arguments as black_scholes_call.
function black_scholes_put(spot: float, strike: float, rate: float, volatility: float, years: float) -> float {
    validate_option_inputs(spot, strike, volatility, years);
    const D1: float = bs_d1(spot, strike, rate, volatility, years);
    const ROOT_T: float = years.sqrt().real;
    const D2: float = D1 - volatility * ROOT_T;
    const DISCOUNT: float = float(c_exp(0.0 - rate * years));
    return strike * DISCOUNT * std_normal_cdf(0.0 - D2) - spot * std_normal_cdf(0.0 - D1);
};

~~ Price of a European option from the matching call or put (shared helper).
local function bs_price(is_call: bool, spot: float, strike: float, rate: float, volatility: float, years: float) -> float {
    if (is_call) {
        return black_scholes_call(spot, strike, rate, volatility, years);
    };
    return black_scholes_put(spot, strike, rate, volatility, years);
};

~~ European put price from a call price using put-call parity. P = C - S + K*e^(-rT).
~~ call_price >= 0, spot > 0, strike > 0, years > 0.
function put_from_call_parity(call_price: float, spot: float, strike: float, rate: float, years: float) -> float {
    validate_non_negative(call_price, "Call price");
    validate_positive(spot, "Spot price");
    validate_positive(strike, "Strike price");
    validate_positive(years, "Years to expiry");
    const DISCOUNT: float = float(c_exp(0.0 - rate * years));
    return call_price - spot + strike * DISCOUNT;
};

~~ Intrinsic value: what the option would pay if exercised now (never below 0).
~~ Call: max(S - K, 0). Put: max(K - S, 0). spot >= 0, strike >= 0.
function option_intrinsic_value(is_call: bool, spot: float, strike: float) -> float {
    validate_non_negative(spot, "Spot price");
    validate_non_negative(strike, "Strike price");
    var value: float = 0.0;
    if (is_call) {
        value = spot - strike;
    } else {
        value = strike - spot;
    };
    if (value < 0.0) {
        value = 0.0;
    };
    return value;
};

~~ Delta: how much the option price moves per 1.00 move in the stock price. Call in (0, 1), put in (-1, 0).
function option_delta(is_call: bool, spot: float, strike: float, rate: float, volatility: float, years: float) -> float {
    validate_option_inputs(spot, strike, volatility, years);
    const D1: float = bs_d1(spot, strike, rate, volatility, years);
    const CALL_DELTA: float = std_normal_cdf(D1);
    if (is_call) {
        return CALL_DELTA;
    };
    return CALL_DELTA - 1.0;
};

~~ Gamma: how fast delta changes per 1.00 move in the stock price (same for calls and puts).
function option_gamma(spot: float, strike: float, rate: float, volatility: float, years: float) -> float {
    validate_option_inputs(spot, strike, volatility, years);
    const D1: float = bs_d1(spot, strike, rate, volatility, years);
    const ROOT_T: float = years.sqrt().real;
    return std_normal_pdf(D1) / (spot * volatility * ROOT_T);
};

~~ Vega: price change per 1.00 (100 points) change in volatility (same for calls and puts).
~~ Divide by 100 for the change per percentage point.
function option_vega(spot: float, strike: float, rate: float, volatility: float, years: float) -> float {
    validate_option_inputs(spot, strike, volatility, years);
    const D1: float = bs_d1(spot, strike, rate, volatility, years);
    const ROOT_T: float = years.sqrt().real;
    return spot * std_normal_pdf(D1) * ROOT_T;
};

~~ Theta: price change per year as time passes (usually negative). Divide by 365 for per day.
function option_theta(is_call: bool, spot: float, strike: float, rate: float, volatility: float, years: float) -> float {
    validate_option_inputs(spot, strike, volatility, years);
    const D1: float = bs_d1(spot, strike, rate, volatility, years);
    const ROOT_T: float = years.sqrt().real;
    const D2: float = D1 - volatility * ROOT_T;
    const DISCOUNT: float = float(c_exp(0.0 - rate * years));
    const DECAY: float = (0.0 - spot) * std_normal_pdf(D1) * volatility / (2.0 * ROOT_T);
    if (is_call) {
        return DECAY - rate * strike * DISCOUNT * std_normal_cdf(D2);
    };
    return DECAY + rate * strike * DISCOUNT * std_normal_cdf(0.0 - D2);
};

~~ Rho: price change per 1.00 change in the interest rate. Divide by 100 for per percentage point.
function option_rho(is_call: bool, spot: float, strike: float, rate: float, volatility: float, years: float) -> float {
    validate_option_inputs(spot, strike, volatility, years);
    const D1: float = bs_d1(spot, strike, rate, volatility, years);
    const ROOT_T: float = years.sqrt().real;
    const D2: float = D1 - volatility * ROOT_T;
    const DISCOUNT: float = float(c_exp(0.0 - rate * years));
    if (is_call) {
        return strike * years * DISCOUNT * std_normal_cdf(D2);
    };
    return (0.0 - strike) * years * DISCOUNT * std_normal_cdf(0.0 - D2);
};

~~ Implied volatility: the volatility that makes the Black-Scholes price equal the market price (bisection).
~~ Searches 0.01% to 500%. Errors if the market price is outside what that range can produce.
function implied_volatility(is_call: bool, market_price: float, spot: float, strike: float, rate: float, years: float) -> float {
    validate_positive(market_price, "Market price");
    validate_positive(spot, "Spot price");
    validate_positive(strike, "Strike price");
    validate_positive(years, "Years to expiry");
    var lo: float = 0.0001;
    var hi: float = 5.0;
    const PRICE_LO: float = bs_price(is_call, spot, strike, rate, lo, years);
    const PRICE_HI: float = bs_price(is_call, spot, strike, rate, hi, years);
    if (market_price < PRICE_LO || market_price > PRICE_HI) {
        c_print_err("MochaLibError (mocha-finance): No implied volatility between 0.01% and 500% reproduces this price.");
        c_exit(2);
    };
    var iter: int = 0;
    while (iter < 200) {
        var mid: float = (lo + hi) / 2.0;
        if (bs_price(is_call, spot, strike, rate, mid, years) < market_price) {
            lo = mid;
        } else {
            hi = mid;
        };
        if (hi - lo < 1E-10) {
            break;
        };
        iter++;
    };
    return (lo + hi) / 2.0;
};

~~ Option price from a Cox-Ross-Rubinstein binomial tree. Handles American options (american = true),
~~ which can be exercised early, so it differs from Black-Scholes for American puts. More steps = more accurate
~~ (200-500 is typical). spot > 0, strike > 0, volatility > 0, years > 0, steps >= 1. No dividends.
function binomial_option_price(is_call: bool, spot: float, strike: float, rate: float, volatility: float, years: float, steps: int, american: bool) -> float {
    validate_option_inputs(spot, strike, volatility, years);
    if (steps < 1) {
        c_print_err("MochaLibError (mocha-finance): Number of steps must be at least 1.");
        c_exit(2);
    };
    const DT: float = years / float(steps);
    const ROOT_DT: float = DT.sqrt().real;
    const UP: float = float(c_exp(volatility * ROOT_DT));
    const DOWN: float = 1.0 / UP;
    const GROWTH: float = float(c_exp(rate * DT));
    const P_UP: float = (GROWTH - DOWN) / (UP - DOWN);
    if (P_UP <= 0.0 || P_UP >= 1.0) {
        c_print_err("MochaLibError (mocha-finance): Binomial tree is unstable for these inputs — increase the number of steps.");
        c_exit(2);
    };
    const DISCOUNT: float = 1.0 / GROWTH;
    var values: float[] = alloc float[steps + 1];
    var j: int = 0;
    while (j <= steps) {
        const NODE: float = spot * float(c_pow(UP, float(j))) * float(c_pow(DOWN, float(steps - j)));
        values[j] = option_intrinsic_value(is_call, NODE, strike);
        j++;
    };
    var step: int = steps - 1;
    while (step >= 0) {
        var k: int = 0;
        while (k <= step) {
            var value: float = DISCOUNT * (P_UP * values[k + 1] + (1.0 - P_UP) * values[k]);
            if (american) {
                const NODE_S: float = spot * float(c_pow(UP, float(k))) * float(c_pow(DOWN, float(step - k)));
                const EXERCISE: float = option_intrinsic_value(is_call, NODE_S, strike);
                if (EXERCISE > value) {
                    value = EXERCISE;
                };
            };
            values[k] = value;
            k++;
        };
        step = step - 1;
    };
    return values[0];
};

// ================================================================
// SECTION 8: FINANCIAL RATIOS
// ================================================================
// Margins and returns are fractions (0.15 = 15%), like all rates in this library.

~~ Current ratio = current assets / current liabilities. Liabilities > 0.
function current_ratio(current_assets: float, current_liabilities: float) -> float {
    validate_non_negative(current_assets, "Current assets");
    validate_positive(current_liabilities, "Current liabilities");
    return current_assets / current_liabilities;
};

~~ Quick (acid-test) ratio = (current assets - inventory) / current liabilities. Inventory <= current assets.
function quick_ratio(current_assets: float, inventory: float, current_liabilities: float) -> float {
    validate_non_negative(current_assets, "Current assets");
    validate_non_negative(inventory, "Inventory");
    validate_positive(current_liabilities, "Current liabilities");
    if (inventory > current_assets) {
        c_print_err("MochaLibError (mocha-finance): Inventory cannot exceed current assets.");
        c_exit(2);
    };
    return (current_assets - inventory) / current_liabilities;
};

~~ Cash ratio = cash and equivalents / current liabilities. Liabilities > 0.
function cash_ratio(cash: float, current_liabilities: float) -> float {
    validate_non_negative(cash, "Cash");
    validate_positive(current_liabilities, "Current liabilities");
    return cash / current_liabilities;
};

~~ Debt-to-equity ratio = total debt / total equity. Equity > 0.
function debt_to_equity(total_debt: float, total_equity: float) -> float {
    validate_non_negative(total_debt, "Total debt");
    validate_positive(total_equity, "Total equity");
    return total_debt / total_equity;
};

~~ Debt ratio = total debt / total assets. Assets > 0.
function debt_ratio(total_debt: float, total_assets: float) -> float {
    validate_non_negative(total_debt, "Total debt");
    validate_positive(total_assets, "Total assets");
    return total_debt / total_assets;
};

~~ Interest coverage = EBIT / interest expense. Interest > 0; EBIT may be negative.
function interest_coverage(ebit: float, interest_expense: float) -> float {
    validate_positive(interest_expense, "Interest expense");
    return ebit / interest_expense;
};

~~ Equity multiplier = total assets / total equity. Both > 0.
function equity_multiplier(total_assets: float, total_equity: float) -> float {
    validate_positive(total_assets, "Total assets");
    validate_positive(total_equity, "Total equity");
    return total_assets / total_equity;
};

~~ Gross margin = (revenue - cost of goods sold) / revenue. Revenue > 0.
function gross_margin(revenue: float, cost_of_goods_sold: float) -> float {
    validate_positive(revenue, "Revenue");
    validate_non_negative(cost_of_goods_sold, "Cost of goods sold");
    return (revenue - cost_of_goods_sold) / revenue;
};

~~ Operating margin = operating income / revenue. Revenue > 0; income may be negative.
function operating_margin(revenue: float, operating_income: float) -> float {
    validate_positive(revenue, "Revenue");
    return operating_income / revenue;
};

~~ Net profit margin = net income / revenue. Revenue > 0; income may be negative.
function net_margin(revenue: float, net_income: float) -> float {
    validate_positive(revenue, "Revenue");
    return net_income / revenue;
};

~~ Return on assets = net income / total assets. Assets > 0.
function return_on_assets(net_income: float, total_assets: float) -> float {
    validate_positive(total_assets, "Total assets");
    return net_income / total_assets;
};

~~ Return on equity = net income / total equity. Equity > 0.
function return_on_equity(net_income: float, total_equity: float) -> float {
    validate_positive(total_equity, "Total equity");
    return net_income / total_equity;
};

~~ Asset turnover = revenue / total assets. Revenue >= 0, assets > 0.
function asset_turnover(revenue: float, total_assets: float) -> float {
    validate_non_negative(revenue, "Revenue");
    validate_positive(total_assets, "Total assets");
    return revenue / total_assets;
};

~~ Inventory turnover = cost of goods sold / average inventory. Inventory > 0.
function inventory_turnover(cost_of_goods_sold: float, average_inventory: float) -> float {
    validate_non_negative(cost_of_goods_sold, "Cost of goods sold");
    validate_positive(average_inventory, "Average inventory");
    return cost_of_goods_sold / average_inventory;
};

~~ Days sales outstanding = receivables / revenue * days in the period (365 for a year). Revenue > 0, days > 0.
function days_sales_outstanding(accounts_receivable: float, revenue: float, days_in_period: float) -> float {
    validate_non_negative(accounts_receivable, "Accounts receivable");
    validate_positive(revenue, "Revenue");
    validate_positive(days_in_period, "Days in period");
    return accounts_receivable / revenue * days_in_period;
};

~~ DuPont return on equity = net margin * asset turnover * equity multiplier.
function dupont_roe(net_margin_value: float, asset_turnover_value: float, equity_multiplier_value: float) -> float {
    return net_margin_value * asset_turnover_value * equity_multiplier_value;
};

~~ Break-even quantity = fixed costs / (price per unit - variable cost per unit).
~~ fixed_costs >= 0, variable cost >= 0, price must be greater than the variable cost.
function break_even_units(fixed_costs: float, price_per_unit: float, variable_cost_per_unit: float) -> float {
    validate_non_negative(fixed_costs, "Fixed costs");
    validate_non_negative(variable_cost_per_unit, "Variable cost per unit");
    if (price_per_unit <= variable_cost_per_unit) {
        c_print_err("MochaLibError (mocha-finance): Price per unit must be greater than the variable cost per unit.");
        c_exit(2);
    };
    return fixed_costs / (price_per_unit - variable_cost_per_unit);
};

// ================================================================
// SECTION 9: MACROECONOMICS
// ================================================================
// Inflation, growth, recessions, policy rates and public debt. Rates and ratios are
// decimals (0.03 = 3%), except price indexes and deflators, which use the usual base of 100.
// Debt ratios are debt / GDP (0.6 = 60% of GDP). Primary balance is a share of GDP
// (surplus positive, deficit negative).

~~ Inflation rate between two price levels. inflation = end / begin - 1. Both prices > 0.
function inflation_rate(price_begin: float, price_end: float) -> float {
    validate_positive(price_begin, "Beginning price level");
    validate_positive(price_end, "Ending price level");
    return price_end / price_begin - 1.0;
};

~~ Price index (such as CPI) = cost of the basket now / cost of the same basket in the base year * 100.
~~ Both costs > 0.
function price_index(basket_cost: float, base_cost: float) -> float {
    validate_positive(basket_cost, "Basket cost");
    validate_positive(base_cost, "Base-year basket cost");
    return basket_cost / base_cost * 100.0;
};

~~ GDP deflator = nominal GDP / real GDP * 100. Both > 0.
function gdp_deflator(nominal_gdp: float, real_gdp: float) -> float {
    validate_positive(nominal_gdp, "Nominal GDP");
    validate_positive(real_gdp, "Real GDP");
    return nominal_gdp / real_gdp * 100.0;
};

~~ Real GDP from nominal GDP and a deflator. real = nominal / deflator * 100.
~~ nominal_gdp >= 0, deflator > 0.
function real_gdp_from_deflator(nominal_gdp: float, deflator: float) -> float {
    validate_non_negative(nominal_gdp, "Nominal GDP");
    validate_positive(deflator, "GDP deflator");
    return nominal_gdp / deflator * 100.0;
};

~~ GDP growth rate between two periods. growth = current / previous - 1.
~~ previous_gdp > 0, current_gdp >= 0.
function gdp_growth_rate(previous_gdp: float, current_gdp: float) -> float {
    validate_positive(previous_gdp, "Previous GDP");
    validate_non_negative(current_gdp, "Current GDP");
    return current_gdp / previous_gdp - 1.0;
};

~~ Annualized growth from a per-period rate, compounding. (1 + g)^periods_per_year - 1.
~~ 4 for quarterly figures, 12 for monthly. rate_per_period > -1, periods_per_year >= 1.
function annualize_growth_rate(rate_per_period: float, periods_per_year: int) -> float {
    validate_rate(rate_per_period, "Growth rate per period");
    validate_period_count(periods_per_year);
    return float(c_pow(1.0 + rate_per_period, float(periods_per_year))) - 1.0;
};

~~ Technical recession test: true if real GDP fell in two consecutive periods.
~~ real_gdp = chronological array of real GDP levels, at least 3 values.
function is_technical_recession(real_gdp: float[]) -> bool {
    var n: int = real_gdp.length;
    if (n < 3) {
        c_print_err("MochaLibError (mocha-finance): Recession test needs at least 3 GDP values.");
        c_exit(2);
    };
    var t: int = 2;
    while (t < n) {
        if (real_gdp[t] < real_gdp[t - 1] && real_gdp[t - 1] < real_gdp[t - 2]) {
            return true;
        };
        t++;
    };
    return false;
};

~~ Okun's law: output gap (as a fraction of potential output) from unemployment.
~~ gap = -coefficient * (unemployment - natural_rate). The classic coefficient is about 2.
~~ Rates >= 0, coefficient > 0. Negative gap = economy below potential.
function okun_output_gap(unemployment_rate: float, natural_rate: float, coefficient: float) -> float {
    validate_non_negative(unemployment_rate, "Unemployment rate");
    validate_non_negative(natural_rate, "Natural unemployment rate");
    validate_positive(coefficient, "Okun coefficient");
    return (0.0 - coefficient) * (unemployment_rate - natural_rate);
};

~~ Taylor rule: suggested central-bank policy rate.
~~ rate = inflation + neutral_real_rate + a * (inflation - target) + b * output_gap.
~~ Classic weights are a = 0.5 and b = 0.5. Weights >= 0; inflation, target and neutral rate > -1.
function taylor_rule_rate(inflation: float, target_inflation: float, output_gap: float, neutral_real_rate: float, inflation_weight: float, gap_weight: float) -> float {
    validate_rate(inflation, "Inflation");
    validate_rate(target_inflation, "Target inflation");
    validate_rate(neutral_real_rate, "Neutral real rate");
    validate_non_negative(inflation_weight, "Inflation weight");
    validate_non_negative(gap_weight, "Output gap weight");
    return inflation + neutral_real_rate + inflation_weight * (inflation - target_inflation) + gap_weight * output_gap;
};

~~ Money multiplier = 1 / reserve ratio: how much deposits can grow from one unit of reserves.
~~ reserve_ratio in (0, 1].
function money_multiplier(reserve_ratio: float) -> float {
    validate_positive(reserve_ratio, "Reserve ratio");
    if (reserve_ratio > 1.0) {
        c_print_err("MochaLibError (mocha-finance): Reserve ratio must be at most 1.");
        c_exit(2);
    };
    return 1.0 / reserve_ratio;
};

~~ Government spending multiplier = 1 / (1 - mpc * (1 - tax_rate)).
~~ mpc (marginal propensity to consume) in [0, 1], tax_rate in [0, 1]. Errors if mpc = 1 and tax_rate = 0.
function spending_multiplier(mpc: float, tax_rate: float) -> float {
    validate_proportion(mpc, "Marginal propensity to consume");
    validate_proportion(tax_rate, "Tax rate");
    const LEAK: float = 1.0 - mpc * (1.0 - tax_rate);
    if (LEAK <= 0.0) {
        c_print_err("MochaLibError (mocha-finance): Multiplier is infinite when mpc = 1 and tax rate = 0.");
        c_exit(2);
    };
    return 1.0 / LEAK;
};

~~ Velocity of money = nominal GDP / money supply. Both > 0.
function velocity_of_money(nominal_gdp: float, money_supply: float) -> float {
    validate_positive(nominal_gdp, "Nominal GDP");
    validate_positive(money_supply, "Money supply");
    return nominal_gdp / money_supply;
};

~~ Inflation implied by the quantity theory of money (M * V = P * Y), exact form:
~~ inflation = (1 + money_growth) * (1 + velocity_growth) / (1 + real_growth) - 1. All growth rates > -1.
function quantity_theory_inflation(money_growth: float, velocity_growth: float, real_growth: float) -> float {
    validate_rate(money_growth, "Money growth");
    validate_rate(velocity_growth, "Velocity growth");
    validate_rate(real_growth, "Real growth");
    return (1.0 + money_growth) * (1.0 + velocity_growth) / (1.0 + real_growth) - 1.0;
};

~~ Purchasing-power-parity exchange rate = domestic price of a basket / foreign price of the same basket.
~~ Result is units of domestic currency per 1 unit of foreign currency. Both prices > 0.
function ppp_exchange_rate(domestic_price: float, foreign_price: float) -> float {
    validate_positive(domestic_price, "Domestic basket price");
    validate_positive(foreign_price, "Foreign basket price");
    return domestic_price / foreign_price;
};

~~ Debt-to-GDP ratio. debt >= 0, gdp > 0.
function debt_to_gdp(debt: float, gdp: float) -> float {
    validate_non_negative(debt, "Debt");
    validate_positive(gdp, "GDP");
    return debt / gdp;
};

~~ Next year's debt ratio: d' = d * (1 + r) / (1 + g) - primary_balance.
~~ debt_ratio >= 0, interest_rate > -1, growth_rate > -1 (nominal growth, same type as the interest rate).
function next_debt_ratio(debt_ratio: float, interest_rate: float, growth_rate: float, primary_balance: float) -> float {
    validate_non_negative(debt_ratio, "Debt ratio");
    validate_rate(interest_rate, "Interest rate");
    validate_rate(growth_rate, "Growth rate");
    return debt_ratio * (1.0 + interest_rate) / (1.0 + growth_rate) - primary_balance;
};

~~ Debt ratio after a number of years with constant interest rate, growth and primary balance.
~~ years >= 0 (0 returns the starting ratio). Can go negative if surpluses exceed the debt.
function projected_debt_ratio(debt_ratio: float, interest_rate: float, growth_rate: float, primary_balance: float, years: int) -> float {
    if (years < 0) {
        c_print_err("MochaLibError (mocha-finance): Years cannot be negative.");
        c_exit(2);
    };
    var d: float = debt_ratio;
    var t: int = 0;
    while (t < years) {
        d = next_debt_ratio(d, interest_rate, growth_rate, primary_balance);
        t++;
    };
    return d;
};

~~ Primary balance that keeps the debt ratio constant: pb = d * (r - g) / (1 + g).
~~ Positive when r > g (a surplus is needed), negative when growth beats the interest rate.
function stabilizing_primary_balance(debt_ratio: float, interest_rate: float, growth_rate: float) -> float {
    validate_non_negative(debt_ratio, "Debt ratio");
    validate_rate(interest_rate, "Interest rate");
    validate_rate(growth_rate, "Growth rate");
    return debt_ratio * (interest_rate - growth_rate) / (1.0 + growth_rate);
};

// ================================================================
// SECTION 10: ENVIRONMENTAL FINANCE
// ================================================================
// Carbon pricing, emissions paths, climate discounting, energy costs and climate risk.
// Rates are decimals like everywhere else. Emissions are in tonnes of CO2-equivalent,
// carbon prices are money per tonne. Arrays of yearly values start with year 1,
// except levelized_cost_of_energy, whose arrays start at t = 0 (like Section 3).

~~ Total cost of emissions at a carbon price. cost = tonnes * price per tonne. Both >= 0.
function carbon_cost(emissions_tonnes: float, price_per_tonne: float) -> float {
    validate_non_negative(emissions_tonnes, "Emissions");
    validate_non_negative(price_per_tonne, "Carbon price");
    return emissions_tonnes * price_per_tonne;
};

~~ Carbon intensity = emissions / revenue (tonnes per unit of revenue). emissions >= 0, revenue > 0.
function carbon_intensity(emissions_tonnes: float, revenue: float) -> float {
    validate_non_negative(emissions_tonnes, "Emissions");
    validate_positive(revenue, "Revenue");
    return emissions_tonnes / revenue;
};

~~ Profit after paying for emissions. adjusted = profit - emissions * carbon price.
~~ profit may be negative, emissions >= 0, price >= 0.
function carbon_adjusted_profit(profit: float, emissions_tonnes: float, price_per_tonne: float) -> float {
    return profit - carbon_cost(emissions_tonnes, price_per_tonne);
};

~~ Carbon price at which the profit becomes exactly zero. price = profit / emissions.
~~ emissions > 0. Negative result means the business already loses money before any carbon cost.
function breakeven_carbon_price(profit: float, emissions_tonnes: float) -> float {
    validate_positive(emissions_tonnes, "Emissions");
    return profit / emissions_tonnes;
};

~~ Net cost under cap-and-trade. cost = (emissions - allowances) * price.
~~ Negative result = surplus allowances sold for money. All arguments >= 0.
function cap_and_trade_cost(emissions_tonnes: float, allowances: float, price_per_tonne: float) -> float {
    validate_non_negative(emissions_tonnes, "Emissions");
    validate_non_negative(allowances, "Allowances");
    validate_non_negative(price_per_tonne, "Allowance price");
    return (emissions_tonnes - allowances) * price_per_tonne;
};

~~ Emissions after cutting by a constant percentage every year. E = E0 * (1 - cut)^years.
~~ initial_emissions >= 0, annual_cut in [0, 1], years >= 0 (may be fractional).
function emissions_after_years(initial_emissions: float, annual_cut: float, years: float) -> float {
    validate_non_negative(initial_emissions, "Initial emissions");
    validate_proportion(annual_cut, "Annual cut");
    validate_non_negative(years, "Years");
    const REMAINING: float = float(c_pow(1.0 - annual_cut, years));
    return initial_emissions * REMAINING;
};

~~ Years needed to reach a total cut when cutting by a constant percentage every year.
~~ years = ln(1 - total_cut) / ln(1 - annual_cut). Both strictly between 0 and 1
~~ (a total_cut of 0.5 means "reach half of today's emissions").
function years_to_cut_emissions(annual_cut: float, total_cut: float) -> float {
    if (annual_cut <= 0.0 || annual_cut >= 1.0) {
        c_print_err("MochaLibError (mocha-finance): Annual cut must be strictly between 0 and 1.");
        c_exit(2);
    };
    if (total_cut <= 0.0 || total_cut >= 1.0) {
        c_print_err("MochaLibError (mocha-finance): Total cut must be strictly between 0 and 1.");
        c_exit(2);
    };
    const TARGET: float = 1.0 - total_cut;
    const STEP: float = 1.0 - annual_cut;
    return TARGET.log().real / STEP.log().real;
};

~~ Years until a remaining carbon budget is used up at constant emissions. years = budget / annual emissions.
~~ remaining_budget >= 0, annual_emissions > 0.
function carbon_budget_years(remaining_budget: float, annual_emissions: float) -> float {
    validate_non_negative(remaining_budget, "Remaining carbon budget");
    validate_positive(annual_emissions, "Annual emissions");
    return remaining_budget / annual_emissions;
};

~~ Ramsey discount rate used in climate economics. r = pure time preference + elasticity * growth.
~~ pure_time_preference >= 0, elasticity >= 0 (how much society dislikes unequal consumption), growth may be any.
function ramsey_discount_rate(pure_time_preference: float, elasticity: float, growth_rate: float) -> float {
    validate_non_negative(pure_time_preference, "Pure time preference");
    validate_non_negative(elasticity, "Elasticity of marginal utility");
    return pure_time_preference + elasticity * growth_rate;
};

~~ Present value of a stream of future climate damages. annual_damages[0] falls at the end of year 1.
~~ discount_rate > -1, array non-empty. Low discount rates make distant damages count more.
function climate_damage_present_value(annual_damages: float[], discount_rate: float) -> float {
    validate_rate(discount_rate, "Discount rate");
    var n: int = annual_damages.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-finance): Damage array cannot be empty.");
        c_exit(2);
    };
    const STEP: float = 1.0 + discount_rate;
    var discount: float = 1.0;
    var total: float = 0.0;
    var t: int = 0;
    while (t < n) {
        discount = discount * STEP;
        total = total + annual_damages[t] / discount;
        t++;
    };
    return total;
};

~~ Levelized cost of energy: discounted lifetime costs / discounted lifetime energy produced.
~~ costs[t] and energy[t] are for year t, starting at t = 0 (construction year). Same length, non-empty.
~~ discount_rate > -1. Errors if the discounted energy is zero. Result is cost per unit of energy.
function levelized_cost_of_energy(costs: float[], energy: float[], discount_rate: float) -> float {
    validate_rate(discount_rate, "Discount rate");
    var n: int = costs.length;
    if (n == 0 || n != energy.length) {
        c_print_err("MochaLibError (mocha-finance): Cost and energy arrays must be non-empty and the same length.");
        c_exit(2);
    };
    const STEP: float = 1.0 + discount_rate;
    var discount: float = 1.0;
    var cost_total: float = 0.0;
    var energy_total: float = 0.0;
    var t: int = 0;
    while (t < n) {
        cost_total = cost_total + costs[t] / discount;
        energy_total = energy_total + energy[t] / discount;
        discount = discount * STEP;
        t++;
    };
    if (energy_total <= 0.0) {
        c_print_err("MochaLibError (mocha-finance): Discounted energy output must be positive.");
        c_exit(2);
    };
    return cost_total / energy_total;
};

~~ Green bond premium ("greenium"): how much cheaper a green bond borrows than a similar ordinary bond.
~~ greenium = conventional yield - green yield. Positive = the green bond yields less. Both > -1.
function green_bond_premium(conventional_yield: float, green_yield: float) -> float {
    validate_rate(conventional_yield, "Conventional yield");
    validate_rate(green_yield, "Green yield");
    return conventional_yield - green_yield;
};

~~ Chance of at least one event (flood, storm, fire) in a time window, for an event with a given return period.
~~ p = 1 - (1 - 1/T)^years. return_period_years >= 1 (a "1-in-100-year" event has T = 100), years >= 0.
function exceedance_probability(return_period_years: float, years: float) -> float {
    if (return_period_years < 1.0) {
        c_print_err("MochaLibError (mocha-finance): Return period must be at least 1 year.");
        c_exit(2);
    };
    validate_non_negative(years, "Years");
    const YEARLY_MISS: float = 1.0 - 1.0 / return_period_years;
    return 1.0 - float(c_pow(YEARLY_MISS, years));
};

~~ Expected loss per year = yearly probability of the event * loss if it happens.
~~ annual_probability in [0, 1], loss >= 0.
function expected_annual_loss(annual_probability: float, loss: float) -> float {
    validate_proportion(annual_probability, "Annual probability");
    validate_non_negative(loss, "Loss");
    return annual_probability * loss;
};

~~ Insurance premium with a loading on top of the expected loss. premium = expected loss * (1 + loading).
~~ expected_loss >= 0, loading >= 0 (0.3 = insurer adds 30% for costs and profit).
function loaded_insurance_premium(expected_loss: float, loading: float) -> float {
    validate_non_negative(expected_loss, "Expected loss");
    validate_non_negative(loading, "Loading");
    return expected_loss * (1.0 + loading);
};