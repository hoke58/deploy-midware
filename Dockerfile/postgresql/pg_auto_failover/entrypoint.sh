#!/bin/bash
set -xo pipefail

MONITOR_PORT=${PGPORT:-5432}
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-"postgres123"}"
user_id=${HOST_UID:-1000}
group_id=${HOST_GID:-1000}
declare -g DATABASE_ALREADY_EXISTS
# look specifically for PG_VERSION, as it is expected in the DB dir
if [ -s "$PGDATA/PG_VERSION" ]; then
  DATABASE_ALREADY_EXISTS='true'
fi

UpdateConf() {
  # pg_hba_conf=`grep "host \"pg_auto_failover\" \"autoctl_node\" 0.0.0.0/0 trust" $PGDATA/pg_hba.conf`
  if [ -z "$(grep "host \"pg_auto_failover\" \"autoctl_node\" 0.0.0.0/0 trust" $PGDATA/pg_hba.conf)" -a "$RUNNING_MODE" == "postgresql_monitor" ]; then
    echo 'host "pg_auto_failover" "autoctl_node" 0.0.0.0/0 trust' >>$PGDATA/pg_hba.conf
    if [ $? -ne 0 ]; then
        echo "ERROR: pg_hba.conf 配置失败"
    fi
  fi
  if [ -z "$(grep "host all all all md5" $PGDATA/pg_hba.conf)" -a "$RUNNING_MODE" == "postgresql_solo" ]; then
    sed -i "/host all all all md5/"d $PGDATA/pg_hba.conf
    echo "host all all all md5" >>$PGDATA/pg_hba.conf
  fi  
  #修改连接配置
  if [ -f $PGDATA/postgresql.conf ]; then
    sed -i $PGDATA/postgresql.conf \
    -e 's/max_connections = 100/max_connections = 1200/' \
    -e 's/#tcp_keepalives_idle = 0/tcp_keepalives_idle = 600/' \
    -e 's/#tcp_keepalives_interval = 0/tcp_keepalives_interval = 10/' \
    -e 's/#tcp_keepalives_count = 0/tcp_keepalives_count = 6/'
  fi
}

setup_hba_conf() {
  if [ "$RUNNING_MODE" == "postgresql_node" -a "$(grep "postgresql2" $PGDATA/pg_hba.conf)" ]; then
    sed -i "/host all all all md5/"d $PGDATA/pg_hba.conf
    echo "host all all all md5" >>$PGDATA/pg_hba.conf
  fi
}

soloPG() {
  if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
    echo "$POSTGRES_PASSWORD" >/opt/postgres_password
    /usr/lib/postgresql/12/bin/initdb -D $PGDATA --username=postgres --pwfile=/opt/postgres_password
    UpdateConf
  fi

  # internal start of server in order to allow setup using psql client
  # does not listen on external TCP/IP and waits until start finishes
# pg_ctl -D /var/lib/postgresql/data -o '-c listen_addresses= -p 5432 ' -w start
  set -- "$@" -c listen_addresses='*' -p "${PGPORT:-5432}"
  PGUSER="postgres"
  pg_ctl -D $PGDATA -o "$(printf '%q ' "$@")" -w start
  pg_ctl -D $PGDATA -m fast -w stop
}

# exec gosu postgres $RUN_COMMAND
if [ "$(id -u)" = '0' ]; then
  groupmod -g $group_id postgres
  usermod -u ${user_id} -g ${group_id} postgres
  chown -R ${user_id}:${group_id} /var/run/postgresql /var/lib/postgresql /opt
  chmod 777 /var/lib/postgresql
  # then restart script as postgres user
  exec gosu postgres "$BASH_SOURCE"
fi
case "$RUNNING_MODE" in
  postgresql_monitor)
    # pg_autoctl create monitor --no-ssl --auth=trust --run
    pg_autoctl create monitor --no-ssl --auth=trust
    UpdateConf
    pg_autoctl run --name $HOSTNAME --hostname $HOSTNAME
    ;;
  postgresql_node)
    if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
      pg_autoctl create postgres --no-ssl --auth trust --name $HOSTNAME --hostname $HOSTNAME --pg-hba-lan --monitor postgres://autoctl_node@postgresql_monitor:$MONITOR_PORT/pg_auto_failover?sslmode=prefer
      UpdateConf
    fi
    setup_hba_conf
    pg_autoctl run --name $HOSTNAME --hostname $HOSTNAME
    ;;
  postgresql_solo)
    soloPG
    exec postgres -h \*
esac