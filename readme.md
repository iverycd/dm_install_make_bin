# 达梦bin包一键安装

## 一、特性
* 安装前会自动检测达梦实例进程(`dmserver`)是否在运行，如有自动退出安装，如果`/home/dmdba/dmdbms/bin/dmserver`存在也会自动退出安装
* 自动修改/etc/security/limits.conf文件，增加达梦用户的资源限制
* 自动创建达梦用户以及用户组
* 安装时参数，大小写不敏感，UTF8字符集，EXTENT_SIZE：16k，PAGE_SIZE：32k，LENGTH_IN_CHAR：0，默认端口5236
* 安装后数据目录在/data/DAMENG目录，归档日志在/data/arch，物理备份在/data/dmbak
* bin包安装后自动开启物理备份任务（周六01点开始全备，其余每天01点开始增量备份，备份保留7天，自动删除7天前的归档日志）
* 安装后随机生成SYSDBA密码

## 二、准备
将原厂bin包放到dm_all_in_one目录，如果是x86的重命名为DMInstall_x86.bin,如果是arm的重命名为DMInstall_arm.bin

## 三、生成bin包
x86环境
```bash
清理x86的环境
make -f Makefile-x86 clean
生成x86环境的bin包
make -f Makefile-x86
```



arm环境
```bash
清理arm的环境
make -f Makefile-arm clean
生成arm环境的bin包
make -f Makefile-arm
```

以上执行make之后bin包生成目录在TargetBin

## 四、如何运行
使用root账号上传到任意目录比如/opt然后执行sh bin包文件名称
例如：sh dm_arm_20231226_INSTALL_2025-07-30_11-12-15.bin


```bash
[root@centos79 ~]# cd /opt/
[root@centos79 opt]# ll
total 908604
-rw-r--r--. 1 root root 930409768 Jul 30 11:07 dm_x86_20240115_INSTALL_2025-07-30_11-07-38.bin
[root@centos79 opt]# sh dm_x86_20240115_INSTALL_2025-07-30_11-07-38.bin 
 ____  __  __   ___ _   _ ____ _____  _    _     _     
|  _ \|  \/  | |_ _| \ | / ___|_   _|/ \  | |   | |    
| | | | |\/| |  | ||  \| \___ \ | | / _ \ | |   | |    
| |_| | |  | |  | || |\  |___) || |/ ___ \| |___| |___ 
|____/|_|  |_| |___|_| \_|____/ |_/_/   \_\_____|_____|
                                                       
dm_all_in_one/DMInstall_x86.bin
dminstall.xml 文件已成功生成。
dmdba 用户创建成功
添加资源限制: dmdba soft nproc 10240
添加资源限制: dmdba hard nproc 10240
添加资源限制: dmdba soft nofile 65536
添加资源限制: dmdba hard nofile 65536
添加资源限制: dmdba hard data unlimited
添加资源限制: dmdba soft data unlimited
添加资源限制: dmdba hard fsize unlimited
添加资源限制: dmdba soft fsize unlimited
添加资源限制: dmdba soft core unlimited
添加资源限制: dmdba hard core unlimited
开始安装达梦数据库...
Extract install files......... 
2025-07-30 11:09:27 
[INFO] Installing DM DBMS...
2025-07-30 11:09:28 
[INFO] Installing BASE Module...
2025-07-30 11:09:30 
[INFO] Installing SERVER Module...
2025-07-30 11:09:30 
[INFO] Installing CLIENT Module...
2025-07-30 11:09:31 
[INFO] Installing DRIVERS Module...
2025-07-30 11:09:31 
[INFO] Installing MANUAL Module...
2025-07-30 11:09:31 
[INFO] Installing SERVICE Module...
2025-07-30 11:09:32 
[INFO] Move log file to log directory.
2025-07-30 11:09:32 
[INFO] Starting DmAPService service...
2025-07-30 11:09:32 
[INFO] Start DmAPService service successfully.
2025-07-30 11:09:32 
[INFO] Installed DM DBMS completely.
2025-07-30 11:09:36 
[INFO] Creating database...
2025-07-30 11:09:39 
[INFO] Create database completed.
2025-07-30 11:09:39 
[INFO] Creating database service...
2025-07-30 11:09:39 
[INFO] Create database service completed.
2025-07-30 11:09:39 
[INFO] Starting the database service(DmServiceDMSERVER)...
2025-07-30 11:09:54 
[INFO] Start the database service(DmServiceDMSERVER) success.
数据库安装成功
检查达梦数据库进程状态...
达梦数据库进程正在运行
进程详情:
dmdba      4227      1 15 11:09 ?        00:00:02 /home/dmdba/dmdbms/bin/dmserver path=/data/DAMENG/dm.ini -noconsole





检查并配置数据库归档模式...
查询当前归档模式状态...
数据库未启用归档模式，开始配置...

Server[localhost:5236]:mode is normal, state is open
login used time : 2.096(ms)
disql V8
SQL> executed successfully
used time: 0.745(ms). Execute id is 0.
SQL> executed successfully
used time: 0.411(ms). Execute id is 0.
SQL> executed successfully
used time: 2.148(ms). Execute id is 0.
SQL> executed successfully
used time: 3.004(ms). Execute id is 0.
SQL> 数据库归档模式配置完成

Server[localhost:5236]:mode is normal, state is open
login used time : 2.002(ms)
disql V8
SQL> DMSQL executed successfully
used time: 89.845(ms). Execute id is 63001.
SQL>         call SP_DROP_JOB('full_bak');
[-8412]:Job not exists.
used time: 0.823(ms). Execute id is 0.
SQL> DMSQL executed successfully
used time: 0.836(ms). Execute id is 63003.
SQL> DMSQL executed successfully
used time: 0.395(ms). Execute id is 63004.
SQL> DMSQL executed successfully
used time: 0.708(ms). Execute id is 63005.
SQL> DMSQL executed successfully
used time: 0.766(ms). Execute id is 63006.
SQL> DMSQL executed successfully
used time: 2.349(ms). Execute id is 63007.
SQL>         call SP_DROP_JOB('incr_bak');
[-8412]:Job not exists.
used time: 0.695(ms). Execute id is 0.
SQL> DMSQL executed successfully
used time: 0.838(ms). Execute id is 63009.
SQL> DMSQL executed successfully
used time: 0.384(ms). Execute id is 63010.
SQL> DMSQL executed successfully
used time: 0.718(ms). Execute id is 63011.
SQL> DMSQL executed successfully
used time: 0.871(ms). Execute id is 63012.
SQL> DMSQL executed successfully
used time: 2.421(ms). Execute id is 63013.
SQL>         call SP_DROP_JOB('remove_bak');
[-8412]:Job not exists.
used time: 0.634(ms). Execute id is 0.
SQL> DMSQL executed successfully
used time: 0.838(ms). Execute id is 63015.
SQL> DMSQL executed successfully
used time: 0.401(ms). Execute id is 63016.
SQL> DMSQL executed successfully
used time: 0.747(ms). Execute id is 63017.
SQL> DMSQL executed successfully
used time: 1.235(ms). Execute id is 63018.
SQL> DMSQL executed successfully
used time: 2.606(ms). Execute id is 63019.
SQL>         call SP_DROP_JOB('JOB_DEL_ARCH_TIMELY');
[-8412]:Job not exists.
used time: 0.673(ms). Execute id is 0.
SQL> DMSQL executed successfully
used time: 0.924(ms). Execute id is 63021.
SQL> DMSQL executed successfully
used time: 0.373(ms). Execute id is 63022.
SQL> DMSQL executed successfully
used time: 0.678(ms). Execute id is 63023.
SQL> DMSQL executed successfully
used time: 0.910(ms). Execute id is 63024.
SQL> DMSQL executed successfully
used time: 2.312(ms). Execute id is 63025.
SQL> 如果创建备份任务失败，请手动执行以下命令:
/home/dmdba/dmdbms/bin/disql SYSDBA/SYSDBA@localhost:5236 < /tmp/create_job.sql
正在生成随机密码...
等待数据库启动...
正在修改SYSDBA用户密码...

Server[localhost:5236]:mode is normal, state is open
login used time : 2.856(ms)
disql V8
SQL> executed successfully
used time: 2.723(ms). Execute id is 63101.
SQL> SYSDBA用户密码修改成功
生成的随机密码: .Y7Z4_TwLYH8_Ep0
请务必记录此密码，它将用于SYSDBA用户登录
请按照顺序执行如下命令:
source /root/.bash_profile
disql SYSDBA/.Y7Z4_TwLYH8_Ep0@localhost:5236
```
