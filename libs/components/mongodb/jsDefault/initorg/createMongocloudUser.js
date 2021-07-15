db.getSiblingDB("admin").auth("MONGO_ADMIN", "MONGO_ADMINPASS")
db.getSiblingDB("mongocloud")
db.createUser({ user:"mongouser",pwd:"mongouser123",roles:[{role:"readWrite", db: "mongocloud"}]})
db.getSiblingDB("mongocloud").auth("mongouser","mongouser123")
