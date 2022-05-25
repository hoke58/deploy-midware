## Quick start

This shell can quickly startup/shutdown container(s) of middleware, such as mongodb, postgresql, rabbitmq etc.

1. Generate `cfg/dynamic.cfg` by copying from `cfg/dynamic.cfg.template` for main pool or `cfg/dynamic-backup.cfg.template` if you are deploying middleware to backup pool.

```sh
# main pool
cp cfg/dynamic.cfg.template cfg/dynamic.cfg
# backup pool
cp cfg/dynamic-backup.cfg.template cfg/dynamic.cfg
# Update environment variables in cfg/dynamic.cfg (see step 2)
vi cfg/dynamic.cfg
```

2.  Update dynamic environment variables, especially ip addresses of servers, as below

```sh
# workhome ------------------------------------------------------------------
export dynamic_install_user=hoke       #安装运行的用户名
export dynamic_install_userHome=/home/hoke  #用户根目录路径，即部署路径
# -----------------------------------------------------------------------

# Mongodb ----------------------------------------------------------------
export dynamic_mongodb1_ip=10.10.1.1
export dynamic_mongodb2_ip=10.10.1.2
export dynamic_mongodb3_ip=10.10.1.3
```
3. Run the shell

```sh
bash deploy-midware.sh
```

## Make package


Clone this project :

	git clone https://github.com/hoke58/deploy-midware.git
	cd deploy-midware

Build package :

	make package
