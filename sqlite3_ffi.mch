// ── FFI declarations ──
function sqlite3_open(path: str) -> null native mocha_sqlite3_open;
function sqlite3_exec(db: null, sql: str) -> int native mocha_sqlite3_exec;
function sqlite3_query(db: null, sql: str) -> int native mocha_sqlite3_query;
function sqlite3_close(db: null) -> null native mocha_sqlite3_close;
function sqlite3_query_run(db: null, sql: str) -> int native mocha_sqlite3_query_run;
function sqlite3_query_rows(db: null) -> int native mocha_sqlite3_query_rows;
function sqlite3_query_cols(db: null) -> int native mocha_sqlite3_query_cols;
function sqlite3_query_cell(db: null, row: int, col: int) -> str native mocha_sqlite3_query_cell;
function sqlite3_query_colname(db: null, col: int) -> str native mocha_sqlite3_query_colname;
function sqlite3_errmsg(db: null) -> str native mocha_sqlite3_errmsg;
function sqlite3_last_rowid(db: null) -> int native mocha_sqlite3_last_rowid;
function sqlite3_changes(db: null) -> int native mocha_sqlite3_changes;
function sqlite3_table_exists(db: null, table: str) -> int native mocha_sqlite3_table_exists;

function sqlite_tests(didLoad) -> null {

    // ══════════════════════════════════════════
    // SECTION 1 — Open and setup
    // ══════════════════════════════════════════
    print("--- 1. Open ---", newLine=true);
    var db: null = sqlite3_open("mocha_test2.db");
    print("db opened", newLine=true);

    // ══════════════════════════════════════════
    // SECTION 2 — Table existence check
    // ══════════════════════════════════════════
    print("--- 2. Table exists ---", newLine=true);
    var exists: int = sqlite3_table_exists(db, "students");
    print("students exists before create: " + str(exists), newLine=true);  // 0

    // ══════════════════════════════════════════
    // SECTION 3 — Create table and insert
    // ══════════════════════════════════════════
    print("--- 3. Create and insert ---", newLine=true);

    var r1: int = sqlite3_exec(db,
        "CREATE TABLE IF NOT EXISTS students (id INTEGER PRIMARY KEY, name TEXT, grade REAL, passed INTEGER);");
    print("create table: " + str(r1), newLine=true);  // 0

    var r2: int = sqlite3_exec(db,
        "INSERT INTO students (name, grade, passed) VALUES ('Alice', 92.5, 1);");
    print("insert Alice rowid: " + str(sqlite3_last_rowid(db)), newLine=true);

    var r3: int = sqlite3_exec(db,
        "INSERT INTO students (name, grade, passed) VALUES ('Bob', 74.0, 1);");
    print("insert Bob rowid: " + str(sqlite3_last_rowid(db)), newLine=true);

    var r4: int = sqlite3_exec(db,
        "INSERT INTO students (name, grade, passed) VALUES ('Charlie', 45.5, 0);");
    print("insert Charlie rowid: " + str(sqlite3_last_rowid(db)), newLine=true);

    var r5: int = sqlite3_exec(db,
        "INSERT INTO students (name, grade, passed) VALUES ('Diana', 88.0, 1);");
    print("insert Diana rowid: " + str(sqlite3_last_rowid(db)), newLine=true);

    // ══════════════════════════════════════════
    // SECTION 4 — Table exists after create
    // ══════════════════════════════════════════
    print("--- 4. Table exists after create ---", newLine=true);
    var exists2: int = sqlite3_table_exists(db, "students");
    print("students exists after create: " + str(exists2), newLine=true);  // 1

    // ══════════════════════════════════════════
    // SECTION 5 — Query all rows
    // ══════════════════════════════════════════
    print("--- 5. Query all ---", newLine=true);

    sqlite3_query_run(db, "SELECT * FROM students;");
    var rows: int = sqlite3_query_rows(db);
    var cols: int = sqlite3_query_cols(db);
    print("rows: " + str(rows) + " cols: " + str(cols), newLine=true);

    // print header
    var h: int = 0;
    while (h < cols) {
        print(sqlite3_query_colname(db, h) + "\t", newLine=false);
        h++;
    };
    print("", newLine=true);
    print("--------", newLine=true);

    // print rows
    var i: int = 0;
    while (i < rows) {
        var j: int = 0;
        while (j < cols) {
            print(sqlite3_query_cell(db, i, j) + "\t", newLine=false);
            j++;
        };
        print("", newLine=true);
        i++;
    };

    // ══════════════════════════════════════════
    // SECTION 6 — Filtered query
    // ══════════════════════════════════════════
    print("--- 6. Filtered query ---", newLine=true);

    sqlite3_query_run(db, "SELECT name, grade FROM students WHERE passed = 1;");
    var rows2: int = sqlite3_query_rows(db);
    print("passed students: " + str(rows2), newLine=true);  // 3
    var i2: int = 0;
    while (i2 < rows2) {
        print(sqlite3_query_cell(db, i2, 0) + " — " + sqlite3_query_cell(db, i2, 1), newLine=true);
        i2++;
    };

    // ══════════════════════════════════════════
    // SECTION 7 — Aggregate query
    // ══════════════════════════════════════════
    print("--- 7. Aggregate ---", newLine=true);

    sqlite3_query_run(db, "SELECT AVG(grade), MAX(grade), MIN(grade) FROM students;");
    print("avg grade: " + sqlite3_query_cell(db, 0, 0), newLine=true);
    print("max grade: " + sqlite3_query_cell(db, 0, 1), newLine=true);
    print("min grade: " + sqlite3_query_cell(db, 0, 2), newLine=true);

    // ══════════════════════════════════════════
    // SECTION 8 — Update and changes
    // ══════════════════════════════════════════
    print("--- 8. Update ---", newLine=true);

    var r6: int = sqlite3_exec(db,
        "UPDATE students SET grade = 50.0 WHERE name = 'Charlie';");
    print("update result: " + str(r6), newLine=true);          // 0
    print("rows changed: " + str(sqlite3_changes(db)), newLine=true);  // 1

    // verify update
    sqlite3_query_run(db, "SELECT name, grade FROM students WHERE name = 'Charlie';");
    print("Charlie new grade: " + sqlite3_query_cell(db, 0, 1), newLine=true);  // 50.0

    // ══════════════════════════════════════════
    // SECTION 9 — Delete and changes
    // ══════════════════════════════════════════
    print("--- 9. Delete ---", newLine=true);

    var r7: int = sqlite3_exec(db,
        "DELETE FROM students WHERE passed = 0;");
    print("delete result: " + str(r7), newLine=true);          // 0
    print("rows deleted: " + str(sqlite3_changes(db)), newLine=true);  // 1

    sqlite3_query_run(db, "SELECT COUNT(*) FROM students;");
    print("remaining rows: " + sqlite3_query_cell(db, 0, 0), newLine=true);  // 3

    // ══════════════════════════════════════════
    // SECTION 10 — Error message
    // ══════════════════════════════════════════
    print("--- 10. Error ---", newLine=true);

    var r8: int = sqlite3_exec(db, "SELECT * FROM nonexistent_table;");
    print("bad query result: " + str(r8), newLine=true);       // nonzero
    print("errmsg: " + sqlite3_errmsg(db), newLine=true);      // no such table

    // ══════════════════════════════════════════
    // SECTION 11 — Cleanup
    // ══════════════════════════════════════════
    print("--- 11. Cleanup ---", newLine=true);

    sqlite3_exec(db, "DROP TABLE IF EXISTS students;");
    print("table dropped", newLine=true);

    sqlite3_close(db);
    print("--- SQLite3 Tests Done ---", newLine=true);
};