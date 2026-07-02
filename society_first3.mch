from "mocha-society" import *;

function main(didLoad) -> null {

    // ----- Section 1: Demography -----

    // population_growth_rate(1000000.0, 1050000.0, 5.0) ~ 0.00975803
    var s1_1: float = population_growth_rate(1000000.0, 1050000.0, 5.0);
    var diff_s1_1: float = s1_1 - 0.00975803;
    var abs_s1_1: float = 0.0;
    if (diff_s1_1 < 0.0) { abs_s1_1 = -diff_s1_1; } else { abs_s1_1 = diff_s1_1; };
    if (abs_s1_1 < 0.00001) {
        print("PASS: population_growth_rate ~ 0.00975803", newLine=true);
    } else {
        print("FAIL: population_growth_rate", newLine=true);
    };
    print(s1_1, newLine=true);

    // population_doubling_time(0.00975803) ~ 71.033495
    var s1_2: float = population_doubling_time(0.00975803);
    var diff_s1_2: float = s1_2 - 71.033495;
    var abs_s1_2: float = 0.0;
    if (diff_s1_2 < 0.0) { abs_s1_2 = -diff_s1_2; } else { abs_s1_2 = diff_s1_2; };
    if (abs_s1_2 < 0.01) {
        print("PASS: population_doubling_time ~ 71.033495", newLine=true);
    } else {
        print("FAIL: population_doubling_time", newLine=true);
    };
    print(s1_2, newLine=true);

    // crude_birth_rate(15000.0, 1000000.0) = 15.0
    var s1_3: float = crude_birth_rate(15000.0, 1000000.0);
    if (s1_3 == 15.0) {
        print("PASS: crude_birth_rate == 15.0", newLine=true);
    } else {
        print("FAIL: crude_birth_rate", newLine=true);
    };
    print(s1_3, newLine=true);

    // crude_death_rate(7000.0, 1000000.0) = 7.0
    var s1_4: float = crude_death_rate(7000.0, 1000000.0);
    if (s1_4 == 7.0) {
        print("PASS: crude_death_rate == 7.0", newLine=true);
    } else {
        print("FAIL: crude_death_rate", newLine=true);
    };
    print(s1_4, newLine=true);

    // natural_increase_rate(15.0, 7.0) = 0.8
    var s1_5: float = natural_increase_rate(15.0, 7.0);
    if (s1_5 == 0.8) {
        print("PASS: natural_increase_rate == 0.8", newLine=true);
    } else {
        print("FAIL: natural_increase_rate", newLine=true);
    };
    print(s1_5, newLine=true);

    // net_migration_rate(3000.0, 1000.0, 1000000.0) = 2.0
    var s1_6: float = net_migration_rate(3000.0, 1000.0, 1000000.0);
    if (s1_6 == 2.0) {
        print("PASS: net_migration_rate == 2.0", newLine=true);
    } else {
        print("FAIL: net_migration_rate", newLine=true);
    };
    print(s1_6, newLine=true);

    // dependency_ratio(250000.0, 150000.0, 600000.0) ~ 66.666667
    var s1_7: float = dependency_ratio(250000.0, 150000.0, 600000.0);
    var diff_s1_7: float = s1_7 - 66.666667;
    var abs_s1_7: float = 0.0;
    if (diff_s1_7 < 0.0) { abs_s1_7 = -diff_s1_7; } else { abs_s1_7 = diff_s1_7; };
    if (abs_s1_7 < 0.001) {
        print("PASS: dependency_ratio ~ 66.666667", newLine=true);
    } else {
        print("FAIL: dependency_ratio", newLine=true);
    };
    print(s1_7, newLine=true);

    // child_dependency_ratio(250000.0, 600000.0) ~ 41.666667
    var s1_8: float = child_dependency_ratio(250000.0, 600000.0);
    var diff_s1_8: float = s1_8 - 41.666667;
    var abs_s1_8: float = 0.0;
    if (diff_s1_8 < 0.0) { abs_s1_8 = -diff_s1_8; } else { abs_s1_8 = diff_s1_8; };
    if (abs_s1_8 < 0.001) {
        print("PASS: child_dependency_ratio ~ 41.666667", newLine=true);
    } else {
        print("FAIL: child_dependency_ratio", newLine=true);
    };
    print(s1_8, newLine=true);

    // old_age_dependency_ratio(150000.0, 600000.0) = 25.0
    var s1_9: float = old_age_dependency_ratio(150000.0, 600000.0);
    if (s1_9 == 25.0) {
        print("PASS: old_age_dependency_ratio == 25.0", newLine=true);
    } else {
        print("FAIL: old_age_dependency_ratio", newLine=true);
    };
    print(s1_9, newLine=true);

    // population_projection(1000000.0, 0.0097, 10.0) ~ 1101860.373621
    var s1_10: float = population_projection(1000000.0, 0.0097, 10.0);
    var diff_s1_10: float = s1_10 - 1101860.373621;
    var abs_s1_10: float = 0.0;
    if (diff_s1_10 < 0.0) { abs_s1_10 = -diff_s1_10; } else { abs_s1_10 = diff_s1_10; };
    if (abs_s1_10 < 0.5) {
        print("PASS: population_projection ~ 1101860.373621", newLine=true);
    } else {
        print("FAIL: population_projection", newLine=true);
    };
    print(s1_10, newLine=true);

    // ----- Section 2: Social Stratification & Inequality -----

    var incomes: float[] = alloc float[6];
    incomes[0] = 10000.0;
    incomes[1] = 15000.0;
    incomes[2] = 20000.0;
    incomes[3] = 30000.0;
    incomes[4] = 45000.0;
    incomes[5] = 80000.0;

    // mean_income(incomes) ~ 33333.3333
    var s2_1: float = mean_income(incomes);
    var diff_s2_1: float = s2_1 - 33333.3333;
    var abs_s2_1: float = 0.0;
    if (diff_s2_1 < 0.0) { abs_s2_1 = -diff_s2_1; } else { abs_s2_1 = diff_s2_1; };
    if (abs_s2_1 < 0.1) {
        print("PASS: mean_income ~ 33333.3333", newLine=true);
    } else {
        print("FAIL: mean_income", newLine=true);
    };
    print(s2_1, newLine=true);

    // gini_coefficient(incomes) = 0.375
    var s2_2: float = gini_coefficient(incomes);
    var diff_s2_2: float = s2_2 - 0.375;
    var abs_s2_2: float = 0.0;
    if (diff_s2_2 < 0.0) { abs_s2_2 = -diff_s2_2; } else { abs_s2_2 = diff_s2_2; };
    if (abs_s2_2 < 0.001) {
        print("PASS: gini_coefficient ~ 0.375", newLine=true);
    } else {
        print("FAIL: gini_coefficient", newLine=true);
    };
    print(s2_2, newLine=true);

    // theil_index(incomes) ~ 0.230738
    var s2_3: float = theil_index(incomes);
    var diff_s2_3: float = s2_3 - 0.230738;
    var abs_s2_3: float = 0.0;
    if (diff_s2_3 < 0.0) { abs_s2_3 = -diff_s2_3; } else { abs_s2_3 = diff_s2_3; };
    if (abs_s2_3 < 0.001) {
        print("PASS: theil_index ~ 0.230738", newLine=true);
    } else {
        print("FAIL: theil_index", newLine=true);
    };
    print(s2_3, newLine=true);

    // atkinson_index(incomes, 0.5) ~ 0.112350
    var s2_4: float = atkinson_index(incomes, 0.5);
    var diff_s2_4: float = s2_4 - 0.112350;
    var abs_s2_4: float = 0.0;
    if (diff_s2_4 < 0.0) { abs_s2_4 = -diff_s2_4; } else { abs_s2_4 = diff_s2_4; };
    if (abs_s2_4 < 0.001) {
        print("PASS: atkinson_index ~ 0.112350", newLine=true);
    } else {
        print("FAIL: atkinson_index", newLine=true);
    };
    print(s2_4, newLine=true);

    // poverty_headcount_ratio(1200.0, 8000.0) = 15.0
    var s2_5: float = poverty_headcount_ratio(1200.0, 8000.0);
    if (s2_5 == 15.0) {
        print("PASS: poverty_headcount_ratio == 15.0", newLine=true);
    } else {
        print("FAIL: poverty_headcount_ratio", newLine=true);
    };
    print(s2_5, newLine=true);

    // poverty_gap_index(incomes, 18000.0) ~ 0.101852
    var s2_6: float = poverty_gap_index(incomes, 18000.0);
    var diff_s2_6: float = s2_6 - 0.101852;
    var abs_s2_6: float = 0.0;
    if (diff_s2_6 < 0.0) { abs_s2_6 = -diff_s2_6; } else { abs_s2_6 = diff_s2_6; };
    if (abs_s2_6 < 0.001) {
        print("PASS: poverty_gap_index ~ 0.101852", newLine=true);
    } else {
        print("FAIL: poverty_gap_index", newLine=true);
    };
    print(s2_6, newLine=true);

    // palma_ratio(28.0, 12.0) ~ 2.333333
    var s2_7: float = palma_ratio(28.0, 12.0);
    var diff_s2_7: float = s2_7 - 2.333333;
    var abs_s2_7: float = 0.0;
    if (diff_s2_7 < 0.0) { abs_s2_7 = -diff_s2_7; } else { abs_s2_7 = diff_s2_7; };
    if (abs_s2_7 < 0.001) {
        print("PASS: palma_ratio ~ 2.333333", newLine=true);
    } else {
        print("FAIL: palma_ratio", newLine=true);
    };
    print(s2_7, newLine=true);

    // income_share_ratio(42.0, 6.0) = 7.0
    var s2_8: float = income_share_ratio(42.0, 6.0);
    if (s2_8 == 7.0) {
        print("PASS: income_share_ratio == 7.0", newLine=true);
    } else {
        print("FAIL: income_share_ratio", newLine=true);
    };
    print(s2_8, newLine=true);

    // relative_poverty_line(27500.0, 0.6) = 16500.0
    var s2_9: float = relative_poverty_line(27500.0, 0.6);
    if (s2_9 == 16500.0) {
        print("PASS: relative_poverty_line == 16500.0", newLine=true);
    } else {
        print("FAIL: relative_poverty_line", newLine=true);
    };
    print(s2_9, newLine=true);

    // ----- Section 3: Political Science / Electoral Systems -----

    // voter_turnout_rate(6500000.0, 10000000.0) = 65.0
    var s3_1: float = voter_turnout_rate(6500000.0, 10000000.0);
    if (s3_1 == 65.0) {
        print("PASS: voter_turnout_rate == 65.0", newLine=true);
    } else {
        print("FAIL: voter_turnout_rate", newLine=true);
    };
    print(s3_1, newLine=true);

    var votes: float[] = alloc float[4];
    votes[0] = 100000.0;
    votes[1] = 80000.0;
    votes[2] = 30000.0;
    votes[3] = 20000.0;

    // dhondt_apportionment(votes, 10) -> [5, 4, 1, 0]
    var s3_2: int[] = dhondt_apportionment(votes, 10);
    if (s3_2[0] == 5 && s3_2[1] == 4 && s3_2[2] == 1 && s3_2[3] == 0) {
        print("PASS: dhondt_apportionment == [5,4,1,0]", newLine=true);
    } else {
        print("FAIL: dhondt_apportionment", newLine=true);
    };
    print(s3_2[0], newLine=true);
    print(s3_2[1], newLine=true);
    print(s3_2[2], newLine=true);
    print(s3_2[3], newLine=true);

    // sainte_lague_apportionment(votes, 10) -> [4, 4, 1, 1]
    var s3_3: int[] = sainte_lague_apportionment(votes, 10);
    if (s3_3[0] == 4 && s3_3[1] == 4 && s3_3[2] == 1 && s3_3[3] == 1) {
        print("PASS: sainte_lague_apportionment == [4,4,1,1]", newLine=true);
    } else {
        print("FAIL: sainte_lague_apportionment", newLine=true);
    };
    print(s3_3[0], newLine=true);
    print(s3_3[1], newLine=true);
    print(s3_3[2], newLine=true);
    print(s3_3[3], newLine=true);

    var shares: float[] = alloc float[4];
    shares[0] = 0.45;
    shares[1] = 0.30;
    shares[2] = 0.15;
    shares[3] = 0.10;

    // effective_number_of_parties(shares) ~ 3.076923
    var s3_4: float = effective_number_of_parties(shares);
    var diff_s3_4: float = s3_4 - 3.076923;
    var abs_s3_4: float = 0.0;
    if (diff_s3_4 < 0.0) { abs_s3_4 = -diff_s3_4; } else { abs_s3_4 = diff_s3_4; };
    if (abs_s3_4 < 0.001) {
        print("PASS: effective_number_of_parties ~ 3.076923", newLine=true);
    } else {
        print("FAIL: effective_number_of_parties", newLine=true);
    };
    print(s3_4, newLine=true);

    var vote_shares: float[] = alloc float[4];
    vote_shares[0] = 45.0;
    vote_shares[1] = 30.0;
    vote_shares[2] = 15.0;
    vote_shares[3] = 10.0;
    var seat_shares: float[] = alloc float[4];
    seat_shares[0] = 50.0;
    seat_shares[1] = 30.0;
    seat_shares[2] = 10.0;
    seat_shares[3] = 10.0;

    // gallagher_index(vote_shares, seat_shares) = 5.0
    var s3_5: float = gallagher_index(vote_shares, seat_shares);
    var diff_s3_5: float = s3_5 - 5.0;
    var abs_s3_5: float = 0.0;
    if (diff_s3_5 < 0.0) { abs_s3_5 = -diff_s3_5; } else { abs_s3_5 = diff_s3_5; };
    if (abs_s3_5 < 0.001) {
        print("PASS: gallagher_index ~ 5.0", newLine=true);
    } else {
        print("FAIL: gallagher_index", newLine=true);
    };
    print(s3_5, newLine=true);

    // seat_vote_deviation(45.0, 50.0) = -5.0
    var s3_6: float = seat_vote_deviation(45.0, 50.0);
    if (s3_6 == -5.0) {
        print("PASS: seat_vote_deviation == -5.0", newLine=true);
    } else {
        print("FAIL: seat_vote_deviation", newLine=true);
    };
    print(s3_6, newLine=true);

    // banzhaf_power_index_3player(4.0, 3.0, 2.0, 6.0) -> (0.6, 0.2, 0.2)
    var s3_7: (float, 3) = banzhaf_power_index_3player(4.0, 3.0, 2.0, 6.0);
    var diff_s3_7a: float = s3_7#0 - 0.6;
    var abs_s3_7a: float = 0.0;
    if (diff_s3_7a < 0.0) { abs_s3_7a = -diff_s3_7a; } else { abs_s3_7a = diff_s3_7a; };
    var diff_s3_7b: float = s3_7#1 - 0.2;
    var abs_s3_7b: float = 0.0;
    if (diff_s3_7b < 0.0) { abs_s3_7b = -diff_s3_7b; } else { abs_s3_7b = diff_s3_7b; };
    var diff_s3_7c: float = s3_7#2 - 0.2;
    var abs_s3_7c: float = 0.0;
    if (diff_s3_7c < 0.0) { abs_s3_7c = -diff_s3_7c; } else { abs_s3_7c = diff_s3_7c; };
    if (abs_s3_7a < 0.001 && abs_s3_7b < 0.001 && abs_s3_7c < 0.001) {
        print("PASS: banzhaf_power_index_3player ~ (0.6, 0.2, 0.2)", newLine=true);
    } else {
        print("FAIL: banzhaf_power_index_3player", newLine=true);
    };
    print(s3_7#0, newLine=true);
    print(s3_7#1, newLine=true);
    print(s3_7#2, newLine=true);

    // shapley_shubik_power_index_3player(4.0, 3.0, 2.0, 6.0) -> (0.666667, 0.166667, 0.166667)
    var s3_8: (float, 3) = shapley_shubik_power_index_3player(4.0, 3.0, 2.0, 6.0);
    var diff_s3_8a: float = s3_8#0 - 0.666667;
    var abs_s3_8a: float = 0.0;
    if (diff_s3_8a < 0.0) { abs_s3_8a = -diff_s3_8a; } else { abs_s3_8a = diff_s3_8a; };
    var diff_s3_8b: float = s3_8#1 - 0.166667;
    var abs_s3_8b: float = 0.0;
    if (diff_s3_8b < 0.0) { abs_s3_8b = -diff_s3_8b; } else { abs_s3_8b = diff_s3_8b; };
    var diff_s3_8c: float = s3_8#2 - 0.166667;
    var abs_s3_8c: float = 0.0;
    if (diff_s3_8c < 0.0) { abs_s3_8c = -diff_s3_8c; } else { abs_s3_8c = diff_s3_8c; };
    if (abs_s3_8a < 0.001 && abs_s3_8b < 0.001 && abs_s3_8c < 0.001) {
        print("PASS: shapley_shubik_power_index_3player ~ (0.666667, 0.166667, 0.166667)", newLine=true);
    } else {
        print("FAIL: shapley_shubik_power_index_3player", newLine=true);
    };
    print(s3_8#0, newLine=true);
    print(s3_8#1, newLine=true);
    print(s3_8#2, newLine=true);

    print("mocha-society sections 1-3 tests done.", newLine=true);
};