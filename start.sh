#!/bin/bash

# 定义3个目标脚本的完整路径（确保路径准确，避免环境变量问题）
SCRIPT1="/root/wallhaven/clean.sh"
SCRIPT2="/root/wallhaven/download.sh"
SCRIPT3="/root/wallhaven/compress.sh"

# 定义日志文件路径（方便排查执行问题，可选但推荐）
LOG_FILE="/vol2/1000/Media/Wallhaven/series_execution_$(date +%Y%m%d).log"

# 脚本执行前置检查：确保3个目标脚本存在且有可执行权限
check_scripts() {
    local scripts=("$SCRIPT1" "$SCRIPT2" "$SCRIPT3")
    for script in "${scripts[@]}"; do
        # 检查文件是否存在
        if [ ! -f "$script" ]; then
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] 错误：脚本 $script 不存在！" >> "$LOG_FILE"
            exit 1
        fi
        # 检查文件是否有可执行权限，若无则添加
        if [ ! -x "$script" ]; then
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] 警告：脚本 $script 无执行权限，正在添加..." >> "$LOG_FILE"
            chmod +x "$script"
            # 再次验证添加权限是否成功
            if [ ! -x "$script" ]; then
                echo "[$(date +'%Y-%m-%d %H:%M:%S')] 错误：无法为脚本 $script 添加执行权限！" >> "$LOG_FILE"
                exit 1
            fi
        fi
    done
}

# 核心：串行执行3个脚本（上一个完全终止后，再执行下一个）
execute_scripts() {
    # 执行脚本1并记录日志
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] 开始执行脚本1：$SCRIPT1" >> "$LOG_FILE"
    "$SCRIPT1" >> "$LOG_FILE" 2>&1
    local script1_exit_code=$?
    if [ $script1_exit_code -eq 0 ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] 脚本1执行成功，退出码：$script1_exit_code" >> "$LOG_FILE"
    else
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] 警告：脚本1执行失败，退出码：$script1_exit_code，继续执行下一个脚本" >> "$LOG_FILE"
    fi

    # 执行脚本2并记录日志（等待脚本1完全终止）
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] 开始执行脚本2：$SCRIPT2" >> "$LOG_FILE"
    "$SCRIPT2" >> "$LOG_FILE" 2>&1
    local script2_exit_code=$?
    if [ $script2_exit_code -eq 0 ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] 脚本2执行成功，退出码：$script2_exit_code" >> "$LOG_FILE"
    else
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] 警告：脚本2执行失败，退出码：$script2_exit_code，继续执行下一个脚本" >> "$LOG_FILE"
    fi

    # 执行脚本3并记录日志（等待脚本2完全终止）
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] 开始执行脚本3：$SCRIPT3" >> "$LOG_FILE"
    "$SCRIPT3" >> "$LOG_FILE" 2>&1
    local script3_exit_code=$?
    if [ $script3_exit_code -eq 0 ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] 脚本3执行成功，退出码：$script3_exit_code" >> "$LOG_FILE"
    else
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] 警告：脚本3执行失败，退出码：$script3_exit_code" >> "$LOG_FILE"
    fi

    # 执行完成总提示
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] 3个脚本串行执行流程结束，详细日志请查看 $LOG_FILE" >> "$LOG_FILE"
    echo "----------------------------------------------------------------------" >> "$LOG_FILE"
}

# 脚本入口：先检查，再执行
main() {
    # 初始化日志文件（若不存在则创建）
    touch "$LOG_FILE"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] 启动3个脚本串行执行任务" >> "$LOG_FILE"
    
    # 执行前置检查
    check_scripts
    
    # 执行串行脚本
    execute_scripts
}

# 调用主函数
main