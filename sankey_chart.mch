from "mocha-ink" import *;

function main(didLoad) -> null {

    // ============================================================
    // TEST 1 — simple 2-column flow
    // ============================================================

    var s1: SankeyChart = sankey();
    s1.title("Simple Flow");
    s1.flow("A", "X", 10.0);
    s1.flow("B", "X", 5.0);
    s1.flow("B", "Y", 8.0);
    s1.flow("C", "Y", 3.0);
    s1.save("sk_basic.svg");

    // ============================================================
    // TEST 2 — 3-column chain
    // ============================================================

    var s2: SankeyChart = sankey();
    s2.title("3 Column Chain");
    s2.flow("Source", "Mid1", 20.0);
    s2.flow("Source", "Mid2", 15.0);
    s2.flow("Mid1", "Sink", 20.0);
    s2.flow("Mid2", "Sink", 15.0);
    s2.save("sk_chain.svg");

    // ============================================================
    // TEST 3 — energy flow (realistic data)
    // ============================================================

    var s3: SankeyChart = sankey();
    s3.title("Energy Flow");
    s3.flow("Coal", "Electricity", 30.0);
    s3.flow("Gas", "Electricity", 20.0);
    s3.flow("Solar", "Electricity", 10.0);
    s3.flow("Electricity", "Industry", 25.0);
    s3.flow("Electricity", "Homes", 20.0);
    s3.flow("Electricity", "Loss", 15.0);
    s3.save("sk_energy.svg");

    // ============================================================
    // TEST 4 — custom node colors
    // ============================================================

    var s4: SankeyChart = sankey();
    s4.title("Custom Colors");
    s4.flow("Revenue", "Costs", 40.0);
    s4.flow("Revenue", "Profit", 60.0);
    s4.flow("Costs", "Salaries", 25.0);
    s4.flow("Costs", "Ops", 15.0);
    s4.flow("Profit", "Reinvest", 35.0);
    s4.flow("Profit", "Dividends", 25.0);
    s4.nodecolor("Revenue", "steelblue");
    s4.nodecolor("Profit", "seagreen");
    s4.nodecolor("Costs", "crimson");
    s4.save("sk_colors.svg");

    // ============================================================
    // TEST 5 — unequal flows (tests ribbon width scaling)
    // ============================================================

    var s5: SankeyChart = sankey();
    s5.title("Unequal Flows");
    s5.flow("Big", "Out1", 80.0);
    s5.flow("Big", "Out2", 15.0);
    s5.flow("Big", "Out3", 5.0);
    s5.save("sk_unequal.svg");

};