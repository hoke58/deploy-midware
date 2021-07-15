db.getSiblingDB("admin").auth("MONGO_ADMIN", "MONGO_ADMINPASS")
db.getSiblingDB("mongo")
db.createUser({ user:"mongouser",pwd:"mongouser123",roles:[{role:"readWrite", db: "mongo"}]})
db.getSiblingDB("mongo").auth("mongouser","mongouser123")

