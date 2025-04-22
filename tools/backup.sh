#! /bin/sh

CATEGORY_NAME=$1
RETAIN_AMOUNT=$2

if [ -z "$CATEGORY_NAME" ]
  then
    echo "error: expected argument <category> (e.g. 'daily')"
    exit 1
fi

# assigns DB_USER, DB_PASS, DB_NAME from .env
eval "$(grep 'DB_.*=.*' .env)"
COMPOSE_NAME=$(basename $(pwd))

CATEGORY_DIR="./backups/$CATEGORY_NAME"
BACKUP_DIR=$CATEGORY_DIR/$(date +%s)
mkdir -p "$BACKUP_DIR"

echo "info: creating backup to $BACKUP_DIR..."
echo "info: archiving bancho .data dir..."
docker cp $COMPOSE_NAME-bancho-1:/srv/root/.data $BACKUP_DIR/.data

echo "info: ensuring that mysql is running..."
MYSQL_CONTAINER=$(docker ps -qf "name=${COMPOSE_NAME}-mysql-1")
if [ -z $MYSQL_CONTAINER ]
  then
    docker compose up -d --wait mysql
fi

echo "info: dumping mysql tables..."
docker exec -e MYSQL_PWD=$DB_PASS ${COMPOSE_NAME}-mysql-1 \
    /usr/bin/mysqldump --no-tablespaces --single-transaction -u $DB_USER $DB_NAME \
    > "$BACKUP_DIR/backup.sql"

# if the mysql server wasn't running before, stop it again
if [ -z MYSQL_CONTAINER ]
  then
    echo "info: mysql wasn't running before. stopping..."
    docker compose stop mysql
fi

if [ -n "$RETAIN_AMOUNT" ]
  then
    backups=$(ls -ld $CATEGORY_DIR/*/ | wc -l)
    if [ $backups -gt $RETAIN_AMOUNT ]
      then
        to_delete=$((backups - $RETAIN_AMOUNT))
        echo "info: purging $to_delete oldest backup(s)..."
        rm -rf $(ls -d $CATEGORY_DIR/*/ | head -$to_delete)
    fi
fi

echo "info: done!"
