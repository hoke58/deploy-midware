#! /bin/bash
MONGO_JS=${@:2}
CONTAINER_MONGO_EXEC="docker exec -u mongodb -i $CONTAINER_ID bash -c"
current_time=$(date '+%Y%m%d')
USER_UID=`id -u`
GROUP_GID=`id -g`
# 要备份的数据库名，多个数据库用空格分开
databases=(mongo mongocloud cache_database)
mongo_user=mongouser
mongo_pw=mongouser123
# 备份文件要保存的目录
CONTAINER_BAKPATH=/backup/${current_time}
HOST_BAKPATH=$MW_WkDir/mongodb_backup/${current_time}
CONTAINER_EXEC="docker exec -i $CONTAINER_ID bash -c"
# echo $MONGO_CONTAINER
# echo $CONTAINER_EXEC
# echo $databases
# echo $CONTAINER_BAKPATH
# echo $HOST_BAKPATH


DeployMongo() {
    mkdir -p ${MW_WkDir}/mongodb_backup ${MW_WkDir}/mongodb_shell
    \cp -rf ${MW_VersionDir}/docker-compose-${MW_Architecture}.yaml ${MW_Yml}

    sed -e "s/\${dynamic_mongodb_port}/$dynamic_mongodb_port/g" \
    -e "s/\${global_mongodb_version}/${global_mongodb_version}/g" \
    -e "s#\${DOCKER_REPO}#$global_docker_repo#g" \
    -e "s#\${MW_ContainerNm}#$MW_ContainerNm#g" \
    -e "s#\${USER_UID}#$USER_UID#g" \
    -e "s#\${GROUP_GID}#$GROUP_GID#g" \
    -e "s#\${mongodb1_ip}#$dynamic_mongodb1_ip#g" \
    -e "s#\${mongodb2_ip}#$dynamic_mongodb2_ip#g" \
    -e "s#\${mongodb3_ip}#$dynamic_mongodb3_ip#g" \
    -e "s#\${MONGO_ADMIN}#$dynamic_mongodb_admin#g" \
    -e "s#\${MONGO_ADMINPASS}#$dynamic_mongodb_adminpass#g" \
    -i ${MW_Yml}
}    

CreateUser() {
    if [ $MW_Architecture == "cluster" ]; then
        $CONTAINER_EXEC "mongo --port ${dynamic_mongodb_port} admin --quiet /custom/creatRepl.js"
        $CONTAINER_EXEC "mongo --port ${dynamic_mongodb_port} admin --quiet /custom/creatAdmin.js"
    fi
    for db in ${databases[*]}; do
        # \cp -rf ${MW_VersionDir}/jsDefault/joinorg/createUser.js ${MW_WkDir}/mongodb_shell/create${db}User.js

        # sed -e "s/MONGO_USER/$mongo_user/g" \
        # -e "s/MONGO_PW/$mongo_pw/g" \
        # -e "s/DATABASE/$db/g" \
        # -i ${MW_WkDir}/mongodb_shell/create${db}User.js

        cat > ${MW_WkDir}/mongodb_shell/create${db}User.js <<-EOF
db.getSiblingDB("admin").auth("$dynamic_mongodb_admin", "$dynamic_mongodb_adminpass")
db.getSiblingDB("$db")
db.createUser({ user:"$mongo_user",pwd:"$mongo_pw",roles:[{role:"readWrite", db: "$db"}]})
db.getSiblingDB("$db").auth("$mongo_user","$mongo_pw")
EOF

        $CONTAINER_EXEC "mongo --port ${dynamic_mongodb_port} $db --quiet /mongodb_shell/create${db}User.js"
    done
}

BakMongo(){
    $CONTAINER_EXEC "chown -R $USER_UID:$GROUP_GID /backup"
    #SetVars
    if [ ! -d ${HOST_BAKPATH} ]; then
        mkdir -p $HOST_BAKPATH
    fi
    for db in ${databases[*]}; do
        if [ $db == "cache_database" ]; then
            break
        fi
        colorEcho "===== Backuping $db... ====="
        $CONTAINER_MONGO_EXEC "/usr/bin/mongodump --port ${dynamic_mongodb_port} -d $db --out $CONTAINER_BAKPATH -u $mongo_user -p $mongo_pw"
        [[ $? -eq 1 ]] && return 1
        
        nice -n 19 tar zcfv ${HOST_BAKPATH}/${db}.tgz -C ${HOST_BAKPATH} ${db}
        rm -rf $HOST_BAKPATH/$db
    done
    find $HOST_BAKPATH -mtime +14 -type d -exec rm -rf {} \;
}

case $1 in
    1)
        DeployMongo
    ;;
    2)
        
        if [ $MONGO_JS == "none" ]; then
            CreateUser
        else
            \cp -rf ${MW_VersionDir}/jsDefault/${MONGO_JS} ${MW_WkDir}/mongodb_shell/
            set -x
            $CONTAINER_MONGO_EXEC "mongo --port ${dynamic_mongodb_port} $db --quiet /mongodb_shell/${MONGO_JS}"
            set +x
        fi
    ;;
    3)
        BakMongo
        [[ $? -eq 1 ]] && return 1
    ;;       
    *)
        colorEcho $RED "ERROR: invalid input"
        exit 1
    ;;
esac
