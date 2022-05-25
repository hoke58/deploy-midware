#! /bin/bash
ACTION=${@:2}
USER_UID=`id -u`
GROUP_GID=`id -g`


# 检查容器是否运行
checkContainer() {
    if [ `docker ps -q -f name="^/${MW_ContainerNm}$"|wc -l` -eq 0 ]; then
        colorEcho $RED "mongo-shake容器未启动成功，请执行 docker ps -a | grep mongo-shake 检查容器"
        exit 1
    fi
}

DeployMongoShake() {
    \cp -rf ${MW_VersionDir}/docker-compose.yaml ${MW_Yml}
    # 生成docker-compose启动文件
    sed -i ${MW_Yml} \
      -e "s/images_version/${global_mongo_shake_version}/" \
      -e "s#docker_repo#${global_docker_repo}#" \
      -e "s/image_name/${MW_ContainerNm}/" \
      -e "s/\${dynamic_mongodb1_host}/${dynamic_mongodb1_host}/g" \
      -e "s/\${dynamic_mongodb2_host}/${dynamic_mongodb2_host}/g" \
      -e "s/\${dynamic_mongodb3_host}/${dynamic_mongodb3_host}/g" \
      -e "s/\${dynamic_mongodb1_ip}/${dynamic_mongodb1_ip}/g" \
      -e "s/\${dynamic_mongodb2_ip}/${dynamic_mongodb2_ip}/g" \
      -e "s/\${dynamic_mongodb3_ip}/${dynamic_mongodb3_ip}/g" \
      -e "s/\${dynamic_mongodb1_src_host}/${dynamic_mongodb1_src_host}/g" \
      -e "s/\${dynamic_mongodb2_src_host}/${dynamic_mongodb2_src_host}/g" \
      -e "s/\${dynamic_mongodb3_src_host}/${dynamic_mongodb3_src_host}/g" \
      -e "s/\${dynamic_mongodb1_src_ip}/${dynamic_mongodb1_src_ip}/g" \
      -e "s/\${dynamic_mongodb2_src_ip}/${dynamic_mongodb2_src_ip}/g" \
      -e "s/\${dynamic_mongodb3_src_ip}/${dynamic_mongodb3_src_ip}/g"
     
    # 复制并修改配置文件
    \cp -rf ${MW_VersionDir}/collector.conf ${MW_WkDir}/
    sed -i ${MW_WkDir}/collector.conf \
      -e "s/\${dynamic_mongodb_port}/${dynamic_mongodb_port}/g" \
      -e "s/\${dynamic_mongodb1_host}/${dynamic_mongodb1_host}/g" \
      -e "s/\${dynamic_mongodb2_host}/${dynamic_mongodb2_host}/g" \
      -e "s/\${dynamic_mongodb3_host}/${dynamic_mongodb3_host}/g" \
      -e "s/\${dynamic_mongodb1_src_host}/${dynamic_mongodb1_src_host}/g" \
      -e "s/\${dynamic_mongodb2_src_host}/${dynamic_mongodb2_src_host}/g" \
      -e "s/\${dynamic_mongodb3_src_host}/${dynamic_mongodb3_src_host}/g"

}


case $1 in
    1)
        DeployMongoShake
        sleep 3
        checkContainer
    ;;
    2)
        echo EN!
    ;;
    4)
        :
    ;;     
    *)
        colorEcho $RED "ERROR: invalid input"
        exit 1
    ;;
esac
