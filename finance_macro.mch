from "mocha-finance" import *;

function run(didLoad) -> null {
    print("inflation_rate(200, 206)               = ", inflation_rate(200.0, 206.0), "   expect 0.03", newLine=true);
    print("price_index(1050, 1000)                = ", price_index(1050.0, 1000.0), "   expect 105", newLine=true);
    print("gdp_deflator(1100, 1000)               = ", gdp_deflator(1100.0, 1000.0), "   expect 110", newLine=true);
    print("real_gdp_from_deflator(1100, 110)      = ", real_gdp_from_deflator(1100.0, 110.0), "   expect 1000", newLine=true);
    print("gdp_growth_rate(1000, 1030)            = ", gdp_growth_rate(1000.0, 1030.0), "   expect 0.03", newLine=true);
    print("annualize_growth_rate(1% quarterly)    = ", annualize_growth_rate(0.01, 4), "   expect 0.040604", newLine=true);

    var falling: float[] = [100.0, 98.0, 96.0, 97.0];
    var wobbly: float[] = [100.0, 98.0, 99.0, 97.0];
    var rec1: int = 0;
    var rec2: int = 0;
    if (is_technical_recession(falling)) { rec1 = 1; };
    if (is_technical_recession(wobbly)) { rec2 = 1; };
    print("is_technical_recession, two falls      = ", rec1, "   expect 1", newLine=true);
    print("is_technical_recession, no two in a row= ", rec2, "   expect 0", newLine=true);

    print("okun_output_gap(6%, 5%, 2)             = ", okun_output_gap(0.06, 0.05, 2.0), "   expect -0.02", newLine=true);
    print("taylor_rule_rate(4%,2%,-1%,2%,.5,.5)   = ", taylor_rule_rate(0.04, 0.02, -0.01, 0.02, 0.5, 0.5), "   expect 0.065", newLine=true);
    print("money_multiplier(0.1)                  = ", money_multiplier(0.1), "   expect 10", newLine=true);
    print("spending_multiplier(0.8, 0.25)         = ", spending_multiplier(0.8, 0.25), "   expect 2.5", newLine=true);
    print("velocity_of_money(20000, 4000)         = ", velocity_of_money(20000.0, 4000.0), "   expect 5", newLine=true);
    print("quantity_theory_inflation(5%,0,3%)     = ", quantity_theory_inflation(0.05, 0.0, 0.03), "   expect 0.019417", newLine=true);
    print("ppp_exchange_rate(300, 4)              = ", ppp_exchange_rate(300.0, 4.0), "   expect 75", newLine=true);

    print("debt_to_gdp(600, 1000)                 = ", debt_to_gdp(600.0, 1000.0), "   expect 0.6", newLine=true);
    print("next_debt_ratio(0.6, 4%, 3%, 0)        = ", next_debt_ratio(0.6, 0.04, 0.03, 0.0), "   expect 0.605825", newLine=true);
    print("projected_debt_ratio, 2 years          = ", projected_debt_ratio(0.6, 0.04, 0.03, 0.0, 2), "   expect 0.611707", newLine=true);
    print("projected_debt_ratio, 0 years          = ", projected_debt_ratio(0.6, 0.04, 0.03, 0.0, 0), "   expect 0.6", newLine=true);
    print("stabilizing_primary_balance            = ", stabilizing_primary_balance(0.6, 0.04, 0.03), "   expect 0.005825", newLine=true);
    print("next_debt_ratio with that balance      = ", next_debt_ratio(0.6, 0.04, 0.03, 0.0058252427), "   expect 0.6", newLine=true);
};