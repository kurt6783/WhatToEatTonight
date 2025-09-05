#!/bin/bash

# Configuration
DB_FILE="sqlite.db"
TABLES=("ingredients")  # List of tables to process
LOG_FILE="migration.log"

# Function to log messages
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

# Function to check if a file exists
check_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        log "ERROR: File $file not found."
        exit 1
    fi
}

# Function to execute SQL file
execute_sql() {
    local sql_file="$1"
    local description="$2"
    log "Executing $description from $sql_file..."
    sqlite3 "$DB_FILE" < "$sql_file"
    if [ $? -eq 0 ]; then
        log "$description executed successfully."
    else
        log "ERROR: Failed to execute $description from $sql_file."
        exit 1
    fi
}

# Check if sqlite3 is installed
if ! command -v sqlite3 &> /dev/null; then
    log "ERROR: sqlite3 is not installed. Please install it first."
    exit 1
fi

# Check if database file exists
if [ ! -f "$DB_FILE" ]; then
    log "Database file $DB_FILE does not exist. Creating new database..."
    touch "$DB_FILE"
fi

# Initialize log file
> "$LOG_FILE"
log "Starting migration process..."

# Process each table
for TABLE_NAME in "${TABLES[@]}"; do
    log "Processing table: $TABLE_NAME"

    # Define schema and data SQL files
    SCHEMA_SQL="${TABLE_NAME}_schema.sql"
    DATA_SQL="${TABLE_NAME}_data.sql"

    # Check if SQL files exist
    check_file "$SCHEMA_SQL"
    check_file "$DATA_SQL"

    # Check if table exists
    TABLE_EXISTS=$(sqlite3 "$DB_FILE" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='$TABLE_NAME';")

    if [ "$TABLE_EXISTS" -eq 0 ]; then
        log "Table $TABLE_NAME does not exist. Running schema migration..."
        execute_sql "$SCHEMA_SQL" "Schema migration for $TABLE_NAME"
    else
        log "Table $TABLE_NAME already exists."
    fi

    # Check if table is empty
    ROW_COUNT=$(sqlite3 "$DB_FILE" "SELECT count(*) FROM $TABLE_NAME;")

    if [ "$ROW_COUNT" -eq 0 ]; then
        log "Table $TABLE_NAME is empty. Inserting seed data..."
        execute_sql "$DATA_SQL" "Seed data for $TABLE_NAME"
    else
        log "Table $TABLE_NAME contains $ROW_COUNT rows. Skipping seed data insertion."
    fi
done

log "Migration process completed successfully."