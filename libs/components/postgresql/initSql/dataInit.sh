#!/bin/bash

DB=$(cd sql; ls -d *)
USER=pguser
PASS=pguser123qwe

CONTAINER=postgresql

createDB() {
  local dbname=$1
  docker exec -u postgres $CONTAINER sh -c "psql -l | grep $dbname" &>/dev/null
  if [ $? -ne 0 ]; then
    docker exec -u postgres $CONTAINER sh -c "createdb -E UTF8 -O postgres $dbname"
  fi
}

createUser() {
  docker exec -u postgres $CONTAINER sh -c "psql -t -c '\\du' | grep $USER"
  if [ $? -ne 0 ]; then
    docker exec -u postgres $CONTAINER sh -c "psql -c \"CREATE ROLE $USER WITH PASSWORD '$PASS';\""
    docker exec -u postgres $CONTAINER sh -c "psql -c 'ALTER ROLE $USER WITH LOGIN;'"
 
  fi
}

importSQL() {
  local dbname=$1
  docker exec -u postgres $CONTAINER sh -c "psql -d $dbname -f /opt/${dbname}/public.sql"
  docker exec -u postgres $CONTAINER sh -c "psql -d $dbname -c 'GRANT SELECT,UPDATE,INSERT,DELETE ON ALL TABLES IN SCHEMA PUBLIC to $USER;'"
  docker exec -u postgres $CONTAINER sh -c "psql -d $dbname -c 'GRANT USAGE,UPDATE,SELECT on hibernate_sequence to $USER;'"
}

# main
createUser
for eachdb in ${DB[@]}; do
  createDB $eachdb
  importSQL $eachdb
done
