#!/bin/bash


CONTAINER=postgresql
# 获取用户和数据库名
getArgs(){
  read -p "User(default pguser): " user
  read -p "Pass(default pguser123): " pass
  read -p "Database(default NO, split by blank):" db
  while :
  do
    echo user: ${user}
    echo pass: ${pass}
    echo db : ${db}
    read -p "y/n: " choice
    case ${choice} in
      y|Y|yes)
        echo "Confirm! Continue..."
        break ;;
      n|N|no|NO)
        getArgs
        break
        ;;
      *)
        exit 99 ;;
    esac
  done
}

createDB() {
  local dbname=$1
  docker exec -u postgres $CONTAINER sh -c "psql -l | grep $dbname" &>/dev/null
  if [ $? -ne 0 ]; then
    docker exec -u postgres $CONTAINER sh -c "createdb -E UTF8 -O postgres $dbname"
    docker exec -u postgres $CONTAINER psql -c "alter database $dbname owner to $USER;"
  fi
}

createUser() {
  docker exec -u postgres $CONTAINER sh -c "psql -t -c '\\du' | grep $USER"
  if [ $? -ne 0 ]; then
    docker exec -u postgres $CONTAINER psql -c "create user ${USER} with password "\'${PASS}\'";"
  fi
}


main (){

getArgs
USER=${user:-pguser}
PASS=${pass:-pguser123}
DB=(${db})
createUser
for eachdb in ${DB[@]}; do
  createDB $eachdb
done
}

main
