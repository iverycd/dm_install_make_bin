#!/bin/bash
######################################################
#
#Install the dm ALL IN ONE
#
#
######################################################

COPY='/usr/bin/cp'
if [[ ! -f ${COPY} ]];then
    COPY='/bin/cp'
fi
export LANG=en_US.UTF-8

# 数据库连接参数
dm_user_default="SYSDBA"          # 改密码之前的默认数据库用户名
dm_password_default="SYSDBA_sysdba_123"  # 改密码之前的数据库默认密码
dm_host_default="localhost"        # 数据库主机
dm_port_default="5236"             # 默认数据库端口
dm_bin_default="/home/dmdba/dmdbms/bin" # 默认达梦bin目录
dm_disql_path_default="/home/dmdba/dmdbms/bin/disql"  # 默认disql工具路径
dm_data_dir_default="/data" # 默认数据库数据目录
backup_keep_time_day=7             # 备份保留时间，单位天
dm_backup_dir_default="/dm_backup"    # 默认备份根目录

# bin包分离出tar包的转储的临时目录
installfilepath=/tmp/dmtmp
mkdir -p ${installfilepath}
# 从bin包分离出来重定向的tar包名称
INSTALL_TAG_GZ=dm_install_content
# 从上面重定向的tar包解压之后，指定应用的数据所在目录
dm_untar_dir=/opt
dm_root_dir=$dm_untar_dir/dm_all_in_one
mkdir -p ${dm_root_dir}


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


# 检查bin包运行时的输入参数
function check_bin_arguments() {
    # 检查指定的达梦安装包是否存在,如果-t指定自定义安装包，对文件进行检查，分别对iso以及bin文件做不同处理
    if [ ! -z "$target_version" ]; then
        # 检查文件是否存在
        if [ -f "$target_version" ]; then
            echo_color green bold "文件存在: $target_version"
            # 在指定-t参数之后，必须显示指定-l参数，否则直接退出程序
            if [ -z "$length_in_char" ]; then
                echo_color red invert "错误: 指定-t参数之后,必须指定-l参数,比如-l 0或者-l 1"
                echo_color red invert "注意: 2024年6月及之后的版本只能指定-l值为0否则安装会失败"
                exit 1
            else
                echo_color green bold "使用的length_in_char参数值: $length_in_char"
                # 判断下length_in_char的值只能是数字0或者数字1
                if [ "$length_in_char" != "0" ] && [ "$length_in_char" != "1" ]; then
                    echo_color red invert "错误: length_in_char参数值只能是数字0或者数字1"
                    exit 1
                fi
            fi
            # 检查文件后缀
            if [[ "$target_version" == *.iso ]]; then
                echo_color yellow bold "检测到ISO文件，准备挂载..."
                # 执行挂载命令
                if mount -o loop "$target_version" /mnt; then
                    echo_color green bold "ISO文件已成功挂载到/mnt"
                    cp /mnt/DMInstall.bin $dm_root_dir/
                    umount /mnt
                else
                    echo_color red invert "错误: 挂载ISO文件失败"
                    exit 1
                fi
            elif [[ "$target_version" == *.bin ]]; then
                echo_color yellow bold "检测到BIN文件，准备移动..."
                # 执行移动命令
                if mv "$target_version" "$dm_root_dir/DMInstall.bin"; then
                    echo_color green bold "BIN文件已成功移动到 $dm_root_dir/DMInstall.bin"
                else
                    echo_color red invert "错误: 移动BIN文件失败"
                    exit 1
                fi
            else
                echo_color red invert "错误: 不支持的文件格式: $target_version"
                exit 1
            fi
        else
            echo_color red invert "错误: 文件不存在或不是常规文件: $target_version"
            exit 1
        fi
    fi

    # 检查数据库数据目录部分 没有指定-d参数，设置数据库默认数据目录
    if [ -z "$dm_data_dir" ]; then
        dm_data_dir=$dm_data_dir_default
    else
        # 检查路径结尾是否包含斜杠
        if [[ "$dm_data_dir" == */ ]]; then
            echo_color red invert "错误: 数据目录路径 '$dm_data_dir' 不规范，结尾不能包含斜杠" >&2
            exit 1
        fi
        # 检查数据目录是否存在
        if [ -d "$dm_data_dir" ]; then
            echo_color green bold "使用的数据目录路径: $dm_data_dir"
        else
            echo_color red invert "错误: 数据目录 '$dm_data_dir' 不存在"
            exit 1
        fi
    fi

    # 检查数据库备份目录部分 没有指定-b参数，设置数据库默认备份目录
    if [ -z "$dm_backup_root_dir" ]; then
        dm_backup_root_dir=$dm_backup_dir_default
    else
        # 检查路径结尾是否包含斜杠
        if [[ "$dm_backup_root_dir" == */ ]]; then
            echo_color red invert "错误: 备份目录路径 '$dm_backup_root_dir' 不规范，结尾不能包含斜杠" >&2
            exit 1
        fi
        # 检查备份目录是否存在
        if [ -d "$dm_backup_root_dir" ]; then
        echo_color green bold "使用的备份目录路径: $dm_backup_root_dir"
        else
        echo_color red invert "错误: 备份目录 '$dm_backup_root_dir' 不存在"
        exit 1
        fi
    fi
    dm_backup_physical_dir="$dm_backup_root_dir/physical"  # 物理备份目录
    dm_backup_logical_dir="$dm_backup_root_dir/logical"    # 逻辑备份目录

    # 检查指定的端口部分 如果dm_run_port为空，即没有指定参数-p,端口号，就使用默认端口号5236
    if [ -z "$dm_run_port" ]; then
    dm_run_port=$dm_port_default
    fi
    # 检查dm_run_port是否为纯数字
    if ! [[ "$dm_run_port" =~ ^[0-9]+$ ]]; then
        echo_color red invert "错误: 指定的端口号 '$dm_run_port' 不是有效的数字" >&2
        echo_color red invert "请使用 -p 参数指定有效的数字端口号" >&2
        exit 1
    fi

    # 检查数据库兼容参数部分 设置数据库兼容模式
    case "$dm_compatible_mode" in
        "oracle_mode")
            # 如果指定为oracle_mode或未指定参数，默认使用oracle兼容模式
            dm_run_compatible_mode=2
            ;;
        "mysql_mode"|"")
            # 如果指定为mysql_mode或未指定参数，默认使用mysql兼容模式
            dm_run_compatible_mode=4
            ;;
        *)
            # 未知的兼容模式，默认使用mysql兼容模式
            echo_color red invert "错误: 未知的兼容模式 '$dm_compatible_mode',请指定oracle_mode或mysql_mode"
            exit 1
            ;;
    esac
}

function init_env()
{
# 如果没有指定-t参数，即没有指定特定安装包
if [ -z "$target_version" ]; then
# 统一安装包名称
mv $dm_root_dir/DMInstall_*.bin $dm_root_dir/DMInstall.bin
fi

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
mkdir $dm_data_dir
chown -R dmdba:dinstall $dm_data_dir
}

function init_xml()
{
col_length_in_char="<LENGTH_IN_CHAR>1</LENGTH_IN_CHAR>"
# 如果length_in_char为0，那么col_length_in_char就为空
if [ "$length_in_char" = "0" ]; then
    col_length_in_char=""
fi
# 输出XML内容到dminstall.xml文件
cat > $dm_root_dir/dminstall.xml << EOF
<?xml version="1.0"?>
<DATABASE>

<LANGUAGE>en</LANGUAGE>

<TIME_ZONE>+08:00</TIME_ZONE>

<KEY></KEY>

<INSTALL_TYPE>0</INSTALL_TYPE>

<INSTALL_PATH>/home/dmdba/dmdbms</INSTALL_PATH>

<INIT_DB>y</INIT_DB>

<DB_PARAMS>

<PATH>$dm_data_dir</PATH>

<DB_NAME>DAMENG</DB_NAME>

<INSTANCE_NAME>DMSERVER</INSTANCE_NAME>
<PORT_NUM>$dm_run_port</PORT_NUM>

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

$col_length_in_char

<USE_NEW_HASH>1</USE_NEW_HASH>

<SYSDBA_PWD>$dm_password_default</SYSDBA_PWD>

<SYSAUDITOR_PWD>$dm_password_default</SYSAUDITOR_PWD>

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
</DATABASE>
EOF

# 检查文件是否成功创建
if [ -f $dm_root_dir/dminstall.xml ]; then
    echo_color green bold "dminstall.xml 文件已成功生成。"
else
    echo_color red invert "生成 dminstall.xml 文件时出错。"
fi
}

function unzipfile()
{
    # 不为空判断，即指定了-t参数，就直接返回，不运行解压
    if [ ! -z "$target_version" ]; then
    echo "你指定了自定义安装包 $target_version"
    return 1
    fi
    split_num=`cat -n $0  | grep --text  '\---------ARCHIVE_FOLLOWS---------'| grep -v "split_num" |awk '{printf $1}' `
    tail -n  +$(($split_num+1)) $0  > ${installfilepath}/${INSTALL_TAG_GZ}.tar.gz
    # 执行解压命令
    if ! tar -zxvf "${installfilepath}/${INSTALL_TAG_GZ}.tar.gz" -C "${dm_untar_dir}"; then
        echo_color red invert "tar ${INSTALL_TAG_GZ}.tar.gz failed"
        exit 1
    fi
}
#OS_Version=$(cat /etc/redhat-release | awk '{$NF="";print}')


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
    arch_mode=$($dm_disql_path_default -S $dm_user_default/$dm_password_default@$dm_host_default:$dm_run_port -e "select arch_mode from v\$database;" | tail -n 1)
    if [ "$arch_mode" = "Y" ]; then
        echo_color green bold "数据库已启用归档模式，无需配置"
    else
        echo_color blue bold "数据库未启用归档模式，开始配置..."
        mkdir -p $dm_data_dir/arch
        echo_color blue bold "打印数据目录:$dm_data_dir"
        ls -l $dm_data_dir
        chown -R dmdba:dinstall $dm_data_dir/arch
        $dm_disql_path_default $dm_user_default/$dm_password_default@$dm_host_default:$dm_run_port << EOF
alter database mount;
sp_set_para_value(1,'ARCH_INI',1);
alter database add archivelog 'dest=$dm_data_dir/arch,TYPE=local,FILE_SIZE=1024,SPACE_LIMIT=0';
alter database archivelog;
alter database open;
exit;
EOF
    echo_color green bold "数据库归档模式配置完成"
    fi
}

function auto_config()
{
source /root/.bash_profile
# 配置参数
mem_per=70          # 数据库可用内存百分比 自定义设定
v_mem_mb=0       # 初始化变量，默认内存大小(MB) 后面会根据环境自动获取
v_cpus=0             # 初始化变量 CPU核数 后面会根据环境自动获取

# 初始化变量
MEMORY_POOL=0
MEMORY_N_POOLS=0
MEMORY_TARGET=0
BUFFER=0
MAX_BUFFER=0
RECYCLE=0
CACHE_POOL_SIZE=0
BUFFER_POOLS=0
RECYCLE_POOLS=0
SORT_BUF_SIZE=0
SORT_BUF_GLOBAL_SIZE=0
DICT_BUF_SIZE=0
HJ_BUF_SIZE=0
HAGR_BUF_SIZE=0
HJ_BUF_GLOBAL_SIZE=0
HAGR_BUF_GLOBAL_SIZE=0
SORT_FLAG=0
SORT_BLK_SIZE=0
RLOG_POOL_SIZE=0
TASK_THREADS=0
IO_THR_GROUPS=0
FAST_POOL_PAGES=3000
FAST_ROLL_PAGES=1000
CNT=0


# 数据库连接参数
dm_user=$dm_user_default          # 数据库用户名
dm_password=$dm_password_default  # 数据库密码
dm_host=$dm_host_default        # 数据库主机
dm_port=$dm_run_port             # 数据库端口
dm_disql_path=$dm_disql_path_default  # disql工具路径



# 获取CPU核数
v_cpus=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || sysctl -n hw.ncpu || echo 8)
    
# 获取物理内存大小(MB)
if [ -f /proc/meminfo ]; then
    v_mem_mb=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}' || echo 8192)
else
    # 注意: sysctl命令在黑名单中，请确认是否符合安全要求
    v_mem_mb=$(sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024/1024)}' || echo 8192)
fi

# 调整内存计算
# v_mem_mb=$(echo "scale=0; $v_mem_mb * $mem_per / 100" | bc)
# 四舍五入到千位
v_mem_mb=$(echo "scale=0; $v_mem_mb / 1000 * 1000" | bc)

# 检查内存阈值
if [ $v_mem_mb -le 2000 ]; then
    echo "内存不足2000MB，退出参数调整"
    exit 0
fi

if [ $v_mem_mb -gt 512000 ]; then
    v_mem_mb=$(echo "scale=0; $v_mem_mb * 0.8" | bc)
fi

# 计算核心参数


# 设置线程参数
TASK_THREADS=4
IO_THR_GROUPS=4
if [ $v_cpus -lt 8 ]; then
    TASK_THREADS=4
    IO_THR_GROUPS=2
fi

if [ $v_cpus -ge 64 ]; then
    v_cpus=64
    TASK_THREADS=16
    IO_THR_GROUPS=8
fi

# 缓冲区参数,根据达梦给的建议是按照物理内存的60%-80%
BUFFER=$(echo "scale=0; $v_mem_mb * 0.6" | bc)
BUFFER=$(echo "scale=0; $BUFFER / 1000 * 1000" | bc)
MAX_BUFFER=$BUFFER

RECYCLE=$(echo "scale=0; $v_mem_mb * 0.04" | bc)

# 计算BUFFER_POOLS和RECYCLE_POOLS
if [ $v_mem_mb -lt 70000 ]; then
    # 查找大于v_mem_mb/800的最小质数
    calculate_pool() {
        threshold=$(echo "scale=0; $v_mem_mb / $1" | bc)
        # 简单查找质数的方法
        for ((i=threshold+1; ; i++)); do
            is_prime=1
            for ((j=2; j*j<=i; j++)); do
                if [ $((i%j)) -eq 0 ]; then
                    is_prime=0
                    break
                fi
            done
            if [ $is_prime -eq 1 ]; then
                echo $i
                break
            fi
        done
    }

    BUFFER_POOLS=$(calculate_pool 800)
    RECYCLE_POOLS=$(calculate_pool 2400)  # 800*3
else
    BUFFER_POOLS=101
    RECYCLE_POOLS=41
fi

# 计算内存池参数
if [ $v_mem_mb -ge 16000 ]; then
    if [ $v_mem_mb -eq 16000 ]; then
        MEMORY_POOL=1500
        SORT_BUF_GLOBAL_SIZE=1000
        MEMORY_N_POOLS=3
        CACHE_POOL_SIZE=512
    else
        MEMORY_POOL=2000
        SORT_BUF_GLOBAL_SIZE=2000
        MEMORY_N_POOLS=11
        CACHE_POOL_SIZE=1024
    fi

    FAST_POOL_PAGES=9999
    SORT_FLAG=0
    SORT_BLK_SIZE=1
    SORT_BUF_SIZE=10
    RLOG_POOL_SIZE=1024

    HJ_BUF_GLOBAL_SIZE=$(echo "scale=0; $v_mem_mb * 0.0625" | bc)
    HAGR_BUF_GLOBAL_SIZE=$HJ_BUF_GLOBAL_SIZE
    if [ $HJ_BUF_GLOBAL_SIZE -gt 10000 ]; then
        HJ_BUF_GLOBAL_SIZE=10000
        HAGR_BUF_GLOBAL_SIZE=10000
    fi
    HJ_BUF_SIZE=250
    HAGR_BUF_SIZE=250
    RECYCLE=$(echo "scale=0; $RECYCLE / 1000 * 1000" | bc)

    if [ $v_mem_mb -ge 64000 ]; then
        FAST_POOL_PAGES=99999
        FAST_ROLL_PAGES=9999
        BUFFER=$((BUFFER - 3000))
        MAX_BUFFER=$BUFFER
        CACHE_POOL_SIZE=2048
        RLOG_POOL_SIZE=2048
        SORT_FLAG=1
        SORT_BLK_SIZE=1
        SORT_BUF_SIZE=50
        SORT_BUF_GLOBAL_SIZE=$(echo "scale=0; $v_mem_mb * 0.02" | bc)

        HJ_BUF_GLOBAL_SIZE=$(echo "scale=0; $v_mem_mb * 0.15625" | bc)
        HAGR_BUF_GLOBAL_SIZE=$(echo "scale=0; $v_mem_mb * 0.04" | bc)
        HJ_BUF_SIZE=512
        HAGR_BUF_SIZE=512
        MEMORY_N_POOLS=59
    fi

    DICT_BUF_SIZE=50
    HJ_BUF_GLOBAL_SIZE=$(echo "scale=0; $HJ_BUF_GLOBAL_SIZE / 1000 * 1000" | bc)
    HAGR_BUF_GLOBAL_SIZE=$(echo "scale=0; $HAGR_BUF_GLOBAL_SIZE / 1000 * 1000" | bc)
    SORT_BUF_GLOBAL_SIZE=$(echo "scale=0; $SORT_BUF_GLOBAL_SIZE / 1000 * 1000" | bc)
    RECYCLE=$(echo "scale=0; $RECYCLE / 1000 * 1000" | bc)
else
    MEMORY_POOL=$(printf "%.0f" $(echo "scale=4; $v_mem_mb * 0.0625" | bc))
    if [ $MEMORY_POOL -lt 100 ]; then
        MEMORY_POOL=100
    fi
    MEMORY_POOL=$(printf "%.0f" $(echo "scale=4; $MEMORY_POOL / 100 * 100" | bc))
    MEMORY_N_POOLS=1
    CACHE_POOL_SIZE=200
    RLOG_POOL_SIZE=256
    SORT_BUF_SIZE=10
    SORT_BUF_GLOBAL_SIZE=500
    DICT_BUF_SIZE=50
    SORT_FLAG=0
    SORT_BLK_SIZE=1

    HJ_BUF_GLOBAL_SIZE=$(printf "%.0f" $(echo "scale=4; $v_mem_mb * 0.0625" | bc))
    if [ $HJ_BUF_GLOBAL_SIZE -lt 500 ]; then
        HJ_BUF_GLOBAL_SIZE=500
    fi
    HAGR_BUF_GLOBAL_SIZE=$HJ_BUF_GLOBAL_SIZE

    HJ_BUF_SIZE=$(printf "%.0f" $(echo "scale=4; $v_mem_mb * 0.00625" | bc))
    if [ $HJ_BUF_SIZE -lt 50 ]; then
        HJ_BUF_SIZE=50
    fi
    HAGR_BUF_SIZE=$HJ_BUF_SIZE
fi

# MEMORY_TARGET=$(echo "scale=0; $v_mem_mb * 0.12" | bc)
# 根据达梦建议MEMORY_TARGET为MEMORY_POOL的1.5-2倍
MEMORY_TARGET=$(echo "scale=0; $MEMORY_POOL * 1.5" | bc)
MEMORY_TARGET=$(echo "scale=0; $MEMORY_TARGET / 1000 * 1000" | bc)

# 执行参数设置
    echo "正在应用参数设置..."
    
    # 函数：执行参数设置
    set_param() {
        param_type=$1
        param_name=$2
        param_value=$3
        sql="SP_SET_PARA_VALUE($param_type, '$param_name', $param_value);"
        echo $sql >> $dm_root_dir/exec_auto_config.sql
        $dm_disql_path $dm_user/$dm_password@$dm_host:$dm_port << EOF
    $sql
    exit;
EOF
    }

    # CPU相关参数
    set_param 2 WORKER_THREADS $v_cpus
    set_param 2 TASK_THREADS $TASK_THREADS
    set_param 2 IO_THR_GROUPS $IO_THR_GROUPS

    # 内存池相关参数
    set_param 2 MAX_OS_MEMORY $mem_per
    set_param 2 MEMORY_POOL $MEMORY_POOL
    set_param 2 MEMORY_N_POOLS $MEMORY_N_POOLS
    set_param 2 MEMORY_TARGET $MEMORY_TARGET

    # 内存检测参数
    set_param 2 MEMORY_MAGIC_CHECK 1

    # 非DSC环境设置
    check_dsc_sql="SELECT count(1) FROM v\$instance WHERE dsc_role != 'NULL'"
    dsc_count=$($dm_disql_path -S $dm_user/$dm_password@$dm_host:$dm_port -e "$check_dsc_sql" | tail -n 1 | grep -oP '\d+' || echo 0)
    # 移除重复的查询行
    if [ $dsc_count -gt 0 ]; then
        set_param 2 ENABLE_FREQROOTS 1
    fi

    # 缓冲区相关参数
    set_param 2 BUFFER $BUFFER
    set_param 2 MAX_BUFFER $MAX_BUFFER
    set_param 2 BUFFER_POOLS $BUFFER_POOLS
    set_param 2 RECYCLE $RECYCLE
    set_param 2 RECYCLE_POOLS $RECYCLE_POOLS

    # Fast pool相关参数
    set_param 2 FAST_POOL_PAGES $FAST_POOL_PAGES
    set_param 2 FAST_ROLL_PAGES $FAST_ROLL_PAGES

    # HASH相关参数
    set_param 1 HJ_BUF_GLOBAL_SIZE $HJ_BUF_GLOBAL_SIZE
    set_param 1 HJ_BUF_SIZE $HJ_BUF_SIZE
    set_param 1 HAGR_BUF_GLOBAL_SIZE $HAGR_BUF_GLOBAL_SIZE
    set_param 1 HAGR_BUF_SIZE $HAGR_BUF_SIZE

    # 排序相关参数
    set_param 2 SORT_FLAG $SORT_FLAG
    set_param 2 SORT_BLK_SIZE $SORT_BLK_SIZE
    set_param 2 SORT_BUF_SIZE $SORT_BUF_SIZE
    set_param 2 SORT_BUF_GLOBAL_SIZE $SORT_BUF_GLOBAL_SIZE

    # 其他内存参数
    set_param 2 RLOG_POOL_SIZE $RLOG_POOL_SIZE
    set_param 2 CACHE_POOL_SIZE $CACHE_POOL_SIZE
    set_param 2 DICT_BUF_SIZE $DICT_BUF_SIZE
    set_param 2 VM_POOL_TARGET 16384
    set_param 2 SESS_POOL_TARGET 16384

    # 实例相关参数
    set_param 2 USE_PLN_POOL 1
    set_param 2 ENABLE_MONITOR 1
    set_param 2 SVR_LOG 0
    set_param 2 TEMP_SIZE 1024
    set_param 2 TEMP_SPACE_LIMIT 102400
    set_param 2 MAX_SESSIONS 1500
    set_param 2 MAX_SESSION_STATEMENT 20000
    set_param 2 PK_WITH_CLUSTER 0
    set_param 2 ENABLE_ENCRYPT 0

    # 优化器相关参数
    set_param 2 OLAP_FLAG 2
    set_param 2 VIEW_PULLUP_FLAG 1
    set_param 2 OPTIMIZER_MODE 1
    set_param 2 ADAPTIVE_NPLN_FLAG 0

    # 并行相关参数
    set_param 2 PARALLEL_PURGE_FLAG 1
    set_param 2 PARALLEL_POLICY 2
    set_param 2 UNDO_EXTENT_NUM 16
    set_param 2 ENABLE_INJECT_HINT 1

    echo "参数设置完成,请重启dmserver服务使配置生效"


    source /root/.bash_profile
    echo_color blue bold "自动调整数据库参数..."
    $dm_disql_path_default $dm_user_default/$dm_password_default@$dm_host_default:$dm_run_port << EOF
    SP_SET_PARA_STRING_VALUE(2, 'EXCLUDE_RESERVED_WORDS', 'DOMAIN,XML,EXCHANGE,link');
    SP_SET_PARA_VALUE(2,'COMPATIBLE_MODE',$dm_run_compatible_mode);
    SP_SET_PARA_VALUE(1,'ENABLE_BLOB_CMP_FLAG',1);
    exit;
EOF
    echo_color green bold "数据库自动配置完成"
}


function check_disk_free_space()
{
# 使用df -k以KB为单位获取剩余空间，这在大多数系统上都兼容
# 使用awk提取可用空间列（不同系统可能列位置不同，这里取第4列）
free_space_kb=$(df -k $dm_backup_root_dir | awk 'NR==2 {print $4}')

# 检查命令执行是否失败（如果变量为空或不是数字）
if [ -z "$free_space_kb" ] || ! [[ "$free_space_kb" =~ ^[0-9]+$ ]]; then
    echo "无法获取有效的剩余空间值"
    backup_keep_time_day=7
    echo "备份保留时间默认设置为7天"
    return 1  # 函数返回，不再继续执行下面的逻辑
fi

# 1TB等于1024GB，1GB等于1024KB，所以1TB = 1024*1024*1024KB = 1073741824KB，现在取整1000000000
# 检查剩余空间是否大于1TB
if [ "$free_space_kb" -gt 1000000000 ]; then
    backup_keep_time_day=30
    echo "备份保留时间默认设置为30天"
else
    # 如果空间不足1TB，也设置为7天
    backup_keep_time_day=7
    echo "备份保留时间默认设置为7天"
fi
}

function create_logical_backup()
{
# 在达梦创建备份专用用户
$dm_disql_path_default $dm_user_default/$dm_password_default@$dm_host_default:$dm_run_port << EOF
    create tablespace dm_backup_user datafile 'dm_backup_user.dbf' size 300;
    create user dm_backup_user identified by "dm_backup_Gepoint_2025_6#6#6#" default tablespace dm_backup_user;
    grant dba to dm_backup_user;
    exit;
EOF
# 定义逻辑备份基础信息
dm_backup_user="dm_backup_user"
dm_backup_pwd="dm_backup_Gepoint_2025_6#6#6#"
mkdir -p $dm_backup_logical_dir
chown -R dmdba:dinstall $dm_backup_logical_dir
# 根据上面dm_backup_logical_dir变量自动计算备份保留的天数
check_disk_free_space

# 根据以上变量生成定时任务脚本
cat > $dm_root_dir/dm_logical_backup.sh << EOF
#!/bin/bash
dm_home="$dm_bin_default"
dm_backup_user="$dm_backup_user"
dm_backup_pwd="$dm_backup_pwd"
export LD_LIBRARY_PATH="\$dm_home:\$LD_LIBRARY_PATH"
backup_dir="$dm_backup_logical_dir"
backup_db_sql="SELECT username from dba_users WHERE username NOT IN ('SYSSSO','SYSDBA','SYS','SYSAUDITOR')"
# 1天是1440分钟,下面的是保留$backup_keep_time_day天,下面的是按照分钟算
keep_time=$((backup_keep_time_day*1440))

if [ ! -d \$backup_dir ]; then
mkdir -p \$backup_dir
chown -R dmdba:dinstall \$backup_dir
fi


db_arr=\$(\$dm_home/disql -S \$dm_backup_user/\"\$dm_backup_pwd\"@$dm_host_default:$dm_run_port -e "\$backup_db_sql"|grep -v "username"|grep -v "-"|awk '{if(\$0!="")print}')

date=\`date +"20%y%m%d%H%M%S"\`

for dbname in \${db_arr}
do
dmpfile=\$dbname-\$date".dmp"
logfile=\$dbname-\$date".log"
\$dm_home/dexp \$dm_backup_user/\"\$dm_backup_pwd\"@$dm_host_default:$dm_run_port file=\$backup_dir/\$dmpfile log=\$backup_dir/\$logfile schemas=\$dbname
done


find \$backup_dir -maxdepth 1 -type f -mmin +\$keep_time -name "*"| xargs rm -rf

EOF

# 添加执行权限
chmod +x $dm_root_dir/dm_logical_backup.sh

# 添加到crontab，每天20点执行
# 先检查是否已经存在该crontab条目
crontab -l | grep -q "$dm_root_dir/dm_logical_backup.sh"
if [ $? -ne 0 ]; then
    # 不存在则添加新的crontab条目
    (crontab -l 2>/dev/null; echo "0 20 * * * $dm_root_dir/dm_logical_backup.sh >/dev/null 2>&1") | crontab -
    echo "已将逻辑备份脚本添加到crontab，每天20点执行"
else
    echo "逻辑备份脚本的crontab条目已存在"
fi
}



function create_backup_job()
{
     mkdir -p $dm_backup_physical_dir
     chown -R dmdba:dinstall $dm_backup_physical_dir
     # 开启归档

     $dm_disql_path_default $dm_user_default/$dm_password_default@$dm_host_default:$dm_run_port << EOF
        call SP_INIT_JOB_SYS(1);
        call SP_DROP_JOB('full_bak');
        call SP_CREATE_JOB('full_bak',1,0,'',0,0,'',0,'');
        call SP_JOB_CONFIG_START('full_bak');
        call SP_ADD_JOB_STEP('full_bak', 'full_bak', 6, '00000000$dm_backup_physical_dir', 0, 0, 0, 0, NULL, 0);
        call SP_ADD_JOB_SCHEDULE('full_bak', 'full_bak', 1, 2, 1, 64, 0, '01:00:00', NULL, '2000-01-01 15:17:07', NULL, '');
        call SP_JOB_CONFIG_COMMIT('full_bak');
        call SP_DROP_JOB('incr_bak');
        call SP_CREATE_JOB('incr_bak',1,0,'',0,0,'',0,'');
        call SP_JOB_CONFIG_START('incr_bak');
        call SP_ADD_JOB_STEP('incr_bak', 'incr_bak', 6, '10000000$dm_backup_physical_dir|$dm_backup_physical_dir', 0, 0, 0, 0, NULL, 0);
        call SP_ADD_JOB_SCHEDULE('incr_bak', 'incr_bak', 1, 2, 1, 63, 0, '01:00:00', NULL, '2000-01-01 15:22:35', NULL, '');
        call SP_JOB_CONFIG_COMMIT('incr_bak');
        call SP_DROP_JOB('remove_bak');
        call SP_CREATE_JOB('remove_bak',1,0,'',0,0,'',0,'');
        call SP_JOB_CONFIG_START('remove_bak');
        call SP_ADD_JOB_STEP('remove_bak', 'remove_bak', 0, 'call sf_bakset_backup_dir_add(''DISK'',''$dm_backup_physical_dir'');call sp_db_bakset_remove_batch(''DISK'',now()-$backup_keep_time_day);', 0, 0, 0, 0, NULL, 0);
        call SP_ADD_JOB_SCHEDULE('remove_bak', 'remove_bak', 1, 1, 1, 0, 0, '20:00:00', NULL, '2000-01-01 15:38:32', NULL, '');
        call SP_JOB_CONFIG_COMMIT('remove_bak');
        call SP_DROP_JOB('JOB_DEL_ARCH_TIMELY');
        call SP_CREATE_JOB('JOB_DEL_ARCH_TIMELY',1,0,'',0,0,'',0,'定时删除备份');
        call SP_JOB_CONFIG_START('JOB_DEL_ARCH_TIMELY');
        call SP_ADD_JOB_STEP('JOB_DEL_ARCH_TIMELY', 'STEP_DEL_ARCH', 0, 'SF_ARCHIVELOG_DELETE_BEFORE_TIME(SYSDATE - $backup_keep_time_day);', 1, 2, 0, 0, NULL, 0);
        call SP_ADD_JOB_SCHEDULE('JOB_DEL_ARCH_TIMELY', 'SCHEDULE_DEL_ARCH', 1, 1, 1, 0, 0, '20:00:00', NULL, '2020-03-20 21:05:57', NULL, '');
        call SP_JOB_CONFIG_COMMIT('JOB_DEL_ARCH_TIMELY');
        exit;
EOF
    cat > /tmp/create_job.sql << EOF
call SP_INIT_JOB_SYS(1);
call SP_DROP_JOB('full_bak');
call SP_CREATE_JOB('full_bak',1,0,'',0,0,'',0,'');
call SP_JOB_CONFIG_START('full_bak');
call SP_ADD_JOB_STEP('full_bak', 'full_bak', 6, '00000000$dm_backup_physical_dir', 0, 0, 0, 0, NULL, 0);
call SP_ADD_JOB_SCHEDULE('full_bak', 'full_bak', 1, 2, 1, 64, 0, '01:00:00', NULL, '2000-01-01 15:17:07', NULL, '');
call SP_JOB_CONFIG_COMMIT('full_bak');
call SP_DROP_JOB('incr_bak');
call SP_CREATE_JOB('incr_bak',1,0,'',0,0,'',0,'');
call SP_JOB_CONFIG_START('incr_bak');
call SP_ADD_JOB_STEP('incr_bak', 'incr_bak', 6, '10000000$dm_backup_physical_dir|$dm_backup_physical_dir', 0, 0, 0, 0, NULL, 0);
call SP_ADD_JOB_SCHEDULE('incr_bak', 'incr_bak', 1, 2, 1, 63, 0, '01:00:00', NULL, '2000-01-01 15:22:35', NULL, '');
call SP_JOB_CONFIG_COMMIT('incr_bak');
call SP_DROP_JOB('remove_bak');
call SP_CREATE_JOB('remove_bak',1,0,'',0,0,'',0,'');
call SP_JOB_CONFIG_START('remove_bak');
call SP_ADD_JOB_STEP('remove_bak', 'remove_bak', 0, 'call sf_bakset_backup_dir_add(''DISK'',''$dm_backup_physical_dir'');call sp_db_bakset_remove_batch(''DISK'',now()-$backup_keep_time_day);', 0, 0, 0, 0, NULL, 0);
call SP_ADD_JOB_SCHEDULE('remove_bak', 'remove_bak', 1, 1, 1, 0, 0, '20:00:00', NULL, '2000-01-01 15:38:32', NULL, '');
call SP_JOB_CONFIG_COMMIT('remove_bak');
call SP_DROP_JOB('JOB_DEL_ARCH_TIMELY');
call SP_CREATE_JOB('JOB_DEL_ARCH_TIMELY',1,0,'',0,0,'',0,'auto delete backup file');
call SP_JOB_CONFIG_START('JOB_DEL_ARCH_TIMELY');
call SP_ADD_JOB_STEP('JOB_DEL_ARCH_TIMELY', 'STEP_DEL_ARCH', 0, 'SF_ARCHIVELOG_DELETE_BEFORE_TIME(SYSDATE - $backup_keep_time_day);', 1, 2, 0, 0, NULL, 0);
call SP_ADD_JOB_SCHEDULE('JOB_DEL_ARCH_TIMELY', 'SCHEDULE_DEL_ARCH', 1, 1, 1, 0, 0, '20:00:00', NULL, '2020-03-20 21:05:57', NULL, '');
call SP_JOB_CONFIG_COMMIT('JOB_DEL_ARCH_TIMELY');
EOF
   echo_color green bold "如果创建备份任务失败，请手动执行以下命令:"
   echo_color green bold "$dm_disql_path_default $dm_user_default/$dm_password_default@$dm_host_default:$dm_run_port < /tmp/create_job.sql"
}

function open_slowlog() {
    echo_color blue bold "正在开启慢查询日志..."
    sed -i "s/^[[:space:]]*SWITCH_LIMIT[[:space:]]*=[[:space:]]*[0-9]*/    SWITCH_LIMIT   = 1024/g" $dm_data_dir/DAMENG/sqllog.ini
    sed -i "s/^[[:space:]]*SQL_TRACE_MASK[[:space:]]*=[[:space:]]*[0-9]*/    SQL_TRACE_MASK   = 2:25:28/g" $dm_data_dir/DAMENG/sqllog.ini
    sed -i "s/^[[:space:]]*MIN_EXEC_TIME[[:space:]]*=[[:space:]]*[0-9]*/    MIN_EXEC_TIME   = 2/g" $dm_data_dir/DAMENG/sqllog.ini
    $dm_disql_path_default $dm_user_default/$dm_password_default@$dm_host_default:$dm_run_port << EOF
    CALL SP_REFRESH_SVR_LOG_CONFIG();
    SP_SET_PARA_VALUE(1,'SVR_LOG',1);
    exit;
EOF
}


function restart_db() {
    echo_color blue bold "正在重启数据库..."
    systemctl restart DmServiceDMSERVER
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
    $dm_disql_path_default $dm_user_default/$dm_password_default@$dm_host_default:$dm_run_port << EOF
    ALTER USER SYSDBA IDENTIFIED BY "$new_password";
    exit;
EOF
    
    # 检查密码修改是否成功
    if [ $? -eq 0 ]; then
        echo_color green bold "SYSDBA用户密码修改成功"
        echo_color purple bold "数据库参数信息如下"
        $dm_disql_path_default -S $dm_user_default/\"$new_password\"@$dm_host_default:$dm_run_port -e "select para_value LENGTH_IN_CHAR,page PAGE_SIZE,SF_GET_EXTENT_SIZE() EXTENT_SIZE, DECODE(unicode,'1','utf8',0,'gbk','EUC-KR') as CHARSET,CASE_SENSITIVE from v\$dm_ini where para_name = 'LENGTH_IN_CHAR';"
        $dm_disql_path_default -S $dm_user_default/\"$new_password\"@$dm_host_default:$dm_run_port -e "select para_name,para_value from v\$dm_ini where para_name in ('COMPATIBLE_MODE','SVR_LOG','BUFFER','MAX_OS_MEMORY','MAX_SESSIONS','MEMORY_POOL','MEMORY_TARGET');"
        echo_color purple bold "物理备份定时任务如下"
        $dm_disql_path_default -S $dm_user_default/\"$new_password\"@$dm_host_default:$dm_run_port -e "SELECT NAME,decode(ENABLE,1,'enable') status,USERNAME,CREATETIME FROM SYSJOB.SYSJOBS;"
        echo_color purple bold "逻辑备份定时任务如下"
        crontab -l|grep dm
    else
        echo_color red bold "SYSDBA用户密码修改失败"
        echo_color yellow bold "请手动使用以下命令修改密码:"
        echo_color yellow bold "$dm_disql_path_default $dm_user_default/$dm_password_default@$dm_host_default:$dm_run_port \"ALTER USER SYSDBA IDENTIFIED BY \"$new_password\"\""
    fi

    # 显示生成的密码（注意保密）
    # echo_color green bold "生成的随机密码: $new_password"
    # echo_color yellow bold "请务必记录此密码，它将用于SYSDBA用户登录"
    echo $new_password > $dm_root_dir/dmpwd.txt
    # echo_color green bold "密码已保存到 $dm_root_dir/dmpwd.txt"
    # echo_color yellow bold "请按照顺序执行如下命令:"
    # echo_color yellow bold "source /root/.bash_profile"
    # echo_color yellow bold "disql SYSDBA/$new_password@$dm_host_default:$dm_run_port"
    echo -e "
##########################################################################
#                                                                        #
#        :) DM Install Complete !                                        #
#\033[31;49;1m     生成的随机密码: $new_password\033[39;49;0m                                   #
#\033[31;49;1m     请务必记录此密码，它将用于SYSDBA用户登录\033[39;49;0m                           #
#\033[31;49;1m     密码已保存到 $dm_root_dir/dmpwd.txt\033[39;49;0m                          #
#\033[31;49;1m     请按照顺序执行如下命令:\033[39;49;0m                                            #
#\033[31;49;1m     source /root/.bash_profile\033[39;49;0m                                         #           
#\033[31;49;1m     连接示例 disql SYSDBA/$new_password@$dm_host_default:$dm_run_port\033[39;49;0m              #
#                                                                        #
##########################################################################
"

}

##############main process##################
while getopts "p:m:d:b:t:l:h" arg
do
    case $arg in
    p)
        echo "you will install the dm and the port while be use $OPTARG"
        dm_run_port=$OPTARG
        ;;
    m)
        echo "we will set the dm_compatible_mode $OPTARG"
        dm_compatible_mode=$OPTARG
        ;;
    d)
        echo "we will set the dm data directory $OPTARG"
        dm_data_dir=$OPTARG
        ;;
    b)
        echo "we will set the dm backup directory $OPTARG"
        dm_backup_root_dir=$OPTARG
        ;;
    t)
        echo "we will install specified dm version $OPTARG"
        target_version=$OPTARG
        ;;
    l)
        echo "we will install specified dm length_in_char $OPTARG"
        length_in_char=$OPTARG
        ;;
    h)
        echo -en "you can use follow options: \n"\
             "-p [default 5236]  set the dm port; \n"\
             "-m [default mysql] set the dm_compatible_mode mysql_mode or oracle_mode; \n"\
             "-d [default /data] set the dm data directory; \n"\
             "-b [default /dm_backup] set the dm backup directory; \n"\
             "-t install  dm specified version; \n"\
             "-l install dm specified length_in_char,like -l 0 then do not enable length_in_char ; \n"\
             "-h Help \n"
        exit 1
        ;;
    ?)
        echo -en "unknow args,you can use '-h' show all options \n"
        exit 1
        ;;
    esac
done
# if [ -z "$target_version" ]; then
#   echo "you must specified -t argument ,example -t /opt/DMInstall.bin"
#   exit 1
# fi
check_bin_arguments
print_info
check_dm_run
unzipfile
init_xml
init_env
install_dm
check_install
add_run_env
enable_arch
create_logical_backup
create_backup_job
auto_config
open_slowlog
restart_db
change_pwd
exit
---------ARCHIVE_FOLLOWS---------
