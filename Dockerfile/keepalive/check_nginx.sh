#!/bin/bash

get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^127\.|^255\.|^0\." | head -n 1 )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

NGINX_C=`curl -f -s http://$(get_ip):8181 | grep OK | wc -l`
if [ $NGINX_C -eq 0 ]; then
  pkill keepalived
fi