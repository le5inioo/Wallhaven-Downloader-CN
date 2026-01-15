#!/bin/bash

# 定义需要清空的目标文件夹路径
TARGET_DIR="/vol2/1000/Media/Wallhaven"
# 定义需要排除的文件
EXCLUDE_FILE="downloaded.txt"

# 第一步：验证目标文件夹是否存在
if [ ! -d "$TARGET_DIR" ]; then
    echo "错误：目标文件夹 $TARGET_DIR 不存在！脚本退出。"
    exit 1
fi

# 第二步：安全清空文件夹内所有文件（保留文件夹+排除指定文件）
echo "正在清空文件夹：$TARGET_DIR（排除 $EXCLUDE_FILE）"

# 核心修改：先移动排除文件到临时位置，清空后移回（最安全的排除方式）
TEMP_FILE="/tmp/$EXCLUDE_FILE"
if [ -f "$TARGET_DIR/$EXCLUDE_FILE" ]; then
    mv "$TARGET_DIR/$EXCLUDE_FILE" "$TEMP_FILE" 2>/dev/null
    echo "已临时移动 $EXCLUDE_FILE 到 $TEMP_FILE"
fi

# 原版的安全清空逻辑（仅删内容，不删文件夹）
rm -rf "$TARGET_DIR"/* 2>/dev/null
find "$TARGET_DIR" -maxdepth 1 -type f -name ".*" -delete 2>/dev/null
find "$TARGET_DIR" -maxdepth 1 -type d -name ".*" ! -name "." ! -name ".." -exec rm -rf {} \; 2>/dev/null

# 移回排除的文件
if [ -f "$TEMP_FILE" ]; then
    mv "$TEMP_FILE" "$TARGET_DIR/$EXCLUDE_FILE" 2>/dev/null
    echo "已将 $EXCLUDE_FILE 移回目标文件夹"
fi

# 第三步：验证清空结果并提示
# 检查时排除目标文件，确保判断准确
RESIDUAL=$(ls -A "$TARGET_DIR" 2>/dev/null | grep -v "^$EXCLUDE_FILE$" | wc -l)
if [ "$RESIDUAL" -eq 0 ]; then
    echo "成功：$TARGET_DIR 文件夹内除 $EXCLUDE_FILE 外所有文件已清空！"
else
    echo "警告：$TARGET_DIR 文件夹内除 $EXCLUDE_FILE 外仍有 $RESIDUAL 个残留项，请手动检查。"
fi

exit 0