# tools
执行如下操作：
1. 生成安装包
```
sh tool.sh module.json 
```
2. 执行安装包
sh iteminstall.sh jsoc.json conf.properties  (前提先编辑好conf.properties)
或者
sh iteminstall jsoc.json 

### 一键安装脚本
 1. 修复rabbit中的deluser admin删除失败，在失败时判断是否存在用户，修改rabbit文件夹下的rabbit.json的修改
 2. 增加application.sh的内存限制，使用memconf.properties的键值对进行限制
 3. 移除module.json中定义，采用cloud.json默认进行打包，module.json中不在定义
   ```
    {
      "name": "cloud.json",
      "desc": "cloud模块安装固定,不可更改",
      "type": "modulejson"
    }
    ```
 4. 修复jsoc.json中的先后顺序执行过程，执行base > db > nacos > ... > cloud
 5. 支持conf.properties的配置系统参数，如果配置了采用配置参数进行安装，没有配置则采用原有的界面输入模式进行安装
    支持sh itemintall.sh jsoc.json conf.properties ， 支持sh itemintall.sh jsoc.json
 6. 修复nacos.service的shutdown.sh的不存在，出现重启后nacos无法启动，修改/usr/lib/systemd/system/nacos.service，把nacos-1.0.zip中的nacos.service版本变更
 7. 修复nacos的启动顺序，api-admin.service的启动需要依赖nacos.service服务，增加after服务配置
	echo "After=nacos.service" >>$serviceitem   #<== nacos.service需要先启动，且是required
	echo "Requires=nacos.service" >>$serviceitem #<== 必须依赖nacos.service
	Restart=on-failure
 8. 修复reboot后nacos无法启动，数据库连接不上问题，修改nacos.service的	
 9. 修复redis-1.1的redis的卸载，service未卸载（1.0已修复，1.1未修复）


	



