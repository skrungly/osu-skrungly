#! /bin/sh

# assigns DB_USER, DB_PASS, DB_NAME from .env
eval "$(grep 'DB_.*=.*' .env)"
COMPOSE_NAME=$(basename $(pwd))

if [ -z "$1" ]
  then
    echo "error: expected argument <path> to backup dir"
    exit 2
fi

if [ ! -d "$1" ]
  then
    echo "error: no such backup found"
    exit 1
fi

echo "info: recovering from $1..."
echo "info: isolating mysql service..."
docker compose down
docker compose up --wait mysql

echo "info: restoring mysql tables..."
docker compose exec -T -e MYSQL_PWD=$DB_PASS mysql \
    mysql -u $DB_USER $DB_NAME < $1/backup.sql

echo "info: starting bancho with fresh .data dir..."
docker volume rm ${COMPOSE_NAME}_data
docker compose up --wait bancho

echo "info: restoring bancho .data dir..."
cat $1/data.tar | docker-compose exec -iT bancho tar x -C /

docker compose down
echo "info: done!"
