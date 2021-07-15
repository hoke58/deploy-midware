db.getSiblingDB("admin").auth("root", "root123" )
db.getSiblingDB("mongocloud")
db.getSiblingDB("mongocloud").auth("mongouser","mongouser123")
db.getCollection("hbcc_cloud_authority").insert([{
	"_class" : "com.hoperun.qkl.cloud.service.domain.ugm.Authority",
	"_id" : "ROLE_ADMIN"
    },
    {
	"_class" : "com.hoperun.qkl.cloud.service.domain.ugm.Authority",
	"_id" : "ROLE_USER"
}])

db.getCollection("hbcc_cloud_user").insert([{
	"_class" : "com.hoperun.qkl.cloud.service.domain.ugm.User",
	"_id" : "admin",
	"activated" : true,
	"authorities" : [
		{
			"_id" : "ROLE_USER"
		},
		{
			"_id" : "ROLE_ADMIN"
		}
	],
	"created_by" : "system.init",
	"created_date" : ISODate("2020-01-21T21:59:49.921+08:00"),
	"email" : "admin@localhost",
	"first_name" : "admin",
	"lang_key" : "en",
	"last_modified_date" : ISODate("2020-01-21T21:59:49.921+08:00"),
	"last_name" : "Administrator",
	"login" : "admin",
	"password" : "$2a$10$gSAhZrxMllrbgj/kkK9UceBPpChGWJA7SYIb1Mqo.n5aNLq1/oRrC"
},
{
	"_class" : "com.hoperun.qkl.cloud.service.domain.ugm.User",
	"_id" : "user",
	"activated" : true,
	"authorities" : [
		{
			"_id" : "ROLE_USER"
		},
		{
			"_id" : "ROLE_ADMIN"
		}
	],
	"created_by" : "system.init",
	"created_date" : ISODate("2020-01-21T21:59:49.968+08:00"),
	"email" : "user@localhost",
	"first_name" : "user",
	"lang_key" : "en",
	"last_modified_date" : ISODate("2020-01-21T21:59:49.968+08:00"),
	"last_name" : "user",
	"login" : "user",
	"password" : "$2a$10$gSAhZrxMllrbgj/kkK9UceBPpChGWJA7SYIb1Mqo.n5aNLq1/oRrC"
}])