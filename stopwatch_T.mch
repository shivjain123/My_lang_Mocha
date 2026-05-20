from "mocha-stopwatch" import *;

function main(didLoad) -> null {
    // ── datetime ──
    print("datetime_now: " + datetime_now(), newLine=true);
    print("date_now:     " + date_now(),     newLine=true);
    print("time_now:     " + time_now(),     newLine=true);
    print("ampm_now:     " + ampm_now(),     newLine=true);
    print("day_now:      " + day_now(),      newLine=true);
    print("month_now:    " + month_now(),    newLine=true);
    print("year_now:     " + year_now(),     newLine=true);
    print("unix_time:    " + str(unix_time()), newLine=true);
    print("now_ms:       " + str(now_ms()),    newLine=true);

    // ── stopwatch ──
    print("--- Stopwatch ---", newLine=true);
    var sw: Stopwatch = Stopwatch();
    sw.begin();

    // burn some time with a loop
    var i: int = 0;
    var sum: int = 0;
    while (i < 1000000) {
        sum = sum + i;
        i++;
    };

    print("elapsed while running: " + str(sw.elapsed_ms()) + "ms", newLine=true);
    sw.end();
    print("elapsed after end:    " + str(sw.elapsed_ms()) + "ms", newLine=true);
    print("elapsed in seconds:    " + str(sw.elapsed_sec()) + "s",  newLine=true);

    // reset and reuse
    sw.reset();
    sw.begin();
    var j: int = 0;
    while (j < 500000) { j++; };
    sw.end();
    print("second run:            " + str(sw.elapsed_ms()) + "ms", newLine=true);
};