#!/bin/bash

# 设置需要清空的目标文件夹路径
TARGET_DIR="/vol2/1000/Media/Wallhaven"

# 第一步：验证目标文件夹是否存在
if [ ! -d "$TARGET_DIR" ]; then
    echo "错误：目标文件夹 $TARGET_DIR 不存在！脚本退出。"
    exit 1
fi

# 第二步：安全清空文件夹内所有文件（保留文件夹本身）
# 使用 rm -rf "$TARGET_DIR"/* 清空普通文件/文件夹
# 使用 rm -rf "$TARGET_DIR"/.* 清空隐藏文件（排除 . 和 ..）
echo "正在清空文件夹：$TARGET_DIR"
# 清空普通文件和子文件夹
rm -rf "$TARGET_DIR"/* 2>/dev/null
# 清空隐藏文件（避免遗漏 .DS_Store、.downloaded 等隐藏文件）
find "$TARGET_DIR" -maxdepth 1 -type f -name ".*" -delete 2>/dev/null
find "$TARGET_DIR" -maxdepth 1 -type d -name ".*" ! -name "." ! -name ".." -exec rm -rf {} \; 2>/dev/null

# 第三步：验证清空结果并提示
if [ "$(ls -A "$TARGET_DIR" 2>/dev/null)" = "" ]; then
    echo "成功：$TARGET_DIR 文件夹内所有文件已清空！"
else
    echo "警告：$TARGET_DIR 文件夹内仍有残留文件，请手动检查。"
fi

# 自动退出脚本
exit 0
