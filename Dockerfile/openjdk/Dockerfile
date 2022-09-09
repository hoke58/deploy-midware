FROM adoptopenjdk/openjdk8:jdk8u342-b07-alpine-slim
LABEL MAINTAINER="Hoke" description="alpine-jdk8-gosu" date="08/03/2022"
ENV TZ=Asia/Shanghai \
    GOSU_VERSION=1.14
#    LANGUAGE=en_US.UTF-8 \
#    LANG=en_US.UTF-8
#ADD alpine-pkg-glibc /tmp/
# Install language pack
RUN set -eux; \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    apk -U upgrade; \
    apk add --no-cache tzdata bash curl; \
    apk add --no-cache --virtual .gosu-deps \
        ca-certificates \
        dpkg \
        gnupg \
    ; \
    \
    apk add --update ttf-dejavu fontconfig; \
#    mv /tmp/sgerrand.rsa.pub /etc/apk/keys/sgerrand.rsa.pub; \
#    apk add /tmp/glibc-2.34-r0.apk /tmp/glibc-bin-2.34-r0.apk /tmp/glibc-i18n-2.34-r0.apk; \
#    /usr/glibc-compat/bin/localedef -i en_US -f UTF-8 en_US.UTF-8; \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime; \
    echo "Asia/Shanghai" > /etc/timezone; \
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
    #wget -e "https_proxy=10.10.255.2:10809" -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
    #wget -e "https_proxy=10.10.255.2:10809" -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
    curl -x 10.10.255.12:10803 -LJo /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
    curl -x 10.10.255.12:10803 -LJo /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
    \
# verify the signature
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
    command -v gpgconf && gpgconf --kill all || :; \
# clean up fetch dependencies
    apk del --no-network .gosu-deps; \
    \
    chmod +x /usr/local/bin/gosu; \
    rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc /tmp/glibc-2.34-r0.apk /tmp/glibc-bin-2.34-r0.apk /tmp/glibc-i18n-2.34-r0.apk /tmp/sgerrand.rsa.pub; \
# verify that the binary works
    gosu --version; \
    gosu nobody true