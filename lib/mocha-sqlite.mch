"""
mocha-sqlite v0.2 — SQLite3 Database Library for Mocha

Section 1: Connections (sqlite3_open, sqlite3_close)
Section 2: Running SQL (sqlite3_exec, sqlite3_query)
Section 3: Reading Results (sqlite3_query_run, sqlite3_query_rows,
           sqlite3_query_cols, sqlite3_query_cell, sqlite3_query_is_null,
           sqlite3_query_colname, sqlite3_query_free)
Section 4: Status & Helpers (sqlite3_errmsg, sqlite3_last_rowid,
           sqlite3_changes, sqlite3_table_exists)

Notes: sqlite3_open() creates the file if it does not exist and returns an
opaque handle that the other functions take first. Close it with
sqlite3_close; closing twice is safe (the second call warns and is ignored).
SQL strings are passed straight to SQLite, so sanitise user input to avoid
injection. sqlite3_exec and sqlite3_query return 0 on success, otherwise a
SQLite error code (-1 for a null handle), print the error message, and
sqlite3_errmsg() gives it again. sqlite3_query only prints rows to the screen;
to read results in code, use sqlite3_query_run, which returns a result handle
(1 or more, or 0 if the query failed). Read it with rows, cols, cell and
colname (all zero-based, an out-of-range index gives an empty string), then
free it with sqlite3_query_free; every result must be freed, and freeing twice
is safe. Several results can be open at once. A SQL NULL comes back from
sqlite3_query_cell as the text "NULL", so use sqlite3_query_is_null to tell
it from a real "NULL" string. A query with no rows has 0 rows and 0 columns,
with no column names. All statements in one sqlite3_query_run must return the
same number of columns. sqlite3_last_rowid is limited to int, so row IDs above
2147483647 come back wrong.

Part of the Mocha Scientific Library Ecosystem
License: Apache 2.0

"""

~~ Opens a SQLite3 database file. Creates it if it does not exist.
~~ @param path  file path to the .db file
function sqlite3_open(path: str) -> null native mocha_sqlite3_open;

~~ Executes a SQL statement with no result set (INSERT, UPDATE, DELETE, CREATE).
~~ Returns 0 on success, otherwise a SQLite error code (-1 for a null handle).
~~ The error message is printed, and sqlite3_errmsg() gives it again.
~~ @param db   the database handle
~~ @param sql  SQL statement to execute
function sqlite3_exec(db: null, sql: str) -> int native mocha_sqlite3_exec;

~~ Executes a SQL query and prints each row to the screen, one "column: value" line per column,
~~ followed by a line with ---. Nothing is stored for reading later:
~~ to read results in code, use sqlite3_query_run() instead.
~~ Returns 0 on success, otherwise a SQLite error code (-1 for a null handle).
~~ The error message is printed, and sqlite3_errmsg() gives it again.
~~ @param db   the database handle
~~ @param sql  SQL SELECT statement
function sqlite3_query(db: null, sql: str) -> int native mocha_sqlite3_query;

~~ Closes a database handle.
~~ Closing the same handle twice is safe: the second close prints a warning and is ignored.
~~ @param db  the database handle
function sqlite3_close(db: null) -> null native mocha_sqlite3_close;

~~ Reading results: sqlite3_query_run returns a handle (0 if the query failed); 
~~ read it with rows, cols, cell and colname (zero-based), then free it with sqlite3_query_free.

~~ Runs a SQL query and keeps its whole result for row/cell access.
~~ Returns a result handle (1 or more), or 0 if the query failed.
~~ The error message is printed, and sqlite3_errmsg() gives it again.
~~ Free the handle with sqlite3_query_free() when you are done.
~~ @param db   the database handle
~~ @param sql  SQL SELECT statement
function sqlite3_query_run(db: null, sql: str) -> int native mocha_sqlite3_query_run;

~~ Returns the number of rows in a query result.
~~ @param res  the result handle from sqlite3_query_run()
function sqlite3_query_rows(res: int) -> int native mocha_sqlite3_query_rows;

~~ Returns the number of columns in a query result.
~~ @param res  the result handle from sqlite3_query_run()
function sqlite3_query_cols(res: int) -> int native mocha_sqlite3_query_cols;

~~ Returns the value of a cell from a query result.
~~ @param res  the result handle from sqlite3_query_run()
~~ @param row  zero-based row index
~~ @param col  zero-based column index
function sqlite3_query_cell(res: int, row: int, col: int) -> str native mocha_sqlite3_query_cell;

~~ Returns 1 if the cell is a SQL NULL, 0 otherwise (also 0 for an out-of-range index).
~~ @param res  the result handle from sqlite3_query_run()
~~ @param row  zero-based row index
~~ @param col  zero-based column index
function sqlite3_query_is_null(res: int, row: int, col: int) -> int native mocha_sqlite3_query_is_null;

~~ Returns the column name at the given index from a query result.
~~ @param res  the result handle from sqlite3_query_run()
~~ @param col  zero-based column index
function sqlite3_query_colname(res: int, col: int) -> str native mocha_sqlite3_query_colname;

~~ Frees a query result.
~~ Freeing the same handle twice is safe: the second free prints a warning and is ignored.
~~ Freeing 0 (a failed sqlite3_query_run) does nothing.
~~ @param res  the result handle from sqlite3_query_run()
function sqlite3_query_free(res: int) -> null native mocha_sqlite3_query_free;

~~ Returns the error message from the last failed operation.
~~ @param db  the database handle
function sqlite3_errmsg(db: null) -> str native mocha_sqlite3_errmsg;

~~ Returns the row ID of the last successful INSERT.
~~ Row IDs above 2147483647 do not fit in an int and come back wrong.
~~ @param db  the database handle
function sqlite3_last_rowid(db: null) -> int native mocha_sqlite3_last_rowid;

~~ Returns the number of rows affected by the last INSERT, UPDATE, or DELETE.
~~ @param db  the database handle
function sqlite3_changes(db: null) -> int native mocha_sqlite3_changes;

~~ Returns 1 if a table with the given name exists, 0 otherwise.
~~ @param db     the database handle
~~ @param table  table name to check
function sqlite3_table_exists(db: null, table: str) -> int native mocha_sqlite3_table_exists;