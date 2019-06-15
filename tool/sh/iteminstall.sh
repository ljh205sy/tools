#!/bin/bash
PATH=$PATH:$(pwd)

success="true"
declare -x dbName="ajb_vap"
declare -x rootPwd=""
declare -x serviceIp=""
declare -x terminalIp=""
declare -x mngif=""
declare -x useageType="install"

#<== 最终生成的文件名称
declare -x finalZipFile=`date +%Y%m%d%H%M%S`
# set -e
# set -x
chmod 755 jq

function subStr {
	local itemStr="$1"
	itemStr=$(echo "${itemStr#'"'}")
	itemStr=$(echo "${itemStr%'"'}")
	echo "$itemStr"
}

function eventanalysisConfig() {
	sed -i "s/^jdbc\.host.*/jdbc\.host=$serviceIp/g" /usr/local/jsoc/jws/config/jdbc.properties
	sed -i "s/^jdbc\.database.*/jdbc\.database=$dbName/g" /usr/local/jsoc/jws/config/jdbc.properties
	sed -i "s/^jdbc\.password.*/jdbc\.password=$rootPwd/g" /usr/local/jsoc/jws/config/jdbc.properties

	sed -i "s/^com\.vrv\.analyzer\.udp\.host.*/com\.vrv\.analyzer\.udp\.host=$serviceIp/g" /usr/local/jsoc/jws/config/userConfig.properties
	sed -i "s/^com\.vrv\.analyzer\.webservice\.host.*/com\.vrv\.analyzer\.webservice\.host=$serviceIp/g" /usr/local/jsoc/jws/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.webservice\.terminal\.ip.*/com\.vrv\.soc\.webservice\.terminal\.ip=$terminalIp/g" /usr/local/jsoc/jws/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.eventserver\.udp\.ip.*/com\.vrv\.soc\.eventserver\.udp\.ip=$serviceIp/g" /usr/local/jsoc/jws/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.monitor\.monitorfiledir.*/com\.vrv\.soc\.monitor\.monitorfiledir=\/usr\/local\/jsoc\/jws\/groovyScript\/monitor/g" /usr/local/jsoc/jws/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.ip.*/com\.vrv\.soc\.ip=$serviceIp/g" /usr/local/jsoc/jws/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.es\.hosts.*/com\.vrv\.soc\.es\.hosts=$serviceIp:9300/g" /usr/local/jsoc/jws/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.application\.rootdir.*/com\.vrv\.soc\.application\.rootdir=\/usr\/local\/jsoc\/jws/g" /usr/local/jsoc/jws/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.groovy\.monitorDir.*/com\.vrv\.soc\.groovy\.monitorDir=\/usr\/local\/jsoc\/jws\/groovyScript\/monitor/g" /usr/local/jsoc/jws/config/userConfig.properties
}

function appendEsConfig() {
	echo "network.host: $serviceIp" >> /usr/share/elasticsearch/config/elasticsearch.yml
	echo "http.cors.enabled: true" >> /usr/share/elasticsearch/config/elasticsearch.yml
	echo "http.cors.allow-origin: \"*\"" >> /usr/share/elasticsearch/config/elasticsearch.yml
	echo "* hard nofile 65536" >> /etc/security/limits.conf
	echo "* soft nofile 65536" >> /etc/security/limits.conf
}

function snmpOidConfig() {
	sed -i "s/.1.3.6.1.2.1.1/.1/g" /etc/snmp/snmpd.conf
}

function lnJars() {
	local modulesFile=$1
	local lnModule=$2
	rm -f "/usr/local/vap/cloud/$2"
	echo "ln -s /usr/local/vap/cloud/$1" "/usr/local/vap/cloud/$2"
	ln -s "/usr/local/vap/cloud/$1" "/usr/local/vap/cloud/$2"
}


function iptablesConvertConfig(){
	natstring=$(grep 'PREROUTING ACCEPT' /etc/sysconfig/iptables | awk '{ print $1}')
	if [ -z "$natstring" ]  
	then
		sed -i '1i\*nat' /etc/sysconfig/iptables
		sed -i '2i\:PREROUTING ACCEPT [0:0]' /etc/sysconfig/iptables 
		sed -i '3i\:POSTROUTING ACCEPT [0:0]' /etc/sysconfig/iptables
		sed -i '4i\:OUTPUT ACCEPT [0:0]' /etc/sysconfig/iptables
		sed -i '5i\-A PREROUTING -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 8080' /etc/sysconfig/iptables
		sed -i '6i\COMMIT' /etc/sysconfig/iptables
	else
		echo "iptables已经创建端口映射"
	fi
	
}

function dbbackupConfig() {
    sed -i "s/^webservice\.ip.*/webservice\.ip=$serviceIp/g" /usr/local/jsoc/dbbackup/DbBackupTool/config/conf.properties
}

function nacosConfig() {
	sed -i "s/^db\.url\.0.*/db\.url\.0=jdbc:mysql:\/\/$serviceIp:3306\/nacos_config?serverTimezone=Asia\/Shanghai\&useSSL=false\&characterEncoding=utf8\&connectTimeout=1000\&socketTimeout=3000\&autoReconnect=true/g" /usr/local/vap/nacos/conf/application.properties
	sed -i "s/^db\.password.*/db\.password=$rootPwd/g"  /usr/local/vap/nacos/conf/application.properties
}

function executegateone(){
	python /usr/local/jsoc/ordereddict-1.1/setup.py install
	localdir=$(pwd)
	cd /opt/gateone
	./gateone.py &
	sleep 3
	gateonepid=$(jobs -l | awk '{print $2}')
	kill -9 $gateonepid
	sed -i "s/^port.*/port = 445/g" /opt/gateone/server.conf
	sed -i "s/^origins.*/origins = \"http:\/\/$serviceIp:445;https:\/\/$serviceIp:445\"/g" /opt/gateone/server.conf
	cd $localdir
}

function execuserdel(){
   # 判断用户是否存在
   local v_userdel=$(cat /etc/passwd | grep $1)
    echo "判断用户: $1是否存在:$v_userdel"
   if [ -z $v_userdel ] ; then  #<== -z 表示zone，长度为0
     echo "用户$1不存在"
   else
     userdel $1
   fi
}


function nmapConfig() {
    sed -i "s/^server.*/server=$serviceIp/g" /usr/local/bin/ScanOSConfig
	sed -i "s/^user.*/user=root/g" /usr/local/bin/ScanOSConfig
	sed -i "s/^password.*/password=$rootPwd/g" /usr/local/bin/ScanOSConfig
	sed -i "s/^database.*/database=$dbName/g" /usr/local/bin/ScanOSConfig
    sed -i "s/^port.*/port=3306/g" /usr/local/bin/ScanOSConfig
}


function sshportbegin() {
     sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/sysconfig/selinux
     setenforce 0 >/dev/null 2>&1
     echo 'ignore the error'
}



function socVersionConfig() {
	sed -i "s/^jdbc\.username.*/jdbc\.username=root/g" /usr/local/jsoc/tomcat/webapps/SOCVersion/WEB-INF/config/jdbc.properties
	sed -i "s/^jdbc\.password.*/jdbc\.password=$rootPwd/g" /usr/local/jsoc/tomcat/webapps/SOCVersion/WEB-INF/config/jdbc.properties
	sed -i "s/^jdbc\.host.*/jdbc\.host=$serviceIp/g" /usr/local/jsoc/tomcat/webapps/SOCVersion/WEB-INF/config/jdbc.properties
	sed -i "s/^jdbc\.port.*/jdbc\.port=3306/g" /usr/local/jsoc/tomcat/webapps/SOCVersion/WEB-INF/config/jdbc.properties
	sed -i "s/^jdbc\.database.*/jdbc\.database=$dbName/g" /usr/local/jsoc/tomcat/webapps/SOCVersion/WEB-INF/config/jdbc.properties
	sed -i "s/^com\.vrv\.soc\.webservice\.terminal\.ip.*/com\.vrv\.soc\.webservice\.terminal\.ip=$terminalIp/g" /usr/local/jsoc/tomcat/webapps/SOCVersion/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.webservice\.ws\.notify\.ip.*/com\.vrv\.soc\.webservice\.ws\.notify\.ip=$serviceIp/g" /usr/local/jsoc/tomcat/webapps/SOCVersion/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.eventserver\.udp\.ip.*/com\.vrv\.soc\.eventserver\.udp\.ip=$serviceIp/g" /usr/local/jsoc/tomcat/webapps/SOCVersion/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.monitor\.monitorfiledir.*/com\.vrv\.soc\.monitor\.monitorfiledir=\/usr\/local\/jsoc\/tomcat\/webapps\/SOC\/WEB-INF\/groovyScript\/monitor/g" /usr/local/jsoc/tomcat/webapps/SOCVersion/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.ip.*/com\.vrv\.soc\.ip=$serviceIp/g" /usr/local/jsoc/tomcat/webapps/SOCVersion/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.dbbak\.ws\.ip.*/com\.vrv\.soc\.dbbak\.ws\.ip=$serviceIp/g" /usr/local/jsoc/tomcat/webapps/SOCVersion/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.webShellIp.*/com\.vrv\.soc\.webShellIp=$serviceIp/g" /usr/local/jsoc/tomcat/webapps/SOCVersion/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.application\.rootdir.*/com\.vrv\.soc\.application\.rootdir=\/usr\/local\/jsoc\/tomcat\/webapps\/SOC\/WEB-INF/g" /usr/local/jsoc/tomcat/webapps/SOCVersion/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.groovy\.monitorDir.*/com\.vrv\.soc\.groovy\.monitorDir=\/usr\/local\/jsoc\/tomcat\/webapps\/SOC\/WEB-INF\/groovyScript\/monitor/g" /usr/local/jsoc/tomcat/webapps/SOCVersion/WEB-INF/config/userConfig.properties
}



function socConfig() {
	sed -i "s/^jdbc\.username.*/jdbc\.username=root/g" /usr/local/jsoc/tomcat/webapps/SOC/WEB-INF/config/jdbc.properties
	sed -i "s/^jdbc\.password.*/jdbc\.password=$rootPwd/g" /usr/local/jsoc/tomcat/webapps/SOC/WEB-INF/config/jdbc.properties
	sed -i "s/^jdbc\.host.*/jdbc\.host=$serviceIp/g" /usr/local/jsoc/tomcat/webapps/SOC/WEB-INF/config/jdbc.properties
	sed -i "s/^jdbc\.port.*/jdbc\.port=3306/g" /usr/local/jsoc/tomcat/webapps/SOC/WEB-INF/config/jdbc.properties
	sed -i "s/^jdbc\.database.*/jdbc\.database=$dbName/g" /usr/local/jsoc/tomcat/webapps/SOC/WEB-INF/config/jdbc.properties
	sed -i "s/^com\.vrv\.soc\.webservice\.terminal\.ip.*/com\.vrv\.soc\.webservice\.terminal\.ip=$terminalIp/g" /usr/local/jsoc/tomcat/webapps/SOC/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.webservice\.ws\.notify\.ip.*/com\.vrv\.soc\.webservice\.ws\.notify\.ip=$serviceIp/g" /usr/local/jsoc/tomcat/webapps/SOC/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.eventserver\.udp\.ip.*/com\.vrv\.soc\.eventserver\.udp\.ip=$serviceIp/g" /usr/local/jsoc/tomcat/webapps/SOC/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.monitor\.monitorfiledir.*/com\.vrv\.soc\.monitor\.monitorfiledir=\/usr\/local\/jsoc\/tomcat\/webapps\/SOC\/WEB-INF\/groovyScript\/monitor/g" /usr/local/jsoc/tomcat/webapps/SOC/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.ip.*/com\.vrv\.soc\.ip=$serviceIp/g" /usr/local/jsoc/tomcat/webapps/SOC/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.es\.hosts.*/com\.vrv\.soc\.es\.hosts=$serviceIp:9300/g" /usr/local/jsoc/tomcat/webapps/SOC/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.dbbak\.ws\.ip.*/com\.vrv\.soc\.dbbak\.ws\.ip=$serviceIp/g" /usr/local/jsoc/tomcat/webapps/SOC/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.webShellIp.*/com\.vrv\.soc\.webShellIp=$serviceIp/g" /usr/local/jsoc/tomcat/webapps/SOC/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.application\.rootdir.*/com\.vrv\.soc\.application\.rootdir=\/usr\/local\/jsoc\/tomcat\/webapps\/SOC\/WEB-INF/g" /usr/local/jsoc/tomcat/webapps/SOC/WEB-INF/config/userConfig.properties
	sed -i "s/^com\.vrv\.soc\.groovy\.monitorDir.*/com\.vrv\.soc\.groovy\.monitorDir=\/usr\/local\/jsoc\/tomcat\/webapps\/SOC\/WEB-INF\/groovyScript\/monitor/g" /usr/local/jsoc/tomcat/webapps/SOC/WEB-INF/config/userConfig.properties
}

function elasticSearchxmlConfig() {
	sed -i "s/# network\.host: 192\.168\.0\.1*/ network\.host: $serviceIp/g" /etc/elasticsearch/elasticsearch.yml
}

function  teleNetConfig() {
    sed -i "s/yes/no/g" /etc/xinetd.d/telnet
}




function updateConfig() {
	sed -i "s/^dbname.*/dbname='$dbName'/g" /usr/local/jsoc/execShell.sh
	sed -i "s/^pwd.*/pwd='$rootPwd'/g" /usr/local/jsoc/execShell.sh
	chmod 755 /usr/local/jsoc/execShell.sh
}

function eventserverConfig() {
	sed -i "s/^log_in_port.*/log_in_port=514/g" /etc/eventserver.ini
	sed -i "s/^nxsoc_host.*/nxsoc_host=$serviceIp/g" /etc/eventserver.ini
	sed -i "s/^nxsoc_username.*/nxsoc_username=root/g" /etc/eventserver.ini
	sed -i "s/^nxsoc_password.*/nxsoc_password=$rootPwd/g" /etc/eventserver.ini
	sed -i "s/^nxsoc_dbname.*/nxsoc_dbname=$dbName/g" /etc/eventserver.ini
	sed -i "s/^json1_host.*/json1_host=$serviceIp/g" /etc/eventserver.ini
	sed -i "s/^json1_port.*/json1_port=6666/g" /etc/eventserver.ini
	sed -i "s/^cmdline_host=.*/cmdline_host=$serviceIp/g" /etc/eventserver.ini
}

function flinkConfig() {
	sed -i "s/^jobmanager.rpc.address.*/jobmanager.rpc.address: $serviceIp/g" /usr/local/vap/flink/conf/flink-conf.yaml
	sed -i "s/^taskmanager\.numberOfTaskSlots.*/taskmanager\.numberOfTaskSlots: 20/g" /usr/local/vap/flink/conf/flink-conf.yaml
}

function kafkaConfig() {
 	sed -i "s/^log.retention.hours=168/log.retention.hours=6/g" /usr/local/vap/kafka/config/server.properties
	sed -i "s/^zookeeper.connect=localhost:2181/zookeeper.connect=$serviceIp:2181/g" /usr/local/vap/kafka/config/server.properties
	echo "listeners=PLAINTEXT://$serviceIp:9092" >> /usr/local/vap/kafka/config/server.properties
	echo "advertised.listeners=PLAINTEXT://$serviceIp:9092" >> /usr/local/vap/kafka/config/server.properties
}

function cboardConfig() {
	sed -i "s/^jdbc_url=.*/jdbc_url=jdbc:mysql:\/\/$serviceIp\/$dbName?characterEncoding=utf-8/g" /usr/local/vap/cboard/config.properties
	sed -i "s/^jdbc_username=.*/jdbc_username=root/g" /usr/local/vap/cboard/config.properties
	sed -i "s/^jdbc_password=.*/jdbc_password=$rootPwd/g" /usr/local/vap/cboard/config.properties
	sed -i "s/^phantomjs_path=.*/phantomjs_path=\/opt\/phantomjs\/bin\/phantomjs/g" /usr/local/vap/cboard/config.properties
}

function configMyCnf() {
	echo "[client]" >> /etc/my.cnf
	echo "host=localhost" >> /etc/my.cnf
	echo "user='root'" >> /etc/my.cnf
	echo "password='$rootPwd'" >> /etc/my.cnf
	sh install_nac.sh $mngif >> install_nac.log
}

# -z [ -z $str ]  这个表达式就是判断str这个字符串是否为空 . 为空返回：True, 不为空返回：False
function mysqlRpmUninstall() {
	local tempmysqllib=$(rpm -qa | grep mysql)
	if [ -z "$tempmysqllib" ] 
      then
		echo "$tempmysqllib not exists, 无需卸载。" | tee -a appendLine
	else
		rpm -e $tempmysqllib --nodeps
	fi;
}


function nginxRpmUninstall() {
	local tempmysqllib=$(rpm -qa | grep nginx)
	if [ -z "$tempmysqllib" ] 
      then
		echo "$tempmysqllib not exists, 无需卸载。" | tee -a appendLine
	else
		rpm -e $tempmysqllib --nodeps
	fi;
}


# qiangzhiwutishi
function forceCpmysqldbiAnddbd {
	\cp -rf libdbi-0.1.0/usr/include/dbi/dbd.h /usr/include/dbi/dbd.h
	\cp -rf libdbi-0.1.0/usr/include/dbi/dbi.h /usr/include/dbi/dbi.h
	\cp -rf libdbi-0.1.0/usr/include/dbi/dbi-dev.h /usr/include/dbi/dbi-dev.h
	
	\cp -rf libdbi-0.1.0/usr/lib64/libdbi* /usr/lib64/
	\cp -rf libdbi-0.1.0/usr/lib64/pkgconfig/dbi.pc /usr/lib64/pkgconfig/dbi.pc 
	
	\cp -rf libdbd-drivers/usr/lib64/dbd /usr/lib64/
}

function mysqlConfig() {
	service mysqld start
    sleep 3	
	mysql -uroot -e "use mysql; update user set authentication_string=PASSWORD('$rootPwd') where User='root';flush privileges;"  
	sed -i "s/^skip_grant_tables.*/validate-password=OFF/g" /etc/my.cnf
	
	echo "重新启动mysql开始"
	service mysqld restart
	
	echo "重新启动mysql结束"
	echo "SET PASSWORD = PASSWORD('$rootPwd');flush privileges; " 
	mysql -uroot -p$rootPwd -hlocalhost -e "SET PASSWORD = PASSWORD('$rootPwd');flush privileges;" --connect-expired-password
	
	
	echo " mysql -uroot -p$rootPwd -hlocalhost -e use mysql;grant all privileges on *.* to 'root'@'%' identified by '$rootPwd';flush privileges;"
	mysql -uroot -p$rootPwd -hlocalhost -e "use mysql;grant all privileges on *.* to 'root'@'%' identified by '$rootPwd';flush privileges;" 
	
	
	echo " mysql -uroot -p$rootPwd -hlocalhost -e use mysql;grant all privileges on *.* to 'root'@'127.0.0.1' identified by '$rootPwd';flush privileges;"
	mysql -uroot -p$rootPwd -hlocalhost -e "use mysql;grant all privileges on *.* to 'root'@'127.0.0.1' identified by '$rootPwd';flush privileges;"
	
	
	echo " mysql -uroot -p$rootPwd -hlocalhost -e use mysql;grant select,reload,lock tables on *.* to 'hotcopyer'@'localhost' identified by '123456';flush privileges;"
    mysql -uroot -p$rootPwd -hlocalhost -e "use mysql;grant select,reload,lock tables on *.* to 'hotcopyer'@'localhost' identified by '123456';flush privileges;"
}


function dbConfig() {
	sh initDB.sh $rootPwd $serviceIp $dbName >> installDB;
}

function securettyBak() {
	if [ -f "/etc/securetty" ];then
		mv /etc/securetty /etc/securetty.bak
	fi
}

# item对象为rpm的安装
function installRpmItem {
	local itemIn="$1"
	echo "type is rpm"
	local rpmFile=$(echo "$itemIn" | jq .file)
	echo "rpm file is $rpmFile"
	local args=$(echo "$itemIn" | jq .args)
	if [ "$args" == "null" ]; then
		rpm -ivh $rpmFile 2>&1 | tee -a installRpmLog
	else
		args=$(subStr "$args")
		rpm -ivh $rpmFile $args 2>&1 | tee -a installRpmLog
	fi
}

function installLnItem {
	local itemIn="$1"
	echo "type is ln"
	local srcfile=$(echo "$itemIn" | jq .srcfile)
	srcfile=$(subStr "$srcfile")
	local dstfile=$(echo "$itemIn" | jq .dstfile)
	dstfile=$(subStr "$dstfile")
	ln -s "$srcfile" "$dstfile"
}

function installCpfileItem {
	local itemIn="$1"
	echo "type is Cpfile"
	local srcfile=$(echo "$itemIn" | jq .srcfile)
	srcfile=$(subStr "$srcfile")
	local dstfile=$(echo "$itemIn" | jq .dstfile)
	dstfile=$(subStr "$dstfile")
	cp "$srcfile" "$dstfile"
}

function installCpDirItem {
	local itemIn="$1"
	echo "type is CpDir"
	local srcfile=$(echo "$itemIn" | jq .srcfile)
	srcfile=$(subStr "$srcfile")
	local dstfile=$(echo "$itemIn" | jq .dstfile)
	dstfile=$(subStr "$dstfile")
	cp -rf "$srcfile" "$dstfile"
}

function installShItem {
	local itemIn="$1"
	echo "type is sh"
	local count=$(echo "$itemIn" | jq '.shs | length')
	local i=0
	for((i=0;i<$count;i++))
	do
		local aItem=$(echo "$itemIn" | jq .shs[$i])
		aItem=$(subStr "$aItem")
		echo "$aItem" >> shlog
		eval $aItem
	done
}

function installItemsItem {
	local itemIn="$1"
	echo "type is items"
	local count=$(echo "$itemIn" | jq '.items | length')
	local i=0
	for((i=0;i<$count;i++))
	do
		local aItem=$(echo "$itemIn" | jq .items[$i])
		installItem "$aItem"
	done
}

function installAppendConfigItem {
	local itemIn="$1"
	echo "type is appendConfig"
	local configFile=$(echo "$itemIn" | jq .file)
	configFile=$(subStr "$configFile")
	local linesCount=$(echo "$itemIn" | jq '.lines | length')
	local i=0
	for((i=0;i<$linesCount;i++))
	do
		local aLine="`echo "$itemIn" | jq .lines[$i]`"
		echo "加入行：""$aLine" 2>&1 | tee -a appendLine
		aLine=$(subStr "$aLine")
		echo "加入行：""$aLine" 2>&1 | tee -a appendLine
		echo "$aLine" >> "$configFile"
	done
}

function installSedConfigItem {
	local itemIn="$1"
	echo "type is appendConfig"
	local configFile=$(echo "$itemIn" | jq .file)
	configFile=$(subStr "$configFile")
	local reg=$(echo "$itemIn" | jq .reg)
	reg=$(subStr "$reg")
	local linesCount=$(echo "$itemIn" | jq '.lines | length')
	local i=0
	for((i=0;i<$linesCount;i++))
	do
		local aLine=$(echo "$itemIn" | jq .lines[$i])
		aLine=$(subStr "$aLine")
		sed -i "/$reg/a $aLine" "$configFile"
	done
}

function installTarzxvfItem {
	local itemIn="$1"
	echo "type is tarzxvf"
	local srcfile=$(echo "$itemIn" | jq .srcfile)
	srcfile=$(subStr "$srcfile")
	local dstfile=$(echo "$itemIn" | jq .dstdir)
	dstfile=$(subStr "$dstfile")
	tar -zxvf "$srcfile" -C "$dstfile"
}

function installUnzipdItem {
	local itemIn="$1"
	echo "type is unzipd"
	local srcfile=$(echo "$itemIn" | jq .srcfile)
	srcfile=$(subStr "$srcfile")
	local dstfile=$(echo "$itemIn" | jq .dstdir)
	dstfile=$(subStr "$dstfile")
	unzip "$srcfile" -d "$dstfile"
}

function installFile {
	local fileName="$1"
	echo "install file name : $fileName"
	local itemStr="$(cat $fileName)" && installItem "$itemStr"
}

function installMkdirItem() {
	local itemIn="$1"
	echo "type is Mkdir"
	local dstDir=$(echo "$itemIn" | jq .dstDir)
	dstDir=$(subStr "$dstDir")
	if test -e "$dstDir"
	then
		echo "已经创建$dstDir目录"
	else
		mkdir -p "$dstDir"
	fi
}

function installItemFile {
	local itemIn="$1"
	echo "type is ItemFile"
	local fileDir=$(echo "$itemIn" | jq .fileDir)
	fileDir=$(subStr "$fileDir")
	local fileName=$(echo "$itemIn" | jq .fileName)
	fileName=$(subStr "$fileName")
	local nPwd=$(pwd)
	echo "当前路径：$nPwd"
	cd "$fileDir"
	echo "当前路径：$(pwd)"
	installFile "$fileName"
	cd "$nPwd"
	echo "当前路径：$(pwd)"
}



function mysqlPwd(){
	echo -n "请输入数据库密码:"
	read -s rootPwd
	echo
	echo -n "请再次输入数据库密码:"
	read -s rootPwd2
	echo
}

function initInstall() {
	echo "当前系统为："
	cat /etc/issue
	
	if [ $(whoami) = "root" ]
	then
		echo "The current user is root"
		echo "SOC system installing........."
	else
		echo "ROOT role is needed to install"
		success="false"
		return
	fi
	
	#<== 如果是升级包，就不需要安装环境变量
	useageType=`cat $1 | ./jq .useage`   #<== install 或者 upgrade
	useageType=$(subStr "$useageType")
	if [ "$useageType" == "upgrade" ] ; then
	    echo "生成更新包【upgrade】ing..."
		success="true"
		return
	else
	     echo "生成安装包【install】ing..."
	fi
	echo "127.0.0.1 $(hostname)" >> /etc/hosts
	
	if [ "$#" -gt 1 ] && [ "$2"=="conf.properties" ]; then
		# 使用配置文件方式进行安装
		local v_hostIp=$(cat ./conf.properties | grep "hostIp")
		local v_real_ip=${v_hostIp#*=}
		local choiseACK="no"
		echo -n "确认服务器ip:${v_real_ip}?[yes|no]:"
		read choiseACK
		if [ "$choiseACK" == "yes" ]; then
		  serviceIp=${v_real_ip}
		else
		  echo "***********参数个数为$#个，使用$2文件中hostIp属性配置系统IP"
		  exit 1
		fi
		echo "系统IP:${serviceIp}"
		
		
		local v_hostMngif=$(cat ./conf.properties | grep "hostMngif")
		choiseACK="no"
		local v_real_mgt=${v_hostMngif#*=}
		echo -n "确认服务器网卡:$v_real_mgt?[yes|no]:"
		read choiseACK
		if [ "$choiseACK" == "yes" ]; then
		  mngif=${v_real_mgt}
		else
		  echo "使用$2文件中hostMngif属性配置系统网卡信息"
		  exit 1
		fi
		echo "系统网卡:${mngif}"
		
		
		local v_dbPwd=$(cat ./conf.properties | grep "dbPwd")
		local v_real_dbPwd=${v_dbPwd#*=}
		choiseACK="no"
		echo -n "确认数据库密码:$v_real_dbPwd?[yes|no]:"
		read choiseACK
		if [ "$choiseACK" == "yes" ]; then
		  rootPwd=${v_real_dbPwd}
		else
		  echo "使用$2文件中dbPwd属性配置数据库密码"
		  exit 1
		fi
		echo "mysql数据库密码:${rootPwd}"	
    elif [[ $# -eq 1 ]] ; then
	    # 使用原有界面输入方式进行安装
		echo "参数个数为1个，使用输入进行系统参数配置"
		localip=$(LC_ALL=C ifconfig  | grep 'inet ' | grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $2}')
		echo "获取到服务器ip为：$localip"
		local choiseServiceIp="no"
		echo -n "确认使用该ip：$localip?[yes|no]:"
		read choiseServiceIp
		if [ "$choiseServiceIp" == "yes" ]
		then
			serviceIp=$localip
		fi
		while [ "$choiseServiceIp" != "yes" ]
		do
			echo -n "请输入服务器的ip："
			read serviceIp
			echo -n "服务器ip是：$serviceIp?[yes|no]:"
			read choiseServiceIp
		done

		echo "进行网卡选择"
		localmngif=$(LC_ALL=C ifconfig | grep ': flags' | grep -v 'lo' | awk -F": flags" '{print $1}')
		echo "获取到的服务器网卡名称是：$localmngif"
		local choiseMngif="no"
		echo -n "确认使用该网卡名：$localmngif?[yes|no]:"
		read choiseMngif
		if [ "$choiseMngif" == "yes" ]
		then
			mngif=$localmngif
		fi
		while [ "$choiseMngif" != "yes" ]
		do
			echo -n "请输入服务器的网卡名称:"
			read mngif
			echo -n "网卡名称是：$mngif?[yes|no]:"
			read choiseMngif
		done

		echo "开始配置数据库........"

		echo -n "是否使用默认数据库名称ajb_vap?[yes|no]:"
		if read -t 10  choice2
		then
		while [ "$choice2" != "yes" ] && [ "$choice2" != "no" ]
		do
			read -p "请重新输入正确选择[yes/no]:" choice2
		done
		if [ "$choice2" = "no" ]
		then
			read -p "请输入数据库名称：" dbName
		else
			echo "Default database is selected"
		fi
		else
			echo "Default database is selected"
		fi
		mysqlPwd
		until [ "$rootPwd" = "$rootPwd2" ]
		do
			echo "Cannot match password,please try again!"
			mysqlPwd
		done
    else 
	  echo "参数输入错误，请检查参数!"
	  exit 1
    fi
	
	echo "*************************"
}


function exportCloudEnvi {
	echo "添加环境变量"
	echo "export MYSQL_HOST=$serviceIp" >> /etc/profile
	echo "export MYSQL_PASSWORD=$rootPwd" >> /etc/profile
	echo "export REDIS_HOST=$serviceIp" >> /etc/profile
	echo "export RABBITMQ_HOST=$serviceIp" >> /etc/profile
	echo "export EUREKA_HOST=$serviceIp" >> /etc/profile
	echo "export ES_CLUSTER_HOST=$serviceIp" >> /etc/profile
	echo "export ES_CLUSTER_NAME=elasticsearch-cluster" >> /etc/profile
	echo "export KAFKA_URL=$serviceIp" >> /etc/profile
	echo "export NACOS_HOST=$serviceIp" >> /etc/profile
	echo "export NACOS_NAMESPACE=a338c762-d2a7-4a2f-86f0-022c171c0928" >> /etc/profile
	echo "export NACOS_PORT=8848" >> /etc/profile
#	echo "export WEBAPP=http://$serviceIp:9999/" >> /etc/profile
	source /etc/profile
	echo "添加环境变量***********完成"
}


function installItem {
	if [ $success == 'false' ];then
		return;
	fi
	success="true"
	local itemIn="$1"
	local itemtype=$(echo "$itemIn" | jq .type) 
	local itemName=$(echo "$itemIn" | jq .name)
	itemtype=$(subStr "$itemtype")
	echo "$itemName:开始安装" | tee -a installLog
	if [ $itemtype == 'rpm' ];then
		installRpmItem "$itemIn" || success="canContinue"
	fi
	
	if [ $itemtype == 'items' ];then
		installItemsItem "$itemIn" || success="false"
	fi
	
	if [ $itemtype == 'appendConfig' ];then
		installAppendConfigItem "$itemIn" || success="false"
	fi
	
	if [ $itemtype == 'sedConfig' ];then
		installSedConfigItem "$itemIn" || success="false"
	fi
	
	if [ $itemtype == 'ln' ];then
		installLnItem "$itemIn" || success="false"
	fi
	
	if [ $itemtype == 'mkdir' ];then
		installMkdirItem "$itemIn" || success="false"
	fi
	
	if [ $itemtype == 'cpfile' ];then
		installCpfileItem "$itemIn" || success="false"
	fi
	
	if [ $itemtype == 'cpfiles' ];then
		installCpDirItem "$itemIn" || success="false"
	fi
	
	if [ $itemtype == 'sh' ];then
		installShItem "$itemIn" || success="false"
	fi
	
	if [ $itemtype == 'tarzxvf' ];then
		installTarzxvfItem "$itemIn" || success="false"
	fi
	
	if [ $itemtype == 'unzipd' ];then
		installUnzipdItem "$itemIn" || success="false"
	fi
	
	if [ $itemtype == 'itemFile' ];then
		installItemFile "$itemIn" || success="false"
	fi
	
	if [ $success == 'true' ];then
		echo "$itemName:安装成功" | tee -a installLog
	else
		echo "$itemName:安装失败" | tee -a installLog
	fi
}

# 如果是有两个参数，使用jsoc.json  conf.properties
if [ "$#" -gt 1 ] && [ "$2"=="conf.properties" ]; then
    echo "参数个数为$#个,第二个参数：$2"
    initInstall "$1" "$2"
elif [[ $# -eq 1 ]] ; then  #<== 如果是一个参数，使用系统手工配置
    echo "参数个数为1"
    initInstall "$1"
else 
    echo "无参数,输入错误!"
    exit 1
fi

installFile "$1"
