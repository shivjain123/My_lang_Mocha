~~ mocha-society — Sociology, Political Science, Anthropology & Socio-Economics Library for Mocha
~~ Section 1: Demography
~~
~~ Part of the Mocha Scientific Library Ecosystem
~~ License: Polyform Non-Commercial

// mocha-lib-deps: mocha-math

function c_exp(x: float) -> float native mocha_wrap_exp;

const DEG_TO_RAD: float = 0.01745329251994;
const RAD_TO_DEG: float = 57.29577951308232;

// ================================================================
// SECTION 1: DEMOGRAPHY
// ================================================================

~~ Continuous (exponential) annual population growth rate from initial and final population.
~~ p0, p1 = population counts, years = elapsed time. r = ln(P1/P0) / years.
function population_growth_rate(p0: float, p1: float, years: float) -> float {
    const RATIO: float = p1 / p0;
    const LN_RATIO: float = RATIO.log().real;
    return LN_RATIO / years;
};

~~ Population doubling time in years from a continuous growth rate.
~~ growth_rate as a decimal (e.g. 0.02 = 2% per year). t = ln(2) / r.
function population_doubling_time(growth_rate: float) -> float {
    const LN2: float = 2.0.log().real;
    return LN2 / growth_rate;
};

~~ Crude birth rate per 1000 population.
~~ births = number of live births, population = total population (same period/area).
function crude_birth_rate(births: float, population: float) -> float {
    return (births / population) * 1000.0;
};

~~ Crude death rate per 1000 population.
~~ deaths = number of deaths, population = total population (same period/area).
function crude_death_rate(deaths: float, population: float) -> float {
    return (deaths / population) * 1000.0;
};

~~ Rate of natural increase as a percentage, from crude birth and death rates.
~~ cbr, cdr = crude birth/death rate (per 1000). NIR(%) = (CBR - CDR) / 10.
function natural_increase_rate(cbr: float, cdr: float) -> float {
    return (cbr - cdr) / 10.0;
};

~~ Net migration rate per 1000 population.
~~ immigrants, emigrants = counts over the period, population = total population.
function net_migration_rate(immigrants: float, emigrants: float, population: float) -> float {
    const NET: float = immigrants - emigrants;
    return (NET / population) * 1000.0;
};

~~ Total age dependency ratio (per 100 working-age population).
~~ pop_under15, pop_65plus = dependent age groups, pop_working = population aged 15-64.
function dependency_ratio(pop_under15: float, pop_65plus: float, pop_working: float) -> float {
    const DEPENDENTS: float = pop_under15 + pop_65plus;
    return (DEPENDENTS / pop_working) * 100.0;
};

~~ Child dependency ratio (per 100 working-age population).
~~ pop_under15 = population aged 0-14, pop_working = population aged 15-64.
function child_dependency_ratio(pop_under15: float, pop_working: float) -> float {
    return (pop_under15 / pop_working) * 100.0;
};

~~ Old-age dependency ratio (per 100 working-age population).
~~ pop_65plus = population aged 65+, pop_working = population aged 15-64.
function old_age_dependency_ratio(pop_65plus: float, pop_working: float) -> float {
    return (pop_65plus / pop_working) * 100.0;
};

~~ Projects future population using continuous exponential growth.
~~ p0 = initial population, growth_rate as decimal, years = projection horizon.
~~ P(t) = P0 * e^(r*t).
function population_projection(p0: float, growth_rate: float, years: float) -> float {
    const EXPONENT: float = growth_rate * years;
    const EXP_VAL: float = float(c_exp(EXPONENT));
    return p0 * EXP_VAL;
};

// ================================================================
// SECTION 2: SOCIAL STRATIFICATION & INEQUALITY
// ================================================================

~~ Arithmetic mean of an income/wealth distribution.
~~ incomes = array of values (any consistent unit).
function mean_income(incomes: float[]) -> float {
    var n: int = incomes.length;
    var total: float = 0.0;
    var i: int = 0;
    while (i < n) {
        total = total + incomes[i];
        i++;
    };
    return total / float(n);
};

~~ Gini coefficient of income inequality (0 = perfect equality, 1 = perfect inequality).
~~ incomes MUST be sorted ascending. Uses the rank-sum formula:
~~ G = (2*Σ(rank_i * x_i) - (n+1)*Σx_i) / (n*Σx_i).
function gini_coefficient(incomes: float[]) -> float {
    var n: int = incomes.length;
    var weighted_sum: float = 0.0;
    var total_sum: float = 0.0;
    var i: int = 0;
    while (i < n) {
        var rank: float = float(i + 1);
        weighted_sum = weighted_sum + rank * incomes[i];
        total_sum = total_sum + incomes[i];
        i++;
    };
    const NUMERATOR: float = 2.0 * weighted_sum - float(n + 1) * total_sum;
    const DENOM: float = float(n) * total_sum;
    return NUMERATOR / DENOM;
};

~~ Theil index of inequality (0 = perfect equality, higher = more unequal, unbounded above).
~~ incomes = array of values in any order. T = (1/n) * Σ( (x_i/mean) * ln(x_i/mean) ).
function theil_index(incomes: float[]) -> float {
    var n: int = incomes.length;
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
~~ incomes = array of values, epsilon = inequality aversion (0 < epsilon, epsilon != 1). Higher epsilon weights the bottom of the distribution more.
~~ A = 1 - (1/mean) * [(1/n)*Σx_i^(1-ε)]^(1/(1-ε)).
function atkinson_index(incomes: float[], epsilon: float) -> float {
    var n: int = incomes.length;
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
~~ poor_count = population below the poverty line, total_population = total population.
function poverty_headcount_ratio(poor_count: float, total_population: float) -> float {
    return (poor_count / total_population) * 100.0;
};

~~ Poverty gap index — average normalized income shortfall below the poverty line across the whole population.
~~ incomes = array of values (including those above the line), poverty_line = threshold value.
~~ PGI = (1/n) * Σ max(0, (z - x_i)/z).
function poverty_gap_index(incomes: float[], poverty_line: float) -> float {
    var n: int = incomes.length;
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
~~ top10_share and bottom40_share as percentages.
function palma_ratio(top10_share: float, bottom40_share: float) -> float {
    return top10_share / bottom40_share;
};

~~ General income share ratio between any two population deciles/quintiles.
~~ top_share and bottom_share as percentages (e.g. 20:20 ratio).
function income_share_ratio(top_share: float, bottom_share: float) -> float {
    return top_share / bottom_share;
};

~~ Relative poverty line as a fraction of median income (commonly 0.5 or 0.6, OECD/EU convention).
~~ median_income = population median, threshold_fraction as a decimal (e.g. 0.6 = 60%).
function relative_poverty_line(median_income: float, threshold_fraction: float) -> float {
    return threshold_fraction * median_income;
};

// ================================================================
// SECTION 3: POLITICAL SCIENCE / ELECTORAL SYSTEMS
// ================================================================

~~ Voter turnout rate as a percentage.
~~ votes_cast = ballots cast, eligible_voters = total eligible electorate.
function voter_turnout_rate(votes_cast: float, eligible_voters: float) -> float {
    return (votes_cast / eligible_voters) * 100.0;
};

~~ Seat allocation via the D'Hondt highest-averages method.
~~ votes = array of party vote totals, total_seats = seats to allocate.
~~ Returns array of seats won per party (same order as input). Divisor sequence: 1,2,3,...
function dhondt_apportionment(votes: float[], total_seats: int) -> int[] {
    var n: int = votes.length;
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

~~ Seat allocation via the Sainte-Laguë highest-averages method.
~~ votes = array of party vote totals, total_seats = seats to allocate.
~~ Returns array of seats won per party (same order as input). Divisor sequence: 1,3,5,7,...
function sainte_lague_apportionment(votes: float[], total_seats: int) -> int[] {
    var n: int = votes.length;
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
~~ vote_shares = array of fractional vote shares summing to 1.0. ENP = 1 / Σ(share_i²).
function effective_number_of_parties(vote_shares: float[]) -> float {
    var n: int = vote_shares.length;
    var sum_sq: float = 0.0;
    var i: int = 0;
    while (i < n) {
        sum_sq = sum_sq + vote_shares[i] * vote_shares[i];
        i++;
    };
    return 1.0 / sum_sq;
};

~~ Gallagher least-squares disproportionality index, measuring vote-seat mismatch.
~~ vote_shares and seat_shares as percentages (same order, same length).
~~ G = sqrt(0.5 * Σ(v_i - s_i)²).
function gallagher_index(vote_shares: float[], seat_shares: float[]) -> float {
    var n: int = vote_shares.length;
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

~~ Per-party deviation between vote share and seat share (a single Gallagher term, useful standalone).
~~ vote_share and seat_share as percentages.
function seat_vote_deviation(vote_share: float, seat_share: float) -> float {
    return vote_share - seat_share;
};

~~ Banzhaf power index for a 3-player weighted voting game.
~~ w1, w2, w3 = voting weights, quota = votes needed to win.
~~ Returns (power1, power2, power3) — fraction of winning coalitions where each player is critical.
function banzhaf_power_index_3player(w1: float, w2: float, w3: float, quota: float) -> (float, 3) {
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
    return (c1 / TOTAL, c2 / TOTAL, c3 / TOTAL);
};

~~ Shapley-Shubik power index for a 3-player weighted voting game.
~~ w1, w2, w3 = voting weights, quota = votes needed to win.
~~ Returns (power1, power2, power3) — fraction of the 6 orderings where each player is pivotal.
function shapley_shubik_power_index_3player(w1: float, w2: float, w3: float, quota: float) -> (float, 3) {
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

~~ Degree of a node — number of edges connected to it.
~~ adjacency = n×n adjacency matrix, node_index = index of the node.
function node_degree(adjacency: int[][], node_index: int) -> int {
    var n: int = adjacency.length;
    var deg: int = 0;
    var j: int = 0;
    while (j < n) {
        deg = deg + adjacency[node_index][j];
        j++;
    };
    return deg;
};

~~ Degree centrality — a node's degree normalized by the maximum possible degree (n-1).
~~ adjacency = n×n adjacency matrix, node_index = index of the node.
function degree_centrality(adjacency: int[][], node_index: int) -> float {
    var n: int = adjacency.length;
    var deg: int = node_degree(adjacency, node_index);
    return float(deg) / float(n - 1);
};

~~ Network density — fraction of possible edges that actually exist.
~~ adjacency = n×n adjacency matrix. D = 2E / (n(n-1)).
function network_density(adjacency: int[][]) -> float {
    var n: int = adjacency.length;
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
~~ adjacency = n×n adjacency matrix.
function average_degree(adjacency: int[][]) -> float {
    var n: int = adjacency.length;
    var total_degree: int = 0;
    var i: int = 0;
    while (i < n) {
        total_degree = total_degree + node_degree(adjacency, i);
        i++;
    };
    return float(total_degree) / float(n);
};

~~ Local clustering coefficient — how interconnected a node's neighbors are with each other.
~~ adjacency = n×n adjacency matrix, node_index = index of the node.
~~ C(v) = 2*E_v / (k_v*(k_v-1)), where E_v = edges among v's neighbors, k_v = degree of v.
function clustering_coefficient(adjacency: int[][], node_index: int) -> float {
    var n: int = adjacency.length;
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

~~ Shortest path length (in edges) between two nodes via BFS.
~~ adjacency = n×n adjacency matrix, source and target = node indices.
function shortest_path_length(adjacency: int[][], source: int, target: int) -> int {
    var n: int = adjacency.length;
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

~~ Closeness centrality — how close a node is to all other nodes on average.
~~ adjacency = n×n adjacency matrix, node_index = index of the node. Assumes connected graph.
~~ C(v) = (n-1) / Σ(shortest_path_length(v, i)).
function closeness_centrality(adjacency: int[][], node_index: int) -> float {
    var n: int = adjacency.length;
    var total_dist: int = 0;
    var i: int = 0;
    while (i < n) {
        if (i != node_index) {
            total_dist = total_dist + shortest_path_length(adjacency, node_index, i);
        };
        i++;
    };
    return float(n - 1) / float(total_dist);
};

~~ Betweenness centrality (raw/unnormalized) — how often a node lies on shortest paths between other pairs.
~~ adjacency = n×n adjacency matrix, node_index = index of the node.
~~ Computes exact shortest-path counts (handles multiple equal-length shortest paths correctly).
function betweenness_centrality(adjacency: int[][], node_index: int) -> float {
    var n: int = adjacency.length;
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
                    if (dist_sv + dist_vt == dist_st) {
                        var sigma_sv: float = sigma[s][v];
                        var sigma_vt: float = sigma[v][t];
                        var sigma_st: float = sigma[s][t];
                        if (sigma_st > 0.0) {
                            result = result + (sigma_sv * sigma_vt) / sigma_st;
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

~~ Homophily index — fraction of edges connecting nodes with the same attribute value.
~~ adjacency = n×n adjacency matrix, attributes = array of group labels per node (same order as adjacency).
function homophily_index(adjacency: int[][], attributes: int[]) -> float {
    var n: int = adjacency.length;
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
    return float(same_group) / float(total_edges);
};

// ================================================================
// SECTION 5: ANTHROPOLOGY / KINSHIP & CULTURAL DIVERSITY
// ================================================================

~~ Wright's coefficient of relationship (r), via path-counting through shared ancestors.
~~ num_paths = number of distinct paths through common ancestor(s) (e.g. 2 for full siblings via both parents),
~~ links_per_path = number of generational links per path. Assumes equal-length paths.
~~ r = num_paths * (0.5)^links_per_path.
function coefficient_of_relationship(num_paths: int, links_per_path: int) -> float {
    const HALF_POWER: float = float(c_pow(0.5, float(links_per_path)));
    return float(num_paths) * HALF_POWER;
};

~~ Inbreeding coefficient of offspring from parents with a given coefficient of relationship.
~~ parental_relationship = r value between the two parents (assumes parents themselves non-inbred).
~~ F = r / 2.
function inbreeding_coefficient(parental_relationship: float) -> float {
    return parental_relationship / 2.0;
};

~~ Simpson's Diversity Index — probability that two randomly sampled individuals belong to different groups.
~~ Equivalent to Greenberg's Linguistic Diversity Index when applied to language-group population counts.
~~ counts = array of group population sizes. D = 1 - Σ(p_i²), where p_i = group_i / total.
function simpsons_diversity_index(counts: float[]) -> float {
    var n: int = counts.length;
    var total: float = 0.0;
    var i: int = 0;
    while (i < n) {
        total = total + counts[i];
        i++;
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
~~ counts = array of group population sizes. 1/D = 1 / Σ(p_i²).
function simpsons_reciprocal_index(counts: float[]) -> float {
    var n: int = counts.length;
    var total: float = 0.0;
    var i: int = 0;
    while (i < n) {
        total = total + counts[i];
        i++;
    };
    var sum_sq: float = 0.0;
    var j: int = 0;
    while (j < n) {
        var p: float = counts[j] / total;
        sum_sq = sum_sq + p * p;
        j++;
    };
    return 1.0 / sum_sq;
};

~~ Shannon Diversity Index (entropy-based), sensitive to both richness and evenness of groups.
~~ counts = array of group population sizes. H = -Σ(p_i * ln(p_i)).
function shannon_diversity_index(counts: float[]) -> float {
    var n: int = counts.length;
    var total: float = 0.0;
    var i: int = 0;
    while (i < n) {
        total = total + counts[i];
        i++;
    };
    var sum_term: float = 0.0;
    var j: int = 0;
    while (j < n) {
        var p: float = counts[j] / total;
        var ln_p: float = p.log().real;
        sum_term = sum_term + p * ln_p;
        j++;
    };
    return -sum_term;
};

~~ Shannon Evenness Index — how uniformly individuals are distributed among groups (0-1, 1 = perfectly even).
~~ counts = array of group population sizes. E = H / ln(S), where S = number of groups.
function shannon_evenness_index(counts: float[]) -> float {
    var n: int = counts.length;
    var h: float = shannon_diversity_index(counts);
    var n_float: float = float(n);
    var ln_s: float = n_float.log().real;
    return h / ln_s;
};

~~ Cultural distance index — proportion of cultural traits that differ between two groups.
~~ differing_traits = count of traits that differ, total_traits = total traits compared.
function cultural_distance_index(differing_traits: int, total_traits: int) -> float {
    return float(differing_traits) / float(total_traits);
};

~~ Cultural similarity index — complement of cultural distance.
~~ differing_traits = count of traits that differ, total_traits = total traits compared.
function cultural_similarity_index(differing_traits: int, total_traits: int) -> float {
    const DISTANCE: float = float(differing_traits) / float(total_traits);
    return 1.0 - DISTANCE;
};

// ================================================================
// SECTION 6: RESEARCH METHODS & MEASUREMENT
// ================================================================

~~ Cronbach's alpha — internal consistency reliability of a multi-item scale.
~~ item_variances = array of variances for each scale item, total_variance = variance of summed scale scores.
~~ α = (k/(k-1)) * (1 - Σ(item_variances)/total_variance).
function cronbachs_alpha(item_variances: float[], total_variance: float) -> float {
    var k: int = item_variances.length;
    var sum_var: float = 0.0;
    var i: int = 0;
    while (i < k) {
        sum_var = sum_var + item_variances[i];
        i++;
    };
    const RATIO: float = sum_var / total_variance;
    const FACTOR: float = float(k) / float(k - 1);
    return FACTOR * (1.0 - RATIO);
};

~~ Cohen's kappa — inter-rater reliability, correcting for chance agreement.
~~ observed_agreement = proportion of cases raters agreed on, expected_agreement = proportion expected by chance.
~~ κ = (p_o - p_e) / (1 - p_e).
function cohens_kappa(observed_agreement: float, expected_agreement: float) -> float {
    const NUMERATOR: float = observed_agreement - expected_agreement;
    const DENOM: float = 1.0 - expected_agreement;
    return NUMERATOR / DENOM;
};

~~ Standard error of a sample proportion.
~~ p = sample proportion (0-1), n = sample size. SE = sqrt(p*(1-p)/n).
function standard_error_of_proportion(p: float, n: float) -> float {
    const INNER: float = (p * (1.0 - p)) / n;
    return INNER.sqrt().real;
};

~~ Margin of error for a sample proportion at a given confidence level.
~~ p = sample proportion, n = sample size, z_score = critical value (e.g. 1.96 for 95% CI).
~~ MOE = z * SE(p).
function margin_of_error_proportion(p: float, n: float, z_score: float) -> float {
    const SE: float = standard_error_of_proportion(p, n);
    return z_score * SE;
};

~~ Required sample size to estimate a proportion within a target margin of error.
~~ z_score = critical value, p = assumed/estimated proportion (use 0.5 for max variance), margin_of_error = target precision.
~~ n = (z² * p*(1-p)) / E².
function sample_size_for_proportion(z_score: float, p: float, margin_of_error: float) -> float {
    const NUMERATOR: float = z_score * z_score * p * (1.0 - p);
    const DENOM: float = margin_of_error * margin_of_error;
    return NUMERATOR / DENOM;
};

~~ Confidence interval for a sample proportion.
~~ p = sample proportion, n = sample size, z_score = critical value. Returns (lower, upper) bounds.
function confidence_interval_proportion(p: float, n: float, z_score: float) -> (float, 2) {
    const MOE: float = margin_of_error_proportion(p, n, z_score);
    const LOWER: float = p - MOE;
    const UPPER: float = p + MOE;
    return (LOWER, UPPER);
};

~~ Standard error of the mean.
~~ std_dev = sample standard deviation, n = sample size. SEM = std_dev / sqrt(n).
function standard_error_of_mean(std_dev: float, n: float) -> float {
    const SQRT_N: float = n.sqrt().real;
    return std_dev / SQRT_N;
};

~~ Pooled standard deviation across two independent samples (used in effect size calculations).
~~ std1, n1 = std dev and size of group 1; std2, n2 = std dev and size of group 2.
function pooled_standard_deviation(std1: float, n1: float, std2: float, n2: float) -> float {
    const NUMERATOR: float = (n1 - 1.0) * std1 * std1 + (n2 - 1.0) * std2 * std2;
    const DENOM: float = n1 + n2 - 2.0;
    const POOLED_VAR: float = NUMERATOR / DENOM;
    return POOLED_VAR.sqrt().real;
};

~~ Cohen's d — standardized effect size between two group means.
~~ mean1, mean2 = group means, pooled_std = pooled standard deviation (see pooled_standard_deviation).
function cohens_d(mean1: float, mean2: float, pooled_std: float) -> float {
    return (mean1 - mean2) / pooled_std;
};

~~ Pearson correlation coefficient between two paired variables.
~~ x, y = arrays of paired observations (same length). r = Σ((x-x̄)(y-ȳ)) / sqrt(Σ(x-x̄)² * Σ(y-ȳ)²).
function pearson_correlation_coefficient(x: float[], y: float[]) -> float {
    var n: int = x.length;
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
    const DENOM: float = (sum_sq_x * sum_sq_y).sqrt().real;
    return numerator / DENOM;
};

// ================================================================
// SECTION 7: SOCIO-ECONOMIC DEVELOPMENT
// ================================================================

~~ Life expectancy sub-index for HDI construction (UNDP-style min-max normalization).
~~ life_expectancy in years. Typical bounds: min=20.0, max=85.0.
function life_expectancy_index(life_expectancy: float, min_val: float, max_val: float) -> float {
    const RANGE: float = max_val - min_val;
    return (life_expectancy - min_val) / RANGE;
};

~~ Schooling sub-index for HDI construction (general purpose — used for both mean and expected years of schooling).
~~ years = years of schooling. Typical bounds: mean years min=0/max=15, expected years min=0/max=18.
function schooling_index(years: float, min_years: float, max_years: float) -> float {
    const RANGE: float = max_years - min_years;
    return (years - min_years) / RANGE;
};

~~ Education sub-index for HDI construction, averaging mean-years and expected-years schooling indices.
~~ mean_years_index and expected_years_index from schooling_index().
function education_index(mean_years_index: float, expected_years_index: float) -> float {
    return (mean_years_index + expected_years_index) / 2.0;
};

~~ Income sub-index for HDI construction, using log-scale normalization (UNDP methodology).
~~ gni_per_capita in PPP dollars. Typical bounds: min=100.0, max=75000.0.
function income_index(gni_per_capita: float, min_gni: float, max_gni: float) -> float {
    const LN_GNI: float = gni_per_capita.log().real;
    const LN_MIN: float = min_gni.log().real;
    const LN_MAX: float = max_gni.log().real;
    const NUMERATOR: float = LN_GNI - LN_MIN;
    const DENOM: float = LN_MAX - LN_MIN;
    return NUMERATOR / DENOM;
};

~~ Human Development Index — geometric mean of life expectancy, education, and income sub-indices.
~~ Inputs from life_expectancy_index(), education_index(), and income_index() respectively.
~~ HDI = (LEI * EI * II)^(1/3).
function human_development_index(life_exp_idx: float, edu_idx: float, inc_idx: float) -> float {
    const PRODUCT: float = life_exp_idx * edu_idx * inc_idx;
    return PRODUCT.cubrot();
};

~~ Continuous (exponential) annual GDP per capita growth rate.
~~ gdp0, gdp1 = GDP per capita at start/end, years = elapsed time. r = ln(GDP1/GDP0) / years.
function gdp_per_capita_growth_rate(gdp0: float, gdp1: float, years: float) -> float {
    const RATIO: float = gdp1 / gdp0;
    const LN_RATIO: float = RATIO.log().real;
    return LN_RATIO / years;
};

~~ Income elasticity of demand — responsiveness of quantity demanded to a change in income.
~~ percent_change_quantity and percent_change_income as percentages. Elasticity > 1 = luxury good, < 1 = necessity, < 0 = inferior good.
function income_elasticity_of_demand(percent_change_quantity: float, percent_change_income: float) -> float {
    return percent_change_quantity / percent_change_income;
};

~~ Engel's coefficient — share of household expenditure spent on food (a classic development/poverty indicator).
~~ food_expenditure and total_expenditure in same currency units.
function engels_coefficient(food_expenditure: float, total_expenditure: float) -> float {
    return (food_expenditure / total_expenditure) * 100.0;
};

~~ Unemployment rate as a percentage of the labor force.
~~ unemployed = count of unemployed persons, labor_force = total labor force (employed + unemployed).
function unemployment_rate(unemployed: float, labor_force: float) -> float {
    return (unemployed / labor_force) * 100.0;
};

~~ Labor force participation rate as a percentage of the working-age population.
~~ labor_force = employed + unemployed persons, working_age_population = total population aged 15-64 (or locally defined working age).
function labor_force_participation_rate(labor_force: float, working_age_population: float) -> float {
    return (labor_force / working_age_population) * 100.0;
};

~~ Converts a nominal monetary value to its purchasing-power-parity-adjusted real value.
~~ nominal_value in local currency, ppp_conversion_factor = PPP conversion rate (local currency per international dollar).
function purchasing_power_parity_adjustment(nominal_value: float, ppp_conversion_factor: float) -> float {
    return nominal_value / ppp_conversion_factor;
};

~~ Misery index — simple sum of inflation and unemployment rates, a rough measure of economic hardship.
~~ inflation_rate and unemployment_rate as percentages.
function misery_index(inflation_rate: float, unemployment_rate_val: float) -> float {
    return inflation_rate + unemployment_rate_val;
};