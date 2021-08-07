#!/bin/bash

declare -A MW_Map_Id2Dir
MW_Map_Id2Dir=(
 [mongodb1]="mongodb1" 
 [mongodb2]="mongodb2"
 [mongodb3]="mongodb3"
 [postgresql1]="postgresql"
 [postgresql2]="postgresql"
 [postgresql3]="postgresql"
 [rabbitmq1]="rabbitmq1"
 [rabbitmq2]="rabbitmq2"
)

declare -i CALL_SUCC=0
declare -i CALL_FAIL=1

MW_Alias=${1?"mongodb/postgresql/rabbitmq"}
MW_func=${2?"function"}
MW_Server=${3?"1/2/3"}
MW_Architecture=${4?"cluster/solo"}
MW_cmd=${@:5}

function MW_getEnvByAliasAndServer() {
  COM_Date=$(date '+%Y%m%d')
  # COM_Time=$(date '+%H%M%s')
  COM_Time=$(date '+%H%M')

  MW_VersionDir=${mainShellPath}/libs/components/${MW_Alias}

  if [ "${MW_Alias}" == "postgresql" -o "${MW_Alias}" == "nginx" ];then
    MW_ContainerNm="${MW_Alias}"
  else
    MW_ContainerNm="${MW_Alias}${MW_Server}"
  fi

  MW_Basename=${MW_Map_Id2Dir[${MW_Alias}${MW_Server}]}
  MW_WkDir=${dynamic_install_userHome}/${MW_Basename}
  if [ "${MW_Alias}" == "postgresql" -o "${MW_Alias}" == "mongodb" ];then
    MW_TmpltYml="${MW_VersionDir}/docker-compose-${MW_Architecture}.yaml"
  else
    MW_TmpltYml="${MW_VersionDir}/docker-compose.yaml"
  fi
  
  MW_Yml=${MW_WkDir}/docker-compose.yaml
  MW_ImgDir=${mainShellPath}/images
  eval MW_ImgVersion="\$global_${MW_Alias}_version"
  MW_ImgFile=${MW_Alias}"-"${MW_ImgVersion}".tar"
  eval MW_ImgID="\$global_${MW_Alias}_imageId"
  
  CONTAINER_ID=`docker ps -aq -f name=$MW_ContainerNm`
  CONTAINER_EXEC="docker exec -i $CONTAINER_ID bash -c"

  MW_BackupDir=${MW_WkDir}/${MW_Alias}_backup
  MW_BackupFile="${MW_BackupDir}/${MW_Alias}${MW_Server}_${COM_Date}${COM_Time}.tgz"
  eval MW_Database="\$global_${MW_Alias}_databases"
  MW_ImgTag="${global_docker_repo}/${MW_Alias}"
  MW_CHK="FAIL"
  MW_Status="NONE"
  # echo "+------------------ ${MW_Alias} variables review -------------------+"
  # echo ""
  # echo "      $MW_Alias path：$(colorEcho ${BLUE} ${MW_WkDir})"
  # echo "      $MW_Alias server：$(colorEcho ${BLUE} ${MW_Server})"
  # echo "      Deploy architecture：$(colorEcho ${BLUE} ${MW_Architecture})"
  # echo ""
  # echo "+--------------------------------------------------------------+"
  
}

function MW_log() {
  logLevel=${1?}
  MW_MSG=${2?}
  if [ ${logLevel} == "ERROR" ];then
    colorEcho $RED "${MW_Alias}${MW_Server} == ${logLevel}: ${MW_MSG}"
    return
  elif [ ${logLevel} == "WARN" ];then
    colorEcho $YELLOW "${MW_Alias}${MW_Server} == ${logLevel}: ${MW_MSG}"
  else
    echo "${MW_Alias}${MW_Server} == ${logLevel}: ${MW_MSG}"
    :
  fi
}

function MW_chkVersion() {
  [[ ! -d ${MW_VersionDir} ]] && MW_log "ERROR" "${FUNCNAME} dir $MW_VersionDir not exist" && return $CALL_FAIL
  [[ ! -f ${MW_TmpltYml} ]] && MW_log "ERROR" "${FUNCNAME} dir $MW_TmpltYml not exist"  && return $CALL_FAIL
  MW_log "DEBUG" "${FUNCNAME} process succed" && return $CALL_SUCC
}

function MW_LoadImg() {
    colorEcho "${GREEN}" "$MW_Alias: $MW_ImgVersion"
    local FILTER_IMAGEID=`docker images |grep $MW_ImgID|awk '{print $3}'`
    if [ -z $FILTER_IMAGEID ]; then
        if [ ! -f ${MW_ImgDir}/${MW_ImgFile} ];then
            curl --fail --connect-timeout 5 -s https://$global_docker_repo &>/dev/null
            check_hub_result=$?
            if [ $check_hub_result -ne 0 ]; then
                MW_log "ERROR" "$FUNCTION image file ${MW_ImgDir}/${MW_ImgFile} not find, or cannot pull $global_docker_repo/$MW_Alias:${MW_ImgVersion}"
                return $CALL_FAIL
            fi
            colorEcho "${GREEN}" "$MW_Alias: $MW_ImgVersion will get it from harbor!"

        else
            docker load -i ${MW_ImgDir}/${MW_ImgFile}
            [[ $? -ne 0 ]] && MW_log "ERROR" "$FUNCTION load image failed " && return $CALL_FAL || return $CALL_SUCC
        fi
    fi
}

function CM_getDockerInfo() {
  echo $1 |awk '{print $1,$2,$4,$5}'
}

function CM_getParamsByName() {
  paramName=$1
  eval "echo \$$paramName"
}

function Execute_Command(){
  # local cmd=${1?"cmd required"}
  # local parm=${@:2}
  # local file=${MW_WkDir}/${cmd}
  # [[ ! -f ${file} ]] && MW_log "ERROR" "$FUNCNAME file  not exist ${file}, execute command failed" && return $CALL_FAIL
  # bash $file $parm

  . $MW_VersionDir/deploy_${MW_Alias}.sh 2 $MW_cmd
  [[ $? -eq $CALL_FAIL ]] && MW_log "ERROR" "${MW_Alias} $FUNCNAME failed" && return $CALL_FAIL
}

function MW_STATUS() {
  serverid=${1?}
  var_ip="dynamic_"${MW_Alias}"_server"${serverid}"_ip"
  var_port="dynamic_"${MW_Alias}"_server"${serverid}"_port"
  svrip=`CM_getParamsByName $var_ip`
  svrport=`CM_getParamsByName $var_port`
  MW_chkDocker
  [[ ${MW_Status} != "UP" ]] && MW_log "ERROR" "${FUNCNAME} middleware ${MW_Alias} not RUNNING" && return $CALL_FAIL

  if [ ${MW_Alias} == "mongodb" ];then
    [[ ${MW_Server} != "1" ]] && MW_log "ERROR" "${FUNCNAME}, Please do mongo cluster status check from server1" && return $CALL_FAIL    
    bash ${MW_Home}/${MW_Alias}/check.sh
    [[ $? -eq $CALL_FAIL ]] && MW_log "ERROR" "$FUNCNAME check mongo cluster status failed" && return $CALL_FAIL
  fi

  if [ ${MW_Alias} == "postgresql" ];then
    [[ ${MW_Server} != "1" ]] && MW_log "ERROR" "${FUNCNAME}, Please do mongo postgresql status check from server1" && return $CALL_FAIL    
    docker exec -i -u postgres postgresql psql -c "select * from pg_stat_replication;"
    [[ $? -eq $CALL_FAIL ]] && MW_log "ERROR" "$FUNCNAME check postgresql cluster status failed" && return $CALL_FAIL
  fi

  MW_log "INFO" "$FUNCNAME ${MW_Alias}${MW_Server} status is Health"
}

function Down_Container() {
  askProceed
  [[ $? -eq $CALL_FAIL ]] && return $CALL_FAIL
  [[ ! -f ${MW_Yml} ]] && MW_log "ERROR" "${MW_Yml} not found" && return $CALL_FAIL
  if [ ${MW_Alias} == "rabbitmq" ]; then
    $CONTAINER_EXEC "chown -R $USER_UID:$GROUP_GID /var/lib/rabbitmq"
  fi  
  docker-compose -f $MW_Yml down
  if [ $? -eq $CALL_FAIL ]; then
    MW_log "ERROR" "$FUNCNAME shutdown ${MW_Alias} failed " && return $CALL_FAIL
  else
    MW_log "INFO" "$FUNCNAME shutdown ${MW_Alias}${MW_Server} SUCC"
  fi
}

function Clean() {
  Down_Container
  [[ $? -eq $CALL_FAIL ]] && return $CALL_FAIL
  [[ -d ${MW_WkDir} ]] && rm -rf ${MW_WkDir}
  MW_log "INFO" "${MW_WkDir} has been clean"
}

function Up_Container() {
  askProceed
  [[ $? -eq $CALL_FAIL ]] && return $CALL_FAIL
  MW_chkVersion
  if [ ${sw} == "Y" ]; then
    MW_log "WARN" "${MW_Alias} is RUNNING!!!"
    askProceed
    [[ $? -eq $CALL_FAIL ]] && return $CALL_FAIL
  fi
  [[ ! -d $MW_WkDir ]] && mkdir -p ${MW_WkDir}
  . $MW_VersionDir/deploy_${MW_Alias}.sh 1
  [[ $? -eq $CALL_FAIL ]] && MW_log "ERROR" "$FUNCNAME failed" && return $CALL_FAIL

  MW_LoadImg
  [[ $? -eq $CALL_FAIL ]] && return $CALL_FAIL
  docker-compose -f $MW_Yml up -d
  if [ $? -eq $CALL_FAIL ]; then
    MW_log "ERROR" "$FUNCNAME startup ${MW_Alias} failed " && return $CALL_FAIL
  else
    MW_log "INFO" "$FUNCNAME startup ${MW_Alias}${MW_Server} SUCC"
  fi
  ## add judge
  [[ ${MW_Alias} =~ "rabbitmq" ]] && . $MW_VersionDir/deploy_${MW_Alias}.sh 3
  [[ ${MW_Alias} =~ "postgres" ]] && [[ ${dynamic_postgresql_numOfServers} -ne 1 ]] && . $MW_VersionDir/deploy_${MW_Alias}.sh 4
}

function Backup() {
  if [ $MW_Alias == "mongodb" -o $MW_Alias == "postgresql" ]; then
    if [ -n `docker ps -aq -f name=^/$MW_ContainerNm` ]; then
      . $MW_VersionDir/deploy_${MW_Alias}.sh 3
    fi
  else  
    [[ ! -d ${MW_BackupDir} ]] && mkdir -p ${MW_BackupDir}
    tar czvf $MW_BackupFile --exclude=logs --exclude=${MW_Alias}_backup -C ${dynamic_install_userHome} $MW_Basename
    MW_log "INFO" "$FUNCNAME Backup ${MW_Alias}${MW_Server} SUCC" 
  fi
}

MW_getEnvByAliasAndServer

$MW_func
