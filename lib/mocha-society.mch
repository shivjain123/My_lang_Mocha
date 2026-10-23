~~ mocha-society — Sociology, Political Science, Anthropology & Socio-Economics Library for Mocha
~~ Section 1: Demography
~~
~~ Part of the Mocha Scientific Library Ecosystem
~~ License: Polyform Non-Commercial

// mocha-lib-deps: mocha-math

local function c_print_err(msg: str) -> null native mocha_print_stderr;
local function c_exit(code: int) -> null native mocha_exit;
local function c_exp(x: float) -> float native mocha_wrap_exp;

const DEG_TO_RAD: float = 0.01745329251994;
const RAD_TO_DEG: float = 57.29577951308232;

// ================================================================
// SECTION 1: DEMOGRAPHY
// ================================================================

~~ Continuous (exponential) annual population growth rate from initial and final population.
~~ p0, p1 = population counts (both > 0), years = elapsed time (must be > 0). r = ln(P1/P0) / years.
function population_growth_rate(p0: float, p1: float, years: float) -> float {
    if (p0 <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Initial population must be positive.");
        c_exit(2);
    };
    if (p1 <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Final population must be positive.");
        c_exit(2);
    };
    if (years <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Elapsed time must be positive.");
        c_exit(2);
    };
    const RATIO: float = p1 / p0;
    const LN_RATIO: float = RATIO.log().real;
    return LN_RATIO / years;
};

~~ Population doubling time in years from a continuous growth rate.
~~ growth_rate as a decimal in (0, 1] (e.g. 0.02 = 2% per year). t = ln(2) / r.
~~ For negative growth (population decline), use halving-time reasoning explicitly — not this function.
function population_doubling_time(growth_rate: float) -> float {
    if (growth_rate <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Growth rate must be positive for doubling time. Use declining-population reasoning for negative rates.");
        c_exit(2);
    };
    if (growth_rate > 1.0) {
        c_print_err("MochaLibError (mocha-society): Growth rate > 1.0 (100% per year) is not a realistic continuous rate.");
        c_exit(2);
    };
    const LN2: float = 2.0.log().real;
    return LN2 / growth_rate;
};

~~ Crude birth rate per 1000 population.
~~ births = number of live births (>= 0), population = total population (> 0).
function crude_birth_rate(births: float, population: float) -> float {
    if (births < 0.0) {
        c_print_err("MochaLibError (mocha-society): Birth count cannot be negative.");
        c_exit(2);
    };
    if (population <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Population must be positive.");
        c_exit(2);
    };
    return (births / population) * 1000.0;
};

~~ Crude death rate per 1000 population.
~~ deaths = number of deaths (>= 0), population = total population (> 0).
function crude_death_rate(deaths: float, population: float) -> float {
    if (deaths < 0.0) {
        c_print_err("MochaLibError (mocha-society): Death count cannot be negative.");
        c_exit(2);
    };
    if (population <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Population must be positive.");
        c_exit(2);
    };
    return (deaths / population) * 1000.0;
};

~~ Rate of natural increase as a percentage, from crude birth and death rates.
~~ cbr, cdr = crude birth/death rate (per 1000, both >= 0). NIR(%) = (CBR - CDR) / 10.
function natural_increase_rate(cbr: float, cdr: float) -> float {
    if (cbr < 0.0) {
        c_print_err("MochaLibError (mocha-society): Crude birth rate cannot be negative.");
        c_exit(2);
    };
    if (cdr < 0.0) {
        c_print_err("MochaLibError (mocha-society): Crude death rate cannot be negative.");
        c_exit(2);
    };
    return (cbr - cdr) / 10.0;
};

~~ Net migration rate per 1000 population.
~~ immigrants, emigrants = counts over the period (both >= 0), population = total population (> 0).
function net_migration_rate(immigrants: float, emigrants: float, population: float) -> float {
    if (immigrants < 0.0) {
        c_print_err("MochaLibError (mocha-society): Immigrant count cannot be negative.");
        c_exit(2);
    };
    if (emigrants < 0.0) {
        c_print_err("MochaLibError (mocha-society): Emigrant count cannot be negative.");
        c_exit(2);
    };
    if (population <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Population must be positive.");
        c_exit(2);
    };
    const NET: float = immigrants - emigrants;
    return (NET / population) * 1000.0;
};

~~ Total age dependency ratio (per 100 working-age population).
~~ pop_under15, pop_65plus = dependent age groups (both >= 0), pop_working = population aged 15-64 (> 0).
function dependency_ratio(pop_under15: float, pop_65plus: float, pop_working: float) -> float {
    if (pop_under15 < 0.0) {
        c_print_err("MochaLibError (mocha-society): Under-15 population cannot be negative.");
        c_exit(2);
    };
    if (pop_65plus < 0.0) {
        c_print_err("MochaLibError (mocha-society): 65+ population cannot be negative.");
        c_exit(2);
    };
    if (pop_working <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Working-age population must be positive.");
        c_exit(2);
    };
    const DEPENDENTS: float = pop_under15 + pop_65plus;
    return (DEPENDENTS / pop_working) * 100.0;
};

~~ Child dependency ratio (per 100 working-age population).
~~ pop_under15 >= 0, pop_working > 0.
function child_dependency_ratio(pop_under15: float, pop_working: float) -> float {
    if (pop_under15 < 0.0) {
        c_print_err("MochaLibError (mocha-society): Under-15 population cannot be negative.");
        c_exit(2);
    };
    if (pop_working <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Working-age population must be positive.");
        c_exit(2);
    };
    return (pop_under15 / pop_working) * 100.0;
};

~~ Old-age dependency ratio (per 100 working-age population).
~~ pop_65plus >= 0, pop_working > 0.
function old_age_dependency_ratio(pop_65plus: float, pop_working: float) -> float {
    if (pop_65plus < 0.0) {
        c_print_err("MochaLibError (mocha-society): 65+ population cannot be negative.");
        c_exit(2);
    };
    if (pop_working <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Working-age population must be positive.");
        c_exit(2);
    };
    return (pop_65plus / pop_working) * 100.0;
};

~~ Projects future population using continuous exponential growth.
~~ p0 = initial population (> 0), growth_rate as decimal, years = projection horizon.
~~ P(t) = P0 * e^(r*t). Errors if |r*years| > 700 (e^700 overflows double precision).
function population_projection(p0: float, growth_rate: float, years: float) -> float {
    if (p0 <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Initial population must be positive.");
        c_exit(2);
    };
    const EXPONENT: float = growth_rate * years;
    if (EXPONENT > 700.0 || EXPONENT < -700.0) {
        c_print_err("MochaLibError (mocha-society): Exponent out of safe range — growth_rate × years exceeds ±700, result would overflow.");
        c_exit(2);
    };
    const EXP_VAL: float = float(c_exp(EXPONENT));
    return p0 * EXP_VAL;
};

// ================================================================
// SECTION 2: SOCIAL STRATIFICATION & INEQUALITY
// ================================================================

~~ Arithmetic mean of an income/wealth distribution.
~~ incomes = array of values (any consistent unit). Requires non-empty array.
function mean_income(incomes: float[]) -> float {
    var n: int = incomes.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-society): Income array cannot be empty.");
        c_exit(2);
    };
    var total: float = 0.0;
    var i: int = 0;
    while (i < n) {
        total = total + incomes[i];
        i++;
    };
    return total / float(n);
};

~~ Gini coefficient of income inequality (0 = perfect equality, 1 = perfect inequality).
~~ incomes MUST be sorted ascending and must all be >= 0. Requires non-empty array and positive total.
~~ Uses rank-sum formula: G = (2*Σ(rank_i * x_i) - (n+1)*Σx_i) / (n*Σx_i).
function gini_coefficient(incomes: float[]) -> float {
    var n: int = incomes.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-society): Income array cannot be empty.");
        c_exit(2);
    };
    var weighted_sum: float = 0.0;
    var total_sum: float = 0.0;
    var i: int = 0;
    var prev: float = -1.0;
    var sorted_ok: bool = true;
    while (i < n) {
        if (incomes[i] < 0.0) {
            c_print_err("MochaLibError (mocha-society): Gini requires non-negative incomes.");
            c_exit(2);
        };
        if (i > 0 && incomes[i] < prev) {
            sorted_ok = false;
        };
        prev = incomes[i];
        var rank: float = float(i + 1);
        weighted_sum = weighted_sum + rank * incomes[i];
        total_sum = total_sum + incomes[i];
        i++;
    };
    if (!sorted_ok) {
        c_print_err("MochaLibError (mocha-society): Gini requires incomes sorted ascending.");
        c_exit(2);
    };
    if (total_sum <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Gini requires positive total income.");
        c_exit(2);
    };
    const NUMERATOR: float = 2.0 * weighted_sum - float(n + 1) * total_sum;
    const DENOM: float = float(n) * total_sum;
    return NUMERATOR / DENOM;
};

~~ Theil index of inequality (0 = perfect equality, higher = more unequal, unbounded above).
~~ incomes = array of values in any order, all must be > 0. T = (1/n) * Σ( (x_i/mean) * ln(x_i/mean) ).
function theil_index(incomes: float[]) -> float {
    var n: int = incomes.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-society): Income array cannot be empty.");
        c_exit(2);
    };
    var i_check: int = 0;
    while (i_check < n) {
        if (incomes[i_check] <= 0.0) {
            c_print_err("MochaLibError (mocha-society): Theil index requires strictly positive incomes.");
            c_exit(2);
        };
        i_check++;
    };
    var mean_val: float = mean_income(incomes);
    var sum_term: float = 0.0;
    var i: int = 0;
    while (i < n) {
        var ratio: float = incomes[i] / mean_val;
        var ln_ratio: float = ratio.log().real;
        sum_term = sum_term + ratio * ln_ratio;
        i++;
    };
    return sum_term / float(n);
};

~~ Atkinson index of inequality, sensitive to a chosen inequality-aversion parameter.
~~ incomes = array of values (non-empty), epsilon = inequality aversion (> 0 and != 1). Higher epsilon weights the bottom of the distribution more.
~~ A = 1 - (1/mean) * [(1/n)*Σx_i^(1-ε)]^(1/(1-ε)).
function atkinson_index(incomes: float[], epsilon: float) -> float {
    if (epsilon <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Inequality aversion epsilon must be positive.");
        c_exit(2);
    };
    if (abs(epsilon - 1.0) < 1E-10) {
        c_print_err("MochaLibError (mocha-society): Epsilon must not equal 1 — Atkinson formula requires epsilon != 1 (use limiting form for epsilon=1).");
        c_exit(2);
    };
    var n: int = incomes.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-society): Income array cannot be empty.");
        c_exit(2);
    };
    var i_check: int = 0;
    while (i_check < n) {
        if (incomes[i_check] <= 0.0) {
            c_print_err("MochaLibError (mocha-society): Atkinson index requires strictly positive incomes.");
            c_exit(2);
        };
        i_check++;
    };
    var mean_val: float = mean_income(incomes);
    var sum_pow: float = 0.0;
    var exponent: float = 1.0 - epsilon;
    var i: int = 0;
    while (i < n) {
        sum_pow = sum_pow + float(c_pow(incomes[i], exponent));
        i++;
    };
    var avg_pow: float = sum_pow / float(n);
    var inv_exp: float = 1.0 / exponent;
    var bracket: float = float(c_pow(avg_pow, inv_exp));
    return 1.0 - (bracket / mean_val);
};

~~ Poverty headcount ratio as a percentage of total population.
~~ poor_count in [0, total_population], total_population > 0.
function poverty_headcount_ratio(poor_count: float, total_population: float) -> float {
    if (poor_count < 0.0) {
        c_print_err("MochaLibError (mocha-society): Poor count cannot be negative.");
        c_exit(2);
    };
    if (total_population <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Total population must be positive.");
        c_exit(2);
    };
    if (poor_count > total_population) {
        c_print_err("MochaLibError (mocha-society): Poor count cannot exceed total population.");
        c_exit(2);
    };
    return (poor_count / total_population) * 100.0;
};

~~ Poverty gap index — average normalized income shortfall below the poverty line across whole population.
~~ incomes = array of values (including those above the line), poverty_line > 0. Requires non-empty array.
~~ PGI = (1/n) * Σ max(0, (z - x_i)/z).
function poverty_gap_index(incomes: float[], poverty_line: float) -> float {
    if (poverty_line <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Poverty line must be positive.");
        c_exit(2);
    };
    var n: int = incomes.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-society): Income array cannot be empty.");
        c_exit(2);
    };
    var sum_gap: float = 0.0;
    var i: int = 0;
    while (i < n) {
        var gap: float = (poverty_line - incomes[i]) / poverty_line;
        if (gap < 0.0) {
            gap = 0.0;
        };
        sum_gap = sum_gap + gap;
        i++;
    };
    return sum_gap / float(n);
};

~~ Palma ratio: income share of the top 10% divided by the income share of the bottom 40%.
~~ top10_share and bottom40_share as percentages, both > 0.
function palma_ratio(top10_share: float, bottom40_share: float) -> float {
    if (top10_share <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Top 10% share must be positive.");
        c_exit(2);
    };
    if (bottom40_share <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Bottom 40% share must be positive.");
        c_exit(2);
    };
    return top10_share / bottom40_share;
};

~~ General income share ratio between any two population deciles/quintiles.
~~ top_share and bottom_share as percentages, both > 0.
function income_share_ratio(top_share: float, bottom_share: float) -> float {
    if (top_share <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Top share must be positive.");
        c_exit(2);
    };
    if (bottom_share <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Bottom share must be positive.");
        c_exit(2);
    };
    return top_share / bottom_share;
};

~~ Relative poverty line as a fraction of median income (commonly 0.5 or 0.6, OECD/EU convention).
~~ median_income > 0, threshold_fraction in (0, 1].
function relative_poverty_line(median_income: float, threshold_fraction: float) -> float {
    if (median_income <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Median income must be positive.");
        c_exit(2);
    };
    if (threshold_fraction <= 0.0 || threshold_fraction > 1.0) {
        c_print_err("MochaLibError (mocha-society): Threshold fraction must be in (0, 1] — commonly 0.5 or 0.6.");
        c_exit(2);
    };
    return threshold_fraction * median_income;
};

// ================================================================
// SECTION 3: POLITICAL SCIENCE / ELECTORAL SYSTEMS
// ================================================================

~~ Voter turnout rate as a percentage.
~~ votes_cast in [0, eligible_voters], eligible_voters > 0.
function voter_turnout_rate(votes_cast: float, eligible_voters: float) -> float {
    if (eligible_voters <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Eligible voter count must be positive.");
        c_exit(2);
    };
    if (votes_cast < 0.0) {
        c_print_err("MochaLibError (mocha-society): Votes cast cannot be negative.");
        c_exit(2);
    };
    if (votes_cast > eligible_voters) {
        c_print_err("MochaLibError (mocha-society): Votes cast cannot exceed eligible voters.");
        c_exit(2);
    };
    return (votes_cast / eligible_voters) * 100.0;
};

~~ Seat allocation via D'Hondt highest-averages method.
~~ votes = non-empty array of non-negative party vote totals, total_seats >= 0.
~~ Returns array of seats per party (same order as input). Divisor sequence: 1,2,3,...
function dhondt_apportionment(votes: float[], total_seats: int) -> int[] {
    var n: int = votes.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-society): Votes array cannot be empty.");
        c_exit(2);
    };
    if (total_seats < 0) {
        c_print_err("MochaLibError (mocha-society): Total seats cannot be negative.");
        c_exit(2);
    };
    var i_check: int = 0;
    var total_votes: float = 0.0;
    while (i_check < n) {
        if (votes[i_check] < 0.0) {
            c_print_err("MochaLibError (mocha-society): Vote counts cannot be negative.");
            c_exit(2);
        };
        total_votes = total_votes + votes[i_check];
        i_check++;
    };
    if (total_votes <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Total votes must be positive.");
        c_exit(2);
    };
    var allocated: int[] = alloc int[n];
    var i: int = 0;
    while (i < n) {
        allocated[i] = 0;
        i++;
    };
    var round: int = 0;
    while (round < total_seats) {
        var best_quotient: float = -1.0;
        var best_party: int = 0;
        var j: int = 0;
        while (j < n) {
            var quotient: float = votes[j] / float(allocated[j] + 1);
            if (quotient > best_quotient) {
                best_quotient = quotient;
                best_party = j;
            };
            j++;
        };
        allocated[best_party] = allocated[best_party] + 1;
        round++;
    };
    return allocated;
};

~~ Seat allocation via Sainte-Laguë highest-averages method.
~~ votes = non-empty array of non-negative party vote totals, total_seats >= 0.
~~ Returns array of seats per party (same order). Divisor sequence: 1,3,5,7,...
function sainte_lague_apportionment(votes: float[], total_seats: int) -> int[] {
    var n: int = votes.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-society): Votes array cannot be empty.");
        c_exit(2);
    };
    if (total_seats < 0) {
        c_print_err("MochaLibError (mocha-society): Total seats cannot be negative.");
        c_exit(2);
    };
    var i_check: int = 0;
    var total_votes: float = 0.0;
    while (i_check < n) {
        if (votes[i_check] < 0.0) {
            c_print_err("MochaLibError (mocha-society): Vote counts cannot be negative.");
            c_exit(2);
        };
        total_votes = total_votes + votes[i_check];
        i_check++;
    };
    if (total_votes <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Total votes must be positive.");
        c_exit(2);
    };
    var allocated: int[] = alloc int[n];
    var i: int = 0;
    while (i < n) {
        allocated[i] = 0;
        i++;
    };
    var round: int = 0;
    while (round < total_seats) {
        var best_quotient: float = -1.0;
        var best_party: int = 0;
        var j: int = 0;
        while (j < n) {
            var divisor: float = float(2 * allocated[j] + 1);
            var quotient: float = votes[j] / divisor;
            if (quotient > best_quotient) {
                best_quotient = quotient;
                best_party = j;
            };
            j++;
        };
        allocated[best_party] = allocated[best_party] + 1;
        round++;
    };
    return allocated;
};

~~ Effective number of parties (Laakso-Taagepera index).
~~ vote_shares = non-empty array of fractional shares in [0, 1] summing to ~1.0.
~~ ENP = 1 / Σ(share_i²).
function effective_number_of_parties(vote_shares: float[]) -> float {
    var n: int = vote_shares.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-society): Vote shares array cannot be empty.");
        c_exit(2);
    };
    var sum_sq: float = 0.0;
    var sum_shares: float = 0.0;
    var i: int = 0;
    while (i < n) {
        if (vote_shares[i] < 0.0 || vote_shares[i] > 1.0) {
            c_print_err("MochaLibError (mocha-society): Each vote share must be in [0, 1] — did you pass percentages instead of fractions?");
            c_exit(2);
        };
        sum_sq = sum_sq + vote_shares[i] * vote_shares[i];
        sum_shares = sum_shares + vote_shares[i];
        i++;
    };
    if (sum_sq <= 0.0) {
        c_print_err("MochaLibError (mocha-society): At least one vote share must be positive.");
        c_exit(2);
    };
    if (abs(sum_shares - 1.0) > 0.01) {
        c_print_err("MochaLibError (mocha-society): Vote shares must sum to approximately 1.0 — did you pass percentages?");
        c_exit(2);
    };
    return 1.0 / sum_sq;
};

~~ Gallagher least-squares disproportionality index.
~~ vote_shares and seat_shares as percentages (same length, both non-empty).
~~ G = sqrt(0.5 * Σ(v_i - s_i)²).
function gallagher_index(vote_shares: float[], seat_shares: float[]) -> float {
    var n: int = vote_shares.length;
    var m: int = seat_shares.length;
    if (n != m) {
        c_print_err("MochaLibError (mocha-society): Vote shares and seat shares arrays must have the same length.");
        c_exit(2);
    };
    if (n == 0) {
        c_print_err("MochaLibError (mocha-society): Input arrays cannot be empty.");
        c_exit(2);
    };
    var sum_sq: float = 0.0;
    var i: int = 0;
    while (i < n) {
        var diff: float = vote_shares[i] - seat_shares[i];
        sum_sq = sum_sq + diff * diff;
        i++;
    };
    var inner: float = 0.5 * sum_sq;
    return inner.sqrt().real;
};

~~ Per-party deviation between vote share and seat share (a single Gallagher term).
~~ vote_share and seat_share as percentages. Returns vote_share - seat_share.
function seat_vote_deviation(vote_share: float, seat_share: float) -> float {
    return vote_share - seat_share;
};

~~ Banzhaf power index for 3-player weighted voting game.
~~ w1, w2, w3 = non-negative voting weights, quota = votes needed to win (> 0 and <= w1+w2+w3).
~~ Returns (power1, power2, power3) — fraction of winning coalitions where each player is critical.
function banzhaf_power_index_3player(w1: float, w2: float, w3: float, quota: float) -> (float, 3) {
    if (w1 < 0.0 || w2 < 0.0 || w3 < 0.0) {
        c_print_err("MochaLibError (mocha-society): Voting weights cannot be negative.");
        c_exit(2);
    };
    if (quota <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Quota must be positive.");
        c_exit(2);
    };
    if (quota > w1 + w2 + w3) {
        c_print_err("MochaLibError (mocha-society): Quota cannot exceed sum of all weights — no coalition could ever win.");
        c_exit(2);
    };
    var c1: float = 0.0;
    var c2: float = 0.0;
    var c3: float = 0.0;

    // {1}
    if (w1 >= quota) { c1 = c1 + 1.0; };
    // {2}
    if (w2 >= quota) { c2 = c2 + 1.0; };
    // {3}
    if (w3 >= quota) { c3 = c3 + 1.0; };
    // {1,2}
    if (w1 + w2 >= quota) {
        if (w2 < quota) { c1 = c1 + 1.0; };
        if (w1 < quota) { c2 = c2 + 1.0; };
    };
    // {1,3}
    if (w1 + w3 >= quota) {
        if (w3 < quota) { c1 = c1 + 1.0; };
        if (w1 < quota) { c3 = c3 + 1.0; };
    };
    // {2,3}
    if (w2 + w3 >= quota) {
        if (w3 < quota) { c2 = c2 + 1.0; };
        if (w2 < quota) { c3 = c3 + 1.0; };
    };
    // {1,2,3}
    if (w1 + w2 + w3 >= quota) {
        if (w2 + w3 < quota) { c1 = c1 + 1.0; };
        if (w1 + w3 < quota) { c2 = c2 + 1.0; };
        if (w1 + w2 < quota) { c3 = c3 + 1.0; };
    };

    const TOTAL: float = c1 + c2 + c3;
    if (TOTAL <= 0.0) {
        c_print_err("MochaLibError (mocha-society): No winning coalition found — Banzhaf index undefined.");
        c_exit(2);
    };
    return (c1 / TOTAL, c2 / TOTAL, c3 / TOTAL);
};

~~ Shapley-Shubik power index for 3-player weighted voting game.
~~ w1, w2, w3 = non-negative voting weights, quota = votes needed to win (> 0 and <= w1+w2+w3).
~~ Returns (power1, power2, power3) — fraction of 6 orderings where each player is pivotal.
function shapley_shubik_power_index_3player(w1: float, w2: float, w3: float, quota: float) -> (float, 3) {
    if (w1 < 0.0 || w2 < 0.0 || w3 < 0.0) {
        c_print_err("MochaLibError (mocha-society): Voting weights cannot be negative.");
        c_exit(2);
    };
    if (quota <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Quota must be positive.");
        c_exit(2);
    };
    if (quota > w1 + w2 + w3) {
        c_print_err("MochaLibError (mocha-society): Quota cannot exceed sum of all weights — no ordering could ever have a pivotal player.");
        c_exit(2);
    };
    var p1: float = 0.0;
    var p2: float = 0.0;
    var p3: float = 0.0;

    // (1,2,3)
    if (w1 >= quota) { p1 = p1 + 1.0; } else { if (w1+w2 >= quota) { p2 = p2 + 1.0; } else { p3 = p3 + 1.0; }; };
    // (1,3,2)
    if (w1 >= quota) { p1 = p1 + 1.0; } else { if (w1+w3 >= quota) { p3 = p3 + 1.0; } else { p2 = p2 + 1.0; }; };
    // (2,1,3)
    if (w2 >= quota) { p2 = p2 + 1.0; } else { if (w2+w1 >= quota) { p1 = p1 + 1.0; } else { p3 = p3 + 1.0; }; };
    // (2,3,1)
    if (w2 >= quota) { p2 = p2 + 1.0; } else { if (w2+w3 >= quota) { p3 = p3 + 1.0; } else { p1 = p1 + 1.0; }; };
    // (3,1,2)
    if (w3 >= quota) { p3 = p3 + 1.0; } else { if (w3+w1 >= quota) { p1 = p1 + 1.0; } else { p2 = p2 + 1.0; }; };
    // (3,2,1)
    if (w3 >= quota) { p3 = p3 + 1.0; } else { if (w3+w2 >= quota) { p2 = p2 + 1.0; } else { p1 = p1 + 1.0; }; };

    return (p1 / 6.0, p2 / 6.0, p3 / 6.0);
};

// ================================================================
// SECTION 4: SOCIAL NETWORK ANALYSIS
// ================================================================
// Graphs represented as symmetric adjacency matrices: int[][], where
// adjacency[i][j] = 1 if an edge exists between node i and node j, else 0.
// Assumes undirected, unweighted, connected graphs.

~~ Validates an adjacency matrix: non-empty, square, symmetric, 0/1 entries only.
~~ Returns node count (n). Called by all functions in this section.
function validate_adjacency(adjacency: int[][]) -> int {
    var n: int = adjacency.length;
    if (n < 1) {
        c_print_err("MochaLibError (mocha-society): Adjacency matrix must have at least one node.");
        c_exit(2);
    };
    var i: int = 0;
    while (i < n) {
        if (adjacency[i].length != n) {
            c_print_err("MochaLibError (mocha-society): Adjacency matrix must be square.");
            c_exit(2);
        };
        var j: int = 0;
        while (j < n) {
            var val: int = adjacency[i][j];
            if (val != 0 && val != 1) {
                c_print_err("MochaLibError (mocha-society): Adjacency entries must be 0 or 1.");
                c_exit(2);
            };
            if (adjacency[i][j] != adjacency[j][i]) {
                c_print_err("MochaLibError (mocha-society): Adjacency matrix must be symmetric (undirected graph).");
                c_exit(2);
            };
            j++;
        };
        i++;
    };
    return n;
};

~~ Validates node_index is within bounds.
function validate_node_index(node_index: int, n: int) -> int {
    if (node_index < 0 || node_index >= n) {
        c_print_err("MochaLibError (mocha-society): Node index out of bounds for this graph.");
        c_exit(2);
    };
    return node_index;
};

~~ Degree of a node — number of edges connected to it.
~~ adjacency = n×n symmetric adjacency matrix, node_index in [0, n-1].
function node_degree(adjacency: int[][], node_index: int) -> int {
    var n: int = validate_adjacency(adjacency);
    validate_node_index(node_index, n);
    var deg: int = 0;
    var j: int = 0;
    while (j < n) {
        deg = deg + adjacency[node_index][j];
        j++;
    };
    return deg;
};

~~ Degree centrality — node's degree normalized by maximum possible degree (n-1).
~~ Requires n >= 2 (undefined for single-node graph).
function degree_centrality(adjacency: int[][], node_index: int) -> float {
    var n: int = validate_adjacency(adjacency);
    if (n < 2) {
        c_print_err("MochaLibError (mocha-society): Degree centrality undefined for graphs with fewer than 2 nodes.");
        c_exit(2);
    };
    validate_node_index(node_index, n);
    var deg: int = node_degree(adjacency, node_index);
    return float(deg) / float(n - 1);
};

~~ Network density — fraction of possible edges that exist. D = 2E / (n(n-1)).
~~ Requires n >= 2.
function network_density(adjacency: int[][]) -> float {
    var n: int = validate_adjacency(adjacency);
    if (n < 2) {
        c_print_err("MochaLibError (mocha-society): Network density undefined for graphs with fewer than 2 nodes.");
        c_exit(2);
    };
    var edge_count: int = 0;
    var i: int = 0;
    while (i < n) {
        var j: int = i + 1;
        while (j < n) {
            edge_count = edge_count + adjacency[i][j];
            j++;
        };
        i++;
    };
    const MAX_EDGES: float = float(n * (n - 1)) / 2.0;
    return float(edge_count) / MAX_EDGES;
};

~~ Average node degree across the whole network.
~~ Requires n >= 1.
function average_degree(adjacency: int[][]) -> float {
    var n: int = validate_adjacency(adjacency);
    var total_degree: int = 0;
    var i: int = 0;
    while (i < n) {
        total_degree = total_degree + node_degree(adjacency, i);
        i++;
    };
    return float(total_degree) / float(n);
};

~~ Local clustering coefficient — how interconnected a node's neighbors are with each other.
~~ C(v) = 2*E_v / (k_v*(k_v-1)). Returns 0.0 for nodes with degree < 2.
function clustering_coefficient(adjacency: int[][], node_index: int) -> float {
    var n: int = validate_adjacency(adjacency);
    validate_node_index(node_index, n);
    var neighbors: int[] = alloc int[n];
    var neighbor_count: int = 0;
    var j: int = 0;
    while (j < n) {
        if (adjacency[node_index][j] == 1) {
            neighbors[neighbor_count] = j;
            neighbor_count++;
        };
        j++;
    };
    if (neighbor_count < 2) {
        return 0.0;
    };
    var edge_count: int = 0;
    var a: int = 0;
    while (a < neighbor_count) {
        var b: int = a + 1;
        while (b < neighbor_count) {
            var u: int = neighbors[a];
            var w: int = neighbors[b];
            edge_count = edge_count + adjacency[u][w];
            b++;
        };
        a++;
    };
    const POSSIBLE: float = float(neighbor_count * (neighbor_count - 1)) / 2.0;
    return float(edge_count) / POSSIBLE;
};

~~ Shortest path length (in edges) via BFS. Returns -1 if source and target are not connected.
~~ source, target in [0, n-1].
function shortest_path_length(adjacency: int[][], source: int, target: int) -> int {
    var n: int = validate_adjacency(adjacency);
    validate_node_index(source, n);
    validate_node_index(target, n);
    var dist: int[] = alloc int[n];
    var i: int = 0;
    while (i < n) {
        dist[i] = -1;
        i++;
    };
    dist[source] = 0;
    var queue: int[] = alloc int[n];
    var qhead: int = 0;
    var qtail: int = 0;
    queue[qtail] = source;
    qtail++;
    while (qhead < qtail) {
        var u: int = queue[qhead];
        qhead++;
        var w: int = 0;
        while (w < n) {
            if (adjacency[u][w] == 1) {
                if (dist[w] == -1) {
                    dist[w] = dist[u] + 1;
                    queue[qtail] = w;
                    qtail++;
                };
            };
            w++;
        };
    };
    return dist[target];
};

~~ Closeness centrality — how close a node is to all others. Requires connected graph (n >= 2).
~~ C(v) = (n-1) / Σ(shortest_path_length(v, i)). Errors if any node is unreachable.
function closeness_centrality(adjacency: int[][], node_index: int) -> float {
    var n: int = validate_adjacency(adjacency);
    if (n < 2) {
        c_print_err("MochaLibError (mocha-society): Closeness centrality undefined for graphs with fewer than 2 nodes.");
        c_exit(2);
    };
    validate_node_index(node_index, n);
    var total_dist: int = 0;
    var i: int = 0;
    while (i < n) {
        if (i != node_index) {
            var d: int = shortest_path_length(adjacency, node_index, i);
            if (d < 0) {
                c_print_err("MochaLibError (mocha-society): Closeness centrality requires a connected graph — some nodes are unreachable.");
                c_exit(2);
            };
            total_dist = total_dist + d;
        };
        i++;
    };
    return float(n - 1) / float(total_dist);
};

~~ Betweenness centrality (raw/unnormalized) — how often a node lies on shortest paths.
~~ Requires connected graph (for correctness of intermediate path check).
function betweenness_centrality(adjacency: int[][], node_index: int) -> float {
    var n: int = validate_adjacency(adjacency);
    validate_node_index(node_index, n);
    var dist: int[][] = alloc int[n][n];
    var sigma: float[][] = alloc float[n][n];

    var src: int = 0;
    while (src < n) {
        var d: int[] = alloc int[n];
        var sig: float[] = alloc float[n];
        var i: int = 0;
        while (i < n) {
            d[i] = -1;
            sig[i] = 0.0;
            i++;
        };
        d[src] = 0;
        sig[src] = 1.0;

        var queue: int[] = alloc int[n];
        var qhead: int = 0;
        var qtail: int = 0;
        queue[qtail] = src;
        qtail++;

        while (qhead < qtail) {
            var u: int = queue[qhead];
            qhead++;
            var w: int = 0;
            while (w < n) {
                if (adjacency[u][w] == 1) {
                    if (d[w] == -1) {
                        d[w] = d[u] + 1;
                        sig[w] = sig[u];
                        queue[qtail] = w;
                        qtail++;
                    } else {
                        if (d[w] == d[u] + 1) {
                            sig[w] = sig[w] + sig[u];
                        };
                    };
                };
                w++;
            };
        };

        var j: int = 0;
        while (j < n) {
            dist[src][j] = d[j];
            sigma[src][j] = sig[j];
            j++;
        };
        src++;
    };

    var v: int = node_index;
    var result: float = 0.0;
    var s: int = 0;
    while (s < n) {
        if (s != v) {
            var t: int = s + 1;
            while (t < n) {
                if (t != v) {
                    var dist_sv: int = dist[s][v];
                    var dist_vt: int = dist[v][t];
                    var dist_st: int = dist[s][t];
                    if (dist_sv >= 0 && dist_vt >= 0 && dist_st >= 0) {
                        if (dist_sv + dist_vt == dist_st) {
                            var sigma_sv: float = sigma[s][v];
                            var sigma_vt: float = sigma[v][t];
                            var sigma_st: float = sigma[s][t];
                            if (sigma_st > 0.0) {
                                result = result + (sigma_sv * sigma_vt) / sigma_st;
                            };
                        };
                    };
                };
                t++;
            };
        };
        s++;
    };
    return result;
};

~~ Homophily index — fraction of edges connecting nodes with same attribute.
~~ attributes array must match adjacency length.
function homophily_index(adjacency: int[][], attributes: int[]) -> float {
    var n: int = validate_adjacency(adjacency);
    if (attributes.length != n) {
        c_print_err("MochaLibError (mocha-society): Attributes array length must match adjacency matrix size.");
        c_exit(2);
    };
    var same_group: int = 0;
    var total_edges: int = 0;
    var i: int = 0;
    while (i < n) {
        var j: int = i + 1;
        while (j < n) {
            if (adjacency[i][j] == 1) {
                total_edges++;
                if (attributes[i] == attributes[j]) {
                    same_group++;
                };
            };
            j++;
        };
        i++;
    };
    if (total_edges == 0) {
        c_print_err("MochaLibError (mocha-society): Homophily undefined for graphs with no edges.");
        c_exit(2);
    };
    return float(same_group) / float(total_edges);
};

// ================================================================
// SECTION 5: ANTHROPOLOGY / KINSHIP & CULTURAL DIVERSITY
// ================================================================

~~ Wright's coefficient of relationship (r), via path-counting through shared ancestors.
~~ num_paths >= 1, links_per_path >= 1 (at least one generation link). Result in [0, 1].
~~ r = num_paths * (0.5)^links_per_path.
function coefficient_of_relationship(num_paths: int, links_per_path: int) -> float {
    if (num_paths < 1) {
        c_print_err("MochaLibError (mocha-society): Number of paths must be at least 1 (use 0 only if you truly mean 'no relation').");
        c_exit(2);
    };
    if (links_per_path < 1) {
        c_print_err("MochaLibError (mocha-society): Generational links must be at least 1.");
        c_exit(2);
    };
    const HALF_POWER: float = float(c_pow(0.5, float(links_per_path)));
    var r: float = float(num_paths) * HALF_POWER;
    if (r > 1.0) {
        c_print_err("MochaLibError (mocha-society): Coefficient of relationship exceeds 1.0 — check inputs (max is 1.0 for identical twins).");
        c_exit(2);
    };
    return r;
};

~~ Inbreeding coefficient of offspring from parents with a given coefficient of relationship.
~~ parental_relationship in [0, 1] (assumes parents themselves non-inbred). F = r / 2.
function inbreeding_coefficient(parental_relationship: float) -> float {
    if (parental_relationship < 0.0) {
        c_print_err("MochaLibError (mocha-society): Parental relationship cannot be negative.");
        c_exit(2);
    };
    if (parental_relationship > 1.0) {
        c_print_err("MochaLibError (mocha-society): Parental relationship cannot exceed 1.0.");
        c_exit(2);
    };
    return parental_relationship / 2.0;
};

~~ Simpson's Diversity Index — probability that two randomly sampled individuals belong to different groups.
~~ counts = non-empty array of non-negative group population sizes with positive total. D = 1 - Σ(p_i²).
function simpsons_diversity_index(counts: float[]) -> float {
    var n: int = counts.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-society): Diversity index requires a non-empty counts array.");
        c_exit(2);
    };
    var total: float = 0.0;
    var i: int = 0;
    while (i < n) {
        if (counts[i] < 0.0) {
            c_print_err("MochaLibError (mocha-society): Group counts cannot be negative.");
            c_exit(2);
        };
        total = total + counts[i];
        i++;
    };
    if (total <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Total population must be positive.");
        c_exit(2);
    };
    var sum_sq: float = 0.0;
    var j: int = 0;
    while (j < n) {
        var p: float = counts[j] / total;
        sum_sq = sum_sq + p * p;
        j++;
    };
    return 1.0 - sum_sq;
};

~~ Simpson's Reciprocal Index — effective number of equally-common groups.
~~ counts = non-empty array of non-negative group sizes with positive total. 1/D = 1 / Σ(p_i²).
function simpsons_reciprocal_index(counts: float[]) -> float {
    var n: int = counts.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-society): Reciprocal index requires a non-empty counts array.");
        c_exit(2);
    };
    var total: float = 0.0;
    var i: int = 0;
    while (i < n) {
        if (counts[i] < 0.0) {
            c_print_err("MochaLibError (mocha-society): Group counts cannot be negative.");
            c_exit(2);
        };
        total = total + counts[i];
        i++;
    };
    if (total <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Total population must be positive.");
        c_exit(2);
    };
    var sum_sq: float = 0.0;
    var j: int = 0;
    while (j < n) {
        var p: float = counts[j] / total;
        sum_sq = sum_sq + p * p;
        j++;
    };
    if (sum_sq <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Reciprocal index undefined — all groups have zero count.");
        c_exit(2);
    };
    return 1.0 / sum_sq;
};

~~ Shannon Diversity Index (entropy-based). H = -Σ(p_i * ln(p_i)). Zero-count groups contribute 0 (limit convention).
~~ counts = non-empty array of non-negative group sizes with positive total.
function shannon_diversity_index(counts: float[]) -> float {
    var n: int = counts.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-society): Shannon index requires a non-empty counts array.");
        c_exit(2);
    };
    var total: float = 0.0;
    var i: int = 0;
    while (i < n) {
        if (counts[i] < 0.0) {
            c_print_err("MochaLibError (mocha-society): Group counts cannot be negative.");
            c_exit(2);
        };
        total = total + counts[i];
        i++;
    };
    if (total <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Total population must be positive.");
        c_exit(2);
    };
    var sum_term: float = 0.0;
    var j: int = 0;
    while (j < n) {
        var p: float = counts[j] / total;
        if (p > 0.0) {
            var ln_p: float = p.log().real;
            sum_term = sum_term + p * ln_p;
        };
        j++;
    };
    return -sum_term;
};

~~ Shannon Evenness Index — E = H / ln(S). Returns 1.0 if only one group (perfectly even by convention).
~~ Requires non-empty counts with positive total.
function shannon_evenness_index(counts: float[]) -> float {
    var n: int = counts.length;
    if (n == 0) {
        c_print_err("MochaLibError (mocha-society): Evenness index requires a non-empty counts array.");
        c_exit(2);
    };
    if (n == 1) {
        // Single group: perfectly even by convention (no way to be uneven)
        return 1.0;
    };
    var h: float = shannon_diversity_index(counts);
    var n_float: float = float(n);
    var ln_s: float = n_float.log().real;
    return h / ln_s;
};

~~ Cultural distance index — proportion of cultural traits that differ between two groups.
~~ differing_traits in [0, total_traits], total_traits > 0.
function cultural_distance_index(differing_traits: int, total_traits: int) -> float {
    if (total_traits <= 0) {
        c_print_err("MochaLibError (mocha-society): Total traits must be positive.");
        c_exit(2);
    };
    if (differing_traits < 0) {
        c_print_err("MochaLibError (mocha-society): Differing traits cannot be negative.");
        c_exit(2);
    };
    if (differing_traits > total_traits) {
        c_print_err("MochaLibError (mocha-society): Differing traits cannot exceed total traits.");
        c_exit(2);
    };
    return float(differing_traits) / float(total_traits);
};

~~ Cultural similarity index — complement of cultural distance.
~~ differing_traits in [0, total_traits], total_traits > 0.
function cultural_similarity_index(differing_traits: int, total_traits: int) -> float {
    if (total_traits <= 0) {
        c_print_err("MochaLibError (mocha-society): Total traits must be positive.");
        c_exit(2);
    };
    if (differing_traits < 0) {
        c_print_err("MochaLibError (mocha-society): Differing traits cannot be negative.");
        c_exit(2);
    };
    if (differing_traits > total_traits) {
        c_print_err("MochaLibError (mocha-society): Differing traits cannot exceed total traits.");
        c_exit(2);
    };
    const DISTANCE: float = float(differing_traits) / float(total_traits);
    return 1.0 - DISTANCE;
};

// ================================================================
// SECTION 6: RESEARCH METHODS & MEASUREMENT
// ================================================================

~~ Validates a proportion is in [0, 1].
function validate_proportion(p: float, name: str) -> float {
    if (p < 0.0 || p > 1.0) {
        c_print_err("MochaLibError (mocha-society): " + name + " must be in [0, 1].");
        c_exit(2);
    };
    return p;
};

~~ Validates a value is positive.
function validate_positive(x: float, name: str) -> float {
    if (x <= 0.0) {
        c_print_err("MochaLibError (mocha-society): " + name + " must be positive.");
        c_exit(2);
    };
    return x;
};

~~ Validates a value is non-negative.
function validate_non_negative(x: float, name: str) -> float {
    if (x < 0.0) {
        c_print_err("MochaLibError (mocha-society): " + name + " cannot be negative.");
        c_exit(2);
    };
    return x;
};

~~ Cronbach's alpha — internal consistency reliability. Requires k >= 2 items and positive total variance.
~~ α = (k/(k-1)) * (1 - Σ(item_variances)/total_variance).
function cronbachs_alpha(item_variances: float[], total_variance: float) -> float {
    var k: int = item_variances.length;
    if (k < 2) {
        c_print_err("MochaLibError (mocha-society): Cronbach's alpha requires at least 2 items.");
        c_exit(2);
    };
    validate_positive(total_variance, "Total variance");
    var sum_var: float = 0.0;
    var i: int = 0;
    while (i < k) {
        if (item_variances[i] < 0.0) {
            c_print_err("MochaLibError (mocha-society): Item variances cannot be negative.");
            c_exit(2);
        };
        sum_var = sum_var + item_variances[i];
        i++;
    };
    const RATIO: float = sum_var / total_variance;
    const FACTOR: float = float(k) / float(k - 1);
    return FACTOR * (1.0 - RATIO);
};

~~ Cohen's kappa — inter-rater reliability. Requires both proportions in [0, 1] and expected < 1.0.
~~ κ = (p_o - p_e) / (1 - p_e).
function cohens_kappa(observed_agreement: float, expected_agreement: float) -> float {
    validate_proportion(observed_agreement, "Observed agreement");
    validate_proportion(expected_agreement, "Expected agreement");
    if (expected_agreement >= 1.0) {
        c_print_err("MochaLibError (mocha-society): Expected agreement cannot be 1.0 (division by zero).");
        c_exit(2);
    };
    const NUMERATOR: float = observed_agreement - expected_agreement;
    const DENOM: float = 1.0 - expected_agreement;
    return NUMERATOR / DENOM;
};

~~ Standard error of a sample proportion. p in [0, 1], n > 0. SE = sqrt(p*(1-p)/n).
function standard_error_of_proportion(p: float, n: float) -> float {
    validate_proportion(p, "Sample proportion");
    validate_positive(n, "Sample size");
    const INNER: float = (p * (1.0 - p)) / n;
    return INNER.sqrt().real;
};

~~ Margin of error for a sample proportion. z_score > 0. MOE = z * SE(p).
function margin_of_error_proportion(p: float, n: float, z_score: float) -> float {
    validate_proportion(p, "Sample proportion");
    validate_positive(n, "Sample size");
    validate_positive(z_score, "Z-score");
    const SE: float = standard_error_of_proportion(p, n);
    return z_score * SE;
};

~~ Required sample size to estimate a proportion within a target margin of error.
~~ z_score > 0, p in [0, 1], margin_of_error > 0. n = (z² * p*(1-p)) / E².
function sample_size_for_proportion(z_score: float, p: float, margin_of_error: float) -> float {
    validate_positive(z_score, "Z-score");
    validate_proportion(p, "Assumed proportion");
    validate_positive(margin_of_error, "Margin of error");
    const NUMERATOR: float = z_score * z_score * p * (1.0 - p);
    const DENOM: float = margin_of_error * margin_of_error;
    return NUMERATOR / DENOM;
};

~~ Confidence interval for a sample proportion. Returns (lower, upper), clamped to [0, 1].
~~ Note: this is the Wald interval, which can be inaccurate for extreme proportions near 0 or 1.
~~ For proportions near 0/1 or small n, use the Wilson score interval instead.
function confidence_interval_proportion(p: float, n: float, z_score: float) -> (float, 2) {
    validate_proportion(p, "Sample proportion");
    validate_positive(n, "Sample size");
    validate_positive(z_score, "Z-score");
    const MOE: float = margin_of_error_proportion(p, n, z_score);
    var lower: float = p - MOE;
    var upper: float = p + MOE;
    if (lower < 0.0) { lower = 0.0; };
    if (upper > 1.0) { upper = 1.0; };
    return (lower, upper);
};

~~ Standard error of the mean. std_dev >= 0, n > 0. SEM = std_dev / sqrt(n).
function standard_error_of_mean(std_dev: float, n: float) -> float {
    validate_non_negative(std_dev, "Standard deviation");
    validate_positive(n, "Sample size");
    const SQRT_N: float = n.sqrt().real;
    return std_dev / SQRT_N;
};

~~ Pooled standard deviation across two independent samples. n1 >= 2, n2 >= 2.
function pooled_standard_deviation(std1: float, n1: float, std2: float, n2: float) -> float {
    validate_non_negative(std1, "Standard deviation 1");
    validate_non_negative(std2, "Standard deviation 2");
    if (n1 < 2.0) {
        c_print_err("MochaLibError (mocha-society): Group 1 sample size must be at least 2.");
        c_exit(2);
    };
    if (n2 < 2.0) {
        c_print_err("MochaLibError (mocha-society): Group 2 sample size must be at least 2.");
        c_exit(2);
    };
    const NUMERATOR: float = (n1 - 1.0) * std1 * std1 + (n2 - 1.0) * std2 * std2;
    const DENOM: float = n1 + n2 - 2.0;
    const POOLED_VAR: float = NUMERATOR / DENOM;
    return POOLED_VAR.sqrt().real;
};

~~ Cohen's d — standardized effect size. pooled_std > 0.
function cohens_d(mean1: float, mean2: float, pooled_std: float) -> float {
    validate_positive(pooled_std, "Pooled standard deviation");
    return (mean1 - mean2) / pooled_std;
};

~~ Pearson correlation coefficient. x and y must be same length, both non-empty with positive variance.
~~ r = Σ((x-x̄)(y-ȳ)) / sqrt(Σ(x-x̄)² * Σ(y-ȳ)²).
function pearson_correlation_coefficient(x: float[], y: float[]) -> float {
    var n: int = x.length;
    var m: int = y.length;
    if (n != m) {
        c_print_err("MochaLibError (mocha-society): x and y arrays must have the same length.");
        c_exit(2);
    };
    if (n < 2) {
        c_print_err("MochaLibError (mocha-society): Pearson correlation requires at least 2 observations.");
        c_exit(2);
    };
    var sum_x: float = 0.0;
    var sum_y: float = 0.0;
    var i: int = 0;
    while (i < n) {
        sum_x = sum_x + x[i];
        sum_y = sum_y + y[i];
        i++;
    };
    var mean_x: float = sum_x / float(n);
    var mean_y: float = sum_y / float(n);

    var numerator: float = 0.0;
    var sum_sq_x: float = 0.0;
    var sum_sq_y: float = 0.0;
    var j: int = 0;
    while (j < n) {
        var dx: float = x[j] - mean_x;
        var dy: float = y[j] - mean_y;
        numerator = numerator + dx * dy;
        sum_sq_x = sum_sq_x + dx * dx;
        sum_sq_y = sum_sq_y + dy * dy;
        j++;
    };
    if (sum_sq_x <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Pearson correlation undefined — x has zero variance.");
        c_exit(2);
    };
    if (sum_sq_y <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Pearson correlation undefined — y has zero variance.");
        c_exit(2);
    };
    const DENOM: float = (sum_sq_x * sum_sq_y).sqrt().real;
    return numerator / DENOM;
};

// ================================================================
// SECTION 7: SOCIO-ECONOMIC DEVELOPMENT
// ================================================================

~~ Life expectancy sub-index for HDI (UNDP min-max normalization). Result in [0, 1].
~~ Requires max_val > min_val, life_expectancy >= 0.
function life_expectancy_index(life_expectancy: float, min_val: float, max_val: float) -> float {
    if (max_val <= min_val) {
        c_print_err("MochaLibError (mocha-society): max_val must be greater than min_val.");
        c_exit(2);
    };
    if (life_expectancy < 0.0) {
        c_print_err("MochaLibError (mocha-society): Life expectancy cannot be negative.");
        c_exit(2);
    };
    const RANGE: float = max_val - min_val;
    var idx: float = (life_expectancy - min_val) / RANGE;
    if (idx < 0.0) { idx = 0.0; };
    if (idx > 1.0) { idx = 1.0; };
    return idx;
};

~~ Schooling sub-index for HDI (general purpose). Result in [0, 1].
~~ Requires max_years > min_years, years >= 0.
function schooling_index(years: float, min_years: float, max_years: float) -> float {
    if (max_years <= min_years) {
        c_print_err("MochaLibError (mocha-society): max_years must be greater than min_years.");
        c_exit(2);
    };
    if (years < 0.0) {
        c_print_err("MochaLibError (mocha-society): Years of schooling cannot be negative.");
        c_exit(2);
    };
    const RANGE: float = max_years - min_years;
    var idx: float = (years - min_years) / RANGE;
    if (idx < 0.0) { idx = 0.0; };
    if (idx > 1.0) { idx = 1.0; };
    return idx;
};

~~ Education sub-index for HDI, averaging mean-years and expected-years indices.
~~ Both inputs must be in [0, 1].
function education_index(mean_years_index: float, expected_years_index: float) -> float {
    if (mean_years_index < 0.0 || mean_years_index > 1.0) {
        c_print_err("MochaLibError (mocha-society): Mean years index must be in [0, 1].");
        c_exit(2);
    };
    if (expected_years_index < 0.0 || expected_years_index > 1.0) {
        c_print_err("MochaLibError (mocha-society): Expected years index must be in [0, 1].");
        c_exit(2);
    };
    return (mean_years_index + expected_years_index) / 2.0;
};

~~ Income sub-index for HDI (UNDP log-scale normalization). Result in [0, 1].
~~ Requires gni_per_capita > 0, min_gni > 0, max_gni > min_gni.
function income_index(gni_per_capita: float, min_gni: float, max_gni: float) -> float {
    if (gni_per_capita <= 0.0) {
        c_print_err("MochaLibError (mocha-society): GNI per capita must be positive (log-scale normalization).");
        c_exit(2);
    };
    if (min_gni <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Minimum GNI must be positive (log-scale normalization). Use 100.0 as UNDP standard.");
        c_exit(2);
    };
    if (max_gni <= min_gni) {
        c_print_err("MochaLibError (mocha-society): max_gni must be greater than min_gni.");
        c_exit(2);
    };
    const LN_GNI: float = gni_per_capita.log().real;
    const LN_MIN: float = min_gni.log().real;
    const LN_MAX: float = max_gni.log().real;
    const NUMERATOR: float = LN_GNI - LN_MIN;
    const DENOM: float = LN_MAX - LN_MIN;
    var idx: float = NUMERATOR / DENOM;
    if (idx < 0.0) { idx = 0.0; };
    if (idx > 1.0) { idx = 1.0; };
    return idx;
};

~~ Human Development Index — geometric mean of three sub-indices. Result in [0, 1].
~~ All inputs must be in [0, 1].
function human_development_index(life_exp_idx: float, edu_idx: float, inc_idx: float) -> float {
    if (life_exp_idx < 0.0 || life_exp_idx > 1.0) {
        c_print_err("MochaLibError (mocha-society): Life expectancy index must be in [0, 1].");
        c_exit(2);
    };
    if (edu_idx < 0.0 || edu_idx > 1.0) {
        c_print_err("MochaLibError (mocha-society): Education index must be in [0, 1].");
        c_exit(2);
    };
    if (inc_idx < 0.0 || inc_idx > 1.0) {
        c_print_err("MochaLibError (mocha-society): Income index must be in [0, 1].");
        c_exit(2);
    };
    const PRODUCT: float = life_exp_idx * edu_idx * inc_idx;
    return PRODUCT.cubrot();
};

~~ Continuous annual GDP per capita growth rate. gdp0 > 0, gdp1 > 0, years > 0.
~~ r = ln(GDP1/GDP0) / years.
function gdp_per_capita_growth_rate(gdp0: float, gdp1: float, years: float) -> float {
    if (gdp0 <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Initial GDP per capita must be positive.");
        c_exit(2);
    };
    if (gdp1 <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Final GDP per capita must be positive.");
        c_exit(2);
    };
    if (years <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Elapsed time must be positive.");
        c_exit(2);
    };
    const RATIO: float = gdp1 / gdp0;
    const LN_RATIO: float = RATIO.log().real;
    return LN_RATIO / years;
};

~~ Income elasticity of demand. percent_change_income != 0.
~~ Elasticity > 1 = luxury, < 1 = necessity, < 0 = inferior good.
function income_elasticity_of_demand(percent_change_quantity: float, percent_change_income: float) -> float {
    if (percent_change_income == 0.0) {
        c_print_err("MochaLibError (mocha-society): Percent change in income cannot be zero (elasticity undefined).");
        c_exit(2);
    };
    return percent_change_quantity / percent_change_income;
};

~~ Engel's coefficient — share of household expenditure on food. Result in [0, 100].
~~ food_expenditure in [0, total_expenditure], total_expenditure > 0.
function engels_coefficient(food_expenditure: float, total_expenditure: float) -> float {
    if (total_expenditure <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Total expenditure must be positive.");
        c_exit(2);
    };
    if (food_expenditure < 0.0) {
        c_print_err("MochaLibError (mocha-society): Food expenditure cannot be negative.");
        c_exit(2);
    };
    if (food_expenditure > total_expenditure) {
        c_print_err("MochaLibError (mocha-society): Food expenditure cannot exceed total expenditure.");
        c_exit(2);
    };
    return (food_expenditure / total_expenditure) * 100.0;
};

~~ Unemployment rate as percentage of labor force. unemployed in [0, labor_force], labor_force > 0.
function unemployment_rate(unemployed: float, labor_force: float) -> float {
    if (labor_force <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Labor force must be positive.");
        c_exit(2);
    };
    if (unemployed < 0.0) {
        c_print_err("MochaLibError (mocha-society): Unemployed count cannot be negative.");
        c_exit(2);
    };
    if (unemployed > labor_force) {
        c_print_err("MochaLibError (mocha-society): Unemployed count cannot exceed labor force.");
        c_exit(2);
    };
    return (unemployed / labor_force) * 100.0;
};

~~ Labor force participation rate as percentage of working-age population. labor_force >= 0, working_age_population > 0.
function labor_force_participation_rate(labor_force: float, working_age_population: float) -> float {
    if (working_age_population <= 0.0) {
        c_print_err("MochaLibError (mocha-society): Working-age population must be positive.");
        c_exit(2);
    };
    if (labor_force < 0.0) {
        c_print_err("MochaLibError (mocha-society): Labor force cannot be negative.");
        c_exit(2);
    };
    return (labor_force / working_age_population) * 100.0;
};

~~ Converts nominal monetary value to PPP-adjusted real value.
~~ nominal_value >= 0, ppp_conversion_factor > 0.
function purchasing_power_parity_adjustment(nominal_value: float, ppp_conversion_factor: float) -> float {
    if (ppp_conversion_factor <= 0.0) {
        c_print_err("MochaLibError (mocha-society): PPP conversion factor must be positive.");
        c_exit(2);
    };
    if (nominal_value < 0.0) {
        c_print_err("MochaLibError (mocha-society): Nominal value cannot be negative.");
        c_exit(2);
    };
    return nominal_value / ppp_conversion_factor;
};

~~ Misery index — sum of inflation and unemployment rates.
~~ Either input may be negative (deflation is meaningful). No range constraint.
function misery_index(inflation_rate: float, unemployment_rate_val: float) -> float {
    return inflation_rate + unemployment_rate_val;
};