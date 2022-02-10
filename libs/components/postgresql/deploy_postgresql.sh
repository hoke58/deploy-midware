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
        if [ ${dynamic_postgres_replication_user} != ${global_postgresql_user} ];then
            docker exec -u postgres postgresql psql -c "CREATE USER $global_postgresql_user PASSWORD '$global_postgresql_pass';"
        fi
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
        docker exec -u postgres postgresql sed -i "$ a\host replication ${dynamic_postgres_replication_user} ${dynamic_postgres_replication_hosts} trust" /var/lib/postgresql/data/pg_hba.conf
        docker restart postgresql
        sleep 5
        docker exec -u postgres postgresql psql -c "SELECT pg_start_backup('base', true)"
    fi

    sed -e "s#^role.*#role=db1#"  -e "s#^master.*#master=db1#" -e "s#^repuser.*#repuser=${dynamic_postgres_replication_user}#" -i ${MW_WkDir}/failover.sh
}

set_slave() {
    volumes_slave=$(docker inspect postgresql -f '{{ range .Mounts }}{{ if eq .Destination "/var/lib/postgresql/data" }}{{ print .Source }}{{ end }}{{ end }}')
    if [ -z $volumes_slave ];then
        echo "error postgresql container not exists!"
        exit 1
    else 
        sleep 5
        docker exec postgresql psql -U postgres -h db1 -c "select * from pg_replication_slots;" |grep ${standby}
        if [ $? -eq 0 ];then
           args="-X stream -P -v -R -w -S"
        else
           args="-X stream -P -v -R -w -C -S"
        fi

        docker exec postgresql sh -c 'rm -rf /var/lib/postgresql/data/*'
        docker exec postgresql pg_basebackup -h db1 -p $global_postgresql_port -U $dynamic_postgres_replication_user -D /var/lib/postgresql/data  ${args} ${standby}
        docker restart postgresql
    fi
    sed -e "s#^role.*#role=db${MW_Server}#"  -e "s#^master.*#master=db1#" -e "s#^repuser.*#repuser=${dynamic_postgres_replication_user}#" -i ${MW_WkDir}/failover.sh
}


DeployPostgresql() {
    mkdir -p ${MW_WkDir}/data
    [ ${dynamic_postgresql_numOfServers} -eq 1 ] && MOD="solo" || MOD="cluster"
    \cp -rf ${MW_VersionDir}/docker-compose-${MOD}.yaml ${MW_Yml}
    if [ ${MOD} == "cluster" ];then
        \cp -rf ${MW_VersionDir}/failover.sh ${MW_WkDir}
        chmod +x ${MW_WkDir}/failover.sh
        sed -i "/DCOM/s/DCOM/${PATH}/" ${MW_WkDir}/failover.sh
        echo "* * * * * /bin/bash ${MW_WkDir}/failover.sh" >> /var/spool/cron/$USER
	echo "=================== Crontab ================"
        crontab -l
        echo "============================================"
    fi
    if [ $MOD == "cluster" ];then
        [ $MW_Server == "2" -o $MW_Server == "3" ] && sed -i '/test/s/-a/#/' ${MW_Yml}
    fi
    sed -e "s/\${global_postgresql_version}/${global_postgresql_version}/g" \
    -e "s#\${DOCKER_REPO}#$global_docker_repo#g" \
    -e "s#\${MW_ContainerNm}#$MW_ContainerNm#g" \
    -e "s#\${data_dir}#$dynamic_postgres_data_dir#g" \
    -e "s#\${postgresql1_ip}#$dynamic_postgresql1_ip#g" \
    -e "s#\${postgresql2_ip}#$dynamic_postgresql2_ip#g" \
    -e "s#\${postgresql3_ip}#$dynamic_postgresql3_ip#g" \
    -i ${MW_Yml}

    if [ ${USER_UID} -ne 0 ];then 
        sed -i "s#USER_UID#$USER_UID#"  ${MW_Yml}
    else
        sed -i "s/USER_UID/1000/" ${MW_Yml}
    fi
}    


E_InitDatabase(){
    echo "Please check the directories, they will be as the databases's names."
    echo "Remove the others."
    echo -e "Local base directory: \e[31;31m${MW_WkDir}/sql/\e[0m"
    
    ls --color=auto -d ${MW_WkDir}/sql/*
    read -p "Ready?(y/n) " Istat

    case ${Istat} in
    "y"|"Y"|"yes"|"YES")
       users=$(docker exec postgresql psql -Upostgres -c "\du"|grep -w -v "postgres"|awk '{if(NR >3){print $1}}')
       count=0
       groups=()
       for i in ${users[@]}
       do
         echo "$count) $i"
         groups[$count]=$i
         ((count += 1))
       done
       read -p "Select(1|2|3..) " userNum
       # Check user
       [ -z ${groups[userNum]} ] && echo "No user" && exit 4
       # Check database
       for directory in $(cd ${MW_WkDir}/sql/; ls -d */)
       do
           docker exec postgresql psql -Upostgres -l | grep -w "${directory%/}"
           if [ $? -ne 0 ];then
               docker exec -u postgres postgresql sh -c "createdb -E UTF8 -O postgres ${directory%/}"
               docker exec -u postgres postgresql psql -c "alter database ${directory%/} owner to ${groups[userNum]};"
           fi
           Sqls=$(ls ${MW_WkDir}/sql/${directory%/})
           for sql in ${Sqls[@]}
           do
               docker exec postgresql psql -U ${groups[userNum]} -d ${directory%/} -f /opt/${directory%/}/${sql}
           done
       done
    ;;
    "n"|"N"|"no"|"NO")
        clear
        E_InitDatabase 
    ;;
    *)
        exit 886
    ;;
    esac
}

case $1 in
    1)
        DeployPostgresql
    ;;
    2)
       ## 执行脚本
        case ${ACTION##*.} in
        1)
           pwd
           $MW_VersionDir/initSql/init_db.sh ${MW_WkDir}
        ;;
        2)
           E_InitDatabase
        ;;
        3)
           echo "PG已有数据库信息"
           docker exec postgresql psql -Upostgres -l
           echo "PG已有用户"
           docker exec postgresql psql -Upostgres -c "\du;"
        ;;   
        *)
           colorEcho $RED "ERROR: invalid input"
           exit 1
        esac
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
