#! /bin/bash
ACTION=${@:2}
USER_UID=`id -u`
GROUP_GID=`id -g`


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


DeployPostgresql() {
    mkdir -p ${MW_WkDir}/data
    [ ${dynamic_postgresql_numOfServers} -eq 1 ] && MOD="solo" || MOD="cluster"
    \cp -rf ${MW_VersionDir}/docker-compose-${MOD}.yaml ${MW_Yml}
    if [ $MOD == "cluster" ];then
        [ $MW_Server == "2" -o $MW_Server == "3" ] && sed -i '/test/s/-a/#/' ${MW_Yml}
    fi
    sed -e "s/\${global_postgresql_version}/${global_postgresql_version}/g" \
    -e "s#USER_UID#$USER_UID#" \
    -e "s#\${DOCKER_REPO}#$global_docker_repo#g" \
    -e "s#\${MW_ContainerNm}#$MW_ContainerNm#g" \
    -e "s#\${postgresql1_ip}#$dynamic_postgresql1_ip#g" \
    -e "s#\${postgresql2_ip}#$dynamic_postgresql2_ip#g" \
    -e "s#\${postgresql3_ip}#$dynamic_postgresql2_ip#g" \
    -i ${MW_Yml}
}    


E_InitDatabase(){
    bash ${MW_VersionDir}/
}

case $1 in
    1)
        DeployPostgresql
    ;;
    2)
       ## 执行脚本
       #echo "${MW_VersionDir}/initSql/${ACTION}"
       if [ -f ${MW_VersionDir}/initSql/${ACTION} ];then 
           case ${ACTION##*.} in
           "sh"|"bash")
               bash ${MW_VersionDir}/initSql/${ACTION}
           ;;
           "sql")
               cp -r ${MW_VersionDir}/initSql/${ACTION} ${MW_WkDir}/sql/
               sleep 3
               docker exec -u postgres postgresql ls /opt/
               echo ---------------
               docker exec -u postgres postgresql psql -f /opt/${ACTION}
           ;;
           esac
       else
           colorEcho $RED "ERROR: invalid input($LINENO)"
           exit 1
       fi 
    ;;
    3)
        BAK_SQL=all-`date +%F_%H%M`.sql
        mkdir -p ${MW_WkDir}/backup
        docker exec postgresql pg_dumpall -U postgres > ${MW_WkDir}/backup/$BAK_SQL
        tail ${MW_WkDir}/backup/$BAK_SQL |grep -q "PostgreSQL database cluster dump complete"
        if [ $? -eq 0 ];then
            colorEcho $GREEN Backup Successfully!
        else
            colorEcho $RED Wrong!! Please checking!
        fi
    ;;
    4)
        if [ $MW_Server == "1" ]; then
            set_master
        elif [ $MW_Server == "2" -o $MW_Server == "3" ]; then
            standby=standby0$((MW_Server - 1))
            set_slave 
        fi
    ;;     
    *)
        colorEcho $RED "ERROR: invalid input"
        exit 1
    ;;
esac
