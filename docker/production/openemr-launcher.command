#!/bin/bash

set -e

# If anything fails, keep terminal open
trap 'echo "";
      echo "================================";
      echo "OpenEMR failed to start.";
      echo "Press ENTER to close.";
      echo "================================";
      read' ERR

cd "$(dirname "$0")" || exit 1

export PATH="/Applications/Docker.app/Contents/Resources/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

APP_URL="http://localhost"

echo ""
echo "================================"
echo "Starting OpenEMR launcher..."
echo "================================"
echo ""

if [ ! -d "/Applications/Docker.app" ]; then
  osascript -e 'display alert "Docker Desktop is not installed" message "Please install Docker Desktop first."'
  exit 1
fi

echo "Opening Docker..."
open -a Docker

echo "Waiting for Docker Desktop..."
until docker info >/dev/null 2>&1; do
  sleep 2
done

echo "Docker is running."

if lsof -i :80 >/dev/null 2>&1; then
  echo "Port 80 already in use."
fi

if docker compose ps --status running | grep -q "openemr"; then
  echo "OpenEMR already running."
else
  echo "Starting OpenEMR..."
  docker compose up -d
fi

echo "Waiting for OpenEMR..."
until curl -ks https://localhost/meta/health/readyz >/dev/null 2>&1; do
  sleep 2
done

echo "Opening OpenEMR..."
open "$APP_URL"

echo ""
echo "OpenEMR started successfully."

# close terminal automatically after success
exit 0