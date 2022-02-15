#! /bin/bash
ACTION=${@:2}


check_container() {
    if [ `docker ps -aq -f name=${MW_ContainerNm}|wc -l` -eq 0 ]; then
        colorEcho $RED "Redis哨兵容器未安装成功，请执行 docker ps -a 检查容器"
        exit 1
    fi
}


DeployRedisSentinel() {
    mkdir -p ${MW_WkDir}/conf
    \cp -rf ${MW_VersionDir}/docker-compose.yaml ${MW_Yml}
    # 生成docker-compose启动文件
    sed -e "s/image_version/${global_redis_sentinel_version}/" -e "s#docker_repo#${global_docker_repo}#" -e "s/image_name/${MW_ContainerNm%_*}/" -i ${MW_Yml}
    # 复制并修改配置文件
    \cp -rf ${MW_VersionDir}/sentinel.conf ${MW_WkDir}/conf
    get_ip_para="dynamic_redis_sentinel${MW_Server}_ip"
    sed -e "/redis_password/s/redis_password/${dynamic_redis_auth}/" \
    -e "/annou_ip/s/annou_ip/${!get_ip_para}/" \
    -e "/redis_masterip/s/redis_masterip/${dynamic_redis1_ip}/" -i ${MW_WkDir}/conf/sentinel.conf

}


E_InitDatabase(){
    bash ${MW_VersionDir}/
}

case $1 in
    1)
        DeployRedisSentinel
    ;;
    *)
        colorEcho $RED "ERROR: invalid input"
        exit 1
    ;;
esac
