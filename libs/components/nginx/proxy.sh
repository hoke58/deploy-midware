#!/usr/bin/env bash
######################脚本注释#############################
# 文件名： proxy.sh                                       #
# 功  能： 一键化生成nginx代理脚本                        #
# 作  者： hoke                                           #
# 时  间： 20190116                                       #
###########################################################

#Current folder
cur_dir=`pwd`
#vhosts_path=${cur_dir}/nginx/vhost
regex_match=8282:8282
CONTAINER_ID=`docker ps -q -f name=nginx`
FILE_UID=`stat -c %u $cur_dir/nginx/conf/nginx.conf`
FILE_GID=`stat -c %u $cur_dir/nginx/conf/nginx.conf`

# Color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

clear
echo "#############################################################"
echo "#              一键生成nginx vhost                        #"
echo "# 请准备如下信息（以下以福费廷应用为例）：            #"
echo "# 1. 需要代理的联盟银行名称，例：hbcc_ctfu                  #"
echo "# 2. 需要代理的联盟银行域名，例：https://hbcc.ctfu.china-cba.net#"
echo "# 3. 需要代理的联盟银行端口，例：14000                      #"
echo "# 注：如输入错误可按 “ctrl+c” 取消，重新执行！              #"
echo "#############################################################"
echo

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

function check_ip() {
    local IPADDR=$1
    VALID_CHECK=$(echo $IPADDR|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
    if echo $IPADDR|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" >/dev/null; then
        if [ $VALID_CHECK == "yes" ]; then
         echo "IP $IPADDR  available!"
            return 0
        else
            echo "IP $IPADDR not available!"
            return 1
        fi
    else
        echo "IP format error!"
        return 1
    fi
}

pre_install(){
    # Set proxy bank name
    echo -e "请输入联盟银行名称（${red}不支持中文${plain}）:\n"
    read -p "(eg. 中银协hbcc_cloud：hbcc_ctfu):" proxybank
    [ -z "${proxybank}" ] && proxybank="hbcc_ctfu"
    echo
    echo "---------------------------------------------"
    echo "需要代理的联盟银行名称 = ${proxybank}"
    echo "---------------------------------------------"
    echo
    # Set proxy bank domain
    echo -e "请输入联盟银行hbcc_cloud访问域名（${red}请加前缀 http:// 或 https:// ${plain}）:"
    read -p "(eg. 中银协hbcc_cloud域名：https://hbcc.ctfu.china-cba.net):" proxydomain
    [ -z "${proxydomain}" ] && proxydomain="https://hbcc.ctfu.china-cba.net"
    echo
    echo "---------------------------------------------"
    echo "需要代理的联盟银行域名 = ${proxydomain}"
    echo "---------------------------------------------"
    echo
    ng_server_name=`echo ${proxydomain} | awk -F '//' '{print $2}'`
    # Set proxy bank IP
    while true; do
        echo -e "请输入${proxybank}的公网IP:"
        read -p "(IP格式：xxx.xxx.xxx.xxx):" IPADDR 
        check_ip $IPADDR
        [ $? -eq 0 ] && break
    done
    echo
    echo "---------------------------------------------"
    echo "${proxybank}银行的公网IP = ${IPADDR}"
    echo "---------------------------------------------"
    echo   
    # Set proxy bank port
    while true
    do
    dport=$(shuf -i 14000-14015 -n 1)
    echo -e "请输入联盟银行hbcc_cloud访问端口 [4040,14000-14015]"
    read -p "(eg. 中银协hbcc_cloud端口： 14000):" proxyport
    [ -z "${proxyport}" ] && proxyport=${dport}
    expr ${proxyport} + 1 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ ${proxyport} -eq 4040 ] || [ ${proxyport} -ge 14000 -a ${proxyport} -le 14015 ] && [ ${proxyport:0:1} != 0 ]; then
            echo
            echo "---------------------------------------------"
            echo "需要代理的联盟银行端口 = ${proxyport}"
            echo "---------------------------------------------"
            echo
            break
        fi
    fi
    echo -e "[${red}Error${plain}] Please enter a correct number [14000-14011]"
    done
}

display(){
echo "----------------------------------------------------------------------------"
echo -e "即将按以下值生成配置，请再次核对："
echo -e "需要代理的联盟银行名称:   ${yellow}${proxybank}${plain}"
echo -e "需要代理的联盟银行域名:   ${yellow}${proxydomain}${plain}"
echo -e "需要代理的联盟银行公网IP: ${yellow}${IPADDR}${plain}"
echo -e "需要代理的联盟银行端口:   ${yellow}${proxyport}${plain}"
echo -e "按任意键继续，按${yellow}ctrl+c${plain}取消"
echo "----------------------------------------------------------------------------"
echo
char=`get_char`
}

# Config vhosts
config_vhosts(){
mkdir -p /tmp/proxy
    cat > /tmp/proxy/$proxybank.conf<<-EOF
server {
    listen ${proxyport};
    server_name ${ng_server_name};
    access_log logs/${proxybank}.access.log main;
    error_log logs/${proxybank}.error.log;
    location ~(/app/|/content/)$ {
        return 404;
    } 
    location / {
        if (\$request_method = TRACE ) {
        return 403;
        }
        if (\$request_method = TRACK ) {
        return 403;
        }
        proxy_pass ${proxydomain}:${proxyport};
    }
}
EOF

docker cp /tmp/proxy/$proxybank.conf $CONTAINER_ID:/etc/nginx/vhost
docker exec -i $CONTAINER_ID chown $FILE_UID:$FILE_GID /etc/nginx/vhost/$proxybank.conf
rm -rf /tmp/proxy
}

# nginx restart
nginx_restart(){
    check_dockercompose=`grep -c ${proxyport} $cur_dir/docker-compose.yml`
    echo "开始重建Nginx容器"
    docker-compose -f $cur_dir/docker-compose.yml down
    if [ ${check_dockercompose} -eq 0 ]; then
        sed -i -e "/${regex_match}/a\    - ${proxyport}:${proxyport}" $cur_dir/docker-compose.yml
        sed -i -e "/extra_hosts/a\      ${ng_server_name}: ${IPADDR}" $cur_dir/docker-compose.yml
    fi
    docker-compose -f $cur_dir/docker-compose.yml up -d
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}]Nginx容器启动失败，请联系CTFU" && exit 1
    fi    
}

pre_install
display
config_vhosts
nginx_restart
clear
check_port=`ss -lntp |egrep -c ${proxyport}`
if [ -n ${check_port} ]; then
    echo
    echo "----------------------------------------------------------------------------"
    echo -e "Nginx代理服务启动完成，请继续根据以下说明操作！"
    echo -e "以下是贵行与联盟银行${green}${proxybank}${plain}的hbcc_cloud访问地址"
    echo -e "${green}${proxydomain}:${proxyport}${plain}"
    echo -e "请在福费廷(forfaiting)的${green}docker-compose.yml${plain}文件${green}extra_hosts${plain}配置项中增加以下值"
    echo -e "${yellow}${ng_server_name}: 本机的IP${plain}"
    echo "----------------------------------------------------------------------------"
    echo
else
    echo -e "[${red}Error${plain}]Nginx proxy server install failed, please contact to CTFU." && exit 1
fi

