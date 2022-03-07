FROM mongo:4.4.6
LABEL maintainer="Hoke <hoke58@qq.com>" version="4.4.6"

ADD ./custom /custom
# COPY ./custom/docker-entrypoint.sh /usr/local/bin/

RUN mv /custom/docker-entrypoint.sh /usr/local/bin/ \
    && chmod 777 /custom/*.sh /usr/local/bin/docker-entrypoint.sh \
    && chmod 600 /custom/mongo.key
