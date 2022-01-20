#!/bin/bash

# Create User and Database

CONTAINER=postgresql

useCase(){
  read -p "y/n: " choice
  case ${choice} in
    y|Y|yes)
      echo "Confirm! Continue..."
      return 0
      ;;
    n|N|no|NO)
      getArgs
      ;;
    *)
      echo "Exit..."
      exit 99
      ;;
  esac
}
# 获取用户和数据库名
getArgs(){
  echo -e "---------------------"
  echo -e "\t1)Create User"
  echo -e "\t2)Create Database"
  echo -e "\t3)Both"
  read -p "Select: " C
  case $C in
  1)
    read -p "User(default pguser): " user
    read -p "Pass(default pguser123): " pass
    echo user: ${user:-pguser}
    echo pass: ${pass:-pguser123}
    if  useCase ;then
      USER=${user}
      PASS=${pass}
    fi
  ;;
  2)
    read -p "Database(default NO, split by blank):" db
    echo db : ${db}
    if useCase; then
      DB=(${db})
    fi
  ;;
  3)
    
    read -p "User(default pguser): " user
    read -p "Pass(default pguser123): " pass
    read -p "Database(default NO, split by blank):" db
    echo user: ${user:-pguser}
    echo pass: ${pass:-pguser123}
    echo db : ${db}
    if  useCase; then
      USER=${user}
      PASS=${pass}
      DB=(${db})
    fi
  ;;
  *)
    exit 88 
  ;;
  esac
}

createDB() {
  local dbname=$1
  echo "Create Databse ${dbname}..."
  docker exec -u postgres $CONTAINER sh -c "psql -l | grep $dbname" &>/dev/null
  if [ $? -ne 0 ]; then
    docker exec -u postgres $CONTAINER sh -c "createdb -E UTF8 -O postgres $dbname"
    docker exec -u postgres $CONTAINER psql -c "alter database $dbname owner to $USER;"
  fi
}

createUser() {
  echo "Create User ${USER}..."
  docker exec -u postgres $CONTAINER sh -c "psql -t -c '\\du' | grep $USER"
  if [ $? -ne 0 ]; then
    docker exec -u postgres $CONTAINER psql -c "create user ${USER} with password "\'${PASS}\'";"
    echo "User: ${USER}     Pass: ${PASS}" >>  $1/User_pass.txt
  fi
}


main (){
getArgs
[ ! -z "${USER}" ] && createUser $1
if [ ! -z "${DB}" ];then
  for eachdb in ${DB[@]}; do
    createDB $eachdb
  done
fi
}

main $1
