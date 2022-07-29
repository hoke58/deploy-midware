#! /bin/bash

check_container() {
    if [ `docker ps -aq -f name=${MW_ContainerNm}|wc -l` -eq 0 ]; then
        colorEcho $RED "Postgresql容器未安装成功，请执行 docker ps -a 检查容器"
        exit 1
    fi
}

set_master() {
    volumes_slave=$(docker inspect postgresql -f '{{ range .Mounts }}{{ if eq .Destination "/var/lib/postgresql/data" }}{{ print .Source }}{{ end }}{{ end }}')
    if [ -z $volumes_slave ];then
        echo "error postgresql container not exists!"
        exit 1
    else 
        sleep 5
        docker exec -u postgres postgresql psql -c "CREATE ROLE $dynamic_postgres_replication_user REPLICATION LOGIN PASSWORD '$dynamic_postgres_replication_password';"
        docker exec -u postgres postgresql sed -i 's/max_connections = 100\>/max_connections = 1000/' /var/lib/postgresql/data/postgresql.conf 
        docker exec -u postgres postgresql sed -i 's/#password_encryption/password_encryption/' /var/lib/postgresql/data/postgresql.conf 
        docker exec -u postgres postgresql sed -i 's/#wal_level/wal_level/' /var/lib/postgresql/data/postgresql.conf 
        docker exec -u postgres postgresql sed -i "s/#synchronous_commit = on/synchronous_commit = off/" /var/lib/postgresql/data/postgresql.conf
        docker exec -u postgres postgresql sed -i 's/#max_wal_senders = 10/max_wal_senders = 5/' /var/lib/postgresql/data/postgresql.conf 
        docker exec -u postgres postgresql sed -i 's/#wal_keep_segments = 0/wal_keep_segments = 32/' /var/lib/postgresql/data/postgresql.conf 
        docker exec -u postgres postgresql sed -i 's/#hot_standby = on/hot_standby = on/' /var/lib/postgresql/data/postgresql.conf
        docker exec -u postgres postgresql sed -i "s/#synchronous_standby_names = ''/synchronous_standby_names = 'standby01,standby02'/" /var/lib/postgresql/data/postgresql.conf
        docker exec -u postgres postgresql sed -i "s|timezone = 'Etc/UTC'|timezone = 'Asia/Shanghai'|" /var/lib/postgresql/data/postgresql.conf
        docker exec -u postgres postgresql sed -i "$ a\host replication ${dynamic_postgres_replication_user} 0.0.0.0\/0 trust" /var/lib/postgresql/data/pg_hba.conf
        docker restart postgresql
        sleep 5
        docker exec -u postgres postgresql psql -c "SELECT pg_start_backup('base', true)"
    fi
}

set_slave() {
    volumes_slave=$(docker inspect postgresql -f '{{ range .Mounts }}{{ if eq .Destination "/var/lib/postgresql/data" }}{{ print .Source }}{{ end }}{{ end }}')
    if [ -z $volumes_slave ];then
        echo "error postgresql container not exists!"
        exit 1
    else 
        sleep 5
        docker exec postgresql sh -c 'rm -rf /var/lib/postgresql/data/*'
        docker exec postgresql pg_basebackup -h db1 -p $global_postgresql_port -U $dynamic_postgres_replication_user -D /var/lib/postgresql/data  -X stream -P -v -R -w -C -S ${standby}
        docker restart postgresql
    fi
}

get_char(){
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

collect_user() {
    while true; do
        echo -e "请输入 pg 用户名:"
        read -p "(eg. pguser):" pguser
        if [ -n "$pguser" ]; then
            echo
            echo "---------------------------------------------"
            echo "数据库用户名(pguser) = ${pguser}"
            echo "---------------------------------------------"
            echo
            break
        fi
    done
}
collect_userpasswd() {    
    while true; do
        echo -e "请输入 $pguser 密码:"
        read -p "(eg. pgpassword):" pgpassword
        if [ -n "$pgpassword" ]; then
            echo
            echo "---------------------------------------------"
            echo "$pguser 密码(pgpassword) = ${pgpassword}"
            echo "---------------------------------------------"
            echo
            break
        fi
    done
}
collect_databasename() {    
    while true; do
        echo -e "请输入数据库名:"
        read -p "(eg. databasename):" databasename
        if [ -n "$databasename" ]; then
            echo
            echo "---------------------------------------------"
            echo "数据库名 = ${databasename}"
            echo "---------------------------------------------"
            echo
            break
        fi
    done
}

display(){
    echo "----------------------------------------------------------------------------"
    echo -e "即将按以下值生效配置，请再次核对："
    echo -e "pg 用户名(pguser):     $(colorEcho $BLUE $pguser)"
    [ -n "$pgpassword" ] && echo -e "$pguser 密码(pgpassword):   $(colorEcho $BLUE $pgpassword)"
    [ -n "$databasename" ] && echo -e "数据库名(databasename):   $(colorEcho $BLUE $databasename)"
    echo -e "按任意键继续，按$(colorEcho $YELLOW 'ctrl+c') 取消"
    echo "----------------------------------------------------------------------------"
    echo
    char=`get_char`
}

createDB() {
    collect_user
    collect_databasename
    display
    docker exec -u postgres $MW_ContainerNm bash -c "psql -l | grep $databasename" &>/dev/null
    if [ $? -ne 0 ]; then
        set -x
        docker exec -u postgres $MW_ContainerNm bash -c "createdb -E UTF8 -O $pguser $databasename"
        # docker exec -u postgres $MW_ContainerNm bash -c "psql -c \"ALTER DATABASE hbcc OWNER TO $pguser;\""
    fi
}

createUser() {
    collect_user
    collect_userpasswd
    display
    docker exec -u postgres $MW_ContainerNm bash -c "psql -t -c '\\du' | grep $pguser"
    if [ $? -ne 0 ]; then
        set -x
        docker exec -u postgres $MW_ContainerNm bash -c "psql -c \"CREATE ROLE $pguser WITH PASSWORD '$pgpassword';\""
        docker exec -u postgres $MW_ContainerNm bash -c "psql -c 'ALTER ROLE $pguser WITH LOGIN;'"
    fi
}

importSQL() {
  local dbname=$1
  docker exec -u postgres $MW_ContainerNm bash -c "psql -d $dbname -f /opt/${dbname}/public.sql"
  docker exec -u postgres $MW_ContainerNm bash -c "psql -d $dbname -c 'GRANT SELECT,UPDATE,INSERT,DELETE ON ALL TABLES IN SCHEMA PUBLIC to $pguser;'"
  docker exec -u postgres $MW_ContainerNm bash -c "psql -d $dbname -c 'GRANT USAGE,UPDATE,SELECT on hibernate_sequence to $pguser;'"
}

# CreateNode() {
#     docker run -it --rm -e RUNNING_MODE=create_node -e HOST_UID=$USER_UID -e HOST_GID=$GROUP_GID -v $MW_WkDir/data/${MW_ContainerNm}:/var/lib/postgresql \
#     --add-host=postgresql_monitor:$dynamic_postgresql3_ip \
#     --add-host=postgresql1:$dynamic_postgresql1_ip \
#     --add-host=postgresql2:$dynamic_postgresql2_ip \
#     --name $MW_ContainerNm \
#     --hostname $MW_ContainerNm \
#     ${global_docker_repo}/postgresql:${global_postgresql_version} /entrypoint.sh | tee $MW_WkDir/create_node.log
# }

# UpPG() {
#     docker-compose -f $MW_Yml up -d --force-recreate
#     if [ $? -eq $CALL_FAIL ]; then
#         MW_log "ERROR" "$FUNCNAME startup ${MW_Alias} failed " && return $CALL_FAIL
#     else
#         MW_log "INFO" "$FUNCNAME startup ${MW_Alias}${MW_Server} SUCC"
#     fi
# }

# UpdateConf() {
#     grep "Transition complete: current state is now" $MW_WkDir/create_node.log
#     if [ $? -eq 0 ]; then
#         UpPG
#     fi
#     if [ -f $MW_WkDir/data/${MW_ContainerNm}/data/pg_hba.conf -a -f $MW_WkDir/data/${MW_ContainerNm}/data/postgresql.conf ]; then
#         # docker exec ${MW_ContainerNm} bash -c "sed -i '/ ${MW_ContainerNm} trust/i\host all all all md5' /var/lib/postgresql/data/pg_hba.conf"
#         docker exec ${MW_ContainerNm} echo "host all all all md5" >>/var/lib/postgresql/data/pg_hba.conf
#         # sed -i '/ pg0 trust/i\host all "pguser" all md5' /data/postgres/data/pg_hba.conf
#     #修改连接配置
#         sed_postgresql_conf="sed -i /var/lib/postgresql/data/postgresql.conf -e 's/max_connections = 100/max_connections = 1200/' -e 's/#tcp_keepalives_idle = 0/tcp_keepalives_idle = 600/' -e 's/#tcp_keepalives_interval = 0/tcp_keepalives_interval = 10/' -e 's/#tcp_keepalives_count = 0/tcp_keepalives_count = 6/'"
#         docker exec ${MW_ContainerNm} bash -c "$sed_postgresql_conf"
#         UpPG
#     else
#         MW_log "ERROR" "[$FUNCTION failed] 配文件不存在，检查 Create Node 是否正常"
#         exit 1
#     fi
# }
DeployPostgresql() {
    mkdir -p ${MW_WkDir}/${MW_ContainerNm}_data ${MW_WkDir}/sql
    \cp -rf ${MW_VersionDir}/docker-compose-${MW_Architecture}.yaml ${MW_Yml}
    # HealthCheck="test -f /var/run/postgresql/.s.PGSQL.5432.lock"
    if [ "${MW_Architecture}" == "solo" ]; then
        running_mode=postgresql_solo
    else
        if [ $MW_Server == "3" ]; then
            running_mode=postgresql_monitor
        else
            running_mode=postgresql_node
        fi
    fi
    sed -e "s/\${global_postgresql_version}/${global_postgresql_version}/g" \
    -e "s#\${DOCKER_REPO}#$global_docker_repo#g" \
    -e "s#\${MW_ContainerNm}#$MW_ContainerNm#g" \
    -e "s#\${running_mode}#$running_mode#g" \
    -e "s#\${POSTGRES_PASSWORD}#$dynamic_postgres_password#g" \
    -e "s#\${postgresql1_ip}#$dynamic_postgresql1_ip#g" \
    -e "s#\${postgresql2_ip}#$dynamic_postgresql2_ip#g" \
    -e "s#\${postgresql3_ip}#$dynamic_postgresql3_ip#g" \
    -e "s#USER_UID#$USER_UID#" \
    -e "s#GROUP_GID#$GROUP_GID#" \
    -i ${MW_Yml}

    if [ $? -ne 0 ]; then
        MW_log "ERROR" "[$FUNCTION failed] compose.yml 配置属主替换失败"
        exit 1
    fi
    
    # if [ $MW_Server -eq 3 ]; then
    #     UpPG
    #     pg_hba_conf=`docker exec ${MW_ContainerNm} grep "host \"pg_auto_failover\" \"autoctl_node\" 0.0.0.0/0 trust" /var/lib/postgresql/data/pg_hba.conf`
    #     if [ -z "$pg_hba_conf" ]; then
    #         docker exec ${MW_ContainerNm} bash -c "echo 'host \"pg_auto_failover\" \"autoctl_node\" 0.0.0.0/0 trust' >>/var/lib/postgresql/data/pg_hba.conf"
    #         if [ $? -ne 0 ]; then
    #             MW_log "ERROR" "[$FUNCTION failed] pg_hba.conf 配置失败"
    #             exit 1
    #         fi
    #     fi    
    # else
    #     container_pgconfig=`docker exec ${MW_ContainerNm} ls /var/lib/postgresql/data/postgresql.conf | wc -l`
    #     if [ ! -f $MW_WkDir/data/${MW_ContainerNm}/data/postgresql.conf -o $container_pgconfig -eq 1 ]; then
    #         CreateNode
    #     fi
    #     UpdateConf
    # fi
}    

ShowState() {
    check_container
    colorEcho $BLUE " 检查 Postgresql 集群状态"
    docker exec -u postgres ${MW_ContainerNm} pg_autoctl show state
}

ExecuteCommand() {
    # if [ $MW_Server -eq 3 ]; then
    #     ShowState
    # fi
    # if [ $MW_Server -eq 2 ]; then
    #     colorEcho $YELLOW "function currently not supported!!"
    # fi
    # if [ $MW_Server -eq 1 ]; then
    #     colorEcho $BLUE "Directly press enter to initialize, if first installation"
    #     colorEcho $BLUE "Or input script filename to invoke script, one by one"
    #     read  -p "Press Enter or Input File name:" cmd1
    #     flag=$(echo "$cmd1" |grep -E "^$|*\.sql$|*\.sh|*\.bash$|*\.js$|showstate" |wc -l)
    #     if [ -f ${MW_VersionDir}/initSql/${cmd1} ]; then
    #         case ${cmd1##*.} in
    #         "sh"|"bash")
    #             bash ${MW_VersionDir}/initSql/${cmd1}
    #         ;;
    #         "sql")
    #             cp -r ${MW_VersionDir}/initSql/${cmd1} ${MW_WkDir}/sql/
    #             sleep 3
    #             docker exec -u postgres ${MW_ContainerNm} ls /opt/
    #             echo ---------------
    #             docker exec -u postgres ${MW_ContainerNm} psql -f /opt/${cmd1}
    #         ;;
    #         esac
    #     else
    #        colorEcho $RED "ERROR: invalid input($LINENO)"
    #        exit 1
    #     fi
    # fi
    current_primary=`docker exec -u postgres ${MW_ContainerNm} pg_autoctl show settings |grep primary |awk '{print $3}'`
    if [ "${MW_ContainerNm}" == "$current_primary" ]; then
        local command_list=(ShowState createUser createDB)
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
        $EXCUTE_COMMAND
    else
        ShowState
        colorEcho $BLUE "${MW_ContainerNm} 是从节点或监控节点，请在 $current_primary 上执行操作命令"
    fi
}

case $1 in
    1)
        DeployPostgresql
    ;;
    2)
        ExecuteCommand
    ;;
    3)
        BAK_SQL=all-`date +%F_%H%M`.sql
        mkdir -p ${MW_WkDir}/backup
        docker exec -u postgres ${MW_ContainerNm} pg_dumpall -U postgres > ${MW_WkDir}/backup/$BAK_SQL
        tail ${MW_WkDir}/backup/$BAK_SQL |grep -q "PostgreSQL database cluster dump complete"
        if [ $? -eq 0 ];then
            colorEcho $GREEN Backup Successfully!
        else
            colorEcho $RED Wrong!! Please checking!
        fi
    ;;
    4)
        if [ ${dynamic_postgresql_numOfServers} -gt 1 ]; then
            if [ $MW_Server == "1" ]; then
                set_master
            elif [ $MW_Server == "2" -o $MW_Server == "3" ]; then
                standby=standby0$((MW_Server - 1))
                set_slave 
            fi
        fi
    ;;     
    *)
        colorEcho $RED "ERROR: invalid input"
        exit 1
    ;;
esac
