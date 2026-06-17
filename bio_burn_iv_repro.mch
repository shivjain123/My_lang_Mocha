from "mocha-bio" import *;

function main(didLoad) -> null {

    // ----- Rule of Nines -----

    // Full head burn only — should be 9% TBSA
    var tbsa1: float = rule_of_nines(100.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
    if (tbsa1 == 9.0) {
        print("PASS: rule_of_nines full head == 9.0%", newLine=true);
    } else {
        print("FAIL: rule_of_nines full head == 9.0%", newLine=true);
    };
    print("TBSA (full head) = ", newLine=false);
    print(tbsa1, newLine=true);

    // Full chest + full abdomen — should be 36% TBSA
    var tbsa2: float = rule_of_nines(0.0, 100.0, 100.0, 0.0, 0.0, 0.0, 0.0, 0.0);
    if (tbsa2 == 36.0) {
        print("PASS: rule_of_nines full chest + abdomen == 36.0%", newLine=true);
    } else {
        print("FAIL: rule_of_nines full chest + abdomen == 36.0%", newLine=true);
    };
    print("TBSA (chest + abdomen) = ", newLine=false);
    print(tbsa2, newLine=true);

    // Full body burn — should be 100% TBSA
    var tbsa3: float = rule_of_nines(100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0);
    if (tbsa3 == 100.0) {
        print("PASS: rule_of_nines full body == 100.0%", newLine=true);
    } else {
        print("FAIL: rule_of_nines full body == 100.0%", newLine=true);
    };
    print("TBSA (full body) = ", newLine=false);
    print(tbsa3, newLine=true);

    // Partial burns — 50% of each arm = 9% total
    var tbsa4: float = rule_of_nines(0.0, 0.0, 0.0, 50.0, 50.0, 0.0, 0.0, 0.0);
    if (tbsa4 == 9.0) {
        print("PASS: rule_of_nines 50% both arms == 9.0%", newLine=true);
    } else {
        print("FAIL: rule_of_nines 50% both arms == 9.0%", newLine=true);
    };
    print("TBSA (50% both arms) = ", newLine=false);
    print(tbsa4, newLine=true);

    // Zero burns — should be 0%
    var tbsa5: float = rule_of_nines(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
    if (tbsa5 == 0.0) {
        print("PASS: rule_of_nines no burns == 0.0%", newLine=true);
    } else {
        print("FAIL: rule_of_nines no burns == 0.0%", newLine=true);
    };

    // ----- Burn Severity -----
    var sev1: BurnSeverity = burn_severity(5.0);
    if (sev1 == BurnSeverity.MINOR) {
        print("PASS: burn_severity(5%) == MINOR", newLine=true);
    } else {
        print("FAIL: burn_severity(5%) == MINOR", newLine=true);
    };

    var sev2: BurnSeverity = burn_severity(15.0);
    if (sev2 == BurnSeverity.MODERATE) {
        print("PASS: burn_severity(15%) == MODERATE", newLine=true);
    } else {
        print("FAIL: burn_severity(15%) == MODERATE", newLine=true);
    };

    var sev3: BurnSeverity = burn_severity(25.0);
    if (sev3 == BurnSeverity.MAJOR) {
        print("PASS: burn_severity(25%) == MAJOR", newLine=true);
    } else {
        print("FAIL: burn_severity(25%) == MAJOR", newLine=true);
    };

    // ----- Parkland Formula -----
    // 70kg patient, 40% TBSA burn
    // Total = 4 * 70 * 40 = 11200 mL
    var park1: float = parkland(70.0, 40.0);
    if (park1 == 11_200.0) {
        print("PASS: parkland(70kg, 40%) == 11200 mL", newLine=true);
    } else {
        print("FAIL: parkland(70kg, 40%) == 11200 mL", newLine=true);
    };
    print("Parkland total = ", newLine=false);
    print(park1, newLine=true);

    // First 8hr rate = 11200 / 2 / 8 = 700 mL/hr
    var rate1: float = parkland_first_8hr_rate(70.0, 40.0);
    if (rate1 == 700.0) {
        print("PASS: parkland_first_8hr_rate == 700 mL/hr", newLine=true);
    } else {
        print("FAIL: parkland_first_8hr_rate == 700 mL/hr", newLine=true);
    };
    print("Parkland first 8hr rate = ", newLine=false);
    print(rate1, newLine=true);

    // Next 16hr rate = 11200 / 2 / 16 = 350 mL/hr
    var rate2: float = parkland_next_16hr_rate(70.0, 40.0);
    if (rate2 == 350.0) {
        print("PASS: parkland_next_16hr_rate == 350 mL/hr", newLine=true);
    } else {
        print("FAIL: parkland_next_16hr_rate == 350 mL/hr", newLine=true);
    };
    print("Parkland next 16hr rate = ", newLine=false);
    print(rate2, newLine=true);

    // Underscore literal test — same calc with underscores
    var park2: float = parkland(70.0, 40.0);
    if (park2 == 11_200.0) {
        print("PASS: underscore literal 11_200.0 works in comparison", newLine=true);
    } else {
        print("FAIL: underscore literal 11_200.0 works in comparison", newLine=true);
    };

    print("Burns tests done.", newLine=true);
};