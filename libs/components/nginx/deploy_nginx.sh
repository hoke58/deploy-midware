#!/bin/bash

# Color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

CONTAINER_EXEC="docker exec -i $CONTAINER_ID sh -c"
declare -a IPADDRS

DeployNginx() {
    mkdir -p ${MW_WkDir}/vhost/stream ${MW_WkDir}/logs $dynamic_nginx_www
    \cp -a ${MW_VersionDir}/html ${MW_WkDir}
    \cp -a ${MW_VersionDir}/conf/nginx.conf ${MW_WkDir}
    \cp -rf ${MW_TmpltYml} ${MW_Yml}
    sed -e "s#\${USER_UID}#$USER_UID#g" \
        -e "s#\${GROUP_GID}#$GROUP_GID#g" \
        -e "s/\${dynamic_nginx_port}/$dynamic_nginx_port/g" \
        -e "s#\${dynamic_nginx_www}#$dynamic_nginx_www#g" \
        -e "s/\${global_nginx_version}/${global_nginx_version}/g" \
        -e "s#\${DOCKER_REPO}#$global_docker_repo#g" \
        -i ${MW_Yml}
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

get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^127\.|^255\.|^0\." | head -n 1 )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

# Pre-installation settings
check_ip() {
    local IPADDR=$1
    VALID_CHECK=$(echo $IPADDR|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
    if echo $IPADDR|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" >/dev/null; then
        if [ "$VALID_CHECK" == "yes" ]; then
         echo "IP $IPADDR available!"
            return 0
        else
            colorEcho $RED "IP $IPADDR not available!"
            return 1
        fi
    else
        colorEcho $RED "IP format error!"
        return 1
    fi
}

which_action() {
    local nginx_command=(vhost proxy)
    while true; do
    echo -e "select command:"
    for ((i=1;i<=${#nginx_command[@]};i++ )); do
        hint="${nginx_command[$i-1]}"
        echo -e "${i}) ${hint}"
    done
    read -p "Select command（default: ${nginx_command[0]}）:" input_nu
    [ -z "$input_nu" ] && input_nu=1
    expr ${input_nu} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        colorEcho $RED "ERROR: invalid input"
        continue
    fi
    if [[ "$input_nu" -lt 1 || "$input_nu" -gt ${#nginx_command[@]} ]]; then
        colorEcho ${RED} "Error: invalid input， number must be between 1 to ${#nginx_command[@]}"
        continue
    fi
    ACTION=${nginx_command[$input_nu-1]}
    break
    done
}

pre_install(){
    while true; do
        echo -e "请输入域名(server_name)${red}勿加前缀 http:// 或 https:// ${plain}:"
        read -p "(eg. abc.com):" servername
        if [ -n "$servername" ]; then
            echo
            echo "---------------------------------------------"
            echo "域名(server_name) = ${servername}"
            echo "---------------------------------------------"
            echo
            break
        fi
    done
    while true; do
        i=0
        echo -e "请输入后端服务的IP，多个IP以空格分隔:"
        read -p "(IP格式：xxx.xxx.xxx.xxx xxx.xxx.xxx.xxx):" inputip
        for ip in $inputip; do
            check_ip $ip
            result=$?
            [ $result -ne 0 ] && break
            IPADDRS[$i]=$ip
            let i++
        done
        if [ $result -eq 0 -a $i -eq ${#IPADDRS[@]} ]; then
            break
        fi
    done
    echo
    echo "---------------------------------------------"
    for ((i=1;i<=${#IPADDRS[@]};i++ )); do
        echo "后端服务$i IP = ${IPADDRS[$i-1]}"
    done    
    echo "---------------------------------------------"
    echo
    while true; do
    echo -e "请输入后端服务端口"
    read -p "(eg. 5555):" proxyport
    if [ -n "$proxyport" ]; then
        expr ${proxyport} + 1 &>/dev/null
        if [ $? -eq 0 ]; then
        echo "\${proxyport:0:1}=${proxyport:0:1}"
            # if [ ${proxyport} -eq 4040 ] || [ ${proxyport} -ge 14000 -a ${proxyport} -le 14015 ] && [ ${proxyport:0:1} != 0 ]; then
                echo
                echo "---------------------------------------------"
                echo "需要代理的联盟银行端口 = ${proxyport}"
                echo "---------------------------------------------"
                echo
                break
            # fi
        fi
    else    
        echo -e "[${red}Error${plain}] Please enter a correct number"
    fi
    done
    set +x  
}

display(){
echo "----------------------------------------------------------------------------"
echo -e "即将按以下值生成配置，请再次核对："
echo -e "域名(server_name):     ${yellow}${servername}${plain}"
for ((i=1;i<=${#IPADDRS[@]};i++ )); do
echo -e "后端服务${i} IP: ${yellow}${IPADDRS[$i-1]}${plain}"
done
echo -e "后端服务端口:   ${yellow}${proxyport}${plain}"
echo -e "按任意键继续，按${yellow}ctrl+c${plain}取消"
echo "----------------------------------------------------------------------------"
echo
char=`get_char`
}

# Config vhosts
config_vhosts(){
mkdir -p ${MW_WkDir}/vhost
if [ -f ${MW_WkDir}/vhost/$servername.conf ]; then
    colorEcho $YELLOW "${MW_WkDir}/vhost/$servername.conf already exists, Are you sure overwrite it?"
    askProceed
fi    
    cat > ${MW_WkDir}/vhost/$servername.conf<<-EOF
upstream app_backend {
    #ip_hash;
}

server {
    listen 80;
    server_name ${servername};
    access_log logs/${servername}.log main;
    error_log logs/${servername}.error.log;
    error_page 404 /404.html;
    error_page 502 503 504 /error.html;
    location /404.html{ root /html; }
    location error.html{ root /html; }
    location ~(/app/|/content/)$ { return 404; }

    location / {
        if (\$request_method ~ (TRACE|TRACK)\$) { return 403; }
        root /www/${servername};
        index index.html;
    }

    location /api {
        if (\$request_method ~ (TRACE|TRACK)\$) { return 403; }
        proxy_pass http://app_backend; 
    }
}
EOF

for ((i=1;i<=${#IPADDRS[@]};i++ )); do
    server="    server ${IPADDRS[$i-1]}:${proxyport} max_fails=2 fail_timeout=10s;"
    sed -i -e "/ip_hash/a\    ${server}" ${MW_WkDir}/vhost/$servername.conf
done

}

# nginx restart
nginx_restart(){
    $CONTAINER_EXEC "nginx -t"
    [[ $? -eq 1 ]] && return 1
    docker-compose -f ${MW_Yml} restart
    [[ $? -eq 1 ]] && return 1
    colorEcho $GREEN "${MW_WkDir}/vhost/$servername.conf was enabled"
    colorEcho $YELLOW "please upload static resources to /www/${servername}, if you have it"
}

up_nginx(){
    regex_match=8282:8282
    $CONTAINER_EXEC "nginx -t"
    [[ $? -eq 1 ]] && return 1
    check_dockercompose=`grep -c ${proxyport} ${MW_Yml}`
    echo "开始重建Nginx容器"
    docker-compose -f ${MW_Yml} down
    if [ ${check_dockercompose} -eq 0 ]; then
        sed -i -e "/${regex_match}/a\    - ${proxyport}:${proxyport}" ${MW_Yml}
    fi
    docker-compose -f ${MW_Yml} up -d
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}]Nginx容器启动失败" && exit 1
    fi    
}

proxy_pre(){
    local proxy_mode=(http/https tcp)
    while true; do
        echo -e "选择代理模式 http/https 7层代理； tcp 4层代理"
        echo -e "select command:"
        for ((i=1;i<=${#proxy_mode[@]};i++ )); do
            hint="${proxy_mode[$i-1]}"
            echo -e "${i}) ${hint}"
        done
        read -p "Select command（default: ${proxy_mode[0]}）:" input_nu
        [ -z "$input_nu" ] && input_nu=1
        expr ${input_nu} + 1 &>/dev/null
        if [ $? -ne 0 ]; then
            colorEcho $RED "ERROR: invalid input"
        continue
        fi
        if [[ "$input_nu" -lt 1 || "$input_nu" -gt ${#proxy_mode[@]} ]]; then
        colorEcho ${RED} "Error: invalid input， number must be between 1 to ${#proxy_mode[@]}"
        continue
        fi
        nginx_proxy_mode=${proxy_mode[$input_nu-1]}
        nginx_proxy_mode_select=$input_nu
        echo
        echo "---------------------------------------------"
        echo "代理模式 = ${nginx_proxy_mode}"
        echo "---------------------------------------------"
        echo
        break
    done 

    # Set proxy name
    while true; do
        echo -e "定义代理名称（${red}不支持中文${plain}）:\n"
        read -p "(eg. hbcc_cloud):" proxyname
        if [ -n "${proxyname}" ]; then
            echo
            echo "---------------------------------------------"
            echo "代理名称 = ${proxyname}"
            echo "---------------------------------------------"
            echo
        break
        fi
    done
    # Set proxy domain
    while true; do
        echo -e "输入代理的域名，格式为http/https://域名（${red}请加前缀 http:// 或 https:// ${plain}）:"
        read -p "(eg. https://proxy.domain.com):" proxydomain
        if [ -n "${proxydomain}" ]; then
            echo
            echo "---------------------------------------------"
            echo "代理域名 = ${proxydomain}"
            echo "---------------------------------------------"
            echo
            ng_server_name=`echo ${proxydomain} | awk -F '//' '{print $2}'`
            ng_protocol=`echo ${proxydomain} | awk -F '//' '{print $1}'`
            break
        fi
    done
    # Set proxy Pub IP
    while true; do
        echo -e "请输入${proxydomain}的公网IP:"
        read -p "(IP格式：xxx.xxx.xxx.xxx):" IPADDR 
        check_ip $IPADDR
        [ $? -eq 0 ] && break
    done
    echo
    echo "---------------------------------------------"
    echo "${proxydomain} 公网IP = ${IPADDR}"
    echo "---------------------------------------------"
    echo   
    # Set proxy port
    while true
    do
    dport=$(shuf -i 10000-15000 -n 1)
    echo -e "输入访问端口 [4040,10000-15000]"
    read -p "(eg. org12-cloud 端口： 13012):" proxyport
    [ -z "${proxyport}" ] && proxyport=${dport}
    expr ${proxyport} + 1 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ ${proxyport} -eq 4040 ] || [ ${proxyport} -ge 10000 -a ${proxyport} -le 15000 ] && [ ${proxyport:0:1} != 0 ]; then
            echo
            echo "---------------------------------------------"
            echo "代理端口 = ${proxyport}"
            echo "---------------------------------------------"
            echo
            break
        fi
    fi
    echo -e "[${red}Error${plain}] Please enter a correct number [10000-15000]"
    done
}

proxy_display(){
echo "----------------------------------------------------------------------------"
echo -e "即将按以下值生成配置，请再次核对："
echo -e "代理模式:   ${yellow}${nginx_proxy_mode}${plain}"
echo -e "代理名称:   ${yellow}${proxyname}${plain}"
echo -e "代理域名:   ${yellow}${proxydomain}${plain}"
echo -e "公网IP:     ${yellow}${IPADDR}${plain}"
echo -e "代理端口:   ${yellow}${proxyport}${plain}"
echo -e "按任意键继续，按${yellow}ctrl+c${plain}取消"
echo "----------------------------------------------------------------------------"
echo
char=`get_char`
}

# Config vhosts
proxy_vhost(){
    if [ $nginx_proxy_mode_select -eq 1 ]; then
    cat > ${MW_WkDir}/vhost/proxy_$proxyname.conf<<-EOF
server {
    listen ${proxyport};
    server_name ${ng_server_name};
    access_log logs/${proxyname}.access.log main;
    error_log logs/${proxyname}.error.log;
    location ~(/app/|/content/)$ { return 404; } 
    location / {
        if (\$request_method ~ (TRACE|TRACK)\$) { return 403; }
        proxy_pass ${ng_protocol}//${IPADDR}:${proxyport};
        proxy_set_header Host \$host;
    }
}
EOF

    else
    cat > ${MW_WkDir}/vhost/stream/proxy_$proxyname.conf<<-EOFEOF
server {
    listen ${proxyport};
	proxy_pass ${IPADDR}:${proxyport};
    access_log  logs/stream_${proxyname}.log stream_proxy;
}
EOFEOF

    fi
    set +x
}

case $1 in
    1)
        DeployNginx
    ;;
    2)
        which_action
        if [ $ACTION == "vhost" ]; then
            pre_install
            display
            config_vhosts
            nginx_restart
        elif [ $ACTION == "proxy" ]; then
            proxy_pre
            proxy_display
            proxy_vhost $nginx_proxy_mode_select
            up_nginx
            check_port=`ss -lntp |egrep -c ${proxyport}`
            if [ -n ${check_port} ]; then
                echo -e "${green}${proxydomain}:${proxyport}${plain} is running"
            else
                echo -e "[${red}Error${plain}]Nginx proxy server install failed, please contact to Admin." && exit 1
            fi
        fi
    ;;
    *)
        colorEcho $RED "ERROR: invalid input"
        exit 1
    ;;
esac