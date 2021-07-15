db.getSiblingDB("admin").auth("MONGO_ADMIN", "MONGO_ADMINPASS")
db.getSiblingDB("cache_database")
db.createUser({ user:"mongouser",pwd:"mongouser123",roles:[{role:"readWrite", db: "cache_database"}]})
db.getSiblingDB("cache_database").auth("mongouser","mongouser123")
