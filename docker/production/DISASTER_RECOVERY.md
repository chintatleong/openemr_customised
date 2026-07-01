# OpenEMR Production Disaster Recovery Guide

**System:** OpenEMR (Docker Compose on macOS)
**Last Updated:** 2026-07-01

---

# 1. System Overview

This OpenEMR instance runs locally on macOS using Docker Desktop and Docker Compose.

## Software

- Docker Desktop
- Docker Compose
- OpenEMR
- MariaDB

## Deployment Directory

```bash
~/openemr/docker/production
```

---

# 2. Directory Structure

```text
production/
├── docker-compose.yml
├── backup.sh
├── restore.sh
├── DISASTER_RECOVERY.md
├── backups/
│   ├── database/
│   ├── sites/
│   ├── logs/
│   ├── backup.log
│   └── backup-history.csv
└── data/
    ├── mysql/
    ├── sites/
    └── logs/
```

---

# 3. Important Principle

Docker containers are disposable.

The actual clinic data lives in:

```text
production/data/
```

The backup and recovery data lives in:

```text
production/backups/
```

The Docker containers themselves contain no important data.

---

# 4. Starting OpenEMR

Navigate to the deployment directory:

```bash
cd ~/openemr/docker/production
```

Start OpenEMR:

```bash
docker compose up -d
```

Check status:

```bash
docker compose ps
```

Open OpenEMR:

```text
http://localhost
https://localhost
```

---

# 5. Stopping OpenEMR

Stop the application:

```bash
docker compose down
```

---

# 6. Verify Running Containers

Check container status:

```bash
docker compose ps
```

Expected:

```text
NAME                 STATUS
production-mysql-1   Up (healthy)
production-openemr-1 Up (healthy)
```

View logs:

```bash
docker compose logs mysql
docker compose logs openemr
```

Tail logs:

```bash
docker compose logs -f openemr
```

---

# 7. Manual Backup

Run a backup:

```bash
./backup.sh
```

Verify backup history:

```bash
tail backups/backup-history.csv
```

Verify files exist:

```bash
ls backups/database
ls backups/sites
ls backups/logs
```

---

# 8. Scheduled Backup

Scheduled backups use macOS launchd.

## Service Name

```text
com.openemr.backup
```

## Verify Scheduler Loaded

```bash
launchctl list | grep openemr
```

Expected:

```text
-       0       com.openemr.backup
```

## Run Backup Immediately

```bash
launchctl start com.openemr.backup
```

## View Scheduler Logs

```bash
tail backups/launchd.log
cat backups/launchd.err
```

---

# 9. Backup Files

## Database Backup

Contains:

- patients
- encounters
- notes
- appointments
- billing
- configuration
- users
- permissions

Location:

```text
backups/database/
```

Example:

```text
openemr-2026-07-01_20-49-26.sql
```

---

## Sites Backup

Contains:

- uploaded PDFs
- x-rays
- photos
- scans
- patient documents
- OpenEMR site configuration
- sqlconf.php

Location:

```text
backups/sites/
```

Example:

```text
sites-2026-07-01_20-49-26.tar
```

---

## Logs Backup

Contains:

- Apache logs
- OpenEMR logs

Location:

```text
backups/logs/
```

Example:

```text
logs-2026-07-01_20-49-26.tar.gz
```

---

# 10. Restore Procedure

List available backups:

```bash
ls backups/database
```

Restore:

```bash
./restore.sh YYYY-MM-DD_HH-MM-SS
```

Example:

```bash
./restore.sh 2026-07-01_20-49-26
```

The restore process:

1. Stops containers
2. Deletes current database
3. Deletes current site data
4. Starts MariaDB
5. Restores database
6. Recreates database user permissions
7. Restores documents and site files
8. Starts OpenEMR

Verify:

```bash
docker compose ps
```

Open:

```text
http://localhost
```

---

# 11. Disaster Recovery Procedure

If the Mac dies or needs rebuilding:

## Step 1

Install:

- macOS
- Docker Desktop
- Git

---

## Step 2

Clone repository:

```bash
git clone <repository>
cd production
```

---

## Step 3

Restore backup files:

```text
production/backups/
```

---

## Step 4

Restore persistent data:

```text
production/data/
```

---

## Step 5

Start services:

```bash
docker compose up -d
```

---

## Step 6

If restoring from backup archives:

```bash
./restore.sh <timestamp>
```

---

## Step 7

Verify:

```bash
docker compose ps
```

Login to OpenEMR.

Verify:

- patients
- encounters
- notes
- uploaded documents
- users
- appointments

---

# 12. Database Credentials

## MariaDB Root

```text
Username: root
Password: stored in password manager
```

## OpenEMR Database

```text
Database: openemr
Username: openemr
Password: stored in password manager
```

---

# 13. OpenEMR User Accounts

Do NOT store passwords here.

Store credentials in:

- Apple Passwords
- Bitwarden
- 1Password
- other password manager

Document only the existence of accounts:

```text
Admin account
Dentist account(s)
Staff account(s)
```

---

# 14. Backup Retention Policy

Current retention:

```text
30 days
```

Current backup frequency:

```text
Daily at 2:00 AM
```

Backups include:

- MariaDB dump
- OpenEMR sites
- OpenEMR logs

---

# 15. Future Improvements

Planned:

- External USB backup
- Offsite backup
- Backup encryption
- Quarterly disaster recovery testing

---

# 16. Useful Commands

Check containers:

```bash
docker compose ps
```

Start:

```bash
docker compose up -d
```

Stop:

```bash
docker compose down
```

View logs:

```bash
docker compose logs openemr
docker compose logs mysql
```

Follow logs:

```bash
docker compose logs -f openemr
```

Run backup:

```bash
./backup.sh
```

Run restore:

```bash
./restore.sh <timestamp>
```

Run scheduled backup immediately:

```bash
launchctl start com.openemr.backup
```

Check scheduler:

```bash
launchctl list | grep openemr
```

View scheduler logs:

```bash
tail backups/launchd.log
cat backups/launchd.err
```

---

# Final Reminder

Remember:

```text
Docker containers are software.

production/data/
    =
    the clinic

production/backups/
    =
    the clinic insurance policy
```

If both `data/` and `backups/` are safe, the clinic can always be recovered.