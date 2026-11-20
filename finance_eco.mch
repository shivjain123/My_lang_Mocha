from "mocha-finance" import *;

function run(didLoad) -> null {
    print("carbon_cost(1000, 50)                  = ", carbon_cost(1000.0, 50.0), "   expect 50000", newLine=true);
    print("carbon_intensity(500, 2000)            = ", carbon_intensity(500.0, 2000.0), "   expect 0.25", newLine=true);
    print("carbon_adjusted_profit(100000,1000,50) = ", carbon_adjusted_profit(100000.0, 1000.0, 50.0), "   expect 50000", newLine=true);
    print("breakeven_carbon_price(100000, 1000)   = ", breakeven_carbon_price(100000.0, 1000.0), "   expect 100", newLine=true);
    print("cap_and_trade_cost, 200 over cap       = ", cap_and_trade_cost(1000.0, 800.0, 50.0), "   expect 10000", newLine=true);
    print("cap_and_trade_cost, 300 surplus        = ", cap_and_trade_cost(700.0, 1000.0, 50.0), "   expect -15000", newLine=true);
    print("emissions_after_years(1000, 5%, 10)    = ", emissions_after_years(1000.0, 0.05, 10.0), "   expect 598.737", newLine=true);
    print("years_to_cut_emissions(5%, halve)      = ", years_to_cut_emissions(0.05, 0.5), "   expect 13.5134", newLine=true);
    print("carbon_budget_years(400, 40)           = ", carbon_budget_years(400.0, 40.0), "   expect 10", newLine=true);
    print("ramsey_discount_rate(1%, 2, 2%)        = ", ramsey_discount_rate(0.01, 2.0, 0.02), "   expect 0.05", newLine=true);

    var damages: float[] = [100.0, 100.0, 100.0];
    print("climate_damage_present_value(5%)       = ", climate_damage_present_value(damages, 0.05), "   expect 272.325", newLine=true);

    var costs: float[] = [1000.0, 100.0, 100.0];
    var energy: float[] = [0.0, 500.0, 500.0];
    print("levelized_cost_of_energy(10%)          = ", levelized_cost_of_energy(costs, energy, 0.1), "   expect 1.352381", newLine=true);

    print("green_bond_premium(4.5%, 4.2%)         = ", green_bond_premium(0.045, 0.042), "   expect 0.003", newLine=true);
    print("exceedance_probability(100y, 1 year)   = ", exceedance_probability(100.0, 1.0), "   expect 0.01", newLine=true);
    print("exceedance_probability(100y, 30 years) = ", exceedance_probability(100.0, 30.0), "   expect 0.2603", newLine=true);
    print("expected_annual_loss(1%, 5,000,000)    = ", expected_annual_loss(0.01, 5000000.0), "   expect 50000", newLine=true);
    print("loaded_insurance_premium(50000, 30%)   = ", loaded_insurance_premium(50000.0, 0.3), "   expect 65000", newLine=true);
};