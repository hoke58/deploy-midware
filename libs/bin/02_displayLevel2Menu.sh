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
 
   lvl2_selected_function=none  
   lvl2_selected_cmd=none

   while true; do
      read  -p "Please select Option:" option
      flag=$(echo $option|egrep "[0-9]|[A-Ha-h,Qq]" |wc -l)
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
      if [ "${lvl1_selected_comp}" == "nginx" ]; then
         local nginx_command=(vhost proxy)
         while true; do
            echo -e "select command:"
            for ((i=1;i<=${#nginx_command[@]};i++ )); do
               hint="${nginx_command[$i-1]}"
               echo -e "${i}) ${hint}"
            done
            read -p "Select command（default: ${nginx_command[0]}）:" input_nu
            [ -z "$input_nu" ] && input_nu=1
            expr ${input_nu} + 1 &>/dev/null
            if [ $? -ne 0 ]; then
               colorEcho $RED "ERROR: invalid input"
               continue
            fi
            if [[ "$input_nu" -lt 1 || "$input_nu" -gt ${#nginx_command[@]} ]]; then
               colorEcho ${RED} "Error: invalid input， number must be between 1 to ${#nginx_command[@]}"
               continue
            fi
            EXCUTE_COMMAND=${nginx_command[$input_nu-1]}
            break
         done
      elif [ "${lvl1_selected_comp}" == "rabbitmq" ]; then
         local command_list=(status setha exchange)
         while true; do
            echo -e "select command:"
            for ((i=1;i<=${#command_list[@]};i++ )); do
               hint="${command_list[$i-1]}"
               echo -e "${i}) ${hint}"
            done
            read -p "Select command（default: ${command_list[0]}）:" input_nu
            [ -z "$input_nu" ] && input_nu=1
            expr ${input_nu} + 1 &>/dev/null
            if [ $? -ne 0 ]; then
               colorEcho $RED "ERROR: invalid input"
               continue
            fi
            if [[ "$input_nu" -lt 1 || "$input_nu" -gt ${#command_list[@]} ]]; then
               colorEcho ${RED} "Error: invalid input， number must be between 1 to ${#command_list[@]}"
               continue
            fi
            EXCUTE_COMMAND=${command_list[$input_nu-1]}
            break
         done

      fi 

      if [ "${lvl1_selected_comp}" == "mongodb" -o "${lvl1_selected_comp}" == "postgresql" ]; then
         colorEcho $YELLOW "Directly press enter to initialize, if first installation"
         colorEcho $YELLOW "Or input script filename to invoke script, one by one"
         read  -p "Press Enter or Input File name:" cmd1 
         flag=$(echo "$cmd1" |grep -E "^$|*\.sql$|*\.sh|*\.bash$|*\.js$" |wc -l)
         if [ $flag -eq 1 ];then
            if [ -z $cmd1 ]; then
               lvl2_selected_cmd="none"
            else
               lvl2_selected_cmd="$cmd1"
            fi
            displayLevel3Menu
         fi
      elif [ "${lvl1_selected_comp}" == "nginx" -o "${lvl1_selected_comp}" == "rabbitmq" ]; then
         lvl2_selected_cmd="$EXCUTE_COMMAND"
         displayLevel3Menu
      else
         colorEcho "function currently not supported!!"
         lvl2Select
      fi
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
