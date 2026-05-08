#!/usr/bin/env bash
# Creates additional databases listed in $MYSQL_MULTIPLE_DATABASES (comma-separated)
# and grants full privileges on each to $MYSQL_USER.
# Runs only on the first boot of the mysql container (when the data dir is empty).
set -euo pipefail

if [ -z "${MYSQL_MULTIPLE_DATABASES:-}" ]; then
    echo "[init] MYSQL_MULTIPLE_DATABASES not set — skipping."
    exit 0
fi

echo "[init] Creating extra databases: $MYSQL_MULTIPLE_DATABASES"

IFS=',' read -ra DBS <<< "$MYSQL_MULTIPLE_DATABASES"
for raw in "${DBS[@]}"; do
    db="$(echo "$raw" | xargs)"   # trim whitespace
    [ -z "$db" ] && continue
    echo "[init] -> $db"
    mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
        CREATE DATABASE IF NOT EXISTS \`$db\`
            CHARACTER SET utf8mb4
            COLLATE utf8mb4_unicode_ci;
        GRANT ALL PRIVILEGES ON \`$db\`.* TO '${MYSQL_USER}'@'%';
EOSQL
done

mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"
echo "[init] Done."
