#!/bin/sh

# Robust shell script setup
set -e          # Exit immediately if a command exits with a non-zero status
set -u          # Treat unset variables as an error
set -o pipefail # Pipelines fail if any command fails

# Environment variable validation
echo "Validating required environment variables..."

# Required environment variables
REQUIRED_VARS="POSTGRES_HOST POSTGRES_PORT POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB CRON_TIME TITLE"

# Check each required variable
for var in $REQUIRED_VARS; do
    eval value=\$$var
    if [ -z "$value" ]; then
        echo "ERROR: Required environment variable '$var' is not set or empty"
        exit 1
    else
        echo "✓ $var is set"
    fi
done

# Optional variables (warn if not set)
if [ -z "${WEBHOOK_URL:-}" ]; then
    echo "WARNING: WEBHOOK_URL is not set - notifications will be disabled"
fi

# Validate encryption and compression settings
if [ -n "${ENCRYPTION_KEY:-}" ]; then
    echo "✓ ENCRYPTION_KEY is set - backups will be encrypted"
    
    # Validate encryption method
    encryption_method="${ENCRYPTION_METHOD:-gpg}"
    case "$encryption_method" in
        "gpg"|"openssl")
            echo "✓ Using encryption method: $encryption_method"
            ;;
        *)
            echo "ERROR: Invalid ENCRYPTION_METHOD '$encryption_method'. Supported methods: gpg, openssl"
            exit 1
            ;;
    esac
else
    echo "INFO: ENCRYPTION_KEY not set - backups will not be encrypted"
fi

# Validate compression settings
compression_type="${COMPRESSION_TYPE:-none}"
case "$compression_type" in
    "none"|"gzip"|"bzip2"|"xz"|"")
        if [ "$compression_type" != "none" ] && [ -n "$compression_type" ]; then
            echo "✓ Using additional compression: $compression_type"
        else
            echo "INFO: Using default pg_dump compression only"
        fi
        ;;
    *)
        echo "ERROR: Invalid COMPRESSION_TYPE '$compression_type'. Supported types: none, gzip, bzip2, xz"
        exit 1
        ;;
esac

echo "All required environment variables are properly configured"
echo "Starting backup service..."

echo "${CRON_TIME} /opt/scripts/backup.sh" | crontab -

chmod +x /opt/scripts/backup.sh

echo "Cron starting";

crond -f -L /var/log/cron.log & tail -f /var/log/cron.log;