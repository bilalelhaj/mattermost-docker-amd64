#!/bin/bash
set -euo pipefail
umask 077

if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --skip-retention ) ]]; then
    echo "Usage: $0 [--skip-retention]" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="$(basename "${SCRIPT_DIR}")"
BACKUP_DIR="${SCRIPT_DIR}/backups"
TIMESTAMP="$(date +"%F_%H%M%S")"
COMPOSE_FILE="${SCRIPT_DIR}/compose.yaml"

if [ -f "${SCRIPT_DIR}/.env" ]; then
    set -a
    source "${SCRIPT_DIR}/.env"
    set +a
else
    echo "Error: .env file not found in ${SCRIPT_DIR}" >&2
    exit 1
fi

VOL_DATA="${PROJECT_NAME}_mm_data"
VOL_CONFIG="${PROJECT_NAME}_mm_config"
VOL_PLUGINS="${PROJECT_NAME}_mm_plugins"
VOL_CLIENT_PLUGINS="${PROJECT_NAME}_mm_client"

FILE_SQL="db_${PROJECT_NAME}_${TIMESTAMP}.sql"
FILE_DATA="data_${PROJECT_NAME}_${TIMESTAMP}.tar.gz"

# Internal name for Rclone remote
REMOTE="s3store"
REMOTE_BACKUP_DIR="${REMOTE}:${S3_BUCKET}/${PROJECT_NAME}"
REMOTE_RUN_DIR="${REMOTE_BACKUP_DIR}/${TIMESTAMP}"

mkdir -p "${BACKUP_DIR}"

# Use the existing R2 bucket without checking or creating it with the object-scoped token.
rclone_cmd() {
    docker run --rm \
        -v "${BACKUP_DIR}:/data" \
        -e RCLONE_CONFIG_S3STORE_TYPE=s3 \
        -e RCLONE_CONFIG_S3STORE_PROVIDER=Cloudflare \
        -e RCLONE_CONFIG_S3STORE_ENV_AUTH=false \
        -e RCLONE_CONFIG_S3STORE_ACCESS_KEY_ID="${S3_ACCESS_KEY}" \
        -e RCLONE_CONFIG_S3STORE_SECRET_ACCESS_KEY="${S3_SECRET_KEY}" \
        -e RCLONE_CONFIG_S3STORE_ENDPOINT="${S3_ENDPOINT}" \
        -e RCLONE_CONFIG_S3STORE_REGION="${S3_REGION}" \
        -e RCLONE_CONFIG_S3STORE_NO_CHECK_BUCKET=true \
        rclone/rclone:latest \
        "$@"
}

echo "[${TIMESTAMP}] Starting Backup: ${PROJECT_NAME}"

# 1. Database Dump
if ! DB_CONTAINER_ID=$(docker compose -f "${COMPOSE_FILE}" ps -q db) || [[ -z "${DB_CONTAINER_ID}" ]]; then
    echo "Error: Database container not found." >&2
    exit 1
fi

docker exec "${DB_CONTAINER_ID}" pg_dump -U "${MM_DB_USER:-mattermost}" "${MM_DB_NAME:-mattermost}" > "${BACKUP_DIR}/${FILE_SQL}"

# 2. Filesystem Archive
docker run --rm \
  -v "${VOL_DATA}:/mnt/data:ro" \
  -v "${VOL_CONFIG}:/mnt/config:ro" \
  -v "${VOL_PLUGINS}:/mnt/plugins:ro" \
  -v "${VOL_CLIENT_PLUGINS}:/mnt/client/plugins:ro" \
  -v "${BACKUP_DIR}:/backup" \
  alpine \
  sh -c 'umask 077 && tar -czf "$1" -C /mnt data config plugins client/plugins && chown "$2:$3" "$1"' \
  _ "/backup/${FILE_DATA}" "$(id -u)" "$(id -g)"

# 3. S3 Upload
echo "Uploading to S3..."
rclone_cmd copyto "/data/${FILE_SQL}" "${REMOTE_RUN_DIR}/db.sql"
rclone_cmd copyto "/data/${FILE_DATA}" "${REMOTE_RUN_DIR}/data.tar.gz"

if [[ "${1:-}" != --skip-retention ]]; then
    echo "Applying Retention Policy (Delete older than ${S3_RETENTION_DAYS} days)..."
    rclone_cmd delete "${REMOTE_BACKUP_DIR}" --min-age "${S3_RETENTION_DAYS}d" \
        --include '/????-??-??_??????/db.sql' \
        --include '/????-??-??_??????/data.tar.gz' \
        --include "/db_${PROJECT_NAME}_????????_??????.sql" \
        --include "/data_${PROJECT_NAME}_????????_??????.tar.gz"

    find "${BACKUP_DIR}" -name "db_*.sql" -mtime "+${BACKUP_RETENTION_DAYS}" -delete
    find "${BACKUP_DIR}" -name "data_*.tar.gz" -mtime "+${BACKUP_RETENTION_DAYS}" -delete
fi

echo "[$(date +"%Y%m%d_%H%M%S")] Backup Completed"
