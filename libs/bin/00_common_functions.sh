#!/bin/bash
export comm_prefix1="dynamic_"
export comm_prefix3="global_"

export RED="31m"      # Error message
export GREEN="32m"    # Success message
export YELLOW="33m"   # Warning message
export BLUE="36m"     # Info message

export USER_UID=`id -u`
export GROUP_GID=`id -g`

verifyResult () {
	if [ $1 -ne 0 ] ; then
      colorEcho ${RED} "ERROR: $2 "
   		exit 1
	fi
}

colorEcho(){
  if [ $# -eq 1 ]; then
    echo "${@}"
  else
    COLOR=$1
    echo -e "\033[${COLOR}${@:2}\033[0m"
  fi
}

askProceed() {
  read -p "Continue? [Y/n] " ans
  case "$ans" in
  y | Y | "")
    echo "Starting..."
    ;;
  n | N)
    echo "Exiting..."
    return 1
    exit 0
    ;;
  *)
    colorEcho ${YELLOW} "Invalid input"
    askProceed
    ;;
  esac
}

getCurrentDate(){
  date +%Y%m%d
}

getTimestamp(){
 local current=`date "+%Y-%m-%d %H:%M:%S"` 
 echo $current
}

getParmByName(){
  local parmName=$1
  #echo $parmName
  local value=`eval echo '$'"${parmName}"`
  #value=`eval echo \${"${parmName}"}`
 
  if [ -z "${parmName}" ];then
     echo "ERROR:${parmName} not configed!"
     exit 1
  fi
  if [ -z "$value" ];then
     echo "ERROR:${parmName}=${value} not updated!"
     exit 1
  fi
  if [ "$value" == "xxx" ];then
     echo "ERROR:${parmName}=${value} not updated!"
     exit 1
  fi
  if [ "$value" == "x.x.x.x" ];then
     echo "ERROR:${parmName}=${value} not updated!"
     exit 1
  fi
  echo $value
}

checkIp(){
  local ip=$1
  for var in `echo $ip | awk -F. '{print $1, $2, $3, $4}'`
   do
     if [ $var -ge 1 -a $var -le 255 ]
     then
        echo "wrong ip format:$ip"
        continue
     else
        exit 1
      fi
   done
}

getContainerNameByServer(){
  comp=$1
  server=$2
}

getServerStatus(){
 local comp=$1
 local server=$2
 if [ "$comp" == "mongodb" -o "$comp" == "rabbitmq" ];then
   name="$comp$server"
 else
   name="$comp"
 fi
 value=`docker ps -a -f name="${name}" --format "{{.Status}}"`
 if [ -z "${value}" ];then
    echo "Uknown"
 else
    echo "$value"
 fi
}

getServerImageVersion(){
 local comp=$1
 local server=$2
 if [ "$comp" == "mongodb" -o "$comp" == "rabbitmq" ];then
   name="$comp$server"
 else
   name="$comp"
 fi
 value=`docker ps -a -f name="${name}" --format "{{.Image}}" |awk -F ':' '{print $2}'`
 if [ -z "${value}" ];then
    echo "Uknown"
 else
    echo "$value"
 fi
}

getServerImageId(){
 local comp=$1
 local server=$2
 if [ "$comp" == "mongodb" -o "$comp" == "rabbitmq" ];then
   name="$comp$server"
 else
   name="$comp"
 fi
 local value=`docker ps -a -f name="${name}" --format "{{.Image}}"`
 if [ -z "${value}" ];then
    echo "Uknown"
 else
    id=`docker images -q "$value"`
    if [ -z "${id}" ];then
       echo "Uknown"
    else
      echo "$id"
    fi
 fi
}

getLocalIps(){
  local ips=`ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`	
  echo "$ips"
}


postgreValidate(){
  cmdParms=${1?}
  local cmdCnt=`echo $cmdParms|awk '{print NF}'`
  local parentPath=${cmdParms%%/*}
  local fileType=${cmdParms##*.}
  fileType=`echo $fileType|tr [:upper:] [:lower:]`
  if [ $cmdCnt -eq 1 ];then
    if [ $parentPath == "platSql" -o $parentPath == "userSql" ];then
      if [ $fileType == "sql" ];then
        echo "PSQL"
        return 0
      fi
    fi
  fi
  #dbInit_boc  platShell  platSql  userShell  userSql
}

getSQLFullPath(){
  local func=$3
  local middle=""
  local path=""
  if [ "$unit" == "web" -o "$unit" == "app" -o $unit == "middleware" -o $unit == "fabric" ];then
     middle="${unit}_"
  fi
  local name="${autoshell_prefix}${middle}${func}.sh"
  
  echo "${path}/${name}"

}

invokePSQL() {
  local unit=${1?}
  local comp=${2?}
  local func=${3?"function is required"}
  local server=$4
  local cmdPath=${5?}
  local path="$(getUserHome)/libs/components/${unit}/${comp}"
  local subpath=${cmdPath%/*}
  local fileName=${cmdPath##*/}
  local fullFilePath=$path/$subpath/${fileName}
  local pgDockerShellPath=/opt/scripts/${subpath}
  echo "###################### invoke PSQL start #############################"
  docker exec postgresql mkdir -p ${pgDockerShellPath}
  docker cp ${fullFilePath} postgresql:${pgDockerShellPath}
  docker exec postgresql psql hbcc postgres -f ${pgDockerShellPath}/${fileName}
  echo "###################### invoke PSQL end #############################"
}

invokeFunction(){
  local comp=${1?"comp is required"}
  local func=${2?"function is required"}
  local server=$3
  local mode=$4
  local cmd=${@:5}

  colorEcho "=============================================================="
  echo "INFO: starting to invoke $(colorEcho $BLUE function[${func}]) for $(colorEcho $BLUE server[${server}]) of application $(colorEcho $BLUE ${comp})"
  local shell=${mainShellPath}/libs/bin/entry.sh
  verifyResult $? "locate auto shell failed, function not supported, will be released in future!!"  
  
  if [ ! -f "${shell}" ];then
     colorEcho $RED "ERROR: [${shell}] not found, function not supported, will be released in future!!"  
  else
     parms="${comp} ${func} ${server} ${mode} ${cmd} "
     colorEcho "lanuching [${shell}]..."
     colorEcho "with parms: ${parms}"
     colorEcho "=============================================================="
     bash ${shell} ${parms}
  fi
}

export -f getParmByName
export -f verifyResult
export -f invokeFunction
export -f askProceed
export -f colorEcho