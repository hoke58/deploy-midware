#!/bin/bash
user_file=/custom/creatAdmin.js
repl_file=/custom/creatRepl.js
generateConf() {
cat > ${repl_file} <<-EOF
cfg = {"_id": "replcluster", "members":[
    {"_id": 0,"host":"mongodb1:27017","priority":2},
    {"_id": 1,"host":"mongodb2:27017","priority":1},
    {"_id": 2,"host":"mongodb3:27017","arbiterOnly":true},
]}

rs.initiate(cfg)
EOF

cat > ${user_file} <<-EOF
admin = db.getSiblingDB("admin")
db.createUser({ user:"ADMINUSER",pwd:"ADMINPASS",roles:["root"]})
EOF

chown -R ${HOST_UID}:${HOST_GID} /custom && chown -R ${HOST_UID}:${HOST_GID} /data
}
argsSet() {
    if [ ! -z $MONGO_ADMIN ] && [ ! -z $MONGO_ADMINPASS ];then
        sed -i "s/ADMINUSER/${MONGO_ADMIN}/g" ${user_file}
        sed -i "s/ADMINPASS/${MONGO_ADMINPASS}/g" ${user_file}
    fi
}

generateConf
argsSet
