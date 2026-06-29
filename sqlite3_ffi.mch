from "mocha-sqlite" import *;

function sqlite_tests(didLoad) -> null {

    // ── 1. Open ────────────────────────────────────────────────────
    print("--- 1. Open ---", newLine=true);
    var db: null = sqlite3_open("mocha_test.db");
    print("db opened", newLine=true);

    // ── 2. Table existence check ───────────────────────────────────
    print("--- 2. Table exists ---", newLine=true);
    print("before create: " + str(sqlite3_table_exists(db, "students")), newLine=true);

    // ── 3. Create and insert ───────────────────────────────────────
    print("--- 3. Create and insert ---", newLine=true);
    sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS students (id INTEGER PRIMARY KEY, name TEXT, grade REAL, passed INTEGER);");
    sqlite3_exec(db, "INSERT INTO students (name, grade, passed) VALUES ('Alice', 92.5, 1);");
    print("Alice rowid: " + str(sqlite3_last_rowid(db)), newLine=true);
    sqlite3_exec(db, "INSERT INTO students (name, grade, passed) VALUES ('Bob', 74.0, 1);");
    print("Bob rowid: "   + str(sqlite3_last_rowid(db)), newLine=true);
    sqlite3_exec(db, "INSERT INTO students (name, grade, passed) VALUES ('Charlie', 45.5, 0);");
    print("Charlie rowid: " + str(sqlite3_last_rowid(db)), newLine=true);
    sqlite3_exec(db, "INSERT INTO students (name, grade, passed) VALUES ('Diana', 88.0, 1);");
    print("Diana rowid: " + str(sqlite3_last_rowid(db)), newLine=true);

    // ── 4. Table exists after create ───────────────────────────────
    print("--- 4. Table exists after create ---", newLine=true);
    print("after create: " + str(sqlite3_table_exists(db, "students")), newLine=true);

    // ── 5. Query all rows ──────────────────────────────────────────
    print("--- 5. Query all ---", newLine=true);
    sqlite3_query_run(db, "SELECT * FROM students;");
    var rows: int = sqlite3_query_rows(db);
    var cols: int = sqlite3_query_cols(db);
    print("rows: " + str(rows) + " cols: " + str(cols), newLine=true);

    var h: int = 0;
    while (h < cols) {
        print(sqlite3_query_colname(db, h) + "\t", newLine=false);
        h++;
    };
    print("", newLine=true);
    print("--------", newLine=true);

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

    // ── 6. Filtered query ──────────────────────────────────────────
    print("--- 6. Filtered query ---", newLine=true);
    sqlite3_query_run(db, "SELECT name, grade FROM students WHERE passed = 1;");
    var rows2: int = sqlite3_query_rows(db);
    print("passed students: " + str(rows2), newLine=true);
    var i2: int = 0;
    while (i2 < rows2) {
        print(sqlite3_query_cell(db, i2, 0) + " — " + sqlite3_query_cell(db, i2, 1), newLine=true);
        i2++;
    };

    // ── 7. Aggregate ───────────────────────────────────────────────
    print("--- 7. Aggregate ---", newLine=true);
    sqlite3_query_run(db, "SELECT AVG(grade), MAX(grade), MIN(grade) FROM students;");
    print("avg: " + sqlite3_query_cell(db, 0, 0), newLine=true);
    print("max: " + sqlite3_query_cell(db, 0, 1), newLine=true);
    print("min: " + sqlite3_query_cell(db, 0, 2), newLine=true);

    // ── 8. Update ──────────────────────────────────────────────────
    print("--- 8. Update ---", newLine=true);
    sqlite3_exec(db, "UPDATE students SET grade = 50.0 WHERE name = 'Charlie';");
    print("rows changed: " + str(sqlite3_changes(db)), newLine=true);
    sqlite3_query_run(db, "SELECT name, grade FROM students WHERE name = 'Charlie';");
    print("Charlie new grade: " + sqlite3_query_cell(db, 0, 1), newLine=true);

    // ── 9. Delete ──────────────────────────────────────────────────
    print("--- 9. Delete ---", newLine=true);
    sqlite3_exec(db, "DELETE FROM students WHERE passed = 0;");
    print("rows deleted: " + str(sqlite3_changes(db)), newLine=true);
    sqlite3_query_run(db, "SELECT COUNT(*) FROM students;");
    print("remaining: " + sqlite3_query_cell(db, 0, 0), newLine=true);

    // ── 10. Error handling ─────────────────────────────────────────
    print("--- 10. Error ---", newLine=true);
    var r8: int = sqlite3_exec(db, "SELECT * FROM nonexistent_table;");
    print("bad query result: " + str(r8), newLine=true);
    print("errmsg: " + sqlite3_errmsg(db), newLine=true);

    // ── 11. Cleanup ────────────────────────────────────────────────
    print("--- 11. Cleanup ---", newLine=true);
    sqlite3_exec(db, "DROP TABLE IF EXISTS students;");
    sqlite3_close(db);
    print("--- SQLite3 Done ---", newLine=true);
};