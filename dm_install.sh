#!/bin/bash
######################################################
#
#Install the dm ALL IN ONE
#
#
######################################################
#setenforce 0
#sed  -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
#sed  -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
COPY='/usr/bin/cp'
if [[ ! -f ${COPY} ]];then
    COPY='/bin/cp'
fi
# 未指定输入参数时候的默认值
port="6379"
pass="Infra5@Gep0int"
target_ip=

# bin包分离出tar包的转储的临时目录
installfilepath=/tmp/dmtmp
mkdir -p ${installfilepath}
# 从bin包分离出来重定向的tar包名称
INSTALL_TAG_GZ=dm_install_content
# 从上面重定向的tar包解压之后，指定应用的数据所在目录
dm_untar_dir=/opt
dm_root_dir=$dm_untar_dir/dm_all_in_one
mkdir -p ${dm_root_dir}

function init_env()
{
# 统一安装包名称
mv $dm_root_dir/DMInstall_*.bin $dm_root_dir/DMInstall.bin
# 检查用户组是否存在，避免使用黑名单命令 groupadd
if grep -q '^dinstall:' /etc/group; then
    echo_color yellow bold "警告: dinstall 用户组已存在，跳过创建"
    # read -p "按 Enter 键继续..."
else
    groupadd dinstall
fi

# 检查用户是否存在
if ! id -u dmdba >/dev/null 2>&1; then
    # 用户不存在，创建用户
    if ! useradd -g dinstall -m -d /home/dmdba -s /bin/bash dmdba; then
        echo_color red invert "创建 dmdba 用户失败"
        exit 1
    fi
    echo_color green bold "dmdba 用户创建成功"
else
    echo_color yellow bold "dmdba 用户已存在，跳过创建"
fi

# 配置资源限制，避免重复添加
LIMITS_FILE="/etc/security/limits.conf"
limits_conf=("dmdba soft nproc 10240"
             "dmdba hard nproc 10240"
             "dmdba soft nofile 65536"
             "dmdba hard nofile 65536"
             "dmdba hard data unlimited"
             "dmdba soft data unlimited"
             "dmdba hard fsize unlimited"
             "dmdba soft fsize unlimited"
             "dmdba soft core unlimited"
             "dmdba hard core unlimited")

for limit in "${limits_conf[@]}"; do
    if ! grep -qxF "$limit" "$LIMITS_FILE"; then
        echo "$limit" >> "$LIMITS_FILE"
        echo_color green bold "添加资源限制: $limit"
    else
        echo_color yellow bold "资源限制已存在: $limit"
    fi
 done

export LANG=en_US
chown dmdba:dinstall $dm_root_dir/DMInstall.bin
chmod +x $dm_root_dir/DMInstall.bin
# 创建达梦数据文件目录
mkdir /data
chown -R dmdba:dinstall /data
}

function init_xml()
{
# 定义要输出的XML内容
xml_content='<?xml version="1.0"?>
<DATABASE>

<LANGUAGE>en</LANGUAGE>

<TIME_ZONE>+08:00</TIME_ZONE>

<KEY></KEY>

<INSTALL_TYPE>0</INSTALL_TYPE>

<INSTALL_PATH>/home/dmdba/dmdbms</INSTALL_PATH>

<INIT_DB>y</INIT_DB>

<DB_PARAMS>

<PATH>/data</PATH>

<DB_NAME>DAMENG</DB_NAME>

<INSTANCE_NAME>DMSERVER</INSTANCE_NAME>
<PORT_NUM>5236</PORT_NUM>

<CTL_PATH></CTL_PATH>

<LOG_PATHS>
<LOG_PATH>
</LOG_PATH>
</LOG_PATHS>

<EXTENT_SIZE>16</EXTENT_SIZE>

<PAGE_SIZE>32</PAGE_SIZE>

<LOG_SIZE>2048</LOG_SIZE>

<CASE_SENSITIVE>N</CASE_SENSITIVE>

<CHARSET>1</CHARSET>

<LENGTH_IN_CHAR>0</LENGTH_IN_CHAR>

<USE_NEW_HASH>1</USE_NEW_HASH>

<SYSDBA_PWD></SYSDBA_PWD>

<SYSAUDITOR_PWD></SYSAUDITOR_PWD>

<SYSSSO_PWD></SYSSSO_PWD>

<SYSDBO_PWD></SYSDBO_PWD>

<TIME_ZONE>+08:00</TIME_ZONE>

<PAGE_CHECK>0</PAGE_CHECK>

<EXTERNAL_CIPHER_NAME></EXTERNAL_CIPHER_NAME>

<EXTERNAL_HASH_NAME></EXTERNAL_HASH_NAME>

<EXTERNAL_CRYPTO_NAME></EXTERNAL_CRYPTO_NAME>

<ENCRYPT_NAME></ENCRYPT_NAME>

<RLOG_ENC_FLAG>N</RLOG_ENC_FLAG>

<USBKEY_PIN></USBKEY_PIN>

<BLANK_PAD_MODE>0</BLANK_PAD_MODE>

<SYSTEM_MIRROR_PATH></SYSTEM_MIRROR_PATH>

<MAIN_MIRROR_PATH></MAIN_MIRROR_PATH>

<ROLL_MIRROR_PATH></ROLL_MIRROR_PATH>

<PRIV_FLAG>0</PRIV_FLAG>

<ELOG_PATH></ELOG_PATH>
</DB_PARAMS>

<CREATE_DB_SERVICE>Y</CREATE_DB_SERVICE>

<STARTUP_DB_SERVICE>Y</STARTUP_DB_SERVICE>
</DATABASE>'

# 输出XML内容到dminstall.xml文件
echo "$xml_content" > $dm_root_dir/dminstall.xml

# 检查文件是否成功创建
if [ -f $dm_root_dir/dminstall.xml ]; then
    echo_color green bold "dminstall.xml 文件已成功生成。"
else
    echo_color red invert "生成 dminstall.xml 文件时出错。"
fi
}

function unzipfile()
{
    split_num=`cat -n $0  | grep --text  '\---------ARCHIVE_FOLLOWS---------'| grep -v "split_num" |awk '{printf $1}' `
    tail -n  +$(($split_num+1)) $0  > ${installfilepath}/${INSTALL_TAG_GZ}.tar.gz
    # 执行解压命令
    if ! tar -zxvf "${installfilepath}/${INSTALL_TAG_GZ}.tar.gz" -C "${dm_untar_dir}"; then
        echo_color red invert "tar ${INSTALL_TAG_GZ}.tar.gz failed"
        exit 1
    fi
}
#OS_Version=$(cat /etc/redhat-release | awk '{$NF="";print}')
function echo_color()
{   
    nn=""
    case "$1" in
        red)    nn="31";;
        green)  nn="32";;
        yellow) nn="33";;
        blue)   nn="34";;
        purple) nn="35";;
        cyan)   nn="36";;
    esac
    ff=""
    case "$2" in
        bold)   ff=";1";;
        bright) ff=";2";;
        uscore) ff=";4";;
        blink)  ff=";5";;
        invert) ff=";7";;
    esac
    color_begin=`echo -e -n "\033[${nn}${ff}m"`
    color_end=`echo -e -n "\033[0m"`
    echo $4 "${color_begin}$3${color_end}"
}

function check_dm_run()
{
    # 检查达梦数据库进程是否在运行
    DM_PROCESS=$(ps -ef | grep dmserver | grep -v grep)
    if [ -n "$DM_PROCESS" ]; then
        echo_color green bold "达梦数据库已存在，退出安装"
        echo "进程详情:"
        echo "$DM_PROCESS"
        exit 1
    fi
}

function print_info() {
  # 输出DM INSTALL
  echo -e "$(echo 'IF9fX18gIF9fICBfXyAgIF9fXyBfICAgXyBfX19fIF9fX19fICBfICAgIF8gICAgIF8gICAgIAp8ICBfIFx8ICBcLyAgfCB8XyBffCBcIHwgLyBfX198XyAgIF98LyBcICB8IHwgICB8IHwgICAgCnwgfCB8IHwgfFwvfCB8ICB8IHx8ICBcfCBcX19fIFwgfCB8IC8gXyBcIHwgfCAgIHwgfCAgICAKfCB8X3wgfCB8ICB8IHwgIHwgfHwgfFwgIHxfX18pIHx8IHwvIF9fXyBcfCB8X19ffCB8X19fIAp8X19fXy98X3wgIHxffCB8X19ffF98IFxffF9fX18vIHxfL18vICAgXF9cX19fX198X19fX198CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAK' | base64 -d)"
}

function install_dm()
{
    # 执行数据库安装命令
    echo_color blue bold "开始安装达梦数据库..."
    sh $dm_root_dir/DMInstall.bin -q $dm_root_dir/dminstall.xml

    # 检查安装是否成功
    if [ $? -ne 0 ]; then
        echo_color red bold "数据库安装失败!"
        echo_color red "请检查安装日志或参数配置后重试"
        exit 1
    else
        echo_color green bold "数据库安装成功"
    fi
}


function check_install()
{
    # 检查达梦数据库进程是否在运行
    echo_color blue bold "检查达梦数据库进程状态..."
    DM_PROCESS=$(ps -ef | grep dmserver | grep -v grep)
    if [ -n "$DM_PROCESS" ]; then
        echo_color green bold "达梦数据库进程正在运行"
        echo "进程详情:"
        echo "$DM_PROCESS"
    else
        echo_color red bold "错误: 未检测到达梦数据库进程"
        echo_color yellow bold "请检查数据库安装和启动日志"
        exit 1
    fi
}

function add_run_env()
{
    # 定义环境变量和路径
    DM_BIN_PATH="/home/dmdba/dmdbms/bin"
    changed=0

    # 为root用户添加环境变量
    if [ "$(id -u)" -eq 0 ]; then
        ROOT_PROFILE="/root/.bash_profile"
        # 检查并添加root用户的PATH
        if ! grep -qxF "export PATH=\$PATH:$DM_BIN_PATH" "$ROOT_PROFILE"; then
            echo "export PATH=\$PATH:$DM_BIN_PATH" >> "$ROOT_PROFILE"
            echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:$DM_BIN_PATH" >> "$ROOT_PROFILE"
            changed=1
            echo_color blue "已为root用户添加环境变量"
        fi
    fi

    # 为dmdba用户添加环境变量
    DMDBA_PROFILE="/home/dmdba/.bash_profile"
    # 确保dmdba主目录存在并设置正确权限
    if [ ! -d "/home/dmdba" ]; then
        mkdir -p /home/dmdba
        chown dmdba:dinstall /home/dmdba
    fi

    # 检查并添加dmdba用户的环境变量
    if ! grep -qxF "export PATH=\$PATH:$DM_BIN_PATH" "$DMDBA_PROFILE"; then
        # 使用sudo以dmdba用户身份写入文件
        sudo -u dmdba bash -c "echo 'export PATH=\\$PATH:$DM_BIN_PATH' >> '$DMDBA_PROFILE'"
        sudo -u dmdba bash -c "echo 'export LD_LIBRARY_PATH=\\$LD_LIBRARY_PATH:$DM_BIN_PATH' >> '$DMDBA_PROFILE'"
        changed=1
        echo_color blue "已为dmdba用户添加环境变量"
    fi

    # 提示用户环境变量生效方法
    if [ $changed -eq 1 ]; then
        echo_color green "环境变量已更新"
        echo_color yellow "注意：root用户需执行 'source /root/.bash_profile' 使环境变量生效"
        echo_color yellow "dmdba用户需执行 'sudo -u dmdba -i source ~/.bash_profile' 使环境变量生效"
    else
        echo_color green "环境变量已存在，无需更新"
    fi
    source /root/.bash_profile
}

function enable_arch()
{
    source /root/.bash_profile
    echo_color blue bold "检查并配置数据库归档模式..."
    # 查询当前归档模式
    echo_color blue bold "查询当前归档模式状态..."
    arch_mode=$(disql -S SYSDBA/SYSDBA@localhost:5236 -e "select arch_mode from v\$database;" | tail -n 1)
    if [ "$arch_mode" = "Y" ]; then
        echo_color green bold "数据库已启用归档模式，无需配置"
    else
        echo_color blue bold "数据库未启用归档模式，开始配置..."
         mkdir -p /data/arch
         chown -R dmdba:dinstall /data/arch
        /home/dmdba/dmdbms/bin/disql SYSDBA/SYSDBA@localhost:5236 << EOF
    alter database mount;
    alter database add archivelog 'dest=/data/arch,TYPE=local,FILE_SIZE=1024,SPACE_LIMIT=0';
    alter database archivelog;
    alter database open;
    exit;
EOF
    echo_color green bold "数据库归档模式配置完成"
    fi
}


function create_backup_job()
{
     mkdir -p /data/dmbak
     chown -R dmdba:dinstall /data/
     # 开启归档

     /home/dmdba/dmdbms/bin/disql SYSDBA/SYSDBA@localhost:5236 << EOF
        call SP_INIT_JOB_SYS(1);
        call SP_DROP_JOB('full_bak');
        call SP_CREATE_JOB('full_bak',1,0,'',0,0,'',0,'');
        call SP_JOB_CONFIG_START('full_bak');
        call SP_ADD_JOB_STEP('full_bak', 'full_bak', 6, '00000000/data/dmbak', 0, 0, 0, 0, NULL, 0);
        call SP_ADD_JOB_SCHEDULE('full_bak', 'full_bak', 1, 2, 1, 64, 0, '01:00:00', NULL, '2000-01-01 15:17:07', NULL, '');
        call SP_JOB_CONFIG_COMMIT('full_bak');
        call SP_DROP_JOB('incr_bak');
        call SP_CREATE_JOB('incr_bak',1,0,'',0,0,'',0,'');
        call SP_JOB_CONFIG_START('incr_bak');
        call SP_ADD_JOB_STEP('incr_bak', 'incr_bak', 6, '10000000/data/dmbak|/data/dmbak', 0, 0, 0, 0, NULL, 0);
        call SP_ADD_JOB_SCHEDULE('incr_bak', 'incr_bak', 1, 2, 1, 63, 0, '01:00:00', NULL, '2000-01-01 15:22:35', NULL, '');
        call SP_JOB_CONFIG_COMMIT('incr_bak');
        call SP_DROP_JOB('remove_bak');
        call SP_CREATE_JOB('remove_bak',1,0,'',0,0,'',0,'');
        call SP_JOB_CONFIG_START('remove_bak');
        call SP_ADD_JOB_STEP('remove_bak', 'remove_bak', 0, 'call sf_bakset_backup_dir_add(''DISK'',''/data/dmbak'');call sp_db_bakset_remove_batch(''DISK'',now()-7);', 0, 0, 0, 0, NULL, 0);
        call SP_ADD_JOB_SCHEDULE('remove_bak', 'remove_bak', 1, 1, 1, 0, 0, '20:00:00', NULL, '2000-01-01 15:38:32', NULL, '');
        call SP_JOB_CONFIG_COMMIT('remove_bak');
        call SP_DROP_JOB('JOB_DEL_ARCH_TIMELY');
        call SP_CREATE_JOB('JOB_DEL_ARCH_TIMELY',1,0,'',0,0,'',0,'定时删除备份');
        call SP_JOB_CONFIG_START('JOB_DEL_ARCH_TIMELY');
        call SP_ADD_JOB_STEP('JOB_DEL_ARCH_TIMELY', 'STEP_DEL_ARCH', 0, 'SF_ARCHIVELOG_DELETE_BEFORE_TIME(SYSDATE - 7);', 1, 2, 0, 0, NULL, 0);
        call SP_ADD_JOB_SCHEDULE('JOB_DEL_ARCH_TIMELY', 'SCHEDULE_DEL_ARCH', 1, 1, 1, 0, 0, '20:00:00', NULL, '2020-03-20 21:05:57', NULL, '');
        call SP_JOB_CONFIG_COMMIT('JOB_DEL_ARCH_TIMELY');
        exit;
EOF
    cat > /tmp/create_job.sql << 'EOF'
call SP_INIT_JOB_SYS(1);
call SP_DROP_JOB('full_bak');
call SP_CREATE_JOB('full_bak',1,0,'',0,0,'',0,'');
call SP_JOB_CONFIG_START('full_bak');
call SP_ADD_JOB_STEP('full_bak', 'full_bak', 6, '00000000/data/dmbak', 0, 0, 0, 0, NULL, 0);
call SP_ADD_JOB_SCHEDULE('full_bak', 'full_bak', 1, 2, 1, 64, 0, '01:00:00', NULL, '2000-01-01 15:17:07', NULL, '');
call SP_JOB_CONFIG_COMMIT('full_bak');
call SP_DROP_JOB('incr_bak');
call SP_CREATE_JOB('incr_bak',1,0,'',0,0,'',0,'');
call SP_JOB_CONFIG_START('incr_bak');
call SP_ADD_JOB_STEP('incr_bak', 'incr_bak', 6, '10000000/data/dmbak|/data/dmbak', 0, 0, 0, 0, NULL, 0);
call SP_ADD_JOB_SCHEDULE('incr_bak', 'incr_bak', 1, 2, 1, 63, 0, '01:00:00', NULL, '2000-01-01 15:22:35', NULL, '');
call SP_JOB_CONFIG_COMMIT('incr_bak');
call SP_DROP_JOB('remove_bak');
call SP_CREATE_JOB('remove_bak',1,0,'',0,0,'',0,'');
call SP_JOB_CONFIG_START('remove_bak');
call SP_ADD_JOB_STEP('remove_bak', 'remove_bak', 0, 'call sf_bakset_backup_dir_add(''DISK'',''/data/dmbak'');call sp_db_bakset_remove_batch(''DISK'',now()-7);', 0, 0, 0, 0, NULL, 0);
call SP_ADD_JOB_SCHEDULE('remove_bak', 'remove_bak', 1, 1, 1, 0, 0, '20:00:00', NULL, '2000-01-01 15:38:32', NULL, '');
call SP_JOB_CONFIG_COMMIT('remove_bak');
call SP_DROP_JOB('JOB_DEL_ARCH_TIMELY');
call SP_CREATE_JOB('JOB_DEL_ARCH_TIMELY',1,0,'',0,0,'',0,'定时删除备份');
call SP_JOB_CONFIG_START('JOB_DEL_ARCH_TIMELY');
call SP_ADD_JOB_STEP('JOB_DEL_ARCH_TIMELY', 'STEP_DEL_ARCH', 0, 'SF_ARCHIVELOG_DELETE_BEFORE_TIME(SYSDATE - 7);', 1, 2, 0, 0, NULL, 0);
call SP_ADD_JOB_SCHEDULE('JOB_DEL_ARCH_TIMELY', 'SCHEDULE_DEL_ARCH', 1, 1, 1, 0, 0, '20:00:00', NULL, '2020-03-20 21:05:57', NULL, '');
call SP_JOB_CONFIG_COMMIT('JOB_DEL_ARCH_TIMELY');
EOF
   echo_color green bold "如果创建备份任务失败，请手动执行以下命令:"
   echo_color green bold "/home/dmdba/dmdbms/bin/disql SYSDBA/SYSDBA@localhost:5236 < /tmp/create_job.sql"
}

function change_pwd() {
    # 使用用户指定的命令生成随机密码
    echo_color blue bold "正在生成随机密码..."
    export new_password=$(</dev/urandom tr -dc '0123456789_,.abcde_,.fghij_,.klmnopq_,.rstuvwxyz_,.ABCDEF_,.GHIJKLMN_,.OPQRST_,.UVWXYZ' | head -c12 ;echo | sed 's/$/_Ep0/g')
    
    # 等待数据库完全启动
    echo_color blue bold "等待数据库启动..."
    sleep 15
    
    # 使用disql修改SYSDBA密码
    echo_color blue bold "正在修改SYSDBA用户密码..."
    /home/dmdba/dmdbms/bin/disql SYSDBA/SYSDBA@localhost:5236 << EOF
    ALTER USER SYSDBA IDENTIFIED BY "$new_password";
    exit;
EOF
    
    # 检查密码修改是否成功
    if [ $? -eq 0 ]; then
        echo_color green bold "SYSDBA用户密码修改成功"
    else
        echo_color red bold "SYSDBA用户密码修改失败"
        echo_color yellow bold "请手动使用以下命令修改密码:"
        echo_color yellow bold "/home/dmdba/dmdbms/bin/disql SYSDBA/SYSDBA@localhost:5236 \"ALTER USER SYSDBA IDENTIFIED BY \"$new_password\"\""
    fi

    # 显示生成的密码（注意保密）
    echo_color green bold "生成的随机密码: $new_password"
    echo_color yellow bold "请务必记录此密码，它将用于SYSDBA用户登录"
    echo_color yellow bold "请按照顺序执行如下命令:"
    echo_color yellow bold "source /root/.bash_profile"
    echo_color yellow bold "disql SYSDBA/$new_password@localhost:5236"
}

##############main process##################
while getopts "p:a:t:h" arg
do
    case $arg in
    p)
        echo "you will install the redis and the port while be use $OPTARG"
        port=$OPTARG
        ;;
    a)
        echo "we will set the redis pass $OPTARG"
        pass=$OPTARG
        ;;
    t)
            echo "we will set the target ip $OPTARG"
            target_ip=$OPTARG
            ;;
    h)
        echo -en "you can use follow options: \n"\
             "-p [default 6379]  set the redis port; \n"\
             "-a [default Gepoint] set the redis pass; \n"\
             "-t set the dm server ip; \n"\
             "-h Help \n"
        exit 1
        ;;
    ?)
        echo -en "unknow args,you can use '-h' show all options \n"
        exit 1
        ;;
    esac
done
# if [ -z "$target_ip" ]; then
#   echo "you must specified -t argument ,example -t 192.168.1.100"
#   exit 1
# fi
print_info
check_dm_run
unzipfile
init_xml
init_env
install_dm
check_install
add_run_env
enable_arch
create_backup_job
change_pwd
exit
---------ARCHIVE_FOLLOWS---------
