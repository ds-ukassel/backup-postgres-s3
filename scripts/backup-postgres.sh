#!/bin/bash
set -eo pipefail

# Required environment variables
: "${POSTGRES_HOST:?Missing POSTGRES_HOST}"
: "${POSTGRES_USER:?Missing POSTGRES_USER}"
: "${POSTGRES_PASSWORD:?Missing POSTGRES_PASSWORD}"
: "${POSTGRES_DATABASE:?Missing POSTGRES_DATABASE}"
: "${MINIO_ENDPOINT:?Missing MINIO_ENDPOINT}"
: "${MINIO_ACCESS_KEY:?Missing MINIO_ACCESS_KEY}"
: "${MINIO_SECRET_KEY:?Missing MINIO_SECRET_KEY}"

# Optional variables with defaults
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DUMP_OWNERS="${POSTGRES_DUMP_OWNERS:-false}"
POSTGRES_DUMP_PRIVILEGES="${POSTGRES_DUMP_PRIVILEGES:-false}"
POSTGRES_TABLES="${POSTGRES_TABLES:-}"
MINIO_BUCKET="${MINIO_BUCKET:-postgres-backups}"
MINIO_PATH="${MINIO_PATH-postgres-backups}"
RETENTION_PERIOD="${RETENTION_PERIOD:-}"
MINIO_COMMAND="${MINIO_COMMAND:-mc}"
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"


PGDUMP_NO_OWNER=""
PGDUMP_NO_PRIVILEGES=""
[ "$POSTGRES_DUMP_OWNERS" = "false" ] && PGDUMP_NO_OWNER="--no-owner"
[ "$POSTGRES_DUMP_PRIVILEGES" = "false" ] && PGDUMP_NO_PRIVILEGES="--no-privileges"

NOW=$(date +%Y%m%d_%H%M%S)

send_webhook_error() {
  if [ -n "$DISCORD_WEBHOOK_URL" ]; then
    echo "[postgres-backup] Sending error notification to Discord webhook..."
    PAYLOAD="{\"content\": \"Backup of PostgreSQL database '$POSTGRES_DATABASE' at $NOW failed!\"}"
    curl -H "Content-Type: application/json" -X POST -d "$PAYLOAD" "$DISCORD_WEBHOOK_URL" || true
  fi
}

trap 'send_webhook_error' ERR

export PGPASSWORD="$POSTGRES_PASSWORD"

echo "[postgres-backup] Starting backup at $NOW..."
$MINIO_COMMAND alias set storage "$MINIO_ENDPOINT" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY"
$MINIO_COMMAND mb -p "storage/$MINIO_BUCKET"

if [ -z "$POSTGRES_TABLES" ]; then
  BACKUP_FILE="${POSTGRES_DATABASE}_${NOW}.sql.gz"

  echo "[postgres-backup] Dumping full database '$POSTGRES_DATABASE' and uploading..."

  # https://www.postgresql.org/docs/current/app-pgdump.html
  pg_dump \
    --host="$POSTGRES_HOST" --port="$POSTGRES_PORT" --username="$POSTGRES_USER" \
    $PGDUMP_NO_OWNER $PGDUMP_NO_PRIVILEGES \
    "$POSTGRES_DATABASE" \
  | gzip -c \
  | $MINIO_COMMAND pipe "storage/$MINIO_BUCKET/$MINIO_PATH/$BACKUP_FILE"

else
  for TABLE in $POSTGRES_TABLES; do
    [ -z "$TABLE" ] && continue # Skip empty table names

    BACKUP_FILE="${POSTGRES_DATABASE}_${TABLE}_${NOW}.sql.gz"

    echo "[postgres-backup] Dumping '$POSTGRES_DATABASE.$TABLE' and uploading..."

    # https://www.postgresql.org/docs/current/app-pgdump.html
    pg_dump \
      --host="$POSTGRES_HOST" --port="$POSTGRES_PORT" --username="$POSTGRES_USER" \
      $PGDUMP_NO_OWNER $PGDUMP_NO_PRIVILEGES \
      --table="$TABLE" "$POSTGRES_DATABASE" \
    | gzip -c \
    | $MINIO_COMMAND pipe "storage/$MINIO_BUCKET/$MINIO_PATH/$BACKUP_FILE"
  done
fi

if [ -n "$RETENTION_PERIOD" ]; then
  echo "[postgres-backup] Deleting backups older than $RETENTION_PERIOD from MinIO..."
  $MINIO_COMMAND rm --recursive --older-than "$RETENTION_PERIOD" --force "storage/$MINIO_BUCKET/$MINIO_PATH/"
fi

echo "[postgres-backup] Backup completed successfully!"
