#### 1、安装docker

```
# yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
# yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
# yum install docker-ce docker-ce-cli containerd.io
# systemctl start docker
```

#### 2、安装docker-compse

``````
# sudo curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
# ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
``````

#### 3、下载代码

```
# mkdir /data/apps && cd /data/apps
# git clone -b v3 https://github.com/welliamcao/OpsManage.git
```

#### 4、修改docker-compse.yaml

```
# cd /data/apps/OpsManage
# vim docker/docker-compse.yaml
version: "3.7"
services:
  mysql:
    image: mysql:5.7  
    container_name: mysql
    environment:
      - MYSQL_HOST=%
      - MYSQL_DATABASE=opsmanage
      - MYSQL_USER="数据库用户名"    #自行修改
      - MYSQL_PASSWORD="数据库用户密码"  #自行修改
      - MYSQL_ROOT_PASSWORD="数据库root密码"  #自行修改
    volumes:
      - /data/apps/mysql:/var/lib/mysql  
    command: ['mysqld', '--sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION', '--character-set-server=utf8mb4', '--collation-server=utf8mb4_unicode_ci']  
    healthcheck:
      test: ["CMD", "mysqladmin" ,"ping", "-h", "localhost"]
      timeout: 20s
      retries: 10
    restart: always  
    networks:
      - default
  redis:
     container_name: redis
     image: redis:3.2.8
     command: /bin/sh -c "redis-server --requirepass $$REDIS_PASSWORD" 
     environment:
       REDIS_PASSWORD: "密码"   #自行修改
       REDIS_AOF_ENABLED: "no"
     ports:
       - "6379:6379"
     volumes:
       - /data/apps/redis:/data
     networks:
       - default  
  rabbitmq:
     container_name: rabbitmq
     image: rabbitmq:management
     environment:
       RABBITMQ_DEFAULT_USER: admin #自行修改
       RABBITMQ_DEFAULT_PASS: admin #自行修改
     volumes:
       - '/data/apps/rabbitmq/data/:/var/lib/rabbitmq/mnesia/'       
     ports:
       - "5672:5672"
       - "15672:15672"
     networks:
       - default  

  ops_web:
     image: opsmanage-base:latest
     container_name: ops_web
     environment:
       MYSQL_USER: root
       MYSQL_DATABASE: opsmanage
       MYSQL_PASSWORD: "数据库用户密码" #记得自己修改
     ports:
       - "8000:8000"
     volumes:
       - /data/apps/OpsManage:/data/apps/opsmanage
       - /data/apps/OpsManage/upload:/data/apps/opsmanage/upload
       - /data/apps/OpsManage/logs:/data/apps/opsmanage/logs
     command: bash /data/apps/opsmanage/docker/start.sh  
     links:
       - mysql
       - redis
       - rabbitmq
     depends_on:
       mysql:
         condition: service_healthy
       redis:
         condition: service_started
       rabbitmq:
         condition: service_started  
     restart: always
     networks:
       - default  

  nginx:
     image: nginx
     container_name: nginx
     ports:
       - "80:80"   
     volumes:
       - /data/apps/nginx/logs:/var/log/nginx
       - /data/apps/OpsManage/docker/opsmanage.conf:/etc/nginx/conf.d/default.conf
       - /data/apps/OpsManage/static:/data/apps/opsmanage/static
       - /data/apps/OpsManage/upload:/data/apps/opsmanage/upload
     depends_on:
       - ops_web
     links:
       - ops_web:ops_web
     networks:
       - default

networks:
  default:
```

#### 5、构建基础镜像

```
# cd /data/apps/OpsManage
# docker build -t opsmanage-base  -f docker/Dockerfile .
```

#### 6、 修改应用配置文件conf/opsmanage.ini

```
# cd /data/apps/OpsManage
# vim conf/opsmanage.ini  #把MySQL/Redis/RabbitMQ的host/password改成docker-compose里面配置的一致，host等于具体container_name
```

#### 7、 启动OpsManage

```
# cd /data/apps/OpsManage/docker
# docker-compose up -d
```

#### 8、访问页面

```
http://<ip>:80
User: admin
Password: admin
```


