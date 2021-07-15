FROM hub.finrunchain.com/midware/keepalived:2.0.20
MAINTAINER Hoke

ADD keepalived.conf /container/service/keepalived/assets/keepalived.conf
ADD check_nginx.sh /opt/check_nginx.sh