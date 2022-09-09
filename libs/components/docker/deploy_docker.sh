#!/bin/bash

REGISTRY_MIRROR=CN

function download_docker() {
  if [[ "$REGISTRY_MIRROR" == CN ]];then
    DOCKER_URL="https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/static/stable/x86_64/docker-${global_docker_ver}.tgz"
  else
    DOCKER_URL="https://download.docker.com/linux/static/stable/x86_64/docker-${global_docker_ver}.tgz"
  fi

  if [[ -f "$mainShellPath/down/docker-${global_docker_ver}.tgz" ]];then
    colorEcho ${YELLOW} "docker binaries already existed"
  else
    colorEcho ${BLUE} "downloading docker binaries, version ${global_docker_ver}"
    if [[ -e /usr/bin/wget ]];then
      wget -c --no-check-certificate "$DOCKER_URL" || { colorEcho ${RED} "downloading docker failed"; exit 1; }
      wget -c --no-check-certificate https://github.com/docker/compose/releases/download/v2.10.2/docker-compose-linux-x86_64 -O $mainShellPath/down/docker-compose
    else
      curl -k -C- -O --retry 3 "$DOCKER_URL" || { colorEcho ${RED} "downloading docker failed"; exit 1; }
      curl -SL https://github.com/docker/compose/releases/download/v2.10.2/docker-compose-linux-x86_64 -o $mainShellPath/down/docker-compose
    fi
    /bin/mv -f "./docker-${global_docker_ver}.tgz" "$mainShellPath/down"
    chmod +x $mainShellPath/down/docker-compose
  fi

  tar zxf "$mainShellPath/down/docker-${global_docker_ver}.tgz" -C "$mainShellPath/down" && \
  /bin/mv -f "$mainShellPath"/down/docker/* /usr/local/sbin && \
  /bin/mv -f "$mainShellPath"/down/docker-compose /usr/local/sbin && \
  ln -sf /usr/local/sbin/docker /bin/docker
}

function install_docker() {
  # check if a container runtime is already installed
  systemctl status docker|grep Active|grep -q running && { colorEcho ${YELLOW} "docker is already running."; return 0; }
 
  colorEcho ${BLUE} "generate docker service file"
  cat > /etc/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io
Requires=docker.socket
[Service]
Environment="PATH=/usr/local/sbin:/bin:/sbin:/usr/bin:/usr/sbin"
ExecStart=/usr/local/sbin/dockerd
ExecStartPost=/sbin/iptables -P FORWARD ACCEPT
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Delegate=yes
KillMode=process
[Install]
WantedBy=multi-user.target
EOF

  cat > /etc/systemd/system/docker.socket << EOF
[Unit]
Description=Docker Socket for the API

[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF

  # configuration for dockerd
  mkdir -p /etc/docker
  groupadd docker
  usermod -aG docker $dynamic_install_user
  DOCKER_VER_MAIN=$(echo "${global_docker_ver}"|cut -d. -f1)
  CGROUP_DRIVER="cgroupfs"
  ((DOCKER_VER_MAIN>=20)) && CGROUP_DRIVER="systemd"
  colorEcho ${BLUE} "generate docker config: /etc/docker/daemon.json"
  cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=$CGROUP_DRIVER"],
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "http://hub-mirror.c.163.com"
  ],
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "10"
    },
  "data-root": "/var/lib/docker"
}
EOF

  if [[ -e /etc/centos-release || -e /etc/redhat-release ]]; then
    colorEcho ${BLUE} "turn off selinux in CentOS/Redhat"
    getenforce|grep Disabled || setenforce 0
    sed -i 's/^SELINUX=.*$/SELINUX=disabled/g' /etc/selinux/config
  fi

  colorEcho ${BLUE} "enable and start docker"
  systemctl daemon-reload && systemctl restart docker && sleep 4
  systemctl enable docker
}

### Main Lines ##################################################
function main() {
  # check if use with root
  [[ "$EUID" -ne 0 ]] && { colorEcho ${RED} "you should run this script as root"; exit 1; }
  
  mkdir -p $mainShellPath/down
  download_docker && \
  install_docker
  chown -R ${dynamic_install_user}. $mainShellPath/down
}

main