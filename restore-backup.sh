#!/usr/bin/env bash

# PostgreSQL Backup Restoration Utility
# This script helps restore backups that may be encrypted and/or compressed

set -e

# Function to display usage
usage() {
    echo "Usage: $0 <backup_file> [options]"
    echo ""
    echo "Options:"
    echo "  -k, --key <key>          Encryption key (required for encrypted backups)"
    echo "  -m, --method <method>    Encryption method: gpg (default) or openssl"
    echo "  -h, --host <host>        PostgreSQL host (default: localhost)"
    echo "  -p, --port <port>        PostgreSQL port (default: 5432)"
    echo "  -U, --username <user>    PostgreSQL username (default: postgres)"
    echo "  -d, --database <db>      Target database name (required)"
    echo "  --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 backup.pgdump.gz.gpg -k 'mypassword' -d restored_db"
    echo "  $0 backup.pgdump.bz2.enc -k 'mypassword' -m openssl -d my_db"
    echo "  $0 backup.pgdump.xz -d my_db  # No encryption"
    exit 1
}

# Default values
ENCRYPTION_KEY=""
ENCRYPTION_METHOD="gpg"
PG_HOST="localhost"
PG_PORT="5432"
PG_USER="postgres"
PG_DATABASE=""
BACKUP_FILE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--key)
            ENCRYPTION_KEY="$2"
            shift 2
            ;;
        -m|--method)
            ENCRYPTION_METHOD="$2"
            shift 2
            ;;
        -h|--host)
            PG_HOST="$2"
            shift 2
            ;;
        -p|--port)
            PG_PORT="$2"
            shift 2
            ;;
        -U|--username)
            PG_USER="$2"
            shift 2
            ;;
        -d|--database)
            PG_DATABASE="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        -*)
            echo "Unknown option $1"
            usage
            ;;
        *)
            if [ -z "$BACKUP_FILE" ]; then
                BACKUP_FILE="$1"
            else
                echo "Multiple backup files specified"
                usage
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "$BACKUP_FILE" ]; then
    echo "Error: Backup file is required"
    usage
fi

if [ -z "$PG_DATABASE" ]; then
    echo "Error: Target database is required"
    usage
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file '$BACKUP_FILE' not found"
    exit 1
fi

echo "Starting backup restoration..."
echo "Backup file: $BACKUP_FILE"
echo "Target database: $PG_DATABASE"

# Create temporary directory for processing
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Determine file processing steps based on file extension
CURRENT_FILE="$BACKUP_FILE"
FINAL_FILE="$TEMP_DIR/backup.pgdump"

# Check if file is encrypted
if [[ "$CURRENT_FILE" == *.gpg ]]; then
    if [ -z "$ENCRYPTION_KEY" ]; then
        echo "Error: GPG encrypted file detected but no encryption key provided"
        exit 1
    fi
    echo "Decrypting GPG file..."
    DECRYPTED_FILE="$TEMP_DIR/$(basename "${CURRENT_FILE%.gpg}")"
    echo "$ENCRYPTION_KEY" | gpg --batch --yes --passphrase-fd 0 --decrypt "$CURRENT_FILE" > "$DECRYPTED_FILE"
    CURRENT_FILE="$DECRYPTED_FILE"
elif [[ "$CURRENT_FILE" == *.enc ]]; then
    if [ -z "$ENCRYPTION_KEY" ]; then
        echo "Error: OpenSSL encrypted file detected but no encryption key provided"
        exit 1
    fi
    echo "Decrypting OpenSSL file..."
    DECRYPTED_FILE="$TEMP_DIR/$(basename "${CURRENT_FILE%.enc}")"
    openssl enc -aes-256-cbc -d -in "$CURRENT_FILE" -out "$DECRYPTED_FILE" -k "$ENCRYPTION_KEY"
    CURRENT_FILE="$DECRYPTED_FILE"
fi

# Check if file is compressed
if [[ "$CURRENT_FILE" == *.gz ]]; then
    echo "Decompressing gzip file..."
    DECOMPRESSED_FILE="$TEMP_DIR/$(basename "${CURRENT_FILE%.gz}")"
    gunzip -c "$CURRENT_FILE" > "$DECOMPRESSED_FILE"
    CURRENT_FILE="$DECOMPRESSED_FILE"
elif [[ "$CURRENT_FILE" == *.bz2 ]]; then
    echo "Decompressing bzip2 file..."
    DECOMPRESSED_FILE="$TEMP_DIR/$(basename "${CURRENT_FILE%.bz2}")"
    bunzip2 -c "$CURRENT_FILE" > "$DECOMPRESSED_FILE"
    CURRENT_FILE="$DECOMPRESSED_FILE"
elif [[ "$CURRENT_FILE" == *.xz ]]; then
    echo "Decompressing xz file..."
    DECOMPRESSED_FILE="$TEMP_DIR/$(basename "${CURRENT_FILE%.xz}")"
    unxz -c "$CURRENT_FILE" > "$DECOMPRESSED_FILE"
    CURRENT_FILE="$DECOMPRESSED_FILE"
fi

# Copy final file if it's not already in the right place
if [ "$CURRENT_FILE" != "$FINAL_FILE" ]; then
    cp "$CURRENT_FILE" "$FINAL_FILE"
fi

echo "Restored backup to: $FINAL_FILE"
echo "Restoring to PostgreSQL database '$PG_DATABASE'..."

# Restore to PostgreSQL
pg_restore -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" --clean --if-exists --verbose "$FINAL_FILE"

echo "Backup restoration completed successfully!"
echo "Database '$PG_DATABASE' has been restored from '$BACKUP_FILE'" 