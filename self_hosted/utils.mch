// ============================================================
// utils.mch — Shared utilities for Mocha self-hosted compiler
// ============================================================

function puts(s: str) -> int native puts;
function exit_program(code: int) -> null native mocha_exit;

function mocha_error(prefix: str, msg: str) -> null {
    puts(prefix + ": " + msg);
    exit_program(1);
};