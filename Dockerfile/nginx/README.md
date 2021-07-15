## nginx镜像升级版本 及 日志轮转使用说明

PRE:
    加载镜像： 
    docker load < nginx.1.20.1-logrotate-alpine.tar
    
    进入nginx部署目录
    docker-compose down

1、日志轮转采用logrotate形式，基线配置为
    ： 
    /etc/nginx/logs/*.log {   # 轮转的日志所在路径及匹配规则  *** 按照实际配置路径修改
            daily             # 轮转频率，按天
            missingok         # 即使日志不存在也不报错
            rotate 30         # 备份份数                      **** 根据需要修改
            compress          # gzip压缩转储以后的日志
            delaycompress     # 延迟压缩，和 compress一起使用时，转储的日志文件到下一次转储时才压缩
            notifempty        # 如果是空文件的话，不转储
            create 640 nginx adm  # 给文件授权640，并且属主和属组为nginx，adm
            sharedscripts     # 运行postrotate脚本
            postrotate
                    if [ -f /etc/nginx/logs/nginx.pid ]; then       # pid文件路径  **** 在 nginx/conf/nginx.conf 中的 pid 配置项 
                            kill -USR1 `cat /etc/nginx/logs/nginx.pid`
                    fi
            endscript
    }

2、添加环境变量，使当前用户对日志有可读权限：
    environment:
      - LOCAL_UID=1501

   
3、其他配置说明：
   docker-compose 修改镜像
   image: hub.finrunchain.com/midware/nginx:1.20.1-logrotate-alpine
   
4、启动镜像
   docker-compose up -d