db.getSiblingDB("admin").auth("root", "root123")
db.getSiblingDB("mongocloud")
db.createUser({ user:"mongouser",pwd:"mongouser123",roles:[{role:"readWrite", db: "mongocloud"}]})
db.getSiblingDB("mongocloud").auth("mongouser","mongouser123")
