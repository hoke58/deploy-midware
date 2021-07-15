db.getSiblingDB("admin").auth("root", "root123" )
db.getSiblingDB("mongo")
db.getSiblingDB("mongo").auth("mongouser","mongouser123")
db.getCollection("hbcc_receiver_cfg").insert({
    "_id":"loc",
    "_class": "com.hoperun.hbcc.receive.msg.domain.ReceiverConfig",
    "sysQueueName": "sys_fftQueue",
    "user_alias": "user_alias_loc",
    "queueName": "fftQueue",
    "consumerAmountsPreQueue": NumberInt("8"),
    "consumerPreConn": NumberInt("2"),
    "mqcfg": {
        "userName": "loc",
        "passwd": "loc",
        "addresses": [
            "mq0.finrunchain.com:5672"
        ]
    },
    "mongocfg": {
        "uri": "mongodb://mongouser:mongouser123@mongodb1.runchain.tech:27010",
        "database": "mongo",
        "collectionBase": "fftQueue"
    }
})


db.getCollection("hbcc_receiver_cfg").insert({
    "_id":"agent_for_LC",
    "_class": "com.hoperun.hbcc.receive.msg.domain.ReceiverConfig",
    "sysQueueName": "sys_agentQueue",
    "user_alias": "user_alias_loc",
    "queueName": "agentQueue",
    "consumerAmountsPreQueue": NumberInt("8"),
    "consumerPreConn": NumberInt("2"),
    "mqcfg": {
        "userName": "loc",
        "passwd": "loc",
        "addresses": [
            "mq0.finrunchain.com:5672"
        ]
    },
    "mongocfg": {
        "uri": "mongodb://mongouser:mongouser123@mongodb1.runchain.tech:27010",
        "database": "mongoagent",
        "collectionBase": "CTFU_channelfft"
    }
})