#!/bin/bash

# node: db1     db2        db3
# role: master  standby01  standby02
# 节点通过探活确认master节点状态
# docker exec postgresql psql -h dbName -U postgres -c "select * from pg_is_in_recovery();"
#  pg_is_in_recovery
# -------------------
#  t ----> 主库返回 f，从库返回 t
# (1 row)
# 如果状态异常，则选择新的master，并且让slave与新的主建立同步

# 重置异常的master节点，并且与新的master同步

image="hub.finrunchain.com/midware/postgresql:12.7"

# 事件改变记录
log=pg_event.log
script=$0
cd $(dirname $script)
# 数据库节点名称
db_pool=(db1 db2 db3)

declare -A slots
slots=(
["db1"]="master"
["db2"]="standby01"
["db3"]="standby02"
)

# 当前节点
role=curNode
# 当前master主机
master=Master
# 同步用户
repuser=Repuser
export PATH=DCOM
cdata_dir="/var/lib/postgresql/data"

logging(){
   echo -e "`date ` : ${*}" >> ${log}
}

# 本机服务状态检查
check_status (){
    logging $FUNCNAME
    # 如果容器异常停止，先拉起来尝试下
    docker ps -f "name=^/postgresql" --format "{{.Names}}"|grep postgresql
    if [ $? -ne 0 ];then
        logging "容器没有运行，重新启动..."
        docker-compose up -d
        sleep 10
    fi
    logging "检查服务运作状态..."
    status=$(docker exec -u postgres postgresql pg_controldata /var/lib/postgresql/data |grep "Database cluster state" |awk '{print $NF}')
    if [ ${status} == "recovery" -a ${role} != ${master} ];then
       :
    elif [ ${status} == "production" -a ${role} == ${master} ];then
       :
    else
       logging 状态错误，（recovery/production）
       return 990
    fi
    docker exec -u postgres postgresql pg_isready
    return $?
}
# 另一台从节点检查
check_another_slave(){
    logging "检查另一从节点状态..."
    docker exec postgresql psql -h $1 -U postgres -c "select * from pg_is_in_recovery();" 
    return $?
}
# 检查与 master 的链接
check_master(){
    logging $FUNCNAME
    getMaster=${1-${master}}
    ctimes=${2-3}
    [ ${ctimes} -le 1 ] && return 4

    r1=`docker exec postgresql psql -h $getMaster -U postgres -c "select * from pg_is_in_recovery();" |head  -n 3 |tail -n1 |awk '{print $1}'`

    if [ "${r1}" == 'f' ];then
        repUser=$( docker exec postgresql psql -h $getMaster -U postgres -c "\du"|grep -w ${repuser})
        if [ ! -z "${repUser}" ];then
            logging "Master is ${getMaster}, it's OK"
            return 0
        else
            sleep 2
            check_master ${getMaster} $(( ctimes - 1))
            if [ $? -ne 0 ];then
                logging $getMaster master数据库状态异常，没有同步用户
                return 6
            fi
            return 0
        fi

    else
        sleep 2
        check_master ${getMaster} $(( ctimes -1 ))
    fi

}


# 寻找新的master节点
get_new_master(){
    sed -i '/failover.sh/s/^/#/' /var/spool/cron/$USER
    count=0
    times=5
    Stime=5
    while [ ${count} -lt ${times} ]
    do  
        for nod in ${db_pool[@]}
        do
#            if [ ${nod} != "${master}" ];then
                check_master ${nod}
                if [ $? -eq 0 ];then
                    new_master=${nod}
                    sed -r -i "/^master/s/(master=).*/\1${new_master}/" ${script}
                    logging "新master ${new_master}"
                    break 2
                fi
#            fi
        done
        (( count += 1 ))
        # 如果暂未找到新的master，则延迟 10s 再进行探测
        sleep ${Stime}
    done

    sed -r -i '/failover.sh/s/^#+//' /var/spool/cron/$USER
    if [ ${count} -ge ${times} ];then
        logging "寻找新master失败"
        return 99
    fi
    return 0
}


# 修改 master
# 如果轮到自己节点，则本节点切换成master，否则寻找新的master进行同步
up_to_master(){
    echo -e "\e[31;31m升级为新master...\e[0m"
    docker exec -u postgres postgresql pg_ctl  promote
    docker exec postgresql sed -i "3,$ d" /var/lib/postgresql/data/postgresql.auto.conf
    #docker-compose restart
    docker exec -u postgres postgresql pg_controldata /var/lib/postgresql/data |grep -q "in production"
    if [ $? -eq 0 ];then
        logging "${role} 成功升级为新master主机！"
        echo "${role} 成功升级为新master主机！" 
        sed -r -i "/^master/s/(master=).*/\1${1}/" ${script}
        for db_slot in ${db_pool[@]}
        do
           set -x 
           [ "${db_slot}" != "${role}"  ] &&  docker exec postgresql psql -U postgres -c "select pg_create_physical_replication_slot('${slots[${db_slot}]}');"
           set +x
        done
        docker exec postgresql psql -U postgres -c "select slot_name,active,restart_lsn from pg_replication_slots;" &>> ${log}
    else
        logging "${role} 升级为新master失败！"
        #echo "${role} 升级为新master失败！" 
        exit 66
    fi

}

change_judge(){
    if [ ${master} == "db1" -a ${role} == "db2" ];then
        up_to_master ${role}
    elif [ ${master} == "db2" -a ${role} == "db3" ];then
        up_to_master ${role}
    elif [ ${master} == "db3" -a ${role} == "db1" ];then
        up_to_master ${role}
    else
        # 寻找到新的 master，修改 postgresql.auto.conf 中 host 值为新主 名称, 重启服务使生效
        get_new_master
        if [ $? -eq 0 ];then
            docker exec postgresql sed -r -i "s/(host=)[^\ ]+/\1${new_master}/" /var/lib/postgresql/data/postgresql.auto.conf
            docker exec postgresql psql -U postgres -h ${new_master} -c "select * from pg_replication_slots;" |grep ${slots[${role}]}
            if [ $? -ne 0 ];then
                docker exec postgresql psql -U postgres -h ${new_master} -c "select pg_create_physical_replication_slot('${slots[${role}]}');"
            fi
            docker-compose  restart
            if [ $? -eq 0 ];then
                logging "Restart success"
                docker exec postgresql psql -U postgres -h ${new_master} -c "select slot_name,active,restart_lsn from pg_replication_slots;" &>> ${log}
            else
                logging "Restart failed"
            fi

        fi
    fi
}

sync_data(){
    rm -rf ${real_path}
    docker run --rm -v ${real_path}:${cdata_dir}  ${image} pg_basebackup -h 10.10.7.19 -p 5432 -U pguser  -D ${cdata_dir} ${args} ${slots[${role}]}
}

reset_pg (){
    docker-compose down
    data_dir=$(grep "${cdata_dir}" docker-compose.yaml |awk -F [:-] '{print $2}')
    if [ ${data_dir:1:1} == "/" ];then
        real_path=${data_dir}
    else
        real_path=`pwd`/${data_dir#*/}
    fi
    mv ${data_dir%/}{,-`date +%F-%H%M%S`-back}
    logging 备份数据目录 ${real_path}
    docker-compose up -d 
    sleep 10
    logging  获取新的master
    get_new_master
    docker exec postgresql psql -U postgres -h ${new_master} -c "select * from pg_replication_slots;" |grep ${slots[${role}]} >> ${log}
    if [ $? -eq 0 ];then
        args="-X stream -P -v -R -w -S"
    else
        args="-X stream -P -v -R -w -C -S"
    fi
    docker-compose down
    logging 同步
    sync_data
    docker-compose up -d
}

main(){
    logging check ....
    # 只检查容器服务是否健康
    if check_status ;then
       if [ "${role}" == "${master}" ];then
           check_master
           if [ $? -eq 0 ];then
               logging "Local is master, it's OK"
           else
               reset_pg
           fi
       else
           # 检查本地容器服务是否健康和 master 和另一台主机 是否能够正常通信
           # 如果只是与 master 通信异常，则根据预定义规则，切换新的 master
           # 如果与另外两台机器通信都异常，则什么都不做
           logging Local is ok,check master ${master}
           check_master
           if [ $? -ne 0 ];then
               for node in ${db_pool[@]}
               do
                   if [ ${node} != "${master}" -a ${node} != "${role}" ];then
                       #echo  Another node is ${node}
                       check_another_slave ${node}
                       if [ $? -ne 0 ];then
                          logging "Lost connection. Do nothing."
                          echo "Lost connection. Do nothing."
                       else
                          logging "Master is wrong, look for a new master"
                          change_judge
                       fi
                   fi
               done
           fi
       fi
    else
        reset_pg
    fi
}

main
