from "mocha-society" import *;

function main(didLoad) -> null {

    // ----- Section 4: Social Network Analysis -----

    var adj: int[][] = alloc int[5][5];
    var zi: int = 0;
    while (zi < 5) {
        var zj: int = 0;
        while (zj < 5) {
            adj[zi][zj] = 0;
            zj++;
        };
        zi++;
    };
    adj[0][1] = 1; adj[1][0] = 1;
    adj[1][2] = 1; adj[2][1] = 1;
    adj[2][3] = 1; adj[3][2] = 1;
    adj[3][4] = 1; adj[4][3] = 1;
    adj[1][3] = 1; adj[3][1] = 1;

    // node_degree(adj, 1) = 3
    var s4_1: int = node_degree(adj, 1);
    if (s4_1 == 3) {
        print("PASS: node_degree(1) == 3", newLine=true);
    } else {
        print("FAIL: node_degree", newLine=true);
    };
    print(s4_1, newLine=true);

    // degree_centrality(adj, 1) = 0.75
    var s4_2: float = degree_centrality(adj, 1);
    if (s4_2 == 0.75) {
        print("PASS: degree_centrality(1) == 0.75", newLine=true);
    } else {
        print("FAIL: degree_centrality(1)", newLine=true);
    };
    print(s4_2, newLine=true);

    // degree_centrality(adj, 0) = 0.25
    var s4_3: float = degree_centrality(adj, 0);
    if (s4_3 == 0.25) {
        print("PASS: degree_centrality(0) == 0.25", newLine=true);
    } else {
        print("FAIL: degree_centrality(0)", newLine=true);
    };
    print(s4_3, newLine=true);

    // network_density(adj) = 0.5
    var s4_4: float = network_density(adj);
    if (s4_4 == 0.5) {
        print("PASS: network_density == 0.5", newLine=true);
    } else {
        print("FAIL: network_density", newLine=true);
    };
    print(s4_4, newLine=true);

    // average_degree(adj) = 2.0
    var s4_5: float = average_degree(adj);
    if (s4_5 == 2.0) {
        print("PASS: average_degree == 2.0", newLine=true);
    } else {
        print("FAIL: average_degree", newLine=true);
    };
    print(s4_5, newLine=true);

    // clustering_coefficient(adj, 1) ~ 0.333333
    var s4_6: float = clustering_coefficient(adj, 1);
    var diff_s4_6: float = s4_6 - 0.333333;
    var abs_s4_6: float = 0.0;
    if (diff_s4_6 < 0.0) { abs_s4_6 = -diff_s4_6; } else { abs_s4_6 = diff_s4_6; };
    if (abs_s4_6 < 0.001) {
        print("PASS: clustering_coefficient(1) ~ 0.333333", newLine=true);
    } else {
        print("FAIL: clustering_coefficient(1)", newLine=true);
    };
    print(s4_6, newLine=true);

    // clustering_coefficient(adj, 3) ~ 0.333333
    var s4_7: float = clustering_coefficient(adj, 3);
    var diff_s4_7: float = s4_7 - 0.333333;
    var abs_s4_7: float = 0.0;
    if (diff_s4_7 < 0.0) { abs_s4_7 = -diff_s4_7; } else { abs_s4_7 = diff_s4_7; };
    if (abs_s4_7 < 0.001) {
        print("PASS: clustering_coefficient(3) ~ 0.333333", newLine=true);
    } else {
        print("FAIL: clustering_coefficient(3)", newLine=true);
    };
    print(s4_7, newLine=true);

    // clustering_coefficient(adj, 0) = 0.0
    var s4_8: float = clustering_coefficient(adj, 0);
    if (s4_8 == 0.0) {
        print("PASS: clustering_coefficient(0) == 0.0", newLine=true);
    } else {
        print("FAIL: clustering_coefficient(0)", newLine=true);
    };
    print(s4_8, newLine=true);

    // shortest_path_length(adj, 0, 4) = 3
    var s4_9: int = shortest_path_length(adj, 0, 4);
    if (s4_9 == 3) {
        print("PASS: shortest_path_length(0,4) == 3", newLine=true);
    } else {
        print("FAIL: shortest_path_length", newLine=true);
    };
    print(s4_9, newLine=true);

    // closeness_centrality(adj, 1) = 0.8
    var s4_10: float = closeness_centrality(adj, 1);
    if (s4_10 == 0.8) {
        print("PASS: closeness_centrality(1) == 0.8", newLine=true);
    } else {
        print("FAIL: closeness_centrality(1)", newLine=true);
    };
    print(s4_10, newLine=true);

    // closeness_centrality(adj, 0) = 0.5
    var s4_11: float = closeness_centrality(adj, 0);
    if (s4_11 == 0.5) {
        print("PASS: closeness_centrality(0) == 0.5", newLine=true);
    } else {
        print("FAIL: closeness_centrality(0)", newLine=true);
    };
    print(s4_11, newLine=true);

    // betweenness_centrality(adj, 1) = 3.0
    var s4_12: float = betweenness_centrality(adj, 1);
    if (s4_12 == 3.0) {
        print("PASS: betweenness_centrality(1) == 3.0", newLine=true);
    } else {
        print("FAIL: betweenness_centrality(1)", newLine=true);
    };
    print(s4_12, newLine=true);

    // betweenness_centrality(adj, 3) = 3.0
    var s4_13: float = betweenness_centrality(adj, 3);
    if (s4_13 == 3.0) {
        print("PASS: betweenness_centrality(3) == 3.0", newLine=true);
    } else {
        print("FAIL: betweenness_centrality(3)", newLine=true);
    };
    print(s4_13, newLine=true);

    // betweenness_centrality(adj, 2) = 0.0
    var s4_14: float = betweenness_centrality(adj, 2);
    if (s4_14 == 0.0) {
        print("PASS: betweenness_centrality(2) == 0.0", newLine=true);
    } else {
        print("FAIL: betweenness_centrality(2)", newLine=true);
    };
    print(s4_14, newLine=true);

    var attributes: int[] = alloc int[5];
    attributes[0] = 0; attributes[1] = 0; attributes[2] = 1; attributes[3] = 1; attributes[4] = 0;

    // homophily_index(adj, attributes) = 0.4
    var s4_15: float = homophily_index(adj, attributes);
    if (s4_15 == 0.4) {
        print("PASS: homophily_index == 0.4", newLine=true);
    } else {
        print("FAIL: homophily_index", newLine=true);
    };
    print(s4_15, newLine=true);

    // ----- Section 5: Anthropology / Kinship & Cultural Diversity -----

    // coefficient_of_relationship(2, 2) [full siblings] = 0.5
    var s5_1: float = coefficient_of_relationship(2, 2);
    if (s5_1 == 0.5) {
        print("PASS: coefficient_of_relationship(siblings) == 0.5", newLine=true);
    } else {
        print("FAIL: coefficient_of_relationship(siblings)", newLine=true);
    };
    print(s5_1, newLine=true);

    // coefficient_of_relationship(2, 4) [first cousins] = 0.125
    var s5_2: float = coefficient_of_relationship(2, 4);
    if (s5_2 == 0.125) {
        print("PASS: coefficient_of_relationship(cousins) == 0.125", newLine=true);
    } else {
        print("FAIL: coefficient_of_relationship(cousins)", newLine=true);
    };
    print(s5_2, newLine=true);

    // coefficient_of_relationship(1, 1) [parent-offspring] = 0.5
    var s5_3: float = coefficient_of_relationship(1, 1);
    if (s5_3 == 0.5) {
        print("PASS: coefficient_of_relationship(parent-offspring) == 0.5", newLine=true);
    } else {
        print("FAIL: coefficient_of_relationship(parent-offspring)", newLine=true);
    };
    print(s5_3, newLine=true);

    // inbreeding_coefficient(0.5) = 0.25
    var s5_4: float = inbreeding_coefficient(0.5);
    if (s5_4 == 0.25) {
        print("PASS: inbreeding_coefficient == 0.25", newLine=true);
    } else {
        print("FAIL: inbreeding_coefficient", newLine=true);
    };
    print(s5_4, newLine=true);

    var lang_counts: float[] = alloc float[4];
    lang_counts[0] = 4500000.0;
    lang_counts[1] = 3000000.0;
    lang_counts[2] = 1500000.0;
    lang_counts[3] = 1000000.0;

    // simpsons_diversity_index(lang_counts) = 0.675
    var s5_5: float = simpsons_diversity_index(lang_counts);
    var diff_s5_5: float = s5_5 - 0.675;
    var abs_s5_5: float = 0.0;
    if (diff_s5_5 < 0.0) { abs_s5_5 = -diff_s5_5; } else { abs_s5_5 = diff_s5_5; };
    if (abs_s5_5 < 0.001) {
        print("PASS: simpsons_diversity_index ~ 0.675", newLine=true);
    } else {
        print("FAIL: simpsons_diversity_index", newLine=true);
    };
    print(s5_5, newLine=true);

    // simpsons_reciprocal_index(lang_counts) ~ 3.076923
    var s5_6: float = simpsons_reciprocal_index(lang_counts);
    var diff_s5_6: float = s5_6 - 3.076923;
    var abs_s5_6: float = 0.0;
    if (diff_s5_6 < 0.0) { abs_s5_6 = -diff_s5_6; } else { abs_s5_6 = diff_s5_6; };
    if (abs_s5_6 < 0.001) {
        print("PASS: simpsons_reciprocal_index ~ 3.076923", newLine=true);
    } else {
        print("FAIL: simpsons_reciprocal_index", newLine=true);
    };
    print(s5_6, newLine=true);

    // shannon_diversity_index(lang_counts) ~ 1.235347
    var s5_7: float = shannon_diversity_index(lang_counts);
    var diff_s5_7: float = s5_7 - 1.235347;
    var abs_s5_7: float = 0.0;
    if (diff_s5_7 < 0.0) { abs_s5_7 = -diff_s5_7; } else { abs_s5_7 = diff_s5_7; };
    if (abs_s5_7 < 0.001) {
        print("PASS: shannon_diversity_index ~ 1.235347", newLine=true);
    } else {
        print("FAIL: shannon_diversity_index", newLine=true);
    };
    print(s5_7, newLine=true);

    // shannon_evenness_index(lang_counts) ~ 0.891114
    var s5_8: float = shannon_evenness_index(lang_counts);
    var diff_s5_8: float = s5_8 - 0.891114;
    var abs_s5_8: float = 0.0;
    if (diff_s5_8 < 0.0) { abs_s5_8 = -diff_s5_8; } else { abs_s5_8 = diff_s5_8; };
    if (abs_s5_8 < 0.001) {
        print("PASS: shannon_evenness_index ~ 0.891114", newLine=true);
    } else {
        print("FAIL: shannon_evenness_index", newLine=true);
    };
    print(s5_8, newLine=true);

    // cultural_distance_index(3, 12) = 0.25
    var s5_9: float = cultural_distance_index(3, 12);
    if (s5_9 == 0.25) {
        print("PASS: cultural_distance_index == 0.25", newLine=true);
    } else {
        print("FAIL: cultural_distance_index", newLine=true);
    };
    print(s5_9, newLine=true);

    // cultural_similarity_index(3, 12) = 0.75
    var s5_10: float = cultural_similarity_index(3, 12);
    if (s5_10 == 0.75) {
        print("PASS: cultural_similarity_index == 0.75", newLine=true);
    } else {
        print("FAIL: cultural_similarity_index", newLine=true);
    };
    print(s5_10, newLine=true);

    // ----- Section 6: Research Methods & Measurement -----

    var item_vars: float[] = alloc float[4];
    item_vars[0] = 2.5;
    item_vars[1] = 3.0;
    item_vars[2] = 2.8;
    item_vars[3] = 3.2;

    // cronbachs_alpha(item_vars, 32.0) ~ 0.854167
    var s6_1: float = cronbachs_alpha(item_vars, 32.0);
    var diff_s6_1: float = s6_1 - 0.854167;
    var abs_s6_1: float = 0.0;
    if (diff_s6_1 < 0.0) { abs_s6_1 = -diff_s6_1; } else { abs_s6_1 = diff_s6_1; };
    if (abs_s6_1 < 0.001) {
        print("PASS: cronbachs_alpha ~ 0.854167", newLine=true);
    } else {
        print("FAIL: cronbachs_alpha", newLine=true);
    };
    print(s6_1, newLine=true);

    // cohens_kappa(0.85, 0.5) = 0.7
    var s6_2: float = cohens_kappa(0.85, 0.5);
    if (s6_2 == 0.7) {
        print("PASS: cohens_kappa == 0.7", newLine=true);
    } else {
        print("FAIL: cohens_kappa", newLine=true);
    };
    print(s6_2, newLine=true);

    // standard_error_of_proportion(0.6, 400.0) ~ 0.024495
    var s6_3: float = standard_error_of_proportion(0.6, 400.0);
    var diff_s6_3: float = s6_3 - 0.024495;
    var abs_s6_3: float = 0.0;
    if (diff_s6_3 < 0.0) { abs_s6_3 = -diff_s6_3; } else { abs_s6_3 = diff_s6_3; };
    if (abs_s6_3 < 0.0001) {
        print("PASS: standard_error_of_proportion ~ 0.024495", newLine=true);
    } else {
        print("FAIL: standard_error_of_proportion", newLine=true);
    };
    print(s6_3, newLine=true);

    // margin_of_error_proportion(0.6, 400.0, 1.96) ~ 0.048010
    var s6_4: float = margin_of_error_proportion(0.6, 400.0, 1.96);
    var diff_s6_4: float = s6_4 - 0.048010;
    var abs_s6_4: float = 0.0;
    if (diff_s6_4 < 0.0) { abs_s6_4 = -diff_s6_4; } else { abs_s6_4 = diff_s6_4; };
    if (abs_s6_4 < 0.0001) {
        print("PASS: margin_of_error_proportion ~ 0.048010", newLine=true);
    } else {
        print("FAIL: margin_of_error_proportion", newLine=true);
    };
    print(s6_4, newLine=true);

    // sample_size_for_proportion(1.96, 0.5, 0.03) ~ 1067.111111
    var s6_5: float = sample_size_for_proportion(1.96, 0.5, 0.03);
    var diff_s6_5: float = s6_5 - 1067.111111;
    var abs_s6_5: float = 0.0;
    if (diff_s6_5 < 0.0) { abs_s6_5 = -diff_s6_5; } else { abs_s6_5 = diff_s6_5; };
    if (abs_s6_5 < 0.01) {
        print("PASS: sample_size_for_proportion ~ 1067.111111", newLine=true);
    } else {
        print("FAIL: sample_size_for_proportion", newLine=true);
    };
    print(s6_5, newLine=true);

    // confidence_interval_proportion(0.6, 400.0, 1.96) -> (0.551990, 0.648010)
    var s6_6: (float, 2) = confidence_interval_proportion(0.6, 400.0, 1.96);
    var diff_s6_6a: float = s6_6#0 - 0.551990;
    var abs_s6_6a: float = 0.0;
    if (diff_s6_6a < 0.0) { abs_s6_6a = -diff_s6_6a; } else { abs_s6_6a = diff_s6_6a; };
    var diff_s6_6b: float = s6_6#1 - 0.648010;
    var abs_s6_6b: float = 0.0;
    if (diff_s6_6b < 0.0) { abs_s6_6b = -diff_s6_6b; } else { abs_s6_6b = diff_s6_6b; };
    if (abs_s6_6a < 0.0001 && abs_s6_6b < 0.0001) {
        print("PASS: confidence_interval_proportion ~ (0.551990, 0.648010)", newLine=true);
    } else {
        print("FAIL: confidence_interval_proportion", newLine=true);
    };
    print(s6_6#0, newLine=true);
    print(s6_6#1, newLine=true);

    // standard_error_of_mean(15.0, 100.0) = 1.5
    var s6_7: float = standard_error_of_mean(15.0, 100.0);
    if (s6_7 == 1.5) {
        print("PASS: standard_error_of_mean == 1.5", newLine=true);
    } else {
        print("FAIL: standard_error_of_mean", newLine=true);
    };
    print(s6_7, newLine=true);

    // pooled_standard_deviation(10.0, 50.0, 12.0, 60.0) ~ 11.137192
    var s6_8: float = pooled_standard_deviation(10.0, 50.0, 12.0, 60.0);
    var diff_s6_8: float = s6_8 - 11.137192;
    var abs_s6_8: float = 0.0;
    if (diff_s6_8 < 0.0) { abs_s6_8 = -diff_s6_8; } else { abs_s6_8 = diff_s6_8; };
    if (abs_s6_8 < 0.001) {
        print("PASS: pooled_standard_deviation ~ 11.137192", newLine=true);
    } else {
        print("FAIL: pooled_standard_deviation", newLine=true);
    };
    print(s6_8, newLine=true);

    // cohens_d(75.0, 68.0, 11.137192) ~ 0.628525
    var s6_9: float = cohens_d(75.0, 68.0, 11.137192);
    var diff_s6_9: float = s6_9 - 0.628525;
    var abs_s6_9: float = 0.0;
    if (diff_s6_9 < 0.0) { abs_s6_9 = -diff_s6_9; } else { abs_s6_9 = diff_s6_9; };
    if (abs_s6_9 < 0.001) {
        print("PASS: cohens_d ~ 0.628525", newLine=true);
    } else {
        print("FAIL: cohens_d", newLine=true);
    };
    print(s6_9, newLine=true);

    var px: float[] = alloc float[5];
    px[0] = 10.0; px[1] = 20.0; px[2] = 30.0; px[3] = 40.0; px[4] = 50.0;
    var py: float[] = alloc float[5];
    py[0] = 15.0; py[1] = 25.0; py[2] = 35.0; py[3] = 55.0; py[4] = 60.0;

    // pearson_correlation_coefficient(px, py) ~ 0.986394
    var s6_10: float = pearson_correlation_coefficient(px, py);
    var diff_s6_10: float = s6_10 - 0.986394;
    var abs_s6_10: float = 0.0;
    if (diff_s6_10 < 0.0) { abs_s6_10 = -diff_s6_10; } else { abs_s6_10 = diff_s6_10; };
    if (abs_s6_10 < 0.001) {
        print("PASS: pearson_correlation_coefficient ~ 0.986394", newLine=true);
    } else {
        print("FAIL: pearson_correlation_coefficient", newLine=true);
    };
    print(s6_10, newLine=true);

    print("mocha-society sections 4-6 tests done.", newLine=true);
};