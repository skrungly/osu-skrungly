#! /bin/sh

BACKUP_TO_RESTORE=$1

if [ -z "$BACKUP_TO_RESTORE" ]
  then
    echo "error: expected argument <path> to backup dir"
    exit 2
fi

if [ ! -d "$BACKUP_TO_RESTORE" ]
  then
    echo "error: no such backup found"
    exit 1
fi

# assigns DB_USER, DB_PASS, DB_NAME from .env
eval "$(grep 'DB_.*=.*' .env)"
COMPOSE_NAME=$(basename $(pwd))

echo "info: restoring from $BACKUP_TO_RESTORE..."
docker compose down

echo "info: deleting redis volume..."
docker volume rm ${COMPOSE_NAME}_redis

echo "info: starting mysql container..."
docker compose up --wait mysql

echo "info: restoring mysql tables..."
docker compose exec -T -e MYSQL_PWD=$DB_PASS mysql \
    mysql -u $DB_USER $DB_NAME < $BACKUP_TO_RESTORE/backup.sql

echo "info: intialising fresh bancho volume ..."
docker volume rm ${COMPOSE_NAME}_data
docker compose up --no-start bancho

echo "info: restoring .data dir..."
docker cp $BACKUP_TO_RESTORE/.data $COMPOSE_NAME-bancho-1:/srv/root/

docker compose down
echo "info: done!"
