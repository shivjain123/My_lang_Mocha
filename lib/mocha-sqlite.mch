~~ Mocha-SQLite3 Library
~~ Provides SQLite3 database access for Mocha programs.
~~ Use sqlite3_open() to open a database and sqlite3_close() when done.
~~ Note: SQL strings are passed directly — sanitize user input to avoid injection.

~~ Opens a SQLite3 database file. Creates it if it does not exist.
~~ @param path  file path to the .db file
function sqlite3_open(path: str) -> null native mocha_sqlite3_open;

~~ Executes a SQL statement with no result set (INSERT, UPDATE, DELETE, CREATE).
~~ Returns 0 on success.
~~ @param db   the database handle
~~ @param sql  SQL statement to execute
function sqlite3_exec(db: null, sql: str) -> int native mocha_sqlite3_exec;

~~ Executes a SQL query and stores the result for reading.
~~ Returns 0 on success.
~~ @param db   the database handle
~~ @param sql  SQL SELECT statement
function sqlite3_query(db: null, sql: str) -> int native mocha_sqlite3_query;

~~ Closes a database handle.
~~ @param db  the database handle
function sqlite3_close(db: null) -> null native mocha_sqlite3_close;

~~ Runs a SQL query and caches all results for row/cell access.
~~ Returns 0 on success. Use sqlite3_query_rows() and sqlite3_query_cell() after this.
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

~~ Returns the column name at the given index from the last sqlite3_query_run() result.
~~ @param db   the database handle
~~ @param col  zero-based column index
function sqlite3_query_colname(db: null, col: int) -> str native mocha_sqlite3_query_colname;

~~ Returns the error message from the last failed operation.
~~ @param db  the database handle
function sqlite3_errmsg(db: null) -> str native mocha_sqlite3_errmsg;

~~ Returns the row ID of the last successful INSERT.
~~ @param db  the database handle
function sqlite3_last_rowid(db: null) -> int native mocha_sqlite3_last_rowid;

~~ Returns the number of rows affected by the last INSERT, UPDATE, or DELETE.
~~ @param db  the database handle
function sqlite3_changes(db: null) -> int native mocha_sqlite3_changes;

~~ Returns 1 if a table with the given name exists, 0 otherwise.
~~ @param db     the database handle
~~ @param table  table name to check
function sqlite3_table_exists(db: null, table: str) -> int native mocha_sqlite3_table_exists;