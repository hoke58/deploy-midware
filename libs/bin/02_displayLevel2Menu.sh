#!/bin/bash
lvl2ShellPath=$(dirname `readlink -f ${BASH_SOURCE[0]}`)
source ${lvl2ShellPath}/03_displayLevel3Menu.sh
 
dislayAllInstances(){
  docker ps -a
}

export lvl2_selected_function=none
export lvl2_selected_cmd=none

function displayLevel2Menu(){
  echo "" 
  echo "************************ Level2 Function Menu ***********************************"
  echo "Component: $(colorEcho $BLUE ${lvl1_selected_comp})"
  echo "*********************************************************************************"
  echo "-------- 1/A：Up $lvl1_selected_comp container"
  echo "-------- 2/B：Down $lvl1_selected_comp container"
  echo "-------- 3/C：Backup $lvl1_selected_comp"
  echo "-------- 4/D：Execute Command"
  echo "-------- 5/E：Clean $lvl1_selected_comp"
  echo "-------- 6/N：Return to previous Menu" 
  echo "-------- 7/Q：Quit"
  echo "*********************************************************************************"
  
  lvl2Select
}

lvl2Select(){
   while true; do
      read  -p "Please select Option:" option
      flag=$(echo $option|egrep "[0-9]|[A-Ea-e,Nn,Qq]" |wc -l)
      [ $flag -eq 1 ] && break
   done
  
   case $option in
   1|A|a)
       lvl2_selected_function=Up_Container
       displayLevel3Menu
   ;;
   2|B|b)
       lvl2_selected_function=Down_Container
       displayLevel3Menu
   ;;
   3|C|c)
       lvl2_selected_function=Backup
       displayLevel3Menu
   ;;
   4|D|d)
      lvl2_selected_function=Execute_Command
      displayLevel3Menu
   ;;
   5|E|e)
      lvl2_selected_function=Clean
      displayLevel3Menu
   ;;
   6|N|n)
      displayMainMenu
   ;;
   7|Q|q)
      colorEcho "byebye!"
      exit 0
   ;;
   *)
      colorEcho $RED "ERROR:invalid input"
      sleep 1
      lvl2Select
    ;;
  esac
}
