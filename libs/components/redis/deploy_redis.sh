#! /bin/bash
ACTION=${@:2}
USER_UID=`id -u ${dynamic_install_user}`
GROUP_GID=`id -g ${dynamic_install_user}`


check_container() {
    if [ `docker ps -aq -f name=${MW_ContainerNm}|wc -l` -eq 0 ]; then
        colorEcho $RED "Redis容器未安装成功，请执行 docker ps -a 检查容器"
        exit 1
    fi
}

set_slave() {
    sed -i '/^\#replicaof/s/\#//' ${MW_WkDir}/conf/redis.conf
}


DeployRedis() {
    mkdir -p ${MW_WkDir}/conf
    \cp -rf ${MW_VersionDir}/docker-compose.yaml ${MW_Yml}
    # 生成docker-compose启动文件
    sed -e "s/images_version/${global_redis_version}/" -e "s#docker_repo#${global_docker_repo}#" -e "s/image_name/${MW_ContainerNm}/" -i ${MW_Yml}
    # 复制并修改配置文件
    \cp -rf ${MW_VersionDir}/redis.conf ${MW_WkDir}/conf
    sed -i "/redis_password/s/redis_password/${dynamic_redis_auth}/" ${MW_WkDir}/conf/redis.conf

    # 判断是否是主从模式
    if [ $dynamic_redis_numOfServers -gt 1 ]; then
        # colorEcho $YELLOW "主从模式 Redis"
        sed "/redis_masterip/s/redis_masterip/${dynamic_redis1_ip}/" -i ${MW_WkDir}/conf/redis.conf
        if [ $MW_Server != "1" ]; then
            set_slave
        fi
    else
        sed -e '/redis_masterip/d' \
        -e '/masterauth/d' \
        -i ${MW_WkDir}/conf/redis.conf
    fi

}


E_InitDatabase(){
    bash ${MW_VersionDir}/
}

case $1 in
    1)
        DeployRedis
    ;;
    2)
        echo EN!
    ;;
    *)
        colorEcho $RED "ERROR: invalid input"
        exit 1
    ;;
esac
