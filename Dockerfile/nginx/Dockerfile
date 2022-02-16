FROM nginx:1.20.1-alpine
LABEL maintainer="Hoke <hoke58@qq.com>, zhangfei" version="nginx-1.20.1"

COPY ./nginx_log.conf /etc/logrotate.d/
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories \
    && apk add logrotate  \
    && rm -rf /var/cache/apk/*   \
    && echo "0 1 * * * /usr/sbin/logrotate -f /etc/logrotate.d/nginx_log.conf && /bin/chown -R \${HOST_UID}:\${HOST_GID} /etc/nginx/logs/*.log "  > /var/spool/cron/crontabs/root 
CMD nginx && crond -f
