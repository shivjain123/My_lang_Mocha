~~ Mocha-SQLite3 Library
~~ Provides SQLite3 database access for Mocha programs.
~~ Use sqlite3_open() to open a database and sqlite3_close() when done.
~~ Note: SQL strings are passed directly — sanitize user input to avoid injection.

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

~~ ── Reading query results ──
~~ 1. Call sqlite3_query_run(db, sql) to run a SELECT and cache the whole result.
~~ 2. Ask for the size with sqlite3_query_rows(db) and sqlite3_query_cols(db).
~~ 3. Read values with sqlite3_query_cell(db, row, col) and column names with sqlite3_query_colname(db, col).
~~ Rows and columns are zero-based. An index that is out of range returns an empty string.
~~ The cache belongs to the last sqlite3_query_run() call: running a new query replaces it.
~~ A SQL NULL is returned by sqlite3_query_cell as the text "NULL". To tell it apart from a real
~~ "NULL" string, use sqlite3_query_is_null().
~~ If the query returns no rows, rows and cols are both 0 and column names are not available.
~~ All statements in one sqlite3_query_run() must return the same number of columns.
~~ If the query fails, the cache is left empty.

~~ Runs a SQL query and caches all results for row/cell access.
~~ Returns 0 on success, otherwise a SQLite error code (-1 for a null handle).
~~ The error message is printed, and sqlite3_errmsg() gives it again. 
~~ Use sqlite3_query_rows() and sqlite3_query_cell() after this.
~~ @param db   the database handle
~~ @param sql  SQL SELECT statement
function sqlite3_query_run(db: null, sql: str) -> int native mocha_sqlite3_query_run;

~~ Returns the number of rows in the last sqlite3_query_run() result.
~~ @param db  the database handle
function sqlite3_query_rows(db: null) -> int native mocha_sqlite3_query_rows;

~~ Returns the number of columns in the last sqlite3_query_run() result.
~~ @param db  the database handle
function sqlite3_query_cols(db: null) -> int native mocha_sqlite3_query_cols;

~~ Returns the value of a cell from the last sqlite3_query_run() result.
~~ @param db   the database handle
~~ @param row  zero-based row index
~~ @param col  zero-based column index
function sqlite3_query_cell(db: null, row: int, col: int) -> str native mocha_sqlite3_query_cell;

~~ Returns 1 if the cell is a SQL NULL, 0 otherwise (also 0 for an out-of-range index).
~~ @param db   the database handle
~~ @param row  zero-based row index
~~ @param col  zero-based column index
function sqlite3_query_is_null(db: null, row: int, col: int) -> int native mocha_sqlite3_query_is_null;

~~ Returns the column name at the given index from the last sqlite3_query_run() result.
~~ @param db   the database handle
~~ @param col  zero-based column index
function sqlite3_query_colname(db: null, col: int) -> str native mocha_sqlite3_query_colname;

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