db.getSiblingDB("admin").auth("MONGO_ADMIN", "MONGO_ADMINPASS")
db.getSiblingDB("mongoagent")
db.createUser({ user:"mongouser",pwd:"mongouser123",roles:[{role:"readWrite", db: "mongoagent"}]})
db.getSiblingDB("mongoagent").auth("mongouser","mongouser123")
