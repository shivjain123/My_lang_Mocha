from "mocha-finance" import *;

function run(didLoad) -> null {
    print("black_scholes_call(100,100,5%,20%,1y)  = ", black_scholes_call(100.0, 100.0, 0.05, 0.2, 1.0), "   expect 10.4506", newLine=true);
    print("black_scholes_put                      = ", black_scholes_put(100.0, 100.0, 0.05, 0.2, 1.0), "   expect 5.5735", newLine=true);
    print("put_from_call_parity(10.4506)          = ", put_from_call_parity(10.4506, 100.0, 100.0, 0.05, 1.0), "   expect 5.5735", newLine=true);
    print("option_intrinsic_value, call at 110    = ", option_intrinsic_value(true, 110.0, 100.0), "   expect 10", newLine=true);
    print("option_intrinsic_value, put at 90      = ", option_intrinsic_value(false, 90.0, 100.0), "   expect 10", newLine=true);
    print("option_delta, call                     = ", option_delta(true, 100.0, 100.0, 0.05, 0.2, 1.0), "   expect 0.636831", newLine=true);
    print("option_delta, put                      = ", option_delta(false, 100.0, 100.0, 0.05, 0.2, 1.0), "   expect -0.363169", newLine=true);
    print("option_gamma                           = ", option_gamma(100.0, 100.0, 0.05, 0.2, 1.0), "   expect 0.018762", newLine=true);
    print("option_vega                            = ", option_vega(100.0, 100.0, 0.05, 0.2, 1.0), "   expect 37.524", newLine=true);
    print("option_theta, call                     = ", option_theta(true, 100.0, 100.0, 0.05, 0.2, 1.0), "   expect -6.414", newLine=true);
    print("option_theta, put                      = ", option_theta(false, 100.0, 100.0, 0.05, 0.2, 1.0), "   expect -1.658", newLine=true);
    print("option_rho, call                       = ", option_rho(true, 100.0, 100.0, 0.05, 0.2, 1.0), "   expect 53.2325", newLine=true);
    print("option_rho, put                        = ", option_rho(false, 100.0, 100.0, 0.05, 0.2, 1.0), "   expect -41.8905", newLine=true);
    print("implied_volatility(call at 10.4506)    = ", implied_volatility(true, 10.4506, 100.0, 100.0, 0.05, 1.0), "   expect about 0.2", newLine=true);
    print("binomial European call (500 steps)     = ", binomial_option_price(true, 100.0, 100.0, 0.05, 0.2, 1.0, 500, false), "   expect close to 10.45", newLine=true);
    print("binomial European put (500 steps)      = ", binomial_option_price(false, 100.0, 100.0, 0.05, 0.2, 1.0, 500, false), "   expect close to 5.57", newLine=true);
    print("binomial AMERICAN put (500 steps)      = ", binomial_option_price(false, 100.0, 100.0, 0.05, 0.2, 1.0, 500, true), "   expect between 6.0 and 6.1", newLine=true);

    print("current_ratio(500, 250)                = ", current_ratio(500.0, 250.0), "   expect 2", newLine=true);
    print("quick_ratio(500, 200, 250)             = ", quick_ratio(500.0, 200.0, 250.0), "   expect 1.2", newLine=true);
    print("cash_ratio(100, 250)                   = ", cash_ratio(100.0, 250.0), "   expect 0.4", newLine=true);
    print("debt_to_equity(400, 800)               = ", debt_to_equity(400.0, 800.0), "   expect 0.5", newLine=true);
    print("debt_ratio(400, 1000)                  = ", debt_ratio(400.0, 1000.0), "   expect 0.4", newLine=true);
    print("interest_coverage(300, 50)             = ", interest_coverage(300.0, 50.0), "   expect 6", newLine=true);
    print("equity_multiplier(1000, 500)           = ", equity_multiplier(1000.0, 500.0), "   expect 2", newLine=true);
    print("gross_margin(1000, 600)                = ", gross_margin(1000.0, 600.0), "   expect 0.4", newLine=true);
    print("operating_margin(1000, 150)            = ", operating_margin(1000.0, 150.0), "   expect 0.15", newLine=true);
    print("net_margin(1000, 100)                  = ", net_margin(1000.0, 100.0), "   expect 0.1", newLine=true);
    print("return_on_assets(100, 1000)            = ", return_on_assets(100.0, 1000.0), "   expect 0.1", newLine=true);
    print("return_on_equity(100, 500)             = ", return_on_equity(100.0, 500.0), "   expect 0.2", newLine=true);
    print("asset_turnover(1500, 1000)             = ", asset_turnover(1500.0, 1000.0), "   expect 1.5", newLine=true);
    print("inventory_turnover(600, 100)           = ", inventory_turnover(600.0, 100.0), "   expect 6", newLine=true);
    print("days_sales_outstanding(50, 600, 365)   = ", days_sales_outstanding(50.0, 600.0, 365.0), "   expect 30.4167", newLine=true);
    print("dupont_roe(10%, 1.5, 2)                = ", dupont_roe(0.1, 1.5, 2.0), "   expect 0.3", newLine=true);
    print("break_even_units(10000, 25, 15)        = ", break_even_units(10000.0, 25.0, 15.0), "   expect 1000", newLine=true);
};