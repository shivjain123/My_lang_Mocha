from "mocha-space" import *;

function assert_close(label: str, got: float, expected: float, tol: float, counts: int[]) -> null {
    var rel: float = unsafe_div(abs(got - expected), abs(expected));
    if (rel < tol) {
        print("  PASS: " + label, newLine=true);
        counts[0] = counts[0] + 1;
        return;
    };
    print("  FAIL: " + label, newLine=true);
    print("    got=" + str(got) + " expected=" + str(expected) + " rel_err=" + str(rel), newLine=true);
    counts[1] = counts[1] + 1;
};

function main(didLoad) -> null {
    var tracking: int[] = [0, 0];

    // 1. Earth's equilibrium temperature from L_sun, 1 AU, real Earth albedo
    // Verified via Python: 253.67 K (matches the well-known "no-greenhouse" Earth figure ~255K)
    assert_close("Earth equilibrium temp", equilibrium_temp(LUMINOSITY_SUN, AU, EARTH_ALBEDO), 253.67, 0.01, tracking);

    // 2. Earth's equilibrium temp via stellar T/R route - should match test 1 closely
    // Verified via Python: 253.67 K
    assert_close("Earth eq temp from star T,R", equilibrium_temp_from_star(TEMP_SUN, RADIUS_SUN, AU, EARTH_ALBEDO), 253.67, 0.01, tracking);

    // 3. Solar flux at 1 AU - should recover the textbook solar constant ~1361 W/m^2
    // Verified via Python: 1361.17
    assert_close("Solar flux at 1AU", solar_flux_at_distance(LUMINOSITY_SUN, AU), 1361.17, 0.01, tracking);

    // 4. Absorbed power by Earth (accounting for albedo and cross-sectional area)
    // Verified via Python: 1.1976E17 W
    assert_close("Earth absorbed power", absorbed_power(LUMINOSITY_SUN, AU, RADIUS_EARTH, EARTH_ALBEDO), 1.1976E17, 0.01, tracking);

    // 5. Earth atmospheric scale height at T=288K (standard surface temp)
    // Verified via Python: 8431.55 m (real-world commonly cited: ~8400-8500m)
    assert_close("Earth scale height", scale_height(288.0, EARTH_MEAN_MOLAR_MASS, EARTH_GRAVITY), 8431.55, 0.01, tracking);

    // 6. Barometric pressure at altitude = one scale height (should drop to P0/e)
    // Verified via Python: 37275.38 Pa (P0=101325 Pa, h=H=8431.55m)
    assert_close("Pressure at one scale height", atmospheric_pressure_at_height(101325.0, 8431.55, 8431.55), 37275.38, 0.001, tracking);

    // 7. Earth's surface gravity from mass and radius
    // Verified via Python: 9.8195 m/s^2 (real measured value: 9.80665, small diff from G/mass precision)
    assert_close("Earth surface gravity", surface_gravity(MASS_EARTH, RADIUS_EARTH), 9.8195, 0.01, tracking);

    // 8. Earth escape velocity via mass/radius route (cross-check against Section 1's escape_velocity)
    // Verified via Python: 11185.73 m/s
    assert_close("Earth escape velocity (mass/radius)", escape_velocity_from_mass_radius(MASS_EARTH, RADIUS_EARTH), 11185.73, 0.01, tracking);

    // 9. Simplified habitable zone distance for a Sun-like star (L=1 solar -> should give 1.0 AU)
    assert_close("HZ distance simple (Sun)", habitable_zone_distance_simple(1.0), 1.0, 0.001, tracking);

    // 10. Simplified habitable zone for a 4x more luminous star -> should give 2.0 AU
    assert_close("HZ distance simple (4x L_sun)", habitable_zone_distance_simple(4.0), 2.0, 0.001, tracking);

    // 11. Thermal velocity of N2 in Earth's atmosphere at 288K
    // Verified via Python: 413.57 m/s
    assert_close("N2 thermal velocity at 288K", thermal_velocity(288.0, 0.028), 413.57, 0.01, tracking);

    // 12. Jeans escape parameter for N2 on Earth (should be >>1, meaning N2 is retained)
    // Verified via Python: 731.53
    assert_close("Jeans parameter N2 on Earth", jeans_escape_parameter(11185.73, 413.57), 731.53, 0.02, tracking);

    // 13. Mean free path of N2 at sea level (T=288K, P=101325 Pa, d=3.7E-10 m)
    // Verified via Python: 6.452E-8 m (real-world commonly cited: ~6.8E-8 m, close given simplified kinetic model)
    assert_close("Mean free path sea level N2", mean_free_path(288.0, 101325.0, 3.7E-10), 6.452E-8, 0.02, tracking);

    print("PASSED: " + str(tracking[0]), newLine=true);
    print("FAILED: " + str(tracking[1]), newLine=true);
};