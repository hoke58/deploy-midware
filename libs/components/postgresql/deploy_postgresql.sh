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
        docker exec -u postgres postgresql psql -c "CREATE ROLE $POSTGRES_REPLICATION_USER REPLICATION LOGIN PASSWORD '$POSTGRES_REPLICATION_PASSWORD';"
        docker exec -u postgres postgresql sed -i 's/max_connections = 100\>/max_connections = 1000/' /var/lib/postgresql/data/postgresql.conf 
        docker exec -u postgres postgresql sed -i 's/#password_encryption/password_encryption/' /var/lib/postgresql/data/postgresql.conf 
        docker exec -u postgres postgresql sed -i 's/#wal_level/wal_level/' /var/lib/postgresql/data/postgresql.conf 
        docker exec -u postgres postgresql sed -i "s/#synchronous_commit = on/synchronous_commit = off/" /var/lib/postgresql/data/postgresql.conf
        docker exec -u postgres postgresql sed -i 's/#max_wal_senders = 10/max_wal_senders = 5/' /var/lib/postgresql/data/postgresql.conf 
        docker exec -u postgres postgresql sed -i 's/#wal_keep_segments = 0/wal_keep_segments = 32/' /var/lib/postgresql/data/postgresql.conf 
        docker exec -u postgres postgresql sed -i 's/#hot_standby = on/hot_standby = on/' /var/lib/postgresql/data/postgresql.conf
        docker exec -u postgres postgresql sed -i "s/#synchronous_standby_names = ''/synchronous_standby_names = 'standby01,standby02'/" /var/lib/postgresql/data/postgresql.conf
        docker exec -u postgres postgresql sed -i "s|timezone = 'Etc/UTC'|timezone = 'Asia/Shanghai'|" /var/lib/postgresql/data/postgresql.conf
        docker exec -u postgres postgresql sed -i "$ a\host replication ${POSTGRES_REPLICATION_USER} 0.0.0.0\/0 trust" /var/lib/postgresql/data/pg_hba.conf
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
        docker exec postgresql pg_basebackup -h db1 -p $global_postgresql_port -U $POSTGRES_REPLICATION_USER -D /var/lib/postgresql/data  -X stream -P -v -R -w -C -S ${standby}
        docker restart postgresql
    fi
}


DeployPostgresql() {
    mkdir -p ${MW_WkDir}/data
    \cp -rf ${MW_VersionDir}/docker-compose.yaml ${MW_Yml}

    sed -e "s/\${global_postgresql_version}/${global_postgresql_version}/g" \
    -e "s#\${DOCKER_REPO}#$global_docker_repo#g" \
    -e "s#\${MW_ContainerNm}#$MW_ContainerNm#g" \
    -e "s#\${mongodb1_ip}#$dynamic_mongodb1_ip#g" \
    -e "s#\${mongodb2_ip}#$dynamic_mongodb2_ip#g" \
    -e "s#\${mongodb3_ip}#$dynamic_mongodb3_ip#g" \
    -i ${MW_Yml}
}    


case $1 in
    1)
        DeployPostgresql
    ;;
    2)
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
