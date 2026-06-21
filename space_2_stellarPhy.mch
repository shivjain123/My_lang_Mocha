from "mocha-space" import *;

// Pass the tracking array by reference to avoid both global IR bugs and stack return bugs
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

    // 1. Sun's own luminosity from its own R and T (Stefan-Boltzmann self-consistency check)
    // R_sun=6.957E8 m, T_sun=5772 K -> verified via Python: 3.828E26 W
    assert_close("Sun luminosity from R,T", luminosity_from_radius_temp(RADIUS_SUN, TEMP_SUN), LUMINOSITY_SUN, 0.01, tracking);

    // 2. Radius roundtrip: from L_sun and T_sun, recover R_sun
    assert_close("Sun radius from L,T", radius_from_luminosity_temp(LUMINOSITY_SUN, TEMP_SUN), RADIUS_SUN, 0.01, tracking);

    // 3. Temp roundtrip: from L_sun and R_sun, recover T_sun
    assert_close("Sun temp from L,R", temp_from_luminosity_radius(LUMINOSITY_SUN, RADIUS_SUN), TEMP_SUN, 0.01, tracking);

    // 4. Wien's law: Sun's peak wavelength (verified via Python: 5.0204E-7 m)
    assert_close("Sun Wien peak wavelength", wien_peak_wavelength(TEMP_SUN), 5.0204E-7, 0.01, tracking);

    // 5. Wien inverse: peak wavelength -> temperature roundtrip
    assert_close("Wien temp roundtrip", wien_temp_from_wavelength(5.0204E-7), TEMP_SUN, 0.01, tracking);

    // 6. Sirius parallax -> distance (source: Wikipedia, parallax = 0.3789 arcsec, distance = 2.639 pc)
    assert_close("Sirius distance from parallax", parallax_to_distance_pc(0.3789), 2.639, 0.01, tracking);

    // 7. Distance -> parallax roundtrip
    assert_close("Sirius parallax from distance", distance_to_parallax(2.639), 0.3789, 0.01, tracking);

    // 8. Sirius distance modulus (m=-1.46, M=1.43, source: Wikipedia)
    assert_close("Sirius distance modulus", distance_modulus(-1.46, 1.43), -2.89, 0.01, tracking);

    // 9. Sirius absolute magnitude from apparent mag and distance
    assert_close("Sirius absolute magnitude", absolute_magnitude(-1.46, 2.639), 1.43, 0.02, tracking);

    // 10. Sirius apparent magnitude roundtrip from absolute magnitude and distance
    assert_close("Sirius apparent magnitude", apparent_magnitude(1.43, 2.639), -1.46, 0.02, tracking);

    // 11. Distance from modulus roundtrip (mu = -2.89 -> d = 2.639 pc)
    assert_close("Distance from modulus", distance_from_modulus(-2.89), 2.639, 0.01, tracking);

    // 12. Flux ratio: Sirius (m=-1.46) vs Sun (m=-26.74) - verified via Python: 7.7268E-11
    assert_close("Flux ratio Sirius vs Sun", flux_ratio_from_magnitudes(-1.46, -26.74), 7.7268E-11, 0.01, tracking);

    // 13. Magnitude diff from flux ratio (clean ratio of 100, which by definition = 5 mag)
    assert_close("Mag diff from flux ratio 100x", magnitude_diff_from_flux_ratio(100.0), -5.0, 0.001, tracking);

    // 14. Luminosity to solar units (Sirius A: 24.74 L_sun, using raw watts)
    assert_close("Luminosity to solar (Sirius A)", luminosity_to_solar(unsafe_mul(24.74, LUMINOSITY_SUN)), 24.74, 0.001, tracking);

    // 15. Luminosity from solar units roundtrip
    assert_close("Luminosity from solar (Sirius A)", luminosity_from_solar(24.74), unsafe_mul(24.74, LUMINOSITY_SUN), 0.001, tracking);

    // 16. Main sequence mass-luminosity relation (Sirius A: mass=2.063 M_sun)
    // L/L_sun = 2.063^3.5 = 12.61 (verified via Python; approximation vs real 24.74, wide tolerance expected)
    assert_close("Main sequence L (Sirius A mass)", main_sequence_luminosity(2.063), 12.61, 0.02, tracking);

    // 17. Schwarzschild radius of the Sun (verified via Python: 2953.99 m)
    assert_close("Sun Schwarzschild radius", schwarzschild_radius(MASS_SUN), 2954.0, 0.01, tracking);

    // 18. Photon energy at 502nm (Sun's peak wavelength) -> verified via Python: 3.9568E-19 J
    assert_close("Photon energy at 502nm", photon_energy(5.0204E-7), 3.9568E-19, 0.01, tracking);

    print("PASSED: " + str(tracking[0]), newLine=true);
    print("FAILED: " + str(tracking[1]), newLine=true);
};