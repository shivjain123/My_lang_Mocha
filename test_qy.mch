from "mocha-stopwatch" import *;

function main(didLoad) -> null {
    var sw: Stopwatch = Stopwatch();
    sw.begin();
    sw.wait(50.0);
    sw.end();
    var ms: float = sw.elapsed_ms();
    print("wall elapsed ms ", ms, newLine=true);

    // switching clocks must clear the old result
    sw.use_cpu_time();
    var s1: float = sw.start_time;
    var s2: float = sw.stop_time;
    print("after switch: start ", s1, " stop ", s2, newLine=true);

    sw.begin();
    sw.end();
    var cpu_ms: float = sw.elapsed_ms();
    print("cpu-clock elapsed ms ", cpu_ms, newLine=true);

    // switch back, take a lap while running, then the final time
    sw.use_wall_time();
    sw.begin();
    sw.wait(20.0);
    var lap: float = sw.elapsed_ms();
    sw.end();
    var total: float = sw.elapsed_ms();
    print("lap ", lap, " total ", total, newLine=true);

    // raw timestamps
    var a: float = wall_ms();
    sw.wait(10.0);
    var b: float = wall_ms();
    print("wall_ms advanced by ", b - a, newLine=true);
    var dt: str = datetime_now();
    print("datetime_now: ", dt, newLine=true);
    print("unix_time: ", unix_time(), newLine=true);

    if (ms >= 49.9 && ms < 150.0) { print("PASS wait(50) measured about 50 ms", newLine=true); } else { print("FAIL wait measurement", newLine=true); };
    if (s1 == 0.0 && s2 == 0.0) { print("PASS clock switch cleared the stopwatch", newLine=true); } else { print("FAIL clock switch did not clear", newLine=true); };
    if (cpu_ms >= 0.0 && cpu_ms < 50.0) { print("PASS back-to-back interval is small and non-negative", newLine=true); } else { print("FAIL back-to-back interval", newLine=true); };
    if (lap >= 19.9 && total >= lap) { print("PASS lap and total are consistent", newLine=true); } else { print("FAIL lap/total", newLine=true); };
    if (b - a >= 9.9 && b - a < 100.0) { print("PASS wall_ms advances", newLine=true); } else { print("FAIL wall_ms", newLine=true); };
    if (dt.length == 19) { print("PASS datetime_now has the YYYY-MM-DD HH:MM:SS shape", newLine=true); } else { print("FAIL datetime_now", newLine=true); };
};