#!/bin/bash

set -e
set -o pipefail

cd "$(dirname "$0")" || exit 1

if [ -z "$1" ]; then
  echo "Usage: ./restore.sh YYYY-MM-DD_HH-MM-SS"
  echo ""
  echo "Available database backups:"
  ls backups/database/*.sql 2>/dev/null || true
  exit 1
fi

DATE="$1"

DB_BACKUP="./backups/database/openemr-$DATE.sql"
SITE_BACKUP="./backups/sites/sites-$DATE.tar"

MYSQL_ROOT_PASSWORD="root"
OPENEMR_DB="openemr"
OPENEMR_DB_USER="openemr"
OPENEMR_DB_PASS="openemr"

if [ ! -f "$DB_BACKUP" ]; then
  echo "ERROR: Database backup not found: $DB_BACKUP"
  exit 1
fi

if [ ! -f "$SITE_BACKUP" ]; then
  echo "ERROR: Sites backup not found: $SITE_BACKUP"
  exit 1
fi

echo "Restoring OpenEMR backup: $DATE"
echo "Database: $DB_BACKUP"
echo "Sites: $SITE_BACKUP"
echo ""

read -p "This will overwrite current OpenEMR data. Type yes to continue: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Restore cancelled."
  exit 1
fi

echo "Stopping containers..."
docker compose down

echo "Clearing current data..."
rm -rf ./data/mysql/*
rm -rf ./data/sites/*

echo "Starting MariaDB only..."
docker compose up -d mysql

echo "Waiting for MariaDB..."
until docker compose exec -T mysql mariadb -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" >/dev/null 2>&1; do
  sleep 2
done

echo "Creating OpenEMR database..."
docker compose exec -T mysql mariadb -u root -p"$MYSQL_ROOT_PASSWORD" -e "
CREATE DATABASE IF NOT EXISTS $OPENEMR_DB;
"

echo "Restoring OpenEMR database..."
cat "$DB_BACKUP" | docker compose exec -T mysql mariadb -u root -p"$MYSQL_ROOT_PASSWORD" "$OPENEMR_DB"

echo "Recreating OpenEMR database user and permissions..."
docker compose exec -T mysql mariadb -u root -p"$MYSQL_ROOT_PASSWORD" -e "
CREATE USER IF NOT EXISTS '$OPENEMR_DB_USER'@'%' IDENTIFIED BY '$OPENEMR_DB_PASS';
ALTER USER '$OPENEMR_DB_USER'@'%' IDENTIFIED BY '$OPENEMR_DB_PASS';
GRANT ALL PRIVILEGES ON $OPENEMR_DB.* TO '$OPENEMR_DB_USER'@'%';
FLUSH PRIVILEGES;
"

echo "Restoring OpenEMR sites/documents..."
tar xf "$SITE_BACKUP"

echo "Fixing site permissions..."
chmod -R u+rwX,go+rX ./data/sites

echo "Starting all containers..."
docker compose up -d

echo "Restore complete."
echo "Open OpenEMR at: https://localhost"