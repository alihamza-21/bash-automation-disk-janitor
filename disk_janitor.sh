#!/bin/bash

# ==============================================================================
# Script Name: disk_janitor.sh
# Description: Automated disk space management with Slack notifications.
# Features: Log rotation, old file cleanup, and Slack alerts.
# ==============================================================================

# 1. 'set -euo pipefail' for robust error handling
# -e: Exit on error, -u: Exit on unset variables, -o pipefail: Catch pipeline errors
set -euo pipefail

# --- Configuration Variables ---
readonly DISK_THRESHOLD=90            # Percentage threshold to trigger cleanup
readonly MOUNT_POINT="/"             # Partition to monitor
readonly LOG_DIR="/var/log/myapp"    # Directory for log cleanup
readonly RETENTION_DAYS_COMPRESS=7   # Compress logs older than this
readonly RETENTION_DAYS_DELETE=90    # Delete logs older than this
readonly SCRIPT_LOG="/var/log/disk_janitor.log"
readonly SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# --- Initialization ---
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "--- DRY RUN MODE ENABLED ---"
fi

# --- Helper Functions ---

log_message() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] - $message" | tee -a "$SCRIPT_LOG"
}

send_slack_notification() {
    local message="$1"
    if [[ -n "$SLACK_WEBHOOK_URL" && "$DRY_RUN" == false ]]; then
        /usr/bin/curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\"}" "$SLACK_WEBHOOK_URL" > /dev/null 2>&1 || true
    fi
}

get_disk_usage() {
    /usr/bin/df -h "$MOUNT_POINT" | /usr/bin/awk 'NR==2 {print $5}' | sed 's/%//'
}

# --- Main Execution Tasks ---

cleanup_logs() {
    log_message "INFO" "Starting log cleanup in $LOG_DIR"
    
    # Compress logs older than X days (ignoring already compressed files)
    log_message "INFO" "Compressing logs older than $RETENTION_DAYS_COMPRESS days..."
    if [ "$DRY_RUN" = true ]; then
        /usr/bin/find "$LOG_DIR" -type f -name "*.log" -mtime +"$RETENTION_DAYS_COMPRESS" -print
    else
        /usr/bin/find "$LOG_DIR" -type f -name "*.log" -mtime +"$RETENTION_DAYS_COMPRESS" -exec /usr/bin/gzip {} \;
    fi

    # Delete compressed logs older than Y days
    log_message "INFO" "Deleting compressed logs older than $RETENTION_DAYS_DELETE days..."
    if [ "$DRY_RUN" = true ]; then
        /usr/bin/find "$LOG_DIR" -type f -name "*.gz" -mtime +"$RETENTION_DAYS_DELETE" -print
    else
        /usr/bin/find "$LOG_DIR" -type f -name "*.gz" -mtime +"$RETENTION_DAYS_DELETE" -delete
    fi
}

identify_large_files() {
    log_message "INFO" "Top 10 largest files in $MOUNT_POINT (over 30 days old):"
    /usr/bin/find "$MOUNT_POINT" -type f -mtime +30 -printf '%s %p\n' 2>/dev/null | \
        /usr/bin/sort -nr | /usr/bin/head -n 10 | /usr/bin/awk '{print $2 " (" $1/1024/1024 " MB)"}' >> "$SCRIPT_LOG"
}

# --- Main Block ---

main() {
    local usage_before
    usage_before=$(get_disk_usage)
    
    if [ "$usage_before" -gt "$DISK_THRESHOLD" ]; then
        log_message "WARN" "Disk usage is at ${usage_before}%. Initiating cleanup."
        
        identify_large_files
        cleanup_logs
        
        local usage_after
        usage_after=$(get_disk_usage)
        
        local summary="🚨 *Disk Janitor Report* 🚨\nServer: $(hostname)\nBefore: ${usage_before}%\nAfter: ${usage_after}%"
        log_message "INFO" "Cleanup complete. New usage: ${usage_after}%"
        send_slack_notification "$summary"
    else
        log_message "INFO" "Disk usage is at ${usage_before}%. No action needed."
    fi
}

main "$@"