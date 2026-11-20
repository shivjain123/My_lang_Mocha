from "mocha-finance" import *;

function run(didLoad) -> null {
    var asset: float[] = [0.10, -0.05, 0.08, 0.02, -0.01];
    var market: float[] = [0.08, -0.04, 0.06, 0.01, -0.02];
    var dividends: float[] = [2.0, 2.1, 2.2];
    var prices: float[] = [100.0, 120.0, 90.0, 110.0, 80.0, 130.0];
    var md: float = modified_duration(1000.0, 0.05, 0.04, 10);
    var cx: float = bond_convexity(1000.0, 0.05, 0.04, 10);
    var sd: float = return_volatility(asset);

    print("zero_coupon_price(1000, 5%, 10)        = ", zero_coupon_price(1000.0, 0.05, 10), "   expect 613.91", newLine=true);
    print("bond_price(1000, 5% coupon, 4% yield)  = ", bond_price(1000.0, 0.05, 0.04, 10), "   expect 1081.11", newLine=true);
    print("current_yield(50, 1081.11)             = ", current_yield(50.0, 1081.11), "   expect 0.046248", newLine=true);
    print("yield_to_maturity(1081.11)             = ", yield_to_maturity(1081.11, 1000.0, 0.05, 10), "   expect about 0.04", newLine=true);
    print("macaulay_duration                      = ", macaulay_duration(1000.0, 0.05, 0.04, 10), "   expect about 8.19", newLine=true);
    print("modified_duration                      = ", md, "   expect about 7.876", newLine=true);
    print("bond_convexity                         = ", cx, "   expect about 77.48", newLine=true);
    print("price change estimate (+1% yield)      = ", bond_price_change_estimate(md, cx, 0.01), "   expect about -0.0749", newLine=true);

    print("gordon_growth_price(2, 8%, 3%)         = ", gordon_growth_price(2.0, 0.08, 0.03), "   expect 40", newLine=true);
    print("dividend_discount_value(10%, 3 divs)   = ", dividend_discount_value(0.1, dividends, 0.03), "   expect about 29.53", newLine=true);
    print("capm_expected_return(3%, 1.2, 8%)      = ", capm_expected_return(0.03, 1.2, 0.08), "   expect 0.09", newLine=true);
    print("wacc(600, 400, 10%, 5%, 25% tax)       = ", wacc(600.0, 400.0, 0.10, 0.05, 0.25), "   expect 0.075", newLine=true);
    print("dividend_yield(2, 50)                  = ", dividend_yield(2.0, 50.0), "   expect 0.04", newLine=true);
    print("earnings_yield(2.5, 50)                = ", earnings_yield(2.5, 50.0), "   expect 0.05", newLine=true);
    print("price_to_earnings_ratio(50, 2.5)       = ", price_to_earnings_ratio(50.0, 2.5), "   expect 20", newLine=true);
    print("payout_ratio(1, 2.5)                   = ", payout_ratio(1.0, 2.5), "   expect 0.4", newLine=true);
    print("sustainable_growth_rate(15%, 60%)      = ", sustainable_growth_rate(0.15, 0.6), "   expect 0.09", newLine=true);

    print("simple_return(100, 125)                = ", simple_return(100.0, 125.0), "   expect 0.25", newLine=true);
    print("log_return(100, 125)                   = ", log_return(100.0, 125.0), "   expect 0.223144", newLine=true);
    print("mean_return                            = ", mean_return(asset), "   expect 0.028", newLine=true);
    print("return_volatility                      = ", sd, "   expect 0.062209", newLine=true);
    print("annualize_volatility(monthly)          = ", annualize_volatility(sd, 12), "   expect about 0.2155", newLine=true);
    print("sharpe_ratio(0.028, 0.005, 0.062209)   = ", sharpe_ratio(0.028, 0.005, 0.062209), "   expect 0.3697", newLine=true);
    print("return_covariance(asset, market)       = ", return_covariance(asset, market), "   expect 0.00317", newLine=true);
    print("return_correlation(asset, market)      = ", return_correlation(asset, market), "   expect 0.9955", newLine=true);
    print("beta_from_returns                      = ", beta_from_returns(asset, market), "   expect 1.2099", newLine=true);
    print("jensens_alpha(12%, 3%, 1.2, 8%)        = ", jensens_alpha(0.12, 0.03, 1.2, 0.08), "   expect 0.03", newLine=true);
    print("two_asset_return(60%, 10%, 4%)         = ", two_asset_return(0.6, 0.10, 0.04), "   expect 0.076", newLine=true);
    print("two_asset_volatility(60%, 20%, 10%, 0.3) = ", two_asset_volatility(0.6, 0.20, 0.10, 0.3), "   expect 0.1374", newLine=true);
    print("parametric_var(100000, 0.1%, 2%, 95%)  = ", parametric_var(100000.0, 0.001, 0.02, 1.645), "   expect 3190", newLine=true);
    print("max_drawdown                           = ", max_drawdown(prices), "   expect 0.33333", newLine=true);
};