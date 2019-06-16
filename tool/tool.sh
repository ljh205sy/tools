#!/bin/bash
PATH=$PATH:$(pwd)
success="true"
declare -x nexus="192.168.118.236:8081"
declare -x shfile="application.sh"

declare -x base_component_dir="/root/vap_nacos"
declare -x base_component_uri="http://192.168.0.106:8089/D%3A/bug0/baseComponent/"
# declare -x base_component_uri="http://192.168.118.236:8989/D%3A/bug0/baseComponent/"
declare -x useagetype="install"

#<== 最终生成的文件名称
declare -x finalZipFile=`date +%Y%m%d%H%M%S`
declare -x tempDir="$finalZipFile/cloud/"

# set -e
# set -x
chmod 755 jq

function subStr() {
	local itemStr="$1"
	itemStr=$(echo "${itemStr#'"'}")
	itemStr=$(echo "${itemStr%'"'}")
	echo "$itemStr"
}

function lnJars() {
	local modulesFile=$1
	local lnModule=$2
	rm -f "/usr/local/vap/cloud/$2"
	echo "ln -s /usr/local/vap/cloud/$1" "/usr/local/vap/cloud/$2"
	ln -s "/usr/local/vap/cloud/$1" "/usr/local/vap/cloud/$2"
}

#function lnJars() {
#	local modulesFile=$1
#	echo "modulesFile:$modulesFile"
#	local lnModule=$2
#	echo "-------------"
#	echo $modulesFile
#	echo $lnModule
#	echo "-------------"
#	local itemStr="$(cat $modulesFile)"
#	local count=$(echo "$itemStr" | jq '.modules | length')
#	local i=0
#	echo $count
#	for ((i = 0; i < $count; i++)); do
#		local aItem=$(echo "$itemStr" | jq .modules[$i])
#		local moduleName=$(echo "$aItem" | jq .name)
#		moduleName=$(subStr "$moduleName")
#		echo "moduleName: $moduleName"
#		if [ $lnModule = $moduleName ]; then
#			local version=$(echo "$aItem" | jq .version)
#			version=$(subStr "$version")
#			local baseDir=$(echo "$aItem" | jq .baseDir)
#			baseDir=$(subStr "$baseDir")
#			echo "ln -s $vapDir$baseDir$lnModule-$version.jar $vapDir$baseDir$lnModule.jar"
#			rm -f "$vapDir$baseDir$lnModule.jar"
#			ln -s "$vapDir$baseDir$lnModule-$version.jar" "$vapDir$baseDir$lnModule.jar"
#			return
#		fi
#	done
#}


# item对象为rpm的安装
function installRpmItem() {
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

function installLnItem() {
	local itemIn="$1"
	echo "type is ln"
	local srcfile=$(echo "$itemIn" | jq .srcfile)
	srcfile=$(subStr "$srcfile")
	local dstfile=$(echo "$itemIn" | jq .dstfile)
	dstfile=$(subStr "$dstfile")
	ln -s "$srcfile" "$dstfile"
}

function installCpfileItem() {
	local itemIn="$1"
	echo "type is Cpfile"
	local srcfile=$(echo "$itemIn" | jq .srcfile)
	srcfile=$(subStr "$srcfile")
	local dstfile=$(echo "$itemIn" | jq .dstfile)
	dstfile=$(subStr "$dstfile")
	cp "$srcfile" "$dstfile"
}

function installCpDirItem() {
	local itemIn="$1"
	echo "type is CpDir"
	local srcfile=$(echo "$itemIn" | jq .srcfile)
	srcfile=$(subStr "$srcfile")
	local dstfile=$(echo "$itemIn" | jq .dstfile)
	dstfile=$(subStr "$dstfile")
	cp -rf "$srcfile" "$dstfile"
}


#<== 下载文件并生成service系统文件
function jarItemFile() {
	local itemIn="$1"
	echo "type is jar"
	local jarName=$(echo "$itemIn" | jq .name)
	local jarVersion=$(echo "$itemIn" | jq .version)
	jarName=$(subStr "$jarName")
	jarVersion=$(subStr "$jarVersion")
	echo "模块文件名称:$jarName ,  文件版本$jarVersion"
	#<== 1.调用获取文件jar包
	wgetJarItem $jarName $jarVersion
	#<== 2.调用获取生成系统servie
	if [ $? -eq 0 ]; then 
		systemctlService $jarName
		return 0
	else
	  return 1
	fi
   
}

#<== 下载文件并生成service系统文件
function toolItemFile() {
   local itemIn="$1"
   echo "type is tool"
   local jarName=$(echo "$itemIn" | jq .name)
   local jarVersion=$(echo "$itemIn" | jq .version)
   jarName=$(subStr "$jarName")
   jarVersion=$(subStr "$jarVersion")
   echo "模块文件名称:$jarName ,  文件版本$jarVersion"
   #<== 1.调用获取文件jar包
   wgetJarItem $jarName $jarVersion
   if [ $? -eq 0 ]; then 
	  return 0
	else
	  return 1
	fi
}


#<== 生成service系统文件
function systemctlService() {
	local serviceName="$1"
    local serviceitem="$tempDir/$serviceName.service"
	echo "serviceitem=========$serviceitem"
	
	touch $serviceitem
	echo "[Unit]" >>$serviceitem
	echo "Description=$serviceName" >>$serviceitem
	echo "After=nacos.service" >>$serviceitem   #<== nacos.service需要先启动，且是required
	echo "Requires=nacos.service" >>$serviceitem #<== 必须依赖nacos.service
	echo "[Service]" >>$serviceitem
	echo "Type=forking" >>$serviceitem
	echo "ExecStart=/usr/local/vap/cloud/application.sh start $serviceName " >>$serviceitem
	echo "ExecStop=/usr/local/vap/cloud/application.sh stop $serviceName " >>$serviceitem
        echo "Restart=on-failure " >>$serviceitem
	echo "User=root" >>$serviceitem
	echo "Group=root" >>$serviceitem
	echo "PrivateTmp=true" >>$serviceitem
	echo "[Install]" >>$serviceitem
	echo "WantedBy=multi-user.target" >>$serviceitem
}


function wgetJarItem1() {
	local jarName="$1"
	local jarversion="$2"
	local dstDir="$tempDir"
	echo "jar名称:$jarName ,  文件版本:$jarversion, 下载路径:$dstDir"
	#<== 先删除已有的文件
	rm -f "$finalZipFile"/"$jarName"-"$jarversion".jar 
	echo "从 http://192.168.0.106:8089/D%3A/bug0/jars 下载jar"	
	wget "http://192.168.0.106:8089/D%3A/bug0/jars/$jarName/$jarName"-"$jarversion.jar" -P "$dstDir"
}

#<== 私服nexus中获取jar文件
function wgetJarItem() {
	local jarName="$1"
	local jarversion="$2"
	local dstDir="$tempDir"
	echo "下载路径:$dstDir"
    #<== wget下载文件,Release的文件下载与SNAPSHOT不一致（SNAPSHOT携带了时间）
	result=$(echo $jarversion | grep "SNAPSHOT")
	if [[ "$result" != "" ]]
	 then
		echo "$jarversion include SNAPSHOT"
		wget http://"$nexus"/repository/maven-public/com/vrv/vap/"$jarName"/"$jarversion"/maven-metadata.xml  -P "$dstDir" -T 20
		#<== xml解析并获取真正的jar文件
		#sed -n  '/<snapshot>/,/<\/snapshot>/1/p' maven-metadata.xml 
		timestamp1=$(awk '/<timestamp/{print gensub(/<([^>]+)>([^<]+)<\/.*/,"\\2",1)}'  "$dstDir/maven-metadata.xml")
		echo "maven-metadata.xml,timestamp1="$timestamp1
		timestamp1=`echo $timestamp1 | sed -e 's/\(^ *\)//' -e 's/\( *$\)//'`
		
		# 去掉前后空格
		local buildNumber=$(awk '/<buildNumber/{print gensub(/<([^>]+)>([^<]+)<\/.*/,"\\2",1)}' "$dstDir/maven-metadata.xml")
		echo "maven-metadata.xml,buildNumber="$buildNumber
		buildNumber=`echo $buildNumber | sed -e 's/\(^ *\)//' -e 's/\( *$\)//'`
		
		local snapshotVersion="${jarversion/SNAPSHOT/$timestamp1}"
		echo "snapshotVersion=$snapshotVersion"
		wget http://"$nexus"/repository/maven-public/com/vrv/vap/"$jarName"/"$jarversion"/"$jarName-$snapshotVersion"-$buildNumber.jar  -P "$dstDir" -T 20
		# 这个maven-metadata.xml有点不准，需要重试
		testOK "http://$nexus/repository/maven-public/com/vrv/vap/$jarName/$jarversion/$jarName-$snapshotVersion-$buildNumber.jar  -P $dstDir -T 20"
		if [ $? -eq 1 ] 
		  then 
			echo "下载失败,私服时间，重试，文件中的时间可能会有延迟1到2秒"
			year_month_day="${timestamp1:0:8}"
			hours="${timestamp1:9:2}"
			minuts="${timestamp1:11:2}"
			seconds="${timestamp1:13}"
			times="$year_month_day $hours:$minuts:$seconds"
			seconds=`date -d "$times" +%s`       #得到时间戳
			seconds_new=`expr $seconds - 1`                   #减1秒
			#date_new=`date -d @$seconds_new "+%Y%m%d %H%M%S"`   #获得指定日前减一秒日前
			date_new=`date -d @$seconds_new "+%Y%m%d.%H%M%S"`   #获得指定日前格式输出
#			echo "---------$seconds"
#			echo "---------$seconds_new"
#			echo "---------$date_new"
			snapshotVersion="${jarversion/SNAPSHOT/$date_new}"
			wget http://"$nexus"/repository/maven-public/com/vrv/vap/"$jarName"/"$jarversion"/"$jarName-$snapshotVersion"-$buildNumber.jar  -P "$dstDir" -T 20
			testOK "http://$nexus/repository/maven-public/com/vrv/vap/$jarName/$jarversion/$jarName-$snapshotVersion-$buildNumber.jar  -P $dstDir -T 20"
			if [ $? -eq 1 ] 
				then 
				year_month_day="${timestamp1:0:8}"
				hours="${timestamp1:9:2}"
				minuts="${timestamp1:11:2}"
				seconds="${timestamp1:13}"
				times="$year_month_day $hours:$minuts:$seconds"
				seconds=`date -d "$times" +%s`       #得到时间戳
				seconds_new=`expr $seconds - 2`                   #减2秒
				date_new=`date -d @$seconds_new "+%Y%m%d.%H%M%S"`
				snapshotVersion="${jarversion/SNAPSHOT/$date_new}"
				wget http://"$nexus"/repository/maven-public/com/vrv/vap/"$jarName"/"$jarversion"/"$jarName-$snapshotVersion"-$buildNumber.jar  -P "$dstDir" -T 20
				testOK "http://$nexus/repository/maven-public/com/vrv/vap/$jarName/$jarversion/$jarName-$snapshotVersion-$buildNumber.jar  -P $dstDir -T 20"
			fi
		fi
		#<== 删除xml解析
		rm -f "$dstDir"/maven-metadata.xml
	else
		echo "$jarName not include SNAPSHOT"
		wget http://"$nexus"/repository/maven-public/com/vrv/vap/"$jarName"/"$jarversion"/"$jarName"-"$jarversion".jar  -P "$dstDir" -T 20
		if [ $? -eq 0 ]; then 
		  return 0
		else
		  echo "下载失败：http://"$nexus"/repository/maven-public/com/vrv/vap/"$wgetfile"/"$wgetversion"/"$wgetfile"-"$wgetversion".jar"
		  return 1
		fi
	fi 
}

function testOK() {
	if [ $? -eq 0 ] 
	  then 
		echo "下载成功 $1"
	    return 0
	else
		echo "下载失败 $1"
		return 1
	fi		  
}

function lnJars() {
	local modulesFile=$1
	local lnModule=$2
	rm -f "/usr/local/vap/cloud/$2"
	echo "ln -s /usr/local/vap/cloud/$1" "/usr/local/vap/cloud/$2"
	ln -s "/usr/local/vap/cloud/$1" "/usr/local/vap/cloud/$2"
}

#<== 获取基础组件，例如mysql、elasticsearch等组件
function installbaseItem() {
   local itemIn="$1"
   echo "type is base"
   local componentName=$(echo "$itemIn" | jq .name)
   local componentVersion=$(echo "$itemIn" | jq .version)
   componentName=$(subStr "$componentName")
   componentVersion=$(subStr "$componentVersion")
   echo "模块文件名称:$componentName ,  文件版本$componentVersion"
   #<== 先删除已有的文件
   rm -rf $finalZipFile/$componentName
   #cp -r $base_component_dir/$componentName $finalZipFile  #<== 本机下载
   
  
   #<== 1.获取基础组件zip包
    echo "从 http://192.168.118.236:8989/D%3A/bug0/baseComponent 下载基础组件(公共构建)"	
    wget "$base_component_uri$componentName/$componentName"-"$componentVersion".zip  -P "$finalZipFile"
    if [ $? -eq 0 ] 
	  then 
	   echo "解压缩$finalZipFile/$componentName-$componentVersion.zip，请稍后.."
	   unzip -q "$finalZipFile/$componentName-$componentVersion.zip" -d $finalZipFile
	   rm -rf "$finalZipFile/$componentName-$componentVersion.zip"
	   return 0
    else
	  echo "下载失败：$base_component_uri$componentName/$componentName-$componentVersion.zip  -P $finalZipFile"
	  return 1
    fi
}

#<== 获取前端版本
function installappItem() {
   local itemIn="$1"
   echo "type is app"
   local appName=$(echo "$itemIn" | jq .name)
   local appVersion=$(echo "$itemIn" | jq .version)
   appName=$(subStr "$appName")
   appVersion=$(subStr "$appVersion")
   echo "模块文件名称:$appName ,  文件版本$appVersion"
   #<== 先删除已有的文件
   rm -rf $finalZipFile/$appName
   # cp -r $base_component_dir/$appName $finalZipFile
   #<== 1.获取基础组件zip包
	echo "从 http://192.168.118.236:8989/D%3A/bug0/baseComponent 下载基础组件(公共构建)"	
	wget "$base_component_uri$appName/$appName"-"$appVersion".zip  -P "$finalZipFile"
	if [ $? -eq 0 ] 
	  then 
	   echo "解压缩$finalZipFile/$appName-$appVersion.zip，请稍后.."
	   unzip -q "$finalZipFile/$appName-$appVersion.zip" -d $finalZipFile
	   rm -rf "$finalZipFile/$appName-$appVersion.zip"
	   return 0
	else
	  echo "下载失败：$base_component_uri$appName/$appName-$appVersion.zip  -P $finalZipFile"
	  return 1
	fi
}

#<== 获取sql版本
function installsqlItem() {
   echo "sql安装"
}

#<== jsoc模块安装包
function installJsocJson() {
    local jsocName="$finalZipFile/temp.json"
	###################################################################
	touch "$jsocName"
	#<== echo "useage的类型代表升级或者安装【upgrade/install】"
	local temp_jsoc_string="{\"name\":\"jsoc\",\"type\":\"items\",\"useage\":\"$useagetype\",\"items\":["
	#<== 如果是安装，那么就需要环境变量，如果是升级则不需要
	if [ "$useagetype" == "install" ] ; then
		temp_jsoc_string=$temp_jsoc_string'{'
		temp_jsoc_string=$temp_jsoc_string"\"name\":\"base-dir\","
		temp_jsoc_string=$temp_jsoc_string'"type":"mkdir",'
		temp_jsoc_string=$temp_jsoc_string'"dstDir":"/usr/local/vap"'
		temp_jsoc_string=$temp_jsoc_string"},"
		
		temp_jsoc_string=$temp_jsoc_string'{'
		temp_jsoc_string=$temp_jsoc_string"\"name\":\"cloud envirment\","
		temp_jsoc_string=$temp_jsoc_string'"type":"sh",'
		temp_jsoc_string=$temp_jsoc_string'"shs":''['
		temp_jsoc_string=$temp_jsoc_string'"exportCloudEnvi"'
		temp_jsoc_string=$temp_jsoc_string"]},"
		
		temp_jsoc_string=$temp_jsoc_string'{'
		temp_jsoc_string=$temp_jsoc_string"\"name\":\"cloud envirment\","
		temp_jsoc_string=$temp_jsoc_string'"type":"sh-uninstall",'
		temp_jsoc_string=$temp_jsoc_string'"shs":''['
		temp_jsoc_string=$temp_jsoc_string'"uninstallCloudEnvi"'
		temp_jsoc_string=$temp_jsoc_string"]},"
	fi

	#<== 根据文件夹进行安装json, 按时间的先后排序，base第一个 
	for temp in $(ls -trl $finalZipFile  | grep  base)
	  do
		#echo "目录下的dir:"$temp
		if [ -d "$finalZipFile/$temp" ]
		  then
		    temp_jsoc_string=$temp_jsoc_string'{'
		    temp_jsoc_string=$temp_jsoc_string"\"name\":\"$temp\","
			temp_jsoc_string=$temp_jsoc_string'"type":"itemFile",'
			temp_jsoc_string=$temp_jsoc_string'"fileDir":"'$temp'",'
			temp_jsoc_string=$temp_jsoc_string'"fileName":"'$temp'.json"'
		    temp_jsoc_string=$temp_jsoc_string'},'
        fi
	done;	
	
	#<== 根据文件夹进行安装json, 按时间的先后排序，db第二个安装 
	for temp in $(ls -trl $finalZipFile  | grep  db)
	  do
		if [ -d "$finalZipFile/$temp" ]
		  then
		    temp_jsoc_string=$temp_jsoc_string'{'
		    temp_jsoc_string=$temp_jsoc_string"\"name\":\"$temp\","
			temp_jsoc_string=$temp_jsoc_string'"type":"itemFile",'
			temp_jsoc_string=$temp_jsoc_string'"fileDir":"'$temp'",'
			temp_jsoc_string=$temp_jsoc_string'"fileName":"'$temp'.json"'
		    temp_jsoc_string=$temp_jsoc_string'},'
        fi
	done;
	
	
	#<== 根据文件夹进行安装json, 按时间的先后排序，nacos第三个安装 
	for temp in $(ls -trl $finalZipFile  | grep  nacos)
	  do
		if [ -d "$finalZipFile/$temp" ]
		  then
		    temp_jsoc_string=$temp_jsoc_string'{'
		    temp_jsoc_string=$temp_jsoc_string"\"name\":\"$temp\","
			temp_jsoc_string=$temp_jsoc_string'"type":"itemFile",'
			temp_jsoc_string=$temp_jsoc_string'"fileDir":"'$temp'",'
			temp_jsoc_string=$temp_jsoc_string'"fileName":"'$temp'.json"'
		    temp_jsoc_string=$temp_jsoc_string'},'
        fi
	done;
	
	#echo "----------------------$temp_jsoc_string"
	
	#<== 根据文件夹进行安装json, 按时间的先后排序，cloud放最后
	for temp in $(ls -trl $finalZipFile | grep -v cloud  | grep -v base | grep -v db  | grep -v nacos)
	  do
		#echo "目录下的dir:"$temp
		if [ -d "$finalZipFile/$temp" ]
		  then
		    temp_jsoc_string=$temp_jsoc_string'{'
		    temp_jsoc_string=$temp_jsoc_string"\"name\":\"$temp\","
			local result=$(echo $temp | grep "app-web")
			if [[ "$result" != "" ]]
			 then
			    # 这个app-web的前端页面有点特殊
				temp_jsoc_string=$temp_jsoc_string'"type":"cpfiles",'
				temp_jsoc_string=$temp_jsoc_string'"srcfile":"'$temp'",'
				temp_jsoc_string=$temp_jsoc_string'"dstfile":"/usr/local/vap"'
			else
				temp_jsoc_string=$temp_jsoc_string'"type":"itemFile",'
				temp_jsoc_string=$temp_jsoc_string'"fileDir":"'$temp'",'
				temp_jsoc_string=$temp_jsoc_string'"fileName":"'$temp'.json"'
			fi
		    temp_jsoc_string=$temp_jsoc_string'},'
        fi
	done;
	
    #<== 根据文件夹进行安装json, 按时间的先后排序，cloud 
	for temp in $(ls -trl $finalZipFile  | grep  cloud)
	  do
		#echo "目录下的dir:"$temp
		if [ -d "$finalZipFile/$temp" ]
		  then
		    temp_jsoc_string=$temp_jsoc_string'{'
		    temp_jsoc_string=$temp_jsoc_string"\"name\":\"$temp\","
			temp_jsoc_string=$temp_jsoc_string'"type":"itemFile",'
			temp_jsoc_string=$temp_jsoc_string'"fileDir":"'$temp'",'
			temp_jsoc_string=$temp_jsoc_string'"fileName":"'$temp'.json"'
		    temp_jsoc_string=$temp_jsoc_string'},'
        fi
	done;
	
	
	
	# 截取不需要最后的逗号（这个是数组中的）
	temp_jsoc_string=${temp_jsoc_string%?}']}' 
	#echo "debug----->>>>>>>$temp_jsoc_string"
	# 格式化并存储到文件中
	echo $temp_jsoc_string | ./jq . > "$jsocName"
	cat "$jsocName" >> "$finalZipFile/jsoc.json"
	rm -f "$jsocName"
   
}


#<== 生成cloud.json,  upgrade和install不一样，upgrade只需要有jar和lnjar，其他的不需要
function installModuleItem() {
#	local itemIn="$1"
#	echo "type is modulejson"
#	local moduleName=$(echo "$itemIn" | jq .name)
#	modulefile=$(subStr "$moduleName")
#	local moduledesc=$(echo "$itemIn" | jq .desc)
#	moduledesc=$(subStr "$moduledesc")


	local modulefile="cloud.json"
	local moduledesc="cloud模块安装"
	
    dstDir="$finalZipFile/cloud"
	echo "【生成文件】:$dstDir/$modulefile"
	cat /dev/null > "$dstDir/$modulefile"
	local moduleitem="$dstDir/$modulefile"
	
	tempFileName=$(date "+%Y%m%d%H%M%S").json
	#echo "tempFileName=$tempFileName"
	###################################################################
	touch "$tempFileName"
	### 数组从这里开始

	echo '{"name":"'$moduledesc'", "type":"items","items":[' > $tempFileName
	# 获取所有的service并写入到cloud.json中
		
	# 第一步: cp jar files 
	local temp_service_string=""
	temp_service_string=$temp_service_string'{'
	temp_service_string=$temp_service_string"\"name\":\"cloud-dir\","
	temp_service_string=$temp_service_string'"type":"mkdir",'
	temp_service_string=$temp_service_string'"dstDir":"/usr/local/vap/cloud"'
	temp_service_string=$temp_service_string"},"
	
	
	temp_service_string=$temp_service_string'{'
	temp_service_string=$temp_service_string"\"name\":\"cp cloud files\","
	temp_service_string=$temp_service_string'"type":"cpfiles",'
	temp_service_string=$temp_service_string'"srcfile":"'.'",'
	temp_service_string=$temp_service_string'"dstfile":"/usr/local/vap/cloud/"'
	temp_service_string=$temp_service_string"},"
	#echo "----------$temp_service_string"
	
	
	#<=== install的时候service是必须的，升级不是必须的  enable servie
	if [ "$useagetype" == "install" ]; then
	# 第二步：systemctl service文件复制
		for item in $(ls $dstDir/*.service); 
		  do
			#echo "------->"$item
			## 号截取，删除左边字符，保留右边字符。
			local subitem=${item##*/}
			#echo "截取之后的文件名称:----->$subitem"
			temp_service_string=$temp_service_string'{'
			temp_service_string=$temp_service_string"\"name\":\"cp $subitem files\","
			temp_service_string=$temp_service_string'"type":"cpfiles",'
			temp_service_string=$temp_service_string'"srcfile":"'$subitem'",'
			temp_service_string=$temp_service_string'"dstfile":"/usr/lib/systemd/system/"'
			temp_service_string=$temp_service_string"},"
		done;
	fi
	
	# 截取不需要最后的逗号（这个是数组中的）
	echo ${temp_service_string%?} >>$tempFileName
	
	local c=0
	local filelist
	for file in $(ls $dstDir/*.service); do
		filelist[$c]=$file
		((c++))
	done
	local _count=${#filelist[*]}
	#echo "个数count:"${_count}
	
	###  第三四五步只跟sh中间内容不同，直接复制的，可优化，先完成功能
	# 第三步 连接ln-jar包
	local link_jar_string=","
	link_jar_string=$link_jar_string'{'
	link_jar_string=$link_jar_string"\"name\":\"${dstDir##*/} ln jar\","
	link_jar_string=$link_jar_string'"type":"sh",'
	# 数组中这里开始
	link_jar_string=$link_jar_string'"shs":''['
	local _index=0
	# 逐一读出数组的值
	for aa in ${filelist[*]}; do
		#echo "===" $aa
		## 截取，删除左边字符，保留右边字符。 去掉左边的路径，得到api-admin.service
		local enable_item=${aa##*/}
		#echo "第一次截取之后的文件名称:----->$enable_item"
		# 得到api-admin字符串，把.service去掉
		enable_item=${enable_item%.*}
		#echo "第二次截取:---$enable_item"
		local realjar=`ls $dstDir | grep $enable_item | grep jar`
		echo $realjar
		if [ $_index -lt $(expr $_count - 1) ]; then
			#echo "*****$link_jar_string"
			link_jar_string=$link_jar_string\""lnJars $realjar $enable_item.jar\","
		else
			#echo "--------$link_jar_string"
			link_jar_string=$link_jar_string\""lnJars $realjar $enable_item.jar\""
		fi
		((_index++))
	done
	link_jar_string=$link_jar_string"]}"
	# 数组从这里结束
	
	#echo "----------$link_jar_string"
	# 截取不需要最后的逗号
	echo ${link_jar_string} >>$tempFileName
	
	
    #<=== 第四步  enable servie
	if [ "$useagetype" == "install" ] 
	  then
		local enable_service_string=","
		enable_service_string=$enable_service_string'{'
		enable_service_string=$enable_service_string"\"name\":\"enable ${dstDir##*/} services\","
		enable_service_string=$enable_service_string'"type":"sh",'
		# 数组中这里开始
		enable_service_string=$enable_service_string'"shs":''["systemctl daemon-reload",'
		
		local _index=0
		# 逐一读出数组的值
		for aa in ${filelist[*]}; do
			#echo "===" $aa
			## 截取，删除左边字符，保留右边字符。 去掉左边的路径，得到api-admin.service
			local enable_item=${aa##*/}
			#echo "第一次截取之后的文件名称:----->$enable_item"
			# 得到api-admin字符串，把.service去掉
			enable_item=${enable_item%.*}
			#echo "第二次截取:---$enable_item"
			
			if [ $_index -lt $(expr $_count - 1) ]; then
				#echo "*****$enable_service_string"
				enable_service_string=$enable_service_string\""systemctl enable $enable_item\","
			else
				#echo "--------$enable_service_string"
				enable_service_string=$enable_service_string\""systemctl enable $enable_item\""
			fi
			((_index++))
		done
		enable_service_string=$enable_service_string"]}"
		# 数组从这里结束
		#echo "----------$enable_service_string"
		# 截取不需要最后的逗号
		echo ${enable_service_string} >>$tempFileName
	fi
	
	local start_service_string=","
	start_service_string=$start_service_string'{'
	start_service_string=$start_service_string"\"name\":\"start ${dstDir##*/} services\","
	start_service_string=$start_service_string'"type":"sh",'
	start_service_string=$start_service_string'"shs":''['
	local _index=0
	# 第五步 start服务
	# 逐一读出数组的值
	for aa in ${filelist[*]}; do
		#echo "===" $aa
		## 截取，删除左边字符，保留右边字符。 去掉左边的路径，得到api-admin.service
		local enable_item=${aa##*/}
		#echo "第一次截取之后的文件名称:----->$enable_item"
		# 得到api-admin字符串，把.service去掉
		enable_item=${enable_item%.*}
		#echo "第二次截取:---$enable_item"
		
		if [ $_index -lt $(expr $_count - 1) ]; then
			#echo "*****$start_service_string"
			if [ "$useagetype" == "install" ]; then  #<== 如果是升级就需要restart服务，如果是安装只需要start服务即可
				 start_service_string=$start_service_string\""systemctl start $enable_item\","
		    else
			     start_service_string=$start_service_string\""systemctl restart $enable_item\","
			fi
		else
		    if [ "$useagetype" == "install" ]; then 
			#echo "--------$start_service_string"
			 start_service_string=$start_service_string\""systemctl start $enable_item\""
			else 
			 start_service_string=$start_service_string\""systemctl restart $enable_item\""
			fi
		fi
		((_index++))
	done
	start_service_string=$start_service_string"]}"
	#echo "----------$start_service_string"
	echo ${start_service_string} >>$tempFileName
       
	# 第六步 拼接json，所有的结尾
	echo ']}' >>$tempFileName
	
	# 第七步: 格式化并存储到文件中
	cat $tempFileName | ./jq . > $moduleitem
	#<== 测试中需要打开，可以查看源文件jsoc格式
	rm -rf "$tempFileName"		
	
}



#<== 方法暂时保留，现在暂时没有用到
function wgetItemFile() {
	local itemIn="$1"
	echo "type is wgetfiles"
	local wgetfile=$(echo "$itemIn" | jq .name)
	local wgetversion=$(echo "$itemIn" | jq .version)
	wgetfile=$(subStr "$wgetfile")
	wgetversion=$(subStr "$wgetversion")
	echo "wget文件名称:$wgetfile ,  wget文件版本$wgetversion"
	local dstDir=$(echo "$itemIn" | jq .dstDir)
	dstDir=$(subStr "$dstDir")
	rm -rf "$dstDir/$wgetfile-$wgetversion.jar"
	#本地修改
	echo "$dstDir"
	# wget https://tool.lu/ -O $wgetfile-$wgetversion.jar
	# mv $wgetfile-$wgetversion.jar "$dstDir"
	wget http://"$nexus"/repository/maven-public/com/vrv/vap/"$wgetfile"/"$wgetversion"/"$wgetfile"-"$wgetversion".jar  -P "$dstDir" -T 1000
    if [ $? -eq 0 ] 
	  then 
	  return 0
    else
	  echo "下载失败：http://"$nexus"/repository/maven-public/com/vrv/vap/"$wgetfile"/"$wgetversion"/"$wgetfile"-"$wgetversion".jar"
	  return 1
    fi
}

# 生成系统service文件，现在暂时没有用到
function sysctlfileItem() {
	local itemIn="$1"
	echo "type is sysctlfile"
	local sysctlFileName=$(echo "$itemIn" | jq .name)
	sysctlfile=$(subStr "$sysctlFileName")
	echo "sysctlfile文件名称:$sysctlfile"
	local dstDir=$(echo "$itemIn" | jq .dstDir)
	dstDir=$(subStr "$dstDir")
	rm -rf "$dstDir/$sysctlfile".service
	local serviceitem="$dstDir/$sysctlfile".service
	echo "serviceitem=$serviceitem"
	touch $serviceitem
	echo "[Unit]" >>$serviceitem
	echo "Description=$sysctlFileName" >>$serviceitem
	echo "After=network.target" >>$serviceitem
	echo "[Service]" >>$serviceitem
	echo "Type=forking" >>$serviceitem
	echo "ExecStart=$shfile start $sysctlfile $dstDir " >>$serviceitem
	echo "ExecStop=$shfile stop $sysctlfile $dstDir" >>$serviceitem
	echo "User=root" >>$serviceitem
	echo "Group=root" >>$serviceitem
	echo "PrivateTmp=true" >>$serviceitem
	echo "[Install]" >>$serviceitem
	echo "WantedBy=multi-user.target" >>$serviceitem
}



function installShItem() {
	local itemIn="$1"
	echo "type is sh"
	local count=$(echo "$itemIn" | jq '.shs | length')
	local i=0
	for ((i = 0; i < $count; i++)); do
		local aItem=$(echo "$itemIn" | jq .shs[$i])
		aItem=$(subStr "$aItem")
		echo "$aItem" >>shlog
		eval $aItem
	done
}

function installItemsItem() {
	local itemIn="$1"
	echo "type is items"
	local count=$(echo "$itemIn" | jq '.items | length')
	local i=0
	for ((i = 0; i < $count; i++)); do
		local aItem=$(echo "$itemIn" | jq .items[$i])
		installItem "$aItem"
	done
}

function installAppendConfigItem() {
	local itemIn="$1"
	echo "type is appendConfig"
	local configFile=$(echo "$itemIn" | jq .file)
	configFile=$(subStr "$configFile")
	local linesCount=$(echo "$itemIn" | jq '.lines | length')
	local i=0
	for ((i = 0; i < $linesCount; i++)); do
		local aLine="$(echo "$itemIn" | jq .lines[$i])"
		echo "加入行：""$aLine" 2>&1 | tee -a appendLine
		aLine=$(subStr "$aLine")
		echo "加入行：""$aLine" 2>&1 | tee -a appendLine
		echo "$aLine" >>"$configFile"
	done
}

function installSedConfigItem() {
	local itemIn="$1"
	echo "type is appendConfig"
	local configFile=$(echo "$itemIn" | jq .file)
	configFile=$(subStr "$configFile")
	local reg=$(echo "$itemIn" | jq .reg)
	reg=$(subStr "$reg")
	local linesCount=$(echo "$itemIn" | jq '.lines | length')
	local i=0
	for ((i = 0; i < $linesCount; i++)); do
		local aLine=$(echo "$itemIn" | jq .lines[$i])
		aLine=$(subStr "$aLine")
		sed -i "/$reg/a $aLine" "$configFile"
	done
}

function installTarzxvfItem() {
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

function installzipdItem() {
#    set -x
	echo "type is zipd"
	local dir_name=`dirname $0`
	echo "zip的文件生成目录：$dir_name"
	cp -rf $dir_name/sh/*.sh $finalZipFile/
        cp -rf $dir_name/conf.properties $finalZipFile/
	cp -rf $dir_name/jq $finalZipFile/
	cp -rf $dir_name/memconf.properties $finalZipFile/cloud/
	
	# 如果是安装才需要application.sh
	if [ "$useagetype" == "install" ] 
	  then
		  cp -rf $dir_name/application.sh $finalZipFile/cloud/
		  chmod 755 $finalZipFile/cloud/application.sh
	else 
		rm -rf $finalZipFile/cloud/*.service  #<== 升级的时候只需要jar和lnjar，不需要
	fi
	
	installJsocJson
	echo "开始压缩文件目录$dir_name/$finalZipFile/，稍等..."
	zip -r -q "$finalZipFile".zip $dir_name/$finalZipFile/
    
	
}

function installFile() {
	local fileName="$1"
	echo "file name : $fileName"
	#cat $1 | jq .useage
	useagetype=`cat $fileName | ./jq .useage`
	useagetype=$(subStr "$useagetype")
	if [ "$useagetype" == "install" ]
	  then
	  echo "生成安装包【install】ing..."
	else
	  echo "生成更新包【upgrade】ing..."
	fi  
	local itemStr="$(cat $fileName)" && installItem "$itemStr"
}

function installMkdirItem() {
	local itemIn="$1"
	echo "type is Mkdir"
	local dstDir=$(echo "$itemIn" | jq .dstDir)
	dstDir=$(subStr "$dstDir")
	if test -e "$dstDir"; then
		echo "已经创建$dstDir目录"
	else
		mkdir -p "$dstDir"
	fi
}

function installItemFile() {
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

function mysqlPwd() {
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

	if [ $(whoami) = "root" ]; then
		echo "The current user is root"
	else
		echo "ROOT role is needed to install"
		success="false"
		return
	fi
	echo "*************************"

}

function installItem() {
	if [ $success == 'false' ]; then
		return
	fi
	success="true"
	local itemIn="$1"
	local itemtype=$(echo "$itemIn" | jq .type)
	local itemName=$(echo "$itemIn" | jq .name)
	itemtype=$(subStr "$itemtype")	
	echo "$itemName:开始下载打包" | tee -a installLog
	if [ $itemtype == 'rpm' ]; then
		installRpmItem "$itemIn" || success="canContinue"
	fi

	if [ $itemtype == 'items' ]; then
		installItemsItem "$itemIn" || success="false"
	fi

	if [ $itemtype == 'appendConfig' ]; then
		installAppendConfigItem "$itemIn" || success="false"
	fi

	if [ $itemtype == 'sedConfig' ]; then
		installSedConfigItem "$itemIn" || success="false"
	fi

	if [ $itemtype == 'ln' ]; then
		installLnItem "$itemIn" || success="false"
	fi

	if [ $itemtype == 'mkdir' ]; then
		installMkdirItem "$itemIn" || success="false"
	fi

	if [ $itemtype == 'cpfile' ]; then
		installCpfileItem "$itemIn" || success="false"
	fi

	if [ $itemtype == 'cpfiles' ]; then
		installCpDirItem "$itemIn" || success="false"
	fi

	if [ $itemtype == 'sh' ]; then
		installShItem "$itemIn" || success="false"
	fi

	if [ $itemtype == 'tarzxvf' ]; then
		installTarzxvfItem "$itemIn" || success="false"
	fi

	if [ $itemtype == 'unzipd' ]; then
		installUnzipdItem "$itemIn" || success="false"
	fi

	if [ $itemtype == 'itemFile' ]; then
		installItemFile "$itemIn" || success="false"
	fi
#<==新增集成jar安装	
	if [ $itemtype == 'jar' ]; then
		jarItemFile "$itemIn" || success="false"
	fi
#<==集成tool安装	
	if [ $itemtype == 'tool' ]; then
		toolItemFile "$itemIn" || success="false"
	fi
#<==新增集成cloud.json	
	if [ $itemtype == 'modulejson' ]; then
		installModuleItem "$itemIn" || success="false"
	fi
#<==新增集成文件zip压缩	
	if [ $itemtype == 'zipd' ]; then
		installzipdItem "$itemIn" || success="false"
	fi
#<==base，基础组件	
	if [ $itemtype == 'base' ]; then
		installbaseItem "$itemIn" || success="false"
	fi
#<==app,前端页面	
	if [ $itemtype == 'app' ]; then
		installappItem "$itemIn" || success="false"
	fi	
#<==sql,sql脚本	
	if [ $itemtype == 'sql' ]; then
		installsqlItem "$itemIn" || success="false"
	fi	
	

#<==新增wget下載 
	if [ $itemtype == 'wgetfile' ]; then
		wgetItemFile "$itemIn" || success="false"
	fi
#<==新增系統application.service服务
	if [ $itemtype == 'sysctlfile' ]; then
		sysctlfileItem "$itemIn" || success="false"
	fi
	if [ $success == 'true' ]; then
		echo "$itemName:成功" | tee -a installLog
	else
		echo "$itemName:失败" | tee -a installLog
	fi
}



mkdir -p $finalZipFile


echo "安装包所在目录:`dirname $0`/$finalZipFile"
initInstall
installFile "$1"
if [ $success == 'true' ]; then
    installModuleItem
    installzipdItem
	echo  "-----------------------------"
	echo "安装包文件:$finalZipFile.zip"
	echo  "-----------------------------"
fi
	
