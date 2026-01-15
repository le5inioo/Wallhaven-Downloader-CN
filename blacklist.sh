#!/bin/bash

# 定义目标文件夹路径和txt文件路径
TARGET_DIR="/vol2/1000/Media/Wallhaven"
TXT_FILE="${TARGET_DIR}/downloaded.txt"
# 临时文件路径（用于写入处理后的内容）
TEMP_FILE="${TARGET_DIR}/downloaded_temp.txt"
# 备份目录路径
BACKUP_DIR="/vol2/1000/Backup/wallhaven"
# 备份文件路径（直接覆盖已有文件）
BACKUP_FILE="${BACKUP_DIR}/downloaded.txt"

# 检查目标文件夹是否存在
if [ ! -d "${TARGET_DIR}" ]; then
    echo "错误：文件夹 ${TARGET_DIR} 不存在！"
    exit 1
fi

# 检查txt文件是否存在
if [ ! -f "${TXT_FILE}" ]; then
    echo "错误：文件 ${TXT_FILE} 不存在！"
    exit 1
fi

# 第一步：收集文件夹中所有图片文件的basename（忽略扩展名）
# 定义常见图片扩展名（小写）
image_extensions=("jpg" "jpeg" "png" "gif" "bmp" "webp" "svg")

# 创建临时文件存储图片basename（去重）
image_basenames_temp=$(mktemp)

# 遍历目标文件夹中的文件
for file in "${TARGET_DIR}"/*; do
    # 只处理文件（排除文件夹）
    if [ -f "${file}" ]; then
        # 获取文件名（不含路径）
        filename=$(basename "${file}")
        # 获取扩展名（小写）
        ext=$(echo "${filename}" | awk -F. '{if (NF>1) print tolower($NF)}')
        # 获取文件名主体（去扩展名）
        basename=$(echo "${filename}" | sed -E "s/\.[^.]+$//")
        
        # 检查扩展名是否在图片列表中
        if [[ " ${image_extensions[@]} " =~ " ${ext} " ]]; then
            echo "${basename}" >> "${image_basenames_temp}"
        fi
    fi
done

# 去重并排序（方便后续对比）
sort -u "${image_basenames_temp}" -o "${image_basenames_temp}"

# 第二步：处理txt文件，保留不存在对应图片的行
line_num=1
> "${TEMP_FILE}"  # 清空临时文件

# 逐行读取txt文件
while IFS= read -r line; do
    # 去除行首尾空白字符
    line_stripped=$(echo "${line}" | xargs)
    # 跳过空行
    if [ -z "${line_stripped}" ]; then
        ((line_num++))
        continue
    fi
    
    # 提取txt中记录的文件名主体（去扩展名）
    txt_basename=$(echo "${line_stripped}" | sed -E "s/\.[^.]+$//")
    
    # 检查该主体是否在图片列表中
    if grep -qxF "${txt_basename}" "${image_basenames_temp}"; then
        # 存在匹配的图片，删除该行（不写入临时文件）
        echo "找到匹配的图片，删除行 ${line_num}: ${line_stripped}"
    else
        # 不存在匹配的图片，保留该行
        echo "${line}" >> "${TEMP_FILE}"
    fi
    
    ((line_num++))
done < "${TXT_FILE}"

# 第三步：用临时文件替换原文件
mv "${TEMP_FILE}" "${TXT_FILE}"

# 第四步：备份处理后的downloaded.txt到指定目录（覆盖已有文件）
# 检查备份目录是否存在，不存在则创建
if [ ! -d "${BACKUP_DIR}" ]; then
    mkdir -p "${BACKUP_DIR}"
    echo "创建备份目录：${BACKUP_DIR}"
fi

# 强制复制并覆盖已有备份文件（cp的-f参数确保覆盖）
cp -f "${TXT_FILE}" "${BACKUP_FILE}"
if [ $? -eq 0 ]; then
    echo "已将 ${TXT_FILE} 备份到 ${BACKUP_FILE}（覆盖已有文件）"
else
    echo "警告：备份 ${TXT_FILE} 失败！"
fi

# 清理临时文件
rm -f "${image_basenames_temp}"

echo -e "\n处理完成！已更新 ${TXT_FILE}"
exit 0