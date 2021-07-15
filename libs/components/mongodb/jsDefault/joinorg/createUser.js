db.getSiblingDB("admin").auth("root", "root123")
db.getSiblingDB("DATABASE")
db.createUser({ user:"MONGO_USER",pwd:"MONGO_PW",roles:[{role:"readWrite", db: "DATABASE"}]})
db.getSiblingDB("DATABASE").auth("MONGO_USER","MONGO_PW")
