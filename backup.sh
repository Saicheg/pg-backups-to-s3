#!/usr/bin/env bash

# Robust shell script setup
set -e          # Exit immediately if a command exits with a non-zero status
set -u          # Treat unset variables as an error
set -o pipefail # Pipelines fail if any command fails

mkdir -p /opt/dumps/$POSTGRES_HOST;

timestamp=$(date +"%Y-%m-%d %H:%M:%S")
subject=$(echo "${TITLE} - $timestamp")
dump_filename="$(date -Iseconds).pgdump"
dump_path="/opt/dumps/${POSTGRES_HOST}/${dump_filename}"

# Configuration: Control whether to clean up local files after backup
CLEANUP_ENABLED="${CLEANUP_ENABLED:-true}"

# Global variable to track all files created during the backup process
declare -a FILES_TO_CLEANUP=()

# Function to detect if webhook URL is for Slack
is_slack_webhook() {
    local webhook_url="$1"
    if [[ "$webhook_url" =~ hooks\.slack\.com ]] || [[ "$webhook_url" =~ slack\.com/api/webhook ]]; then
        return 0  # true - it's a Slack webhook
    else
        return 1  # false - it's not a Slack webhook
    fi
}

# Function to send webhook notification
send_webhook() {
    local title="$1"
    local status="$2"
    local webhook_url="${WEBHOOK_URL:-}"
    
    if [ -z "$webhook_url" ]; then
        echo "No webhook URL configured, skipping notification" >&2
        return 0
    fi
    
    echo "Sending webhook notification to: $webhook_url" >&2
    echo "Title: $title" >&2
    echo "Status: $status" >&2
    
    local payload=""
    local curl_exit_code=0
    
    if is_slack_webhook "$webhook_url"; then
        echo "Detected Slack webhook, using Slack format" >&2

        # Create Slack-formatted payload
        local status_emoji=""
        case "$status" in
            "Success"*) 
                status_emoji=':white_check_mark:'
                ;;
            "Failure"*|"Failed"*)
                status_emoji=':x:'
                ;;
            *)
                status_emoji=':information_source:'
                ;;
        esac

        # Construct the text field separately to avoid shell expansion issues
        
        local slack_text="${status_emoji} Database Backup Notification"
        local block_text="*${status_emoji} ${title}*"
        
        # Use jq to create Slack blocks payload with proper emoji handling
        payload=$(jq -n \
            --arg text "$slack_text" \
            --arg block_text "$block_text" \
            '{
                text: $text,
                blocks: [
                    {
                        type: "section",
                        text: {
                            type: "mrkdwn",
                            text: $block_text
                        }
                    }
                ]
            }')
    else
        echo "Using generic webhook format" >&2
        payload=$(jq -n --arg title "$title" --arg description "$description" --arg status "$status" '{title: $title, description: $description, status: $status}')
    fi

    echo "Sending webhook payload..." >&2

    set +e
    curl -X POST "$webhook_url" \
        -H 'Content-Type: application/json' \
        -d "$payload" \
        --max-time 30 \
        --retry 2 \
        --retry-delay 5
    curl_exit_code=$?
    set -e

    if [ $curl_exit_code -eq 0 ]; then
        echo "Webhook sent successfully" >&2
        return 0
    else
        echo "Failed to send webhook (exit code: $curl_exit_code)" >&2
        return 1
    fi
}

# Function to send failure webhook with fallback
send_failure_webhook() {
    local title="$1"
    
    echo "Attempting to send failure notification..." >&2
    
    if ! send_webhook "$title" "Failure"; then
        echo "Primary failure webhook failed, attempting fallback..." >&2
        send_webhook "Failed Curl $title" "Failure" || echo "Fallback webhook also failed" >&2
    fi
}

# Function to add file to cleanup list
add_to_cleanup() {
    local file="$1"
    if [ -f "$file" ]; then
        FILES_TO_CLEANUP+=("$file")
        echo "Added to cleanup list: $file" >&2
    fi
}

# Function to perform cleanup of all temporary and backup files
cleanup_files() {
    if [ "$CLEANUP_ENABLED" = "true" ]; then
        echo "Cleaning up all local files..." >&2
        for file in "${FILES_TO_CLEANUP[@]}"; do
            if [ -f "$file" ]; then
                echo "Removing: $file" >&2
                rm -f "$file"
            else
                echo "File already removed: $file" >&2
            fi
        done
        echo "Cleanup completed." >&2
    else
        echo "Cleanup disabled - keeping final backup file, removing intermediate files..." >&2
        # Get the total number of files
        local total_files=${#FILES_TO_CLEANUP[@]}
        
        # Clean up all files except the last one (if there are any files)
        if [ $total_files -gt 1 ]; then
            local i=0
            local limit=$((total_files - 1))
            while [ $i -lt $limit ]; do
                local file="${FILES_TO_CLEANUP[i]}"
                if [ -f "$file" ]; then
                    echo "Removing intermediate file: $file" >&2
                    rm -f "$file"
                else
                    echo "Intermediate file already removed: $file" >&2
                fi
                i=$((i + 1))
            done
        fi
        
        # Report the final file that's being kept
        if [ $total_files -gt 0 ]; then
            local final_file="${FILES_TO_CLEANUP[$((total_files - 1))]}"
            if [ -f "$final_file" ]; then
                echo "Keeping final backup file: $final_file" >&2
            fi
        fi
        
        echo "Selective cleanup completed." >&2
    fi
}

# Function to compress file
compress_file() {
    local input_file="$1"
    local compression_type="${COMPRESSION_TYPE:-none}"
    
    case "$compression_type" in
        "gzip")
            echo "Compressing with gzip..." >&2
            gzip -9 "$input_file"
            echo "${input_file}.gz"
            ;;
        "bzip2")
            echo "Compressing with bzip2..." >&2
            bzip2 -9 "$input_file"
            echo "${input_file}.bz2"
            ;;
        "xz")
            echo "Compressing with xz..." >&2
            xz -9 "$input_file"
            echo "${input_file}.xz"
            ;;
        "none"|"")
            echo "No additional compression applied (pg_dump custom format already compressed)" >&2
            echo "$input_file"
            ;;
        *)
            echo "Warning: Unknown compression type '$compression_type', skipping compression" >&2
            echo "$input_file"
            ;;
    esac
}

# Function to encrypt file
encrypt_file() {
    local input_file="$1"
    local encryption_key="${ENCRYPTION_KEY:-}"
    local encryption_method="${ENCRYPTION_METHOD:-gpg}"
    
    if [ -z "$encryption_key" ]; then
        echo "No encryption key provided, skipping encryption" >&2
        echo "$input_file"
        return 0
    fi
    
    case "$encryption_method" in
        "gpg")
            echo "Encrypting with GPG..." >&2
            local encrypted_file="${input_file}.gpg"
            echo "$encryption_key" | gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 --output "$encrypted_file" "$input_file"
            
            # Verify encryption worked
            if [ $? -eq 0 ] && [ -f "$encrypted_file" ]; then
                rm -f "$input_file"  # Remove unencrypted file
                echo "$encrypted_file"
            else
                echo "Encryption failed, keeping original file" >&2
                echo "$input_file"
            fi
            ;;
        "openssl")
            echo "Encrypting with OpenSSL..." >&2
            local encrypted_file="${input_file}.enc"
            openssl enc -aes-256-cbc -salt -in "$input_file" -out "$encrypted_file" -k "$encryption_key"
            
            # Verify encryption worked
            if [ $? -eq 0 ] && [ -f "$encrypted_file" ]; then
                rm -f "$input_file"  # Remove unencrypted file
                echo "$encrypted_file"
            else
                echo "Encryption failed, keeping original file" >&2
                echo "$input_file"
            fi
            ;;
        *)
            echo "Warning: Unknown encryption method '$encryption_method', skipping encryption" >&2
            echo "$input_file"
            ;;
    esac
}

# Temporarily disable exit on error to capture pg_dump exit status
set +e
PGPASSWORD=$POSTGRES_PASSWORD pg_dump -h $POSTGRES_HOST -U $POSTGRES_USER -p $POSTGRES_PORT --format=custom --clean --verbose --create --file $dump_path $POSTGRES_DB
DUMP_EXIT_CODE=$?
set -e

if [ $DUMP_EXIT_CODE -eq 0 ]; then
  echo "Dump executed successfully."
  
  # Add initial dump file to cleanup list
  add_to_cleanup "$dump_path"
  
  # Apply compression if requested
  final_file_path=$(compress_file "$dump_path")
  
  # If compression changed the file, add the new file to cleanup and remove old file from list if different
  if [ "$final_file_path" != "$dump_path" ]; then
    add_to_cleanup "$final_file_path"
  fi
  
  # Apply encryption if requested
  encrypted_file_path=$(encrypt_file "$final_file_path")
  
  # If encryption changed the file, add the new file to cleanup
  if [ "$encrypted_file_path" != "$final_file_path" ]; then
    add_to_cleanup "$encrypted_file_path"
  fi
  
  # Use the final file (encrypted or not)
  final_file_path="$encrypted_file_path"
  
  # Extract just the filename for S3 upload
  final_filename=$(basename "$final_file_path")
  
  echo "Final backup file: $final_file_path"
  
  # Upload to S3 if S3_BUCKET is configured
  if [ -n "${S3_BUCKET:-}" ]; then
    echo "Uploading dump to S3..."
    s3_key="${S3_PREFIX:-backups}/${POSTGRES_HOST}/${final_filename}"
    
    set +e
    aws s3 cp "$final_file_path" "s3://${S3_BUCKET}/${s3_key}" ${S3_OPTIONS:-}
    S3_EXIT_CODE=$?
    set -e
    
    if [ $S3_EXIT_CODE -eq 0 ]; then
      echo "Successfully uploaded to S3: s3://${S3_BUCKET}/${s3_key}"
      upload_status="Success - Uploaded to S3"
    else
      echo "Failed to upload to S3"
      upload_status="Success - S3 Upload Failed"
    fi
  else
    echo "S3 not configured - backup stored locally only"
    upload_status="Success - Local Only"
  fi
  
  # Always clean up local files after processing (regardless of S3 configuration or upload success)
  cleanup_files
  
  if [ -n "${WEBHOOK_URL:-}" ]; then
    send_webhook "$subject" "$upload_status"
  fi
else
  echo "Failed to Execute Dump"
  
  # Clean up any files that may have been created even if dump failed
  add_to_cleanup "$dump_path"
  cleanup_files
  
  if [ -n "${WEBHOOK_URL:-}" ]; then
    send_failure_webhook "$subject"
  fi
fi
