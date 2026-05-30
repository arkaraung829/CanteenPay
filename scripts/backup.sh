#!/bin/bash
# Paynow MM Database Backup Script
# Run daily via cron: 0 2 * * * /path/to/backup.sh
#
# Requires: supabase CLI logged in, or pg_dump with connection string
# Get connection string from Supabase Dashboard → Settings → Database → Connection String

BACKUP_DIR="$HOME/paynow_backups"
DATE=$(date +%Y-%m-%d_%H%M)
FILENAME="paynow_backup_${DATE}.sql"

mkdir -p "$BACKUP_DIR"

# Option 1: Using Supabase CLI (simpler)
# supabase db dump --project-ref quwwkpbiovsaujhtkgzt > "$BACKUP_DIR/$FILENAME"

# Option 2: Using pg_dump (more reliable)
# Replace YOUR_DB_PASSWORD with your database password from Supabase Dashboard
DB_HOST="db.quwwkpbiovsaujhtkgzt.supabase.co"
DB_PORT="5432"
DB_NAME="postgres"
DB_USER="postgres"
# DB_PASSWORD from environment variable
export PGPASSWORD="${DB_PASSWORD:-your_password_here}"

pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  --no-owner --no-acl \
  -F c \
  -f "$BACKUP_DIR/$FILENAME.dump"

# Compress
gzip "$BACKUP_DIR/$FILENAME.dump" 2>/dev/null

# Keep only last 30 days
find "$BACKUP_DIR" -name "paynow_backup_*" -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR/$FILENAME"
