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
  echo "-------- 1/A：Nginx $(isInstalled nginx)"
  echo "-------- 2/B：MongoDB $(isInstalled mongodb)"
  echo "-------- 3/C：PostgreSQL $(isInstalled postgresql)"
  echo "-------- 4/D：RabbitMQ $(isInstalled rabbitmq)"
  echo "-------- 5/E：Redis $(isInstalled redis)"
  echo "-------- 6/F：MySQL $(isInstalled mysql)"
  echo "-------- 7/G：Keepalive $(isInstalled keepalive)"
  echo "-------- 8/H：Display all local docker instances"
  echo "-------- 9/Q：Quilt"
  echo "*********************************************************************************"

  mainSelect
}

mainSelect()
{
  while true; do
    read -p "Please select Option:" option
    flag=$(echo $option|egrep "[0-9]|[A-Ha-h,Qq]" |wc -l)
    [ $flag -eq 1 ] && break
  done
  
  case $option in
    1|A|a)
       lvl1_selected_comp=nginx
       displayLevel2Menu
    ;;
    2|B|b)
       lvl1_selected_comp=mongodb
       displayLevel2Menu
    ;;
    3|C|c)
       lvl1_selected_comp=postgresql
       displayLevel2Menu
    ;;
    4|D|d)
       lvl1_selected_comp=rabbitmq
       displayLevel2Menu
    ;;
    5|E|e)
       lvl1_selected_comp=redis
       displayLevel2Menu
    ;;
    6|F|f)
       lvl1_selected_comp=mysql
       displayLevel2Menu
    ;;
    7|G|g)
       lvl1_selected_comp=keepalive
       displayLevel2Menu
    ;;    
    8|H|h)
       lvl1_selected_comp=displayDockers
       displayAllInstances
       mainSelect
    ;;
    9|Q|q)
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
