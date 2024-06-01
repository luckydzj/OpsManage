#!/bin/sh
count=$(mysql -h mysql -D ${MYSQL_DATABASE} -e "show tables;" -u${MYSQL_USER} -p${MYSQL_ROOT_PASSWORD}|wc -l)
if [[ $? -eq 0 ]]; then
   if [ "${count}" -eq 0 ]
      then
         mysql -h mysql -D ${MYSQL_DATABASE} -u${MYSQL_USER} -p${MYSQL_ROOT_PASSWORD} < /data/apps/opsmanage/docker/init.sql
         cd /data/apps/opsmanage/ && python manage.py loaddata docker/superuser.json
   fi 
else
    echo "MySQL connection failed, program exited"
    exit 256
fi
echo_supervisord_conf > /etc/supervisord.conf
export PYTHONOPTIMIZE=1
cat > /etc/supervisord.conf << EOF
[unix_http_server]
file=/tmp/supervisor.sock 

[supervisord]
logfile=/data/apps/opsmanage/logs/supervisord.log 
logfile_maxbytes=50MB        
logfile_backups=10           
loglevel=info                
pidfile=/var/run/supervisord.pid 
nodaemon=false               
minfds=1024                  
minprocs=200      
           
[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///tmp/supervisor.sock

[program:celery-worker-default]
environment=C_FORCE_ROOT="true",PYTHONOPTIMIZE=1
command=celery -A OpsManage worker --loglevel=info -E -Q default -n worker-default@%%h
directory=/data/apps/opsmanage
stdout_logfile=/data/apps/opsmanage/logs/celery-worker-default.log
autostart=true
autorestart=true
redirect_stderr=true
stopsignal=QUIT
numprocs=1

[program:celery-worker-ansible]
environment=C_FORCE_ROOT="true",PYTHONOPTIMIZE=1
command=celery -A OpsManage worker --loglevel=info -E -Q ansible -n worker-ansible@%%h
directory=/data/apps/opsmanage
stdout_logfile=/data/apps/opsmanage/logs/celery-worker-ansible.log
autostart=true
autorestart=true
redirect_stderr=true
stopsignal=QUIT
numprocs=1

[program:celery-beat]
environment=C_FORCE_ROOT="true",PYTHONOPTIMIZE=1
command=celery -A OpsManage  beat --loglevel=info --scheduler django_celery_beat.schedulers:DatabaseScheduler
directory=/data/apps/opsmanage
stdout_logfile=/data/apps/opsmanage/logs/celery-beat.log
autostart=true
autorestart=true
redirect_stderr=true
stopsignal=QUIT
numprocs=1

[program:apply-task]
environment=C_FORCE_ROOT="true",PYTHONOPTIMIZE=1
command=python3 manage.py apply_task
directory=/data/apps/opsmanage
stdout_logfile=/data/apps/opsmanage/logs/apply-task.log
autostart=true
autorestart=true
redirect_stderr=true
stopsignal=QUIT
numprocs=1


EOF

supervisord -c /etc/supervisord.conf
sleep 3
cd /data/apps/opsmanage/
python3 manage.py runserver 0.0.0.0:8000 --http_timeout=1200