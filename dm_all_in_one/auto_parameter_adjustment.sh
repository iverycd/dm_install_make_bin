#!/bin/bash
# **************************************************************************
# *
# * Auto parameter adjustment 2.6
# * [November 16, 2021 ]
# * Take effect after restart dmserver
# *
# **************************************************************************

# 配置参数
exec_mode=0          # 0:直接执行修改, 1:仅打印语句
mem_per=60          # 数据库可用内存百分比
v_mem_mb=16000       # 内存大小(MB)
v_cpus=8             # CPU核数
v_bak_dmini=0        # 是否备份dmini参数:0不备份,1备份

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
dm_user="SYSDBA"          # 数据库用户名
dm_password="Tjt,1kzJ6Wrj_Ep0"  # 数据库密码
dm_host="localhost"        # 数据库主机
dm_port="5236"             # 数据库端口
dm_disql_path="/home/dmdba/dmdbms/bin/disql"  # disql工具路径


# 获取系统信息(如果exec_mode=0)
if [ $exec_mode -eq 0 ]; then
    # 获取CPU核数
    v_cpus=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || sysctl -n hw.ncpu || echo 8)
    
    # 获取物理内存大小(MB)
    if [ -f /proc/meminfo ]; then
        v_mem_mb=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}' || echo 8192)
    else
        # 注意: sysctl命令在黑名单中，请确认是否符合安全要求
        v_mem_mb=$(sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024/1024)}' || echo 8192)
    fi
fi

# 调整内存计算
v_mem_mb=$(echo "scale=0; $v_mem_mb * $mem_per / 100" | bc)
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
MEMORY_TARGET=$(echo "scale=0; $v_mem_mb * 0.12" | bc)
MEMORY_TARGET=$(echo "scale=0; $MEMORY_TARGET / 1000 * 1000" | bc)

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

# 缓冲区参数
BUFFER=$(echo "scale=0; $v_mem_mb * 0.4" | bc)
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

# 备份dmini参数
# if [ $v_bak_dmini -eq 1 ]; then
#     tname="BAK_DMINI_$(date +%y%m%d)"
#     # 检查表是否存在
#     check_table_sql="select count(*) from USER_ALL_TABLES where table_name='$tname'"
#     CNT=$(echo $check_table_sql | $dm_sql_exe SYSDBA/SYSDBA@localhost:5236 | grep -oP '(?<=\s)\d+(?=\s)')

#     if [ $CNT -eq 0 ]; then
#         create_table_sql="CREATE TABLE $tname as select *,sysdate uptime from v$dm_ini"
#         echo $create_table_sql | $dm_sql_exe SYSDBA/SYSDBA@localhost:5236
#     else
#         insert_sql="INSERT INTO $tname select *,sysdate uptime from v$dm_ini"
#         echo $insert_sql | $dm_sql_exe SYSDBA/SYSDBA@localhost:5236
#     fi
# fi

# 执行参数设置
if [ $exec_mode -eq 0 ]; then
    echo "正在应用参数设置..."
    
    # 函数：执行参数设置
    set_param() {
        param_type=$1
        param_name=$2
        param_value=$3
        sql="SP_SET_PARA_VALUE($param_type, '$param_name', $param_value);"
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

    echo "参数设置完成，请重启dmserver服务使配置生效"
else
    echo "参数设置语句如下(未执行):"
    
    # 打印CPU相关参数
    echo "SP_SET_PARA_VALUE(2, 'WORKER_THREADS', $v_cpus);"
    echo "SP_SET_PARA_VALUE(2, 'TASK_THREADS', $TASK_THREADS);"
    echo "SP_SET_PARA_VALUE(2, 'IO_THR_GROUPS', $IO_THR_GROUPS);"

    # 打印内存池相关参数
    echo "SP_SET_PARA_VALUE(2, 'MAX_OS_MEMORY', $mem_per);"
    echo "SP_SET_PARA_VALUE(2, 'MEMORY_POOL', $MEMORY_POOL);"
    echo "SP_SET_PARA_VALUE(2, 'MEMORY_N_POOLS', $MEMORY_N_POOLS);"
    echo "SP_SET_PARA_VALUE(2, 'MEMORY_TARGET', $MEMORY_TARGET);"

    # 打印内存检测参数
    echo "SP_SET_PARA_VALUE(2, 'MEMORY_MAGIC_CHECK', 1);"

    # 打印非DSC环境设置
    check_dsc_sql="SELECT count(1) FROM v\$instance WHERE dsc_role != 'NULL'"
    dsc_count=$($dm_disql_path -S $dm_user/$dm_password@$dm_host:$dm_port -e "$check_dsc_sql" | tail -n 1 | grep -oP '\d+' || echo 0)
    # 移除重复的查询行
    if [ $dsc_count -gt 0 ]; then
        echo "SP_SET_PARA_VALUE(2, 'ENABLE_FREQROOTS', 1);"
    fi




    # 打印缓冲区相关参数
    echo "SP_SET_PARA_VALUE(2, 'BUFFER', $BUFFER);"
    echo "SP_SET_PARA_VALUE(2, 'MAX_BUFFER', $MAX_BUFFER);"
    echo "SP_SET_PARA_VALUE(2, 'BUFFER_POOLS', $BUFFER_POOLS);"
    echo "SP_SET_PARA_VALUE(2, 'RECYCLE', $RECYCLE);"
    echo "SP_SET_PARA_VALUE(2, 'RECYCLE_POOLS', $RECYCLE_POOLS);"

    # 打印Fast pool相关参数
    echo "SP_SET_PARA_VALUE(2, 'FAST_POOL_PAGES', $FAST_POOL_PAGES);"
    echo "SP_SET_PARA_VALUE(2, 'FAST_ROLL_PAGES', $FAST_ROLL_PAGES);"

    # 打印HASH相关参数
    echo "SP_SET_PARA_VALUE(1, 'HJ_BUF_GLOBAL_SIZE', $HJ_BUF_GLOBAL_SIZE);"
    echo "SP_SET_PARA_VALUE(1, 'HJ_BUF_SIZE', $HJ_BUF_SIZE);"
    echo "SP_SET_PARA_VALUE(1, 'HAGR_BUF_GLOBAL_SIZE', $HAGR_BUF_GLOBAL_SIZE);"
    echo "SP_SET_PARA_VALUE(1, 'HAGR_BUF_SIZE', $HAGR_BUF_SIZE);"

    # 打印排序相关参数
    echo "SP_SET_PARA_VALUE(2, 'SORT_FLAG', $SORT_FLAG);"
    echo "SP_SET_PARA_VALUE(2, 'SORT_BLK_SIZE', $SORT_BLK_SIZE);"
    echo "SP_SET_PARA_VALUE(2, 'SORT_BUF_SIZE', $SORT_BUF_SIZE);"
    echo "SP_SET_PARA_VALUE(2, 'SORT_BUF_GLOBAL_SIZE', $SORT_BUF_GLOBAL_SIZE);"

    # 打印其他内存参数
    echo "SP_SET_PARA_VALUE(2, 'RLOG_POOL_SIZE', $RLOG_POOL_SIZE);"
    echo "SP_SET_PARA_VALUE(2, 'CACHE_POOL_SIZE', $CACHE_POOL_SIZE);"
    echo "SP_SET_PARA_VALUE(2, 'DICT_BUF_SIZE', $DICT_BUF_SIZE);"
    echo "SP_SET_PARA_VALUE(2, 'VM_POOL_TARGET', 16384);"
    echo "SP_SET_PARA_VALUE(2, 'SESS_POOL_TARGET', 16384);"

    # 打印实例相关参数
    echo "SP_SET_PARA_VALUE(2, 'USE_PLN_POOL', 1);"
    echo "SP_SET_PARA_VALUE(2, 'ENABLE_MONITOR', 1);"
    echo "SP_SET_PARA_VALUE(2, 'SVR_LOG', 0);"
    echo "SP_SET_PARA_VALUE(2, 'TEMP_SIZE', 1024);"
    echo "SP_SET_PARA_VALUE(2, 'TEMP_SPACE_LIMIT', 102400);"
    echo "SP_SET_PARA_VALUE(2, 'MAX_SESSIONS', 1500);"
    echo "SP_SET_PARA_VALUE(2, 'MAX_SESSION_STATEMENT', 20000);"
    echo "SP_SET_PARA_VALUE(2, 'PK_WITH_CLUSTER', 0);"
    echo "SP_SET_PARA_VALUE(2, 'ENABLE_ENCRYPT', 0);"

    # 打印优化器相关参数
    echo "SP_SET_PARA_VALUE(2, 'OLAP_FLAG', 2);"
    echo "SP_SET_PARA_VALUE(2, 'VIEW_PULLUP_FLAG', 1);"
    echo "SP_SET_PARA_VALUE(2, 'OPTIMIZER_MODE', 1);"
    echo "SP_SET_PARA_VALUE(2, 'ADAPTIVE_NPLN_FLAG', 0);"

    # 打印并行相关参数
    echo "SP_SET_PARA_VALUE(2, 'PARALLEL_PURGE_FLAG', 1);"
    echo "SP_SET_PARA_VALUE(2, 'PARALLEL_POLICY', 2);"
    echo "SP_SET_PARA_VALUE(2, 'UNDO_EXTENT_NUM', 16);"
    echo "SP_SET_PARA_VALUE(2, 'ENABLE_INJECT_HINT', 1);"
fi

exit 0