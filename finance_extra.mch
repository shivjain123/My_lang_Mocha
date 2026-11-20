from "mocha-math" import *;
from "mocha-finance" import *;

function run(didLoad) -> null {
    var flows: float[] = [-100.0, 60.0, 60.0];

    print("simple_interest(1000, 5%, 3y)          = ", simple_interest(1000.0, 0.05, 3.0), "   expect 150", newLine=true);
    print("present_value(1628.894627, 5%, 10)     = ", present_value(1628.894627, 0.05, 10.0), "   expect 1000", newLine=true);
    print("compound_amount(1000, 6%, 5y, monthly) = ", compound_amount(1000.0, 0.06, 5.0, 12), "   expect 1348.85", newLine=true);
    print("nominal_rate_from_effective(0.126825)  = ", nominal_rate_from_effective(0.126825, 12), "   expect about 0.12", newLine=true);
    print("continuous_compound_amount(1000, 5%, 10y) = ", continuous_compound_amount(1000.0, 0.05, 10.0), "   expect 1648.72", newLine=true);
    print("effective_rate_from_continuous(5%)     = ", effective_rate_from_continuous(0.05), "   expect 0.051271", newLine=true);
    print("continuous_rate_from_effective(0.051271) = ", continuous_rate_from_effective(0.051271), "   expect about 0.05", newLine=true);
    print("doubling_time(7%)                      = ", doubling_time(0.07), "   expect 10.2448", newLine=true);
    print("rule_of_72(8)                          = ", rule_of_72(8.0), "   expect 9", newLine=true);
    print("real_interest_rate(5%, 3%)             = ", real_interest_rate(0.05, 0.03), "   expect 0.019417", newLine=true);
    print("inflation_adjusted_value(1000, 3%, 10y) = ", inflation_adjusted_value(1000.0, 0.03, 10.0), "   expect 744.09", newLine=true);
    print("cagr(100 -> 200, 5 years)              = ", cagr(100.0, 200.0, 5.0), "   expect 0.148698", newLine=true);

    print("annuity_present_value(100, 5%, 10)     = ", annuity_present_value(100.0, 0.05, 10, false), "   expect 772.17", newLine=true);
    print("annuity_present_value, annuity due     = ", annuity_present_value(100.0, 0.05, 10, true), "   expect 810.78", newLine=true);
    print("annuity_future_value(100, 5%, 10)      = ", annuity_future_value(100.0, 0.05, 10, false), "   expect 1257.79", newLine=true);
    print("perpetuity_present_value(50, 5%)       = ", perpetuity_present_value(50.0, 0.05), "   expect 1000", newLine=true);
    print("growing_perpetuity(100, 8%, 3%)        = ", growing_perpetuity_present_value(100.0, 0.08, 0.03), "   expect 2000", newLine=true);
    print("loan_balance after 60 payments         = ", loan_balance(200000.0, 0.005, 360, 60), "   expect about 186108", newLine=true);
    print("loan_interest_in_payment, payment 1    = ", loan_interest_in_payment(200000.0, 0.005, 360, 1), "   expect 1000", newLine=true);
    print("loan_principal_in_payment, payment 1   = ", loan_principal_in_payment(200000.0, 0.005, 360, 1), "   expect 199.10", newLine=true);
    print("total_interest_paid                    = ", total_interest_paid(200000.0, 0.005, 360), "   expect about 231676", newLine=true);

    print("discounted_payback_period(10%)         = ", discounted_payback_period(0.1, flows), "   expect 1.91667", newLine=true);
    print("profitability_index(10%)               = ", profitability_index(0.1, flows), "   expect 1.041322", newLine=true);
    print("modified_internal_rate_of_return       = ", modified_internal_rate_of_return(flows, 0.1, 0.1), "   expect 0.122497", newLine=true);
};