#!/bin/bash
getConfigedServer(){

   lvl3_svr_mode="cluster"
   lvl3_svr_id_list[0]="none"
   lvl3_svr_type_list[0]="none"

   local comp="${lvl1_selected_comp/-/_}" 
   local func="${lvl2_selected_function}"
   local prefix="dynamic_${comp}"
   local prefix2="global_${comp}"

#   local parmName="${prefix}_mode";
#   value=$(getParmByName "${parmName}")
#   if [ $? -eq 0 ];then
#      lvl3_svr_mode=$value
#   fi

   local  parmName="${prefix}_numOfServers";
   lvl3_svr_numOfServers=$(getParmByName "${parmName}")
   verifyResult $? "getParmByName failed!${lvl3_svr_numOfServers}"
   if [ -z "$lvl3_svr_numOfServers" ];then
      colorEcho $RED "${parmName} not configed!"
      exit 1
   fi
   if [ $lvl3_svr_numOfServers -gt 1 ];then
      lvl3_svr_mode="cluster"
   else
      lvl3_svr_mode="solo"
   fi

  echo "------------------------------------------------------------------------------------------------------------"
  echo "-[#]-[component][type][instance][Ip address:Port][Status][cfg verion][cfg ImageId][Verion][ ImageId ][Matched?]"
  echo "------------------------------------------------------------------------------------------------------------"
 
  let  i=1
  while ((i<=$lvl3_svr_numOfServers))
  do
    parmName="${prefix}${i}_ip"
    ip=$(getParmByName "${parmName}")
    verifyResult $? "getParmByName failed!${ip}"

    parmName="${prefix}_port"
    port=$(getParmByName "${parmName}")
    verifyResult $? "getParmByName failed!${port}"

    parmName="${prefix2}_version"
    cfgVersion=$(getParmByName "${parmName}")
    verifyResult $? "getParmByName failed!${cfgVersion}"

    parmName="${prefix2}_imageId"
    cfgImageId=$(getParmByName "${parmName}")
    verifyResult $? "getParmByName failed!${cfgImageId}"
     
    local status=""
    if [ "${func}" == "install" ];then
       status="New"
    else
       status=$(getServerStatus "$comp" $i)
    fi

    version=$(getServerImageVersion "$comp" $i)
    imageId=$(getServerImageId "$comp" $i)
 
    local type="";
    flag=`echo "$(getLocalIps)" |grep "$ip" |wc -l` 
    if  [ $flag -eq 1 ];then
        type="local"
    else
       type="remote"
    fi

    sw=""
    if [ "verion" == "cfgVersion" -o "${cfgImageId}" == "${imageId}" ];then
       export sw="Y"
    else
       export sw="N"
    fi

    lvl3_svr_id_list[i]="$i"
    lvl3_svr_type_list[i]="$type"

    if [ "$type" == "local" ];then
       colorEcho $BLUE "-[${i}]-[$comp][${type}][server${i}][${ip}:${port}][${status}][${cfgVersion}][${cfgImageId}][${version}][${imageId}] [$sw]"
    else
       echo "-[${i}]-[$comp][${type}][server${i}][${ip}:${port}][N/A][${cfgVersion}][${cfgImageId}][Unknown][Unknown] [N/A]"
    fi

    let i++
  done
  #echo "${lvl3_svr_id_list[*]}"
  #echo "${lvl3_svr_type_list[*]}"
  echo "------------------------------------------------------------------------------------------------------------"
}

getRunningInstances(){
   
   local containerName="${lvl1_selected_comp}"
   docker ps -a -f name="${containerName}" --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}\t{{.Image}}\t{{.ID}}"
   #docker inspect --format '[{{.Name}}][{{.NetworkSettings.Ports}}][{{.State.Status}}]'
   lvl3_svr_numOfServers=`docker ps -a -f name="${containerName}" |wc -l`
   let lvl3_svr_numOfServers--
}

function displayLevel3Menu(){
     #source "${shell} ${parms}"
  lvl3_selected_server=none
  
  echo ""
  echo "************************ Level3 Server Menu *************************************"
  echo "Component: $(colorEcho $BLUE ${lvl1_selected_comp})  Function: $(colorEcho $BLUE ${lvl2_selected_function}) Command: $(colorEcho $BLUE ${lvl2_selected_cmd})"
  echo ""
  getConfigedServer
  echo " "
  echo "---- 7/R：Refresh screen"
  echo "---- 8/N：Return to previous Menu"
  echo "---- 9/Q：Quit"
  echo "*********************************************************************************"
  lvl3Select
}

lvl3Select(){

  while true; do
    read  -p "Please select Option:" option
    flag=$(echo $option|egrep "[0-9]|[a-z]" |wc -l)
    [ $flag -eq 1 ] && break
  done
  
  case $option in
    1|2|3)
       colorEcho "selected server:${lvl3_svr_type_list[$option]} Server${lvl3_svr_id_list[$option]}"
       if [ "${lvl3_svr_type_list[$option]}" == "remote" ];then
          colorEcho "currently not supported to execute on remote server, please select local server only!"
          lvl3Select
       else
          lvl3_selected_server=$option
          invokeFunction "${lvl1_selected_comp}" "${lvl2_selected_function}" "${lvl3_selected_server}" "${lvl3_svr_mode}" "${lvl2_selected_cmd}" 
       fi
      # lvl3_selected_server=$option
      # invokeFunction "${lvl1_selected_comp}" "${lvl2_selected_function}" "${lvl3_selected_server}" "${lvl3_svr_mode}" "${lvl2_selected_cmd}" 
    ;;
    7|r)
      displayLevel3Menu  
    ;;
    8|n)
      displayLevel2Menu  
    ;;
    9|q)
      colorEcho  "byebye!"
      exit 0
    ;;
    *)
      colorEcho "ERROR: invalid input"
      lvl3Select
    ;;
  esac
}
