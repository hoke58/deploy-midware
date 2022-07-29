#!/bin/bash
lvl1ShellPath=$(dirname `readlink -f ${BASH_SOURCE[0]}`)
source ${lvl1ShellPath}/02_displayLevel2Menu.sh

isInstalled(){
  local containerName=$1
  local flag=`docker ps -a --format "table {{.Names}}" |grep $containerName|wc -l`
  [ $flag -eq 1 ] && colorEcho $GREEN "[installed]"
}

displayAllInstances(){
  docker ps -a
}

export lvl1_selected_comp=none
function displayMainMenu(){
  lvl1_selected_comp=none

  echo "************************* Level1 Main Menu **************************************"
  echo "*                     Operation Console version${console_Version}                              *"
  echo "*********************************************************************************"
  echo "-------- 0/A：Nginx $(isInstalled nginx)"
  echo "-------- 1/B：MongoDB $(isInstalled mongodb)"
  echo "-------- 2/C：PostgreSQL $(isInstalled postgresql)"
  echo "-------- 3/D：RabbitMQ $(isInstalled rabbitmq)"
  echo "-------- 4/E：Redis $(isInstalled redis-server)"
  echo "-------- 5/F：Redis Sentinel $(isInstalled redis-sentinel)"
  echo "-------- 6/G：MySQL $(isInstalled mysql)"
  echo "-------- 7/H：Keepalive $(isInstalled keepalive)"
  echo "-------- 8/I: Mongo shake $(isInstalled mongo-shake)"
  echo "-------- 9/J：Display all local docker instances"
  echo "-------- Q：Quit"
  echo "*********************************************************************************"

  mainSelect
}

mainSelect()
{
  while true; do
    read -p "Please select Option:" option
    flag=$(echo $option|egrep "[0-9]|[A-Ka-k,Qq]" |wc -l)
    [ $flag -eq 1 ] && break
  done
  
  case $option in
    0|A|a)
       lvl1_selected_comp=nginx
       displayLevel2Menu
    ;;
    1|B|b)
       lvl1_selected_comp=mongodb
       displayLevel2Menu
    ;;
    2|C|c)
       lvl1_selected_comp=postgresql
       displayLevel2Menu
    ;;
    3|D|d)
       lvl1_selected_comp=rabbitmq
       displayLevel2Menu
    ;;
    4|E|e)
       lvl1_selected_comp=redis
       displayLevel2Menu
    ;;
    5|F|f)
       lvl1_selected_comp=redis_sentinel
       displayLevel2Menu
    ;;
    6|G|g)
       lvl1_selected_comp=mysql
       displayLevel2Menu
    ;;
    7|H|h)
       lvl1_selected_comp=keepalive
       displayLevel2Menu
    ;;    
    8|I|i)
       lvl1_selected_comp="mongo-shake"
       displayLevel2Menu
    ;; 
    9|J|j)
       lvl1_selected_comp=displayDockers
       displayAllInstances
       mainSelect
    ;;
    Q|q)
      colorEcho "byebye!"
      exit 0
    ;;
    *)
      colorEcho "ERROR: invalid input"
      sleep 1
      mainSelect
    ;;
  esac

}

export -f displayMainMenu
