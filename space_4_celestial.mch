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

function assert_near_zero(label: str, got: float, tol_abs: float, counts: int[]) -> null {
    if (abs(got) < tol_abs) {
        print("  PASS: " + label, newLine=true);
        counts[0] = counts[0] + 1;
        return;
    };
    print("  FAIL: " + label, newLine=true);
    print("    got=" + str(got) + " (expected near 0)", newLine=true);
    counts[1] = counts[1] + 1;
};

function main(didLoad) -> null {
    var tracking: int[] = [0, 0];

    // ── Equatorial <-> Horizontal ──────────────────────────────────────────
    var alt_az: (float, 2) = equatorial_to_horizontal(101.287, -16.716, 30.0, 110.0);
    assert_close("Sirius altitude", alt_az#0, 42.535, 0.01, tracking);
    assert_close("Sirius azimuth", alt_az#1, 191.355, 0.01, tracking);

    var ra_dec: (float, 2) = horizontal_to_equatorial(alt_az#0, alt_az#1, 30.0, 110.0);
    assert_close("Sirius RA roundtrip", ra_dec#0, 101.287, 0.001, tracking);
    assert_close("Sirius Dec roundtrip", ra_dec#1, -16.716, 0.001, tracking);

    var transit: (float, 2) = equatorial_to_horizontal(110.0, -16.716, 30.0, 110.0);
    assert_close("Meridian transit azimuth (south)", transit#1, 180.0, 0.001, tracking);

    // ── Angular Separation ──────────────────────────────────────────────────
    assert_close("Sirius-Betelgeuse separation", angular_separation(101.287, -16.716, 88.793, 7.407), 27.104, 0.001, tracking);

    var exact_sep: float = angular_separation(100.0, 20.0, 100.008, 20.005);
    var approx_sep: float = angular_separation_small(100.0, 20.0, 100.008, 20.005);
    assert_close("Small-angle approx matches exact", approx_sep, exact_sep, 0.001, tracking);

    // ── Equatorial <-> Ecliptic ────────────────────────────────────────────
    var ecl: (float, 2) = equatorial_to_ecliptic(279.2347, 38.7837, OBLIQUITY_J2000);
    assert_close("Vega ecliptic longitude", ecl#0, 285.316, 0.01, tracking);
    assert_close("Vega ecliptic latitude", ecl#1, 61.733, 0.01, tracking);

    var eq_back: (float, 2) = ecliptic_to_equatorial(ecl#0, ecl#1, OBLIQUITY_J2000);
    assert_close("Vega RA roundtrip (ecliptic)", eq_back#0, 279.2347, 0.001, tracking);
    assert_close("Vega Dec roundtrip (ecliptic)", eq_back#1, 38.7837, 0.001, tracking);

    var equinox: (float, 2) = equatorial_to_ecliptic(0.0, 0.0, OBLIQUITY_J2000);
    assert_near_zero("Equinox ecliptic longitude", equinox#0, 0.001, tracking);
    assert_near_zero("Equinox ecliptic latitude", equinox#1, 0.001, tracking);

    // ── Equatorial <-> Galactic ────────────────────────────────────────────
    var gal_center: (float, 2) = equatorial_to_galactic(266.4051, -28.936175);
    assert_near_zero("Galactic Center longitude", gal_center#0, 0.01, tracking);
    assert_near_zero("Galactic Center latitude", gal_center#1, 0.01, tracking);

    var sirius_gal: (float, 2) = equatorial_to_galactic(101.287, -16.716);
    assert_close("Sirius galactic longitude", sirius_gal#0, 227.230, 0.01, tracking);
    assert_close("Sirius galactic latitude", sirius_gal#1, -8.890, 0.01, tracking);

    var vega_gal: (float, 2) = equatorial_to_galactic(279.2347, 38.7837);
    assert_close("Vega galactic longitude", vega_gal#0, 67.448, 0.01, tracking);
    assert_close("Vega galactic latitude", vega_gal#1, 19.237, 0.01, tracking);

    var ngp: (float, 2) = equatorial_to_galactic(192.859508, 27.128336);
    assert_close("NGP galactic latitude", ngp#1, 90.0, 0.001, tracking);

    // ── Position Angle ────────────────────────────────────────────────────
    assert_near_zero("Position angle due north", position_angle(100.0, 10.0, 100.0, 20.0), 0.001, tracking);
    assert_close("Position angle due east", position_angle(100.0, 10.0, 100.5, 10.0), 89.957, 0.01, tracking);

    // ── Proper Motion ──────────────────────────────────────────────────────
    assert_close("Proper motion total (3-4-5)", proper_motion_total(3.0, 4.0, 0.0), 5.0, 0.001, tracking);

    // ── Atmospheric Refraction ────────────────────────────────────────────
    assert_close("Refraction at 45deg altitude", atmospheric_refraction(45.0), 1.0, 0.001, tracking);
    assert_close("Refraction at 10deg altitude", atmospheric_refraction(10.0), 5.671, 0.01, tracking);

    // ── Precession ─────────────────────────────────────────────────────────
    var precessed: (float, 2) = precess_ra_dec(0.0, 0.0, 100.0);
    assert_close("Precession RA shift over 100yr", precessed#0, 1.39697, 0.001, tracking);

    // ── Hour/Degree and Sexagesimal Conversions ───────────────────────────
    assert_close("Hours to degrees (6h)", hours_to_degrees(6.0), 90.0, 0.001, tracking);
    assert_close("Degrees to hours (90deg)", degrees_to_hours(90.0), 6.0, 0.001, tracking);

    assert_close("Vega RA from HMS", hms_to_degrees(18.0, 36.0, 56.34), 279.23475, 0.001, tracking);
    assert_close("Vega Dec from DMS", dms_to_degrees(38.0, 47.0, 1.3), 38.78369, 0.001, tracking);

    var dms: (float, 3) = degrees_to_dms(38.7837);
    assert_close("Degrees to DMS - degrees part", dms#0, 38.0, 0.001, tracking);
    assert_close("Degrees to DMS - arcmin part", dms#1, 47.0, 0.001, tracking);
    assert_close("Degrees to DMS - arcsec part", dms#2, 1.32, 0.05, tracking);

    print("PASSED: " + str(tracking[0]), newLine=true);
    print("FAILED: " + str(tracking[1]), newLine=true);
};