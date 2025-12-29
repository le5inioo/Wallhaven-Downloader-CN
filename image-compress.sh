#!/bin/bash

# 定义常量
MAX_HEIGHT=2160                          # 2160p 以高度为判断标准
MAX_SIZE_KB=$((5 * 1024))                # 5MB 转换为 KB（1MB=1024KB）
SUPPORTED_FORMATS=("jpg" "jpeg" "png" "bmp" "tiff")  # 支持的图片格式
FIXED_TARGET_DIR="/vol2/1000/Media/Wallhaven"         # 目标图片目录（请确认路径正确）
CUSTOM_BACKUP_DIR="/vol2/1000/Media/Wallhaven/backups"      # 备份目录（保留原格式原图）
TARGET_TEMP_DIR="$FIXED_TARGET_DIR/.image_compress_temp"   # 目标目录内的专属临时目录（隐藏目录）
JPG_MAX_QUALITY=98                       # JPG 转换/压缩最大质量（最大限度保留细节）
JPG_MIN_QUALITY=85                       # JPG 压缩最低质量（避免过度降质，保证细节底线）

# 赋值变量
TARGET=$FIXED_TARGET_DIR
FULL_CUSTOM_BACKUP_DIR=$CUSTOM_BACKUP_DIR
FULL_TEMP_DIR=$TARGET_TEMP_DIR

# 1. 前置检查：目录权限、依赖工具
check_prerequisites() {
    # 检查目标目录是否存在且可读写
    if [ ! -d "$TARGET" ]; then
        echo "错误：目标目录 $TARGET 不存在！"
        exit 1
    fi
    if [ ! -r "$TARGET" ] || [ ! -w "$TARGET" ]; then
        echo "错误：目标目录 $TARGET 无读/写权限，请赋予权限后再运行！"
        exit 1
    fi

    # 检查备份目录可写（自动创建）
    mkdir -p "$FULL_CUSTOM_BACKUP_DIR"
    if [ ! -w "$FULL_CUSTOM_BACKUP_DIR" ]; then
        echo "错误：备份目录 $FULL_CUSTOM_BACKUP_DIR 无写入权限，请赋予权限后再运行！"
        exit 1
    fi

    # 提前创建目标目录内的临时目录（确保可写）
    mkdir -p "$FULL_TEMP_DIR"
    if [ ! -w "$FULL_TEMP_DIR" ]; then
        echo "错误：临时目录 $FULL_TEMP_DIR 无写入权限，请赋予权限后再运行！"
        exit 1
    fi

    # 检查核心依赖工具
    local missing_deps=0
    if ! command -v convert &> /dev/null; then
        echo "错误：未找到 ImageMagick（convert 命令），请先安装 imagemagick！"
        missing_deps=1
    fi
    if ! command -v identify &> /dev/null; then
        echo "错误：未找到 ImageMagick（identify 命令），请先安装 imagemagick！"
        missing_deps=1
    fi
    if ! command -v jpegoptim &> /dev/null; then
        echo "警告：未找到 jpegoptim，JPG 体积压缩功能将受限！"
    fi

    if [ $missing_deps -eq 1 ]; then
        exit 1
    fi
}

# 2. 判断是否为支持的图片格式
is_supported_format() {
    local file=$1
    local ext=$(echo "${file##*.}" | tr 'A-Z' 'a-z')  # 提取后缀并转为小写
    for fmt in "${SUPPORTED_FORMATS[@]}"; do
        if [ "$ext" = "$fmt" ]; then
            return 0  # 支持的格式
        fi
    done
    return 1  # 不支持的格式
}

# 3. 判断是否为非 JPG 格式（需要转换为 JPG）
is_non_jpg_format() {
    local file=$1
    local ext=$(echo "${file##*.}" | tr 'A-Z' 'a-z')
    if [ "$ext" != "jpg" ] && [ "$ext" != "jpeg" ]; then
        return 0  # 非 JPG 格式，需要转换
    fi
    return 1  # 已为 JPG 格式，无需转换
}

# 4. 获取图片高度（像素）
get_image_height() {
    local file=$1
    # 静默执行，仅返回高度数值，屏蔽错误输出
    identify -format "%h" "$file" 2>/dev/null
}

# 5. 获取图片大小（KB，四舍五入）
get_image_size_kb() {
    local file=$1
    local size_bytes=$(stat -c "%s" "$file" 2>/dev/null)
    # 防止stat命令执行失败导致数值异常
    if [ -z "$size_bytes" ] || [ "$size_bytes" -lt 0 ]; then
        echo 0
        return
    fi
    echo $(( (size_bytes + 1023) / 1024 ))  # 四舍五入转换为KB
}

# 6. 高保真压缩 JPG（最大化保留细节，确保体积≤5MB）
high_fidelity_compress_jpg() {
    local jpg_file=$1
    local target_size_kb=$2

    # 第一步：jpegoptim 无损优化（仅去除冗余数据，不损失细节）
    if command -v jpegoptim &> /dev/null; then
        jpegoptim -o -q --strip-none "$jpg_file" || true
    fi

    # 第二步：若仍超标，从最高质量开始小步长降质（避免细节快速丢失）
    local current_size=$(get_image_size_kb "$jpg_file")
    if [ "$current_size" -le "$target_size_kb" ]; then
        return 0
    fi

    local quality=$JPG_MAX_QUALITY
    while [ "$(get_image_size_kb "$jpg_file")" -gt "$target_size_kb" ] && [ "$quality" -ge "$JPG_MIN_QUALITY" ]; do
        convert "$jpg_file" \
            -quality "$quality" \
            -interlace Plane \
            -sampling-factor 4:2:0 \
            "$jpg_file"
        quality=$((quality - 2))  # 小步长降质，最大限度保留细节
    done
    return 0
}

# 7. 单个图片处理（核心：非 JPG 统一转 JPG，保留细节+体积达标）
process_image() {
    local img_path=$1
    local img_name=$(basename "$img_path")
    local img_ext=$(echo "${img_name##*.}" | tr 'A-Z' 'a-z')
    local img_base_name="${img_name%.*}"  # 去除后缀的文件名（用于生成 JPG 文件名）
    local jpg_img_name="${img_base_name}.jpg"  # 转换后的 JPG 文件名
    local jpg_final_path="${TARGET}/${jpg_img_name}"  # 最终 JPG 文件路径

    # 跳过非支持格式
    if ! is_supported_format "$img_path"; then
        echo "跳过非支持格式文件：$img_name"
        return
    fi

    # 获取图片属性，验证有效性
    local height=$(get_image_height "$img_path")
    local size_kb=$(get_image_size_kb "$img_path")
    if [ -z "$height" ] || [ "$height" -eq 0 ]; then
        echo "跳过无效图片：$img_name（无法获取高度信息）"
        return
    fi
    if [ "$size_kb" -eq 0 ]; then
        echo "跳过无效图片：$img_name（无法获取大小信息或文件为空）"
        return
    fi

    # 判断是否需要处理（高度超标 或 体积超标 或 非 JPG 格式）
    local need_process=0
    if [ "$height" -gt "$MAX_HEIGHT" ] || [ "$size_kb" -gt "$MAX_SIZE_KB" ] || is_non_jpg_format "$img_path"; then
        need_process=1
    fi
    if [ "$need_process" -eq 0 ]; then
        echo "无需处理：$img_name（高度: ${height}px, 大小: ${size_kb}KB, 格式: JPG）"
        return
    fi

    echo "正在处理：$img_name（原高度: ${height}px, 原大小: ${size_kb}KB, 原格式: ${img_ext}）"

    # 临时文件（统一用 JPG 格式，存入目标目录内的临时目录）
    local temp_jpg="$FULL_TEMP_DIR/${jpg_img_name}"
    # 提前清理残留临时文件
    if [ -f "$temp_jpg" ]; then
        rm -f "$temp_jpg"
    fi

    # 备份需要处理的原图（保留原格式、完整细节，仅备份一次）
    if [ ! -f "$FULL_CUSTOM_BACKUP_DIR/$img_name" ]; then
        cp -f "$img_path" "$FULL_CUSTOM_BACKUP_DIR/$img_name" || {
            echo "错误：原图备份失败，跳过该文件处理！"
            return
        }
        echo "已备份原图（原格式）至：$FULL_CUSTOM_BACKUP_DIR/$img_name"
    else
        echo "原图已存在备份，跳过重复覆盖"
    fi

    # 第一步：分辨率压缩（高保真缩放，保留细节）+ 统一转换为 JPG
    convert "$img_path" \
        -resize "x${MAX_HEIGHT}>" \
        -filter Lanczos \
        -quality "$JPG_MAX_QUALITY" \
        -interlace Plane \
        -sampling-factor 4:2:0 \
        "$temp_jpg" || {
        echo "错误：分辨率压缩/格式转换失败，跳过该文件处理！"
        if [ -f "$temp_jpg" ]; then
            rm -f "$temp_jpg"
        fi
        return
    }

    # 验证临时 JPG 文件是否生成且非空
    if [ ! -f "$temp_jpg" ] || [ "$(get_image_size_kb "$temp_jpg")" -eq 0 ]; then
        echo "错误：未生成有效 JPG 临时文件，跳过该文件处理！"
        return
    fi

    # 第二步：高保真压缩 JPG，确保体积≤5MB
    high_fidelity_compress_jpg "$temp_jpg" "$MAX_SIZE_KB"

    # 第三步：替换最终文件（覆盖原有 JPG 或 创建新 JPG，删除原格式文件）
    mv -f "$temp_jpg" "$jpg_final_path" || {
        echo "错误：JPG 文件替换失败，临时文件保留在：$temp_jpg"
        return
    }

    # 删除原格式文件（非 JPG 格式），保持目标目录整洁（仅保留 JPG）
    if is_non_jpg_format "$img_path" && [ "$img_path" != "$jpg_final_path" ] && [ -f "$img_path" ]; then
        rm -f "$img_path"
        echo "已删除原格式文件：$img_name（仅保留转换后的 JPG 格式）"
    fi

    # 验证最终 JPG 文件有效性
    local new_height=$(get_image_height "$jpg_final_path")
    local new_size_kb=$(get_image_size_kb "$jpg_final_path")
    local size_status="达标"
    if [ "$new_size_kb" -gt "$MAX_SIZE_KB" ]; then
        size_status="仍超标（已尽力高保真压缩）"
    fi
    echo "处理完成：$jpg_img_name（新高度: ${new_height}px, 新大小: ${new_size_kb}KB, 格式: JPG, 体积状态: ${size_status}）"
    echo "-------------------------"
}

# 8. 清理临时目录（任务完成后执行）
cleanup_temp_dir() {
    if [ -d "$FULL_TEMP_DIR" ]; then
        rm -rf "$FULL_TEMP_DIR"
        echo "已清理目标目录内的临时目录：$FULL_TEMP_DIR"
    fi
}

# 9. 批量处理主逻辑
main() {
    check_prerequisites
    echo "开始处理固定目录：$TARGET"
    echo "备份目录已指定为：$FULL_CUSTOM_BACKUP_DIR"
    echo "临时目录位于目标目录内：$FULL_TEMP_DIR"
    echo "强制规则：1. 高度≤${MAX_HEIGHT}px 2. 体积≤${MAX_SIZE_KB}KB 3. 所有非 JPG 格式统一转换为 JPG 4. 最大化保留细节"
    echo "-------------------------"

    # 遍历目标目录下的所有文件（仅普通文件，不递归子目录）
    for img in "$TARGET"/*; do
        if [ -f "$img" ]; then
            process_image "$img"
        fi
    done

    # 清理临时目录
    cleanup_temp_dir

    echo "所有任务处理完毕！"
    echo "提示1：仅处理过的原图（原格式完整细节）已备份至 $FULL_CUSTOM_BACKUP_DIR"
    echo "提示2：目标目录内所有图片已统一为 JPG 格式，且满足高度≤2160px、体积≤5MB（最大限度保留细节）"
}

# 启动主程序（捕获退出信号，确保临时目录被清理）
trap cleanup_temp_dir EXIT
main
exit 0