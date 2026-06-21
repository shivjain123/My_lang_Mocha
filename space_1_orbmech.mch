from "mocha-space" import *;

// Pass the tracking array by reference to avoid both global IR bugs and stack return bugs
function assert_close(label: str, got: float, expected: float, tol: float, counts: int[]) -> null {
    var rel: float = abs(got - expected) / abs(expected);
    if (rel < tol) {
        print("  PASS: " + label, newLine=true);
        counts[0] = counts[0] + 1; // Index 0 is PASS
        return;
    };
    print("  FAIL: " + label, newLine=true);
    print("    got=" + str(got) + " expected=" + str(expected) + " rel_err=" + str(rel), newLine=true);
    counts[1] = counts[1] + 1; // Index 1 is FAIL
};

function main(didLoad) -> null {
    // A single tracking array allocation inside the main stack frame
    var tracking: int[] = [0, 0];

    // 1. Earth Period
    assert_close("Earth period", orbital_period(1.496E11, GM_SUN), 3.15576E7, 0.005, tracking);

    // 2. SMA Roundtrip
    assert_close("SMA roundtrip", semi_major_axis(orbital_period(1.496E11, GM_SUN), GM_SUN), 1.496E11, 0.001, tracking);

    // 3. ISS Velocity
    assert_close("ISS velocity", orbital_velocity_circular(6.771E6, GM_EARTH), 7672.0, 0.005, tracking);

    // 4. Earth Escape
    assert_close("Earth escape v", escape_velocity(RADIUS_EARTH, GM_EARTH), 11186.0, 0.002, tracking);

    // 5. Mars Perihelion
    assert_close("Mars perihelion", periapsis(2.279E11, 0.0934), 2.067E11, 0.005, tracking);

    // 6. Mars Aphelion
    assert_close("Mars aphelion", apoapsis(2.279E11, 0.0934), 2.492E11, 0.005, tracking);

    // 7. Eccentric Anomaly
    assert_close("Eccentric anomaly", eccentric_anomaly(1.0, 0.1), 1.0887, 0.001, tracking);

    // 8. True Anomaly Circular
    assert_close("True anomaly circular", true_anomaly_from_mean(1.5, 0.0), 1.5, 0.0001, tracking);

    // 9. Hohmann Earth->Mars
    assert_close("Hohmann Earth→Mars", hohmann_dv_total(1.496E11, 2.279E11, GM_SUN), 5590.0, 0.02, tracking);

    // 10. Earth Hill Sphere
    assert_close("Earth Hill sphere", hill_sphere(1.496E11, 0.0167, MASS_EARTH, MASS_SUN), 1.5E9, 0.05, tracking);

    // 11. Roche Rigid
    assert_close("Roche rigid", roche_limit_rigid(RADIUS_EARTH, 5514.0, 3346.0), 1.849E7, 0.02, tracking);

    // 12. Synodic Earth-Mars
    assert_close("Synodic Earth-Mars", synodic_period(3.15576E7, 5.93596E7) / 86400.0, 779.9, 0.005, tracking);

    // 13. Inclination Delta-V
    assert_close("Inclination Δv", inclination_change_dv(7672.0, 28.5), 3779.0, 0.01, tracking);

    print("PASSED: " + str(tracking[0]), newLine=true);
    print("FAILED: " + str(tracking[1]), newLine=true);
};