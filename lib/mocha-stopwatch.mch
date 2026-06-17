"""
    mocha-stopwatch v0.1
    Timing and datetime utilities for Mocha
"""

// ── C wrappers ──
function c_print_err(msg: str) -> null native mocha_print_stderr;
function c_exit(code: int) -> null native mocha_exit;
function c_time_ms() -> float native mocha_wrap_time_ms;
function c_unix_time() -> float native mocha_wrap_unix_time;
function c_datetime_now() -> str native mocha_wrap_datetime_now;
function c_date_now() -> str native mocha_wrap_date_now;
function c_time_now() -> str native mocha_wrap_time_now;
function c_ampm_now() -> str native mocha_wrap_ampm_now;
function c_day_now() -> str native mocha_wrap_day_now;
function c_month_now() -> str native mocha_wrap_month_now;
function c_year_now() -> str native mocha_wrap_year_now;
function c_wall_ms() -> float native mocha_wrap_wall_ms;
function c_wait_ms(ms: float) -> null native mocha_stopwatch_wait;

// ── Raw timestamp functions ──

function now_ms() -> float { return c_time_ms(); };
function wall_ms() -> float { return c_wall_ms(); };
function unix_time() -> float { return c_unix_time(); };

// ── Human readable datetime ──

function datetime_now() -> str {
    return c_datetime_now();
};

function date_now() -> str {
    return c_date_now();
};

function time_now() -> str {
    return c_time_now();
};

function ampm_now() -> str {
    return c_ampm_now();
};

function day_now() -> str {
    return c_day_now();
};

function month_now() -> str {
    return c_month_now();
};

function year_now() -> str {
    return c_year_now();
};

// ── Stopwatch class ──

class Stopwatch {
    var start_time: float;
    var stop_time: float;
    var running: int;
    var has_result: int;
    var use_wall: int;  // 0 = cpu time, 1 = wall time

    function constructor() -> null {
        this.start_time = 0.0;
        this.stop_time = 0.0;
        this.running = 0;
        this.has_result = 0;
        this.use_wall = 1;  // default to wall time on Windows
    };

    function use_cpu_time() -> null { this.use_wall = 0; };
    function use_wall_time() -> null { this.use_wall = 1; };

    function begin() -> null {
        if (this.use_wall == 1) {
            this.start_time = c_wall_ms();
        };
        if (this.use_wall == 0) {
            this.start_time = c_time_ms();
        };
        this.running = 1;
        this.has_result = 0;
    };

    function end() -> null {
        if (this.running == 0) {
            c_print_err("MochaStopwatchError: end() called before begin().");
            c_exit(2);
            return;
        };
        if (this.use_wall == 1) { this.stop_time = c_wall_ms(); };
        if (this.use_wall == 0) { this.stop_time = c_time_ms(); };
        this.running = 0;
        this.has_result = 1;
    };

    function elapsed_ms() -> float {
        if (this.has_result == 0 && this.running == 0) {
            c_print_err("MochaStopwatchError: elapsed_ms() called before begin() and end().");
            c_exit(2);
            return 0.0;
        };
        var current: float = 0.0;
        if (this.use_wall == 1) { current = c_wall_ms(); };
        if (this.use_wall == 0) { current = c_time_ms(); };
        if (this.running == 1) { return current - this.start_time; };
        return this.stop_time - this.start_time;
    };

    function elapsed_sec() -> float {
        return this.elapsed_ms() / 1000.0;
    };

    function reset() -> null {
        this.start_time = 0.0;
        this.stop_time = 0.0;
        this.running = 0;
        this.has_result = 0;
    };

    function is_running() -> bool {
        return this.running == 1;
    };

    function wait(ms: float) -> null {
        if (ms < 0.0) {
            c_print_err("MochaStopwatchError: wait() called with negative duration.");
            c_exit(2);
            return;
        };
        c_wait_ms(ms);
    };
};