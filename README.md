## Quick start

This shell can be quickly start container of midware, like as mongodb, postgresql, rabbitmq etd.

```sh
cp cfg/dynamic.cfg.template cfg/dynamic.cfg
bash deploy-midware.sh
```

Setting dynamic environment variables, eg.

```sh
# workhome ------------------------------------------------------------------
export dynamic_install_user=hoke       #安装运行的用户名
export dynamic_install_userHome=/home/hoke  #用户根目录路径，即部署路径
# -----------------------------------------------------------------------

# Mongodb ----------------------------------------------------------------
export dynamic_mongodb1_ip=192.168.8.171
export dynamic_mongodb2_ip=10.10.255.202
export dynamic_mongodb3_ip=10.10.255.13
```
Running shell

```sh
bash deploy-midware.sh
```

## Make package


Clone this project :

	git clone https://github.com/hoke58/deploy-fabric.git
	cd deploy-fabric

Build package :

	make package
