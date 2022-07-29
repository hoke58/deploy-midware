#
# Using --build-arg PGVERSION=11 we can build pg_auto_failover for any
# target version of Postgres. In the Makefile, we use that to our advantage
# and tag test images such as pg_auto_failover_test:pg14.
#
ARG PGVERSION=12

#
# Define a base image with all our build dependencies.
#
# This base image contains all our target Postgres versions.
#
FROM debian:buster-slim as base

ARG PGVERSION

COPY sources.list /etc/apt/

RUN apt-get update; \
    apt-get upgrade; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    gnupg \
    git \
    iproute2 \
    libicu-dev \
    libkrb5-dev \
    libssl-dev \
    libedit-dev \
    libreadline-dev \
    libpam-dev \
    zlib1g-dev \
    liblz4-dev \
    libxml2-dev \
    libxslt1-dev \
    libselinux1-dev \
    libncurses-dev \
    libncurses6 \
    lsb-release \
    make \
    openssl \
    pipenv \
    python3-nose \
    python3 \
    python3-setuptools \
    python3-psycopg2 \
    python3-pip \
    sudo \
    tmux \
    watch \
    lsof \
    psutils \
    valgrind \
    postgresql-common; \
    # rm -rf /var/lib/apt/lists/*; \
    \
    curl http://mirrors.cloud.tencent.com/postgresql/repos/apt/ACCC4CF8.asc | apt-key add -; \
    echo "deb https://mirrors.cloud.tencent.com/postgresql/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list; \
    \
# bypass initdb of a "main" cluster
    echo 'create_main_cluster = false' | sudo tee -a /etc/postgresql-common/createcluster.conf; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    postgresql-server-dev-${PGVERSION} \
    postgresql-${PGVERSION} \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    pip3 install pyroute2>=0.5.17 -i https://pypi.mirrors.ustc.edu.cn/simple/

# RUN adduser --disabled-password --gecos '' docker
# RUN adduser docker sudo
# RUN adduser docker postgres
# RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

#
# On-top of the base build-dependencies image, now we can build
# pg_auto_failover for a given --build-arg PGVERSION target version of
# Postgres.
#
FROM base as build

ARG PGVERSION

ENV PG_CONFIG /usr/lib/postgresql/${PGVERSION}/bin/pg_config

WORKDIR /usr/src/pg_auto_failover

COPY Makefile ./
COPY ./src/ ./src
RUN make -s clean && make -s install -j8

#
# Given the build image above, we can now run our test suite targetting a
# given version of Postgres.
#
FROM build as test

ARG PGVERSION

COPY ./tests/ ./tests
COPY ./valgrind ./valgrind
RUN chmod a+w ./valgrind

# USER docker

ENV PG_AUTOCTL_DEBUG=1 \
    PATH=/usr/lib/postgresql/${PGVERSION}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

#
# And finally our "run" images with the bare minimum for run-time.
#
FROM debian:buster-slim as run

ARG PGVERSION

COPY sources.list /etc/apt/
RUN apt-get update; \
    apt-get upgrade; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    gosu \
    make \
    sudo \
    tmux \
    watch \
    libncurses6 \
    locales \
    lsb-release \
    lsof \
    psutils \
    dnsutils \
    bind9-host \
    postgresql-common \
    libpq-dev \
    iputils-ping \
    telnet; \
    # rm -rf /var/lib/apt/lists/*; \
    \
    sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen; \
    locale-gen; \
    curl http://mirrors.cloud.tencent.com/postgresql/repos/apt/ACCC4CF8.asc | apt-key add -; \
    echo "deb https://mirrors.cloud.tencent.com/postgresql/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list; \
    \
# bypass initdb of a "main" cluster
    echo 'create_main_cluster = false' | sudo tee -a /etc/postgresql-common/createcluster.conf; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends postgresql-${PGVERSION} \
    ; \
    rm -rf /var/lib/apt/lists/*

# RUN adduser --disabled-password --gecos '' --home /var/lib/postgres docker
# RUN adduser docker sudo
# RUN adduser docker postgres
# RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

COPY --from=build /usr/lib/postgresql/${PGVERSION}/lib/pgautofailover.so /usr/lib/postgresql/${PGVERSION}/lib
COPY --from=build /usr/share/postgresql/${PGVERSION}/extension/pgautofailover* /usr/share/postgresql/${PGVERSION}/extension/
COPY --from=build /usr/lib/postgresql/${PGVERSION}/bin/pg_autoctl /usr/local/bin

#
# In tests/upgrade/docker-compose.yml we use internal docker volumes in
# order to be able to restart the nodes and keep the data around. For that
# to work, we must prepare a mount-point that is owned by our target user
# (docker), so that once the volume in mounted there by docker compose,
# pg_autoctl has the necessary set of privileges.
#
COPY entrypoint.sh /entrypoint.sh
RUN mkdir -p /var/lib/postgresql; \
    chmod +x /entrypoint.sh; \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers; \
    usermod -aG sudo postgres

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/lib/postgresql/${PGVERSION}/bin \
    PG_AUTOCTL_DEBUG=1 \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    TZ=Asia/Shanghai \
    PGDATA=/var/lib/postgresql/data

# CMD pg_autoctl do tmux session --nodes 3 --binpath /usr/local/bin/pg_autoctl
# ENTRYPOINT /entrypoint.sh
