from "mocha-geo" import *;

function tested(didLoad) {

    // ============================================================
    // TEST 1: plate_velocity with time = 0
    // ============================================================
    print("TEST 1: plate_velocity(100.0, 0.0)", newLine=true);
    print(plate_velocity(100.0, 0.0), newLine=true);
    print("---", newLine=true);

    // ============================================================
    // TEST 2: true_dip with alpha = 90 (cos = 0)
    // ============================================================
    print("TEST 2: true_dip(30.0, 90.0)", newLine=true);
    print(true_dip(30.0, 90.0), newLine=true);
    print("---", newLine=true);

    // ============================================================
    // TEST 3: airy_isostasy_root with mantle = crust (denom = 0)
    // ============================================================
    print("TEST 3: airy_isostasy_root(5.0, 2700.0, 2700.0)", newLine=true);
    print(airy_isostasy_root(5.0, 2700.0, 2700.0), newLine=true);
    print("---", newLine=true);

    // ============================================================
    // TEST 4: strain_ellipse_ratio with e3 = -1 (denom = 0)
    // ============================================================
    print("TEST 4: strain_ellipse_ratio(0.5, -1.0)", newLine=true);
    print(strain_ellipse_ratio(0.5, -1.0), newLine=true);
    print("---", newLine=true);

    // ============================================================
    // TEST 5: baseline — normal division still works
    // ============================================================
    print("TEST 5: plate_velocity(100.0, 10.0) — should be 1.0", newLine=true);
    print(plate_velocity(100.0, 10.0), newLine=true);
    print("---", newLine=true);

};