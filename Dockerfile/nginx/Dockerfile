FROM nginx:1.21.6-alpine
LABEL maintainer="Hoke <hoke58@qq.com>, zhangfei" version="1.21.6-alpine-logrotate" date="06/06/2022"

COPY ./nginx_log.conf /etc/logrotate.d/
RUN set -eux; \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories; \
    apk -U upgrade; \
    apk add --no-cache bash logrotate busybox-extras; \
    rm -rf /var/cache/apk/*; \
    echo "0 1 * * * /usr/sbin/logrotate -f /etc/logrotate.d/nginx_log.conf && kill -USR1 `cat /etc/nginx/logs/nginx.pid` && /bin/chown -R \${HOST_UID}:\${HOST_GID} /etc/nginx/logs/*.log "  > /var/spool/cron/crontabs/root
CMD nginx && crond -f
