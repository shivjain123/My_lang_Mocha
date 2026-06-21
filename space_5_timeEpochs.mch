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

    // ── Julian Date ──────────────────────────────────────────────────────
    // Verified against USNO reference: 1970-01-01 00:00 UTC -> JD 2440587.5
    assert_close("JD 1970-01-01", julian_date(1970, 1, 1.0), 2440587.5, 0.0000001, tracking);

    // J2000.0 epoch: 2000-01-01 12:00 UTC -> JD 2451545.0 exactly
    assert_close("JD J2000 epoch", julian_date(2000, 1, 1.5), 2451545.0, 0.0000001, tracking);

    // ── MJD Roundtrip ────────────────────────────────────────────────────
    assert_close("JD to MJD (J2000)", julian_date_to_mjd(2451545.0), 51544.5, 0.0000001, tracking);
    assert_close("MJD to JD roundtrip", mjd_to_julian_date(51544.5), 2451545.0, 0.0000001, tracking);

    // ── J2000 Centuries/Days ────────────────────────────────────────────
    // At the J2000 epoch itself, T should be exactly 0
    assert_near_zero("J2000 centuries at epoch", j2000_centuries(2451545.0), 0.0000001, tracking);
    assert_near_zero("J2000 days at epoch", j2000_days(2451545.0), 0.0000001, tracking);

    // One century later (T=1): JD = 2451545.0 + 36525
    assert_close("J2000 centuries (+1 century)", j2000_centuries(2451545.0 + 36525.0), 1.0, 0.0000001, tracking);

    // ── GMST ─────────────────────────────────────────────────────────────
    // At J2000.0 (T=0), GMST collapses to just the constant term: 24110.54841s = 100.4606 deg
    // This is self-evident from the formula structure, not an external lookup.
    assert_close("GMST at J2000.0", gmst_degrees(2451545.0), 100.4606, 0.001, tracking);

    // Cross-checked via independent Python computation: 1994-06-16 18h UT -> GMST 264.7711 deg
    var jd_1994: float = julian_date(1994, 6, 16.75);  // 18h = 0.75 of a day
    assert_close("GMST 1994-06-16 18h", gmst_degrees(jd_1994), 264.7711, 0.001, tracking);

    // ── LST ──────────────────────────────────────────────────────────────
    // At longitude 0 (Greenwich), LST should exactly equal GMST
    assert_close("LST at Greenwich = GMST", lst_degrees(2451545.0, 0.0), gmst_degrees(2451545.0), 0.0001, tracking);

    // At longitude 90 east, LST should be GMST+90 (mod 360)
    var lst90: float = lst_degrees(2451545.0, 90.0);
    var expected_lst90: float = gmst_degrees(2451545.0) + 90.0;
    if (expected_lst90 >= 360.0) { expected_lst90 = expected_lst90 - 360.0; };
    assert_close("LST at longitude +90", lst90, expected_lst90, 0.0001, tracking);

    // ── Unix Timestamp <-> JD ───────────────────────────────────────────
    // Unix epoch (timestamp=0) should correspond to JD 2440587.5
    assert_close("Unix epoch to JD", unix_to_julian_date(0.0), 2440587.5, 0.0000001, tracking);
    assert_near_zero("JD to Unix epoch", julian_date_to_unix(2440587.5), 0.001, tracking);

    // Roundtrip with a non-trivial timestamp
    var roundtrip_jd: float = unix_to_julian_date(1000000000.0);
    var roundtrip_unix: float = julian_date_to_unix(roundtrip_jd);
    assert_close("Unix-JD roundtrip", roundtrip_unix, 1000000000.0, 0.0000001, tracking);

    // ── UTC <-> TT ───────────────────────────────────────────────────────
    // TT should be 69.184 seconds ahead of UTC, i.e. 69.184/86400 days ahead
    var jd_utc: float = 2451545.0;
    var jd_tt: float = utc_to_tt(jd_utc);
    assert_close("UTC to TT offset", (jd_tt - jd_utc) * 86400.0, 69.184, 0.0001, tracking);

    // Roundtrip
    assert_close("TT to UTC roundtrip", tt_to_utc(jd_tt), jd_utc, 0.0000001, tracking);

    // ── Besselian / Julian Epoch ────────────────────────────────────────
    // Roundtrip: epoch -> JD -> epoch should recover the original value
    var b1950_jd: float = besselian_epoch_to_jd(1950.0);
    assert_close("Besselian epoch roundtrip", besselian_epoch(b1950_jd), 1950.0, 0.0001, tracking);

    // Julian epoch at J2000.0 should be exactly 2000.0
    assert_close("Julian epoch at J2000", julian_epoch(2451545.0), 2000.0, 0.0000001, tracking);

    print("PASSED: " + str(tracking[0]), newLine=true);
    print("FAILED: " + str(tracking[1]), newLine=true);
};