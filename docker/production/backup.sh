#!/bin/bash

set -o pipefail

cd "$(dirname "$0")" || exit 1
export PATH="/Applications/Docker.app/Contents/Resources/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

DATE=$(date +"%Y-%m-%d_%H-%M-%S")

BACKUP_ROOT="./backups"
DB_DIR="$BACKUP_ROOT/database"
SITE_DIR="$BACKUP_ROOT/sites"
LOG_DIR="$BACKUP_ROOT/logs"
RUN_LOG="$BACKUP_ROOT/backup.log"
HISTORY_FILE="$BACKUP_ROOT/backup-history.csv"

DB_BACKUP="$DB_DIR/openemr-$DATE.sql"
SITE_BACKUP="$SITE_DIR/sites-$DATE.tar"
LOG_BACKUP="$LOG_DIR/logs-$DATE.tar.gz"

mkdir -p "$DB_DIR" "$SITE_DIR" "$LOG_DIR"

if [ ! -f "$HISTORY_FILE" ]; then
  echo "timestamp,status,database_file,database_size,sites_file,sites_size,logs_file,logs_size,message" > "$HISTORY_FILE"
fi

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$RUN_LOG"
}

fail() {
  log "ERROR: $1"
  echo "$DATE,failed,$DB_BACKUP,${DB_SIZE:-},$SITE_BACKUP,${SITE_SIZE:-},$LOG_BACKUP,${LOG_SIZE:-},$1" >> "$HISTORY_FILE"
  exit 1
}

log "======================================"
log "Starting OpenEMR backup: $DATE"

log "Backing up MariaDB..."
if docker compose exec -T mysql mariadb-dump -u root -proot openemr > "$DB_BACKUP"; then
  [ -s "$DB_BACKUP" ] || fail "Database backup file is empty"
  DB_SIZE=$(du -h "$DB_BACKUP" | cut -f1)
  log "Database backup complete: $DB_BACKUP ($DB_SIZE)"
else
  fail "Database backup failed"
fi

log "Backing up OpenEMR sites/documents..."
if tar cf "$SITE_BACKUP" data/sites; then
  [ -s "$SITE_BACKUP" ] || fail "Sites backup file is empty"
  SITE_SIZE=$(du -h "$SITE_BACKUP" | cut -f1)
  log "Sites backup complete: $SITE_BACKUP ($SITE_SIZE)"
else
  fail "Sites backup failed"
fi

log "Backing up logs..."
if tar czf "$LOG_BACKUP" data/logs; then
  [ -s "$LOG_BACKUP" ] || fail "Logs backup file is empty"
  LOG_SIZE=$(du -h "$LOG_BACKUP" | cut -f1)
  log "Logs backup complete: $LOG_BACKUP ($LOG_SIZE)"
else
  fail "Logs backup failed"
fi

log "Cleaning backups older than 30 days..."
find "$DB_DIR" -name "*.sql" -mtime +30 -delete
find "$SITE_DIR" -name "*.tar" -mtime +30 -delete
find "$LOG_DIR" -name "*.tar.gz" -mtime +30 -delete

echo "$DATE,success,$DB_BACKUP,$DB_SIZE,$SITE_BACKUP,$SITE_SIZE,$LOG_BACKUP,$LOG_SIZE,Backup completed successfully" >> "$HISTORY_FILE"

log "Backup completed successfully"
log "======================================"