#! /bin/bash
CONTAINER_ID=`docker ps -aq -f name=rabbit`
CONTAINER_EXEC="docker exec -i $CONTAINER_ID bash -c"


check_container() {
    if [ `docker ps -aq -f name=${MW_ContainerNm}|wc -l` -eq 0 ]; then
        colorEcho $RED "RabbitMQ容器未安装成功，请执行 docker ps -a 检查容器"
        exit 1
    fi
}

JoinCluster() {
    $CONTAINER_EXEC "rabbitmqctl stop_app"
    $CONTAINER_EXEC "rabbitmqctl join_cluster rabbit@rabbitmq1"
    sleep 3
    $CONTAINER_EXEC "rabbitmqctl start_app"
    $CONTAINER_EXEC "rabbitmqctl cluster_status"
}

check_messages(){
if [ `docker exec -i $CONTAINER_ID rabbitmqctl list_queues messages | sed -r -n '/^[1-9]/p' | wc -l` -ne 0 ]; then
    echo "WARN: MQ 队列中有拥塞消息，请人工介入"
    echo
    exit 1
fi
}

set_ha(){
# Set Check shell
policy_check=`docker exec -i $CONTAINER_ID rabbitmqctl list_policies | awk 'NR>1 {print $2}'`
if [ "$policy_check" = "ha-all" ]; then
    echo "WARN: RabbitMQ mirror-policy has been set [ha-all], nothing to do."
    exit 0
else
    check_messages
    docker exec -i $CONTAINER_ID rabbitmqctl set_policy ha-all "^" '{"ha-mode":"all"}'
    echo "IFNO: RabbitMQ mirror-policy has been set successfully."
    exit 0
fi
}

DeployRabbitmq() {
    mkdir -p ${MW_WkDir}/mq_mount
    \cp -rf ${MW_VersionDir}/docker-compose-${MW_Architecture}.yaml ${MW_Yml}

    sed -e "s/\${global_rabbitmq_version}/${global_rabbitmq_version}/g" \
    -e "s#\${DOCKER_REPO}#$global_docker_repo#g" \
    -e "s#\${MW_ContainerNm}#$MW_ContainerNm#g" \
    -e "s#\${mq0_org1_ip}#$dynamic_rabbitmq1_ip#g" \
    -e "s#\${mq1_org1_ip}#$dynamic_rabbitmq2_ip#g" \
    -i ${MW_Yml}

#    sleep 10
#    if [ $MW_Architecture == "cluster" -a $MW_Server -ne 1 ]; then
#        JoinCluster
#    fi
}    

CheckStatus() {
    echo "--------------list cluster status & policies-----------"
    docker exec rabbitmq${MW_Server} rabbitmqctl cluster_status
    docker exec rabbitmq${MW_Server} rabbitmqctl list_policies
    echo "--------------list exchanges------------------"
    docker exec rabbitmq${MW_Server} rabbitmqctl list_exchanges
    echo "--------------list queues------------------"
    docker exec rabbitmq${MW_Server} rabbitmqctl list_queues
    echo "--------------list bindings------------------"
    docker exec rabbitmq${MW_Server} rabbitmqctl list_bindings
}

exchange() {
    while true; do
        echo -e "Input Exchange name:"
        read -p "(eg. myexchage):" EXCHANGE
        if [ -n "$EXCHANGE" ]; then
            echo
            echo "---------------------------------------------"
            echo "Exchange name = ${EXCHANGE}"
            echo "---------------------------------------------"
            echo
            break
        fi
    done
    docker exec $CONTAINER_ID rabbitmqctl list_exchanges | grep $EXCHANGE &>/dev/null
    if [ $? -eq 0 ]; then
        echo "Exchange '$EXCHANGE' existed."
    else
    # curl -O http://127.0.0.1:15672/cli/rabbitmqadmin && chmod +x rabbitmqadmin
        docker exec $CONTAINER_ID rabbitmqadmin -u loc -p loc declare exchange name=$EXCHANGE type=fanout
        if [ $? -eq 0 ]; then
            echo "Creat Exchange '$EXCHANGE' successfully"
        else
            echo "Failed to creat Exchange"
            exit 1
        fi
    fi

    docker exec $CONTAINER_ID rabbitmqctl list_queues name -t 5 | grep -Ev '^{'| awk 'NR>1' | grep $EXCHANGE
    if [ $? -eq 0 ]; then
        echo "Queue '$EXCHANGE' existed."
    else
        docker exec $CONTAINER_ID rabbitmqadmin -u loc -p loc declare queue name=$EXCHANGE
        if [ $? -eq 0 ]; then
            echo "Creat Queue '$EXCHANGE' successfully"
        else
            echo "Failed to creat Queue"
            exit 1
        fi
    fi

    docker exec $CONTAINER_ID rabbitmqadmin -u loc -p loc declare binding source=$EXCHANGE destination=$EXCHANGE
    
    docker exec $CONTAINER_ID rabbitmqadmin -u loc -p loc list bindings
}

which_action() {
    local command_list=(status setha exchange)
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
        ACTION=${command_list[$input_nu-1]}
        break
    done
}

case $1 in
    1)
        DeployRabbitmq
    ;;
    2)
        which_action
        if [ $ACTION == "status" ]; then
            check_container
            CheckStatus
        elif [ $ACTION == "setha" ]; then
            check_container
            set_ha
        elif [ $ACTION == "exchange" ]; then
            check_container
            exchange
        fi
    ;;     
    3)
        sleep 10
        if [ $MW_Architecture == "cluster" -a $MW_Server -ne 1 ]; then
            JoinCluster
        fi
    ;;
    *)
        colorEcho $RED "ERROR: invalid input"
        exit 1
    ;;
esac
