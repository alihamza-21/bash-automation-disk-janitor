# Disk Janitor: Automated Bash Cleanup

This script monitors disk usage and automatically cleans up logs and large files when a threshold is hit.

## Features
- Alerts via **Slack** 
- Compresses logs older than 7 days
- Deletes files older than 90 days
- Includes a `--dry-run` mode for safety

## Setup
1. Clone the repo: `git clone <your-repo-link>`
2. Add your Slack Webhook URL inside the script.
3. Make it executable: `chmod +x disk_janitor.sh`

## Usage
```bash
./disk_janitor.sh --dry-run  # To test
./disk_janitor.sh            # To execute


To make this script truly "DevOps-ready" for your audience, suggest they add it to their crontab to run every hour:

# Edit crontab
crontab -e

# Add this line to run every hour
0 * * * * /usr/local/bin/disk_janitor.sh >> /var/log/disk_janitor_cron.log 2>&1# bash-automation-disk-janitor
