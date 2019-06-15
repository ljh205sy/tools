#!/bin/bash
#这里可替换为你自己的执行程序，其他代码无需更改

CLOUD_HOME=/usr/local/vap/cloud
APP_NAME=$2
echo "APP_NAME=$APP_NAME"
#6月 04 14:45:08 localhost.localdomain application.sh[91672]: APP_NAME=api-admin
#6月 04 14:45:08 localhost.localdomain application.sh[91672]: CLOUD_HOME=/usr/local/vap/cloud
# /usr/local/vap/cloud/application.sh restart api-admin 
echo "CLOUD_HOME=$CLOUD_HOME,限制参数: -Xms200m -Xmx200m -XX:PermSize=200m -XX:MaxPermSize=200m -XX:MaxNewSize=200m"


source /etc/profile
#使用说明，用来提示输入参数
usage() {
    echo "Usage: sh 执行脚本.sh [start|stop|restart|status]"
    exit 1
}
#检查程序是否在运行
is_exist(){
  pid=`ps -ef | grep java |grep $APP_NAME|grep -v grep|awk '{print $2}' `
  #如果不存在返回1，存在返回0     
  if [ -z "${pid}" ]; then
   return 1
  else
    return 0
  fi
}

#<==限制内存大小


start(){
  is_exist
  if [ $? -eq "0" ]; then
    echo "${APP_NAME} is already running. pid=${pid} ."
  else
    local v_memory="-Xms200m -Xmx200m"
    local v_var=$(cat $CLOUD_HOME/memconf.properties | grep $APP_NAME)
    echo "$APP_NAME,$v_var"
    if [ ${#v_var} -lt 1 ]; then  #<== 获取个数
      echo "$APP_NAME limits is default $v_memory"
    else
      v_memory=${v_var#*=}
      echo "$APP_NAME limit memory is : $v_memory"
    fi
    echo "------------->>>> Real commond:nohup java -jar ${v_memory} $CLOUD_HOME/$APP_NAME.jar >> $CLOUD_HOME/$APP_NAME.log 2>&1 &"
    nohup java -jar ${v_memory} $CLOUD_HOME/$APP_NAME.jar >> $CLOUD_HOME/$APP_NAME.log 2>&1 &
	echo "查看详细日志: systemctl status $APP_NAME -l"
  fi
}

#停止方法
stop(){
  is_exist
  if [ $? -eq "0" ]; then
    kill -9 $pid
  else
    echo "${APP_NAME} is not running"
  fi  
}

#输出运行状态
status(){
  is_exist
  if [ $? -eq "0" ]; then
    echo "${APP_NAME} is running. Pid is ${pid}"
  else
    echo "${APP_NAME} is NOT running."
  fi
}

#重启
restart(){
  stop
  start
}

#根据输入参数，选择执行对应方法，不输入则执行使用说明
case "$1" in
  "start")
    start
    ;;
  "stop")
    stop
    ;;
  "status")
    status
    ;;
  "restart")
    restart
    ;;
  *)
    usage
    ;;
esac
