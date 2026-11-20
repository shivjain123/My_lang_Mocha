from "mocha-math" import *;
from "mocha-finance" import *;

function run(didLoad) -> null {
    var flows: float[] = [-100.0, 60.0, 60.0];

    print("future_value(1000, 5%, 10)       = ", future_value(1000.0, 0.05, 10.0), "   expect 1628.89", newLine=true);
    print("effective_annual_rate(12%, 12)   = ", effective_annual_rate(0.12, 12), "   expect 0.126825", newLine=true);
    print("loan_payment(200000, 0.5%, 360)  = ", loan_payment(200000.0, 0.005, 360), "   expect 1199.10", newLine=true);
    print("number_of_payments               = ", number_of_payments(200000.0, 0.005, 1199.10), "   expect about 360", newLine=true);
    print("net_present_value(10%)           = ", net_present_value(0.1, flows), "   expect 4.1322", newLine=true);
    print("internal_rate_of_return          = ", internal_rate_of_return(flows), "   expect 0.130662", newLine=true);
    print("payback_period                   = ", payback_period(flows), "   expect 1.6667", newLine=true);
};