#!/bin/bash
PATH=$PATH:$(pwd)

chmod 755 jq
function subStr {
	local itemStr="$1"
	itemStr=$(echo "${itemStr#'"'}")
	itemStr=$(echo "${itemStr%'"'}")
	echo "$itemStr"
}

# liujinhui 2019年5月28日17:34:39 修改卸载
#function uninstallRpmItem() {
#	local itemIn="$1"
##	echo "type is rpm: $1"
#	local rpmName=$(echo "$itemIn" | jq .rpmName)
#	rpmName=$(subStr "$rpmName")
#	echo "rpm file is $rpmName"
#	local args=$(echo "$itemIn" | jq .args)
#	if [ "$args" == "null" ]; then
#	    echo "rpm -e $rpmName 2>&1 | tee -a uninstallRpmLog"
#		rpm -e $rpmName 2>&1 | tee -a uninstallRpmLog
#	else
#		args=$(subStr "$args")
#		echo "rpm -e $rpmName $args 2>&1 | tee -a installRpmLog"
#		rpm -e $rpmName $args 2>&1 | tee -a installRpmLog
#	fi
#	echo "rpm file is $rpmName"
#}

function uninstallRpmItem() {
        local itemIn="$1"
        echo "type is rpm"
        local rpmName=$(echo "$itemIn" | jq .rpmName)
        rpmName=$(subStr "$rpmName")
        echo "rpm file is $rpmName"
        rpm -e $rpmName 2>&1 | tee -a uninstallRpmLog
}


function uninstallItemsItem() {
	local itemIn="$1"
	echo "type is items"
	local count=$(echo "$itemIn" | jq '.items | length')
	local i=$[$count-1]
	for((i;i>=0;i--))
	do
		local aItem=$(echo "$itemIn" | jq .items[$i])
		uninstallItem "$aItem"
	done
}

function uninstallAppendConfigItem() {
	local itemIn="$1"
	echo "type is appendConfig"
	local configFile=$(echo "$itemIn" | jq .file)
	configFile=$(subStr "$configFile")
	local linesCount=$(echo "$itemIn" | jq '.lines | length')
	local i=$[$linesCount-1]
	for((i;i>=0;i--))
	do
		local aLine=`echo "$itemIn" | jq .lines[$i]`
		aLine=$(subStr "$aLine")
		echo "删除行：$aLine" 2>&1 | tee -a appendLine
		sed -i "s#$aLine#EXCLUSIVE#;/EXCLUSIVE/d" "$configFile"
	done
}

function uninstallCloudEnvi {
	sed -i "/^export MYSQL_HOST=.*/d" /etc/profile
    sed -i "/^export MYSQL_PASSWORD=.*/d" /etc/profile
    sed -i "/^export REDIS_HOST=.*/d" /etc/profile
    sed -i "/^export RABBITMQ_HOST=.*/d" /etc/profile
    sed -i "/^export EUREKA_HOST=.*/d" /etc/profile
	sed -i "/^export ES_CLUSTER_HOST=.*/d" /etc/profile
	sed -i "/^export ES_CLUSTER_NAME=.*/d" /etc/profile
	sed -i "/^export KAFKA_URL=.*/d" /etc/profile
	sed -i "/^export NACOS_HOST=.*/d" /etc/profile
	sed -i "/^export NACOS_NAMESPACE=.*/d" /etc/profile
	sed -i "/^export NACOS_PORT=.*/d" /etc/profile
	sed -i "/^export WEBAPP=.*/d" /etc/profile
}

function uninstallSedConfigItem() {
	local itemIn="$1"
	echo "type is appendConfig"
	local configFile=$(echo "$itemIn" | jq .file)
	configFile=$(subStr "$configFile")
	local linesCount=$(echo "$itemIn" | jq '.lines | length')
	local i=$[$linesCount-1]
	for((i;i>=0;i--))
	do
		local aLine=$(echo "$itemIn" | jq .lines[$i])
		aLine=$(subStr "$aLine")
		sed -i "s#$aLine#EXCLUSIVE#;/EXCLUSIVE/d" "$configFile"
	done
}

function uninstallLnItem() {
	local itemIn="$1"
	echo "type is ln"
	local dstfile=$(echo "$itemIn" | jq .dstfile)
	dstfile=$(subStr "$dstfile")
	echo "删除软连接：$dstfile" 2>&1 | tee -a uninstallRMLog
	rm -rf "$dstfile"
}

function uninstallCpfileItem() {
	local itemIn="$1"
	echo "type is Cpfile"
	local srcfile=$(echo "$itemIn" | jq .srcfile)
	srcfile=$(subStr "$srcfile")
	local dstfile=$(echo "$itemIn" | jq .dstfile)
	dstfile=$(subStr "$dstfile")
	if [ -d "$dstfile" ]; then  
　　	dstfile="$dstfile$srcfile"
	fi 
	if [ -f "$dstfile" ]; then  
		echo "删除文件：$dstfile" 2>&1 | tee -a uninstallRMLog
		rm "$dstfile"
	fi
}

function uninstallCpDirsItem() {
	local itemIn="$1"
	echo "type is CpDirs"
	local srcfile=$(echo "$itemIn" | jq .srcfile)
	srcfile=$(subStr "$srcfile")
	local dstfile=$(echo "$itemIn" | jq .dstfile)
	dstfile=$(subStr "$dstfile")
	dstfile="$dstfile$srcfile"
	echo "删除路径：$dstfile" 2>&1 | tee -a uninstallRMLog
	rm -rf "$dstfile"
}

function uninstallTarzxvfItem() {
	local itemIn="$1"
	echo "type is Tarzxvf"
	local targetdir=$(echo "$itemIn" | jq .targetdir)
	targetdir=$(subStr "$targetdir")
	local dstdir=$(echo "$itemIn" | jq .dstdir)
	dstdir=$(subStr "$dstdir")
	dstdir="$dstdir$targetdir"
	echo "删除解压文件夹：$dstdir" 2>&1 | tee -a uninstallRMLog
	rm -rf "$dstdir"
}

function uninstallMkdirItem() {
	local itemIn="$1"
	echo "type is Mkdir"
	local dstDir=$(echo "$itemIn" | jq .dstDir)
	dstDir=$(subStr "$dstDir")
	if test -e "$dstDir"
	then
		echo "删除新建文件夹：$dstdir" 2>&1 | tee -a uninstallRMLog
		rm -rf "$dstDir"
	else
		echo "$dstDir不存在"
	fi
}

function uninstallFile {
	local fileName="$1"
	echo $fileName
	local itemStr="$(cat $fileName)" && uninstallItem "$itemStr"
}

function uninstallItemFile() {
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
	uninstallFile "$fileName"
	cd "$nPwd"
	echo "当前路径：$(pwd)"
}

function shItem() {
	echo "type is shell,不做任何操作"
}

function unininstallShItem() {
	local itemIn="$1"
	echo "type is sh"
	local count=$(echo "$itemIn" | jq '.shs | length')
	local i=$[$count-1]
	for((i;i>=0;i--))
	do
		local aItem=$(echo "$itemIn" | jq .shs[$i])
		aItem=$(subStr "$aItem")
		echo "$aItem" >> shlog
		eval $aItem
	done
}



success="true"
function uninstallItem {
        local itemIn="$1"
        local itemtype=$(echo "$itemIn" | jq .type)
		local itemName=$(echo "$itemIn" | jq .name)
        itemtype=$(subStr "$itemtype")
		echo "$itemName:开始卸载" | tee -a uninstallLog
		if [ $itemtype == 'rpm' ];then
			uninstallRpmItem "$itemIn"  || success="false"
		fi
		
		if [ $itemtype == 'items' ];then
			uninstallItemsItem "$itemIn" || success="false"
		fi
		
		if [ $itemtype == 'appendConfig' ];then
			uninstallAppendConfigItem "$itemIn" || success="false"
		fi
		
		if [ $itemtype == 'sedConfig' ];then
			uninstallSedConfigItem "$itemIn" || success="false"
		fi
		
		if [ $itemtype == 'ln' ];then
			uninstallLnItem "$itemIn" || success="false"
		fi
		
		if [ $itemtype == 'mkdir' ];then
			uninstallMkdirItem "$itemIn" || success="false"
		fi
		
		if [ $itemtype == 'cpfile' ];then
			uninstallCpfileItem "$itemIn" || success="false"
		fi
		
		if [ $itemtype == 'cpfiles' ];then
			uninstallCpDirsItem "$itemIn" || success="false"
		fi
		
		if [ $itemtype == 'sh' ];then
			shItem "$itemIn" || success="false"
		fi
		
		if [ $itemtype == 'sh-uninstall' ];then
			unininstallShItem "$itemIn" || success="false"
		fi
		
		if [ $itemtype == 'tarzxvf' ];then
			uninstallTarzxvfItem "$itemIn" || success="false"
		fi
		
		if [ $itemtype == 'itemFile' ];then
			uninstallItemFile "$itemIn" || success="false"
		fi
		
		if [ $success == 'false' ];then
			echo "$itemName:卸载失败" | tee -a uninstallLog
		else
			echo "$itemName:卸载成功" | tee -a uninstallLog
		fi
		success="true"
}

uninstallFile "$1"
rm -rf /usr/local/vap
