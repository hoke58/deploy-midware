FROM nginx:1.24.0-alpine
LABEL maintainer="Hoke <hoke58@qq.com>, zhangfei" version="nginx-1.24.0"

COPY ./nginx_log.conf /etc/logrotate.d/
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories \
    && apk --no-cache add logrotate shadow \
    && rm -rf /var/cache/apk/*  /docker-entrypoint.sh \
    && echo '0 1 * * * /usr/sbin/logrotate -f /etc/logrotate.d/nginx_log.conf && kill -USR1 `cat /etc/nginx/logs/nginx.pid` '  >> /var/spool/cron/crontabs/root 
COPY ./docker-entrypoint.sh /
#CMD [ "/root/nginx_userID.sh" , "&&", "nginx", "-g", "daemon off;"]
