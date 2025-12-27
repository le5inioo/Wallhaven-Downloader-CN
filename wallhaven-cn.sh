#!/bin/bash
#
# 该脚本用于从 http://wallhaven.cc 网站获取精美壁纸
# 该脚本由 MacEarl 提供，基于 wallbase.cc 的下载脚本进行修改
# （wallbase.cc 脚本地址：https://github.com/sevensins/Wallbase-Downloader）
#
# 本脚本为 GNU Linux 系统编写，在 Mac OS 系统下也应能正常工作

REVISION=0.2.6.cn

#####################################
###   下载NSFW内容/个人收藏集所需配置   ###
#####################################
# 输入你的 API 密钥
# 可在此地址获取：https://wallhaven.cc/settings/account
APIKEY=" "
#####################################
###  结束 NSFW内容/个人收藏集所需配置  ###
#####################################

#####################################
###       核心配置选项             ###
#####################################
# 壁纸的保存路径
LOCATION=/vol2/1000/Media/Wallhaven
# 最终要下载的达标图片数量
WPNUMBER=24
# 开始下载的页码，默认值和最小值均为 1
STARTPAGE=1
# 下载类型：standard(newest, oldest, random, hits, mostfav)、search（搜索）、
# collections（收藏集，目前仅支持默认收藏集）、useruploads（用户上传，仅过滤条件生效）
TYPE=standard
# 要下载的壁纸分类，三个数字依次对应：通用类General,动漫类Anime,人物类People
# 1 表示启用该分类，0 表示禁用该分类
CATEGORIES=111
# 下载前的内容过滤规则，三个数字依次对应：安全内容（SFW）、可疑内容（Sketchy）、成人内容（NSFW）
# 1 表示包含该类内容，0 表示排除该类内容
FILTER=100
# 要下载的壁纸分辨率，留空表示下载所有分辨率（支持常见分辨率，详情参考 wallhaven 官网）
# 多个分辨率用英文逗号分隔，示例：1920x1080,1920x1200
RESOLUTION=
# 或者指定最小分辨率，注意：同时设置分辨率和最小分辨率时，分辨率设置会被忽略
# 为避免异常，只需设置其中一个选项，另一个留空即可
ATLEAST=1920x1080
# 要下载的壁纸宽高比，留空表示下载所有比例（可选值：4x3, 5x4, 16x9, 16x10, 21x9, 32x9, 48x9, 9x16, 10x16）
# 多个比例用英文逗号分隔，示例：4x3,16x9
ASPECTRATIO=16x9,16x10,21x9
# 结果排序模式（可选值：relevance 相关度, random 随机, date_added 添加时间, views 浏览量,
# favorites 收藏数, toplist 排行榜, toplist-beta 测试版排行榜）
MODE=favorites
# 当排序模式设为 toplist 时，指定排行榜的时间范围
# 可选值：1d（最近1天）, 3d（最近3天）, 1w（最近1周）, 1M（最近1个月）,
# 3M（最近3个月）, 6M（最近6个月）, 1y（最近1年）
TOPRANGE=
# 壁纸排序顺序（可选值：desc 降序, asc 升序）
ORDER=desc
# 收藏集名称，仅当 TYPE = collections 时生效
# 默认值为 wallhaven 平台的默认收藏集名称
# 如需下载自己的收藏集，请确保 USR 配置项填写你的账号用户名
# 如需下载他人的公开收藏集，请在此填写收藏集名称，并在 USR 配置项填写对方用户名
# 注意：收藏集下载仅会过滤图片数量，不会过滤分辨率、内容纯度等其他条件
COLLECTION="Default"
# 搜索关键词，仅当 TYPE = search 时生效
# 也可通过标签ID搜索，格式为 id:标签ID
# 标签ID可在此查询：https://wallhaven.cc/tags/
# 示例：通过「自然」标签搜索相关壁纸，可设置 QUERY="id:37"
QUERY="nature"
# 搜索包含指定颜色的图片
# 取值为 RGB 十六进制值（000000=黑色, ffffff=白色, ff0000=红色，以此类推）
COLOR=""
# 是否将搜索结果保存到独立子文件夹
# 0=不创建独立文件夹，1=创建独立文件夹
SUBFOLDER=0
# 要下载其壁纸的用户账号
# 用于 TYPE=useruploads（用户上传） 和 TYPE=collections（收藏集）场景
# 如需下载自己的收藏集，此项必须填写你的用户名
USR="AksumkA"
# 是否使用 GNU Parallel 加速下载（0=禁用, 1=启用），启用前请确保已安装 GNU Parallel
# 参考文档：normal.vs.parallel.txt（查看速度提升对比数据）
# 启用此选项可能导致 Cloudflare 屏蔽部分下载请求
PARALLEL=0
# 每页显示的缩略图数量
# 可在此地址修改该配置：https://wallhaven.cc/settings/browsing
# 有效值：24, 32, 64
# 若设置为 32 或 64，必须提供有效的 API 密钥
THUMBS=24

# 收藏数筛选阈值（只下载收藏数大于或等于该值的图片）
MIN_FAVORITES=220
# 图片大小限制（600KB ~ 10MB，已转换为字节单位）
MIN_FILE_SIZE=$((600 * 1024))    # 600KB
MAX_FILE_SIZE=$((10 * 1024 * 1024)) # 10MB

# 页码范围设置
# 最小页码（不能小于1）
MIN_PAGE=1
# 最大页码（不能小于最小页码）
MAX_PAGE=99
#####################################
###     结束核心配置选项           ###
#####################################

# 检查系统依赖软件是否已安装
function checkDependencies {
    printf "正在检查依赖软件..."
    dependencies=(wget jq sed shuf)
    [[ $PARALLEL == 1 ]] && dependencies+=(parallel)

    for name in "${dependencies[@]}"
    do
        [[ $(command -v "$name" 2>/dev/null) ]] ||
        { printf "\n%s 软件未安装，请使用系统包管理器安装，例如 'sudo apt install %s'" "$name" "$name";deps=1; }
    done

    if [[ $deps -ne 1 ]]
    then
        printf "检查完成（所有依赖已安装）\n"
    else
        printf "\n请安装上述缺失的软件后，重新运行本脚本\n"
        exit 1
    fi
} # /checkDependencies

#
# 设置认证请求头/API密钥，以获取更多功能使用权限
# 要求传入 1 个参数：
# 参数1: API 密钥字符串
#
function setAPIkeyHeader {
    # 检查参数是否有效，若无效则打印错误信息并退出脚本
    if [ $# -lt 1 ] || [ "$1" == '' ]
    then
        printf "请确保输入有效的 API 密钥，\n"
        printf "该密钥是下载 NSFW 内容和个人收藏集的必要条件，\n"
        printf "同时请确保你的每页缩略图配置与 THUMBS 变量的值保持一致\n\n"
        printf "按任意键退出脚本\n"
        read -r
        exit
    fi

    # 参数验证通过，设置 API 密钥请求头
    httpHeader="X-API-Key: $APIKEY"
} # /setAPIkeyHeader

#
# 检查收藏数是否达到设定阈值
# 参数：图片的收藏数字符串
# 返回值：0（达标）/1（不达标）
#
function is_favorite_ok {
    local favorites="$1"
    # 检查收藏数是否为纯数字，且大于或等于设定的最小收藏数阈值
    if [[ "$favorites" =~ ^[0-9]+$ ]] && [ "$favorites" -ge "$MIN_FAVORITES" ]; then
        return 0
    else
        return 1
    fi
} # /is_favorite_ok

#
# 检查文件大小是否在合法范围
# 参数：图片的网络访问URL
# 返回值：0（合法）/1（不合法）
#
function is_size_valid {
    local url="$1"
    # 仅获取HTTP响应头，不下载文件本体，提取Content-Length字段获取文件大小
    local size=$(wget --spider --server-response --header="$httpHeader" \
                      --keep-session-cookies --save-cookies cookies.txt --load-cookies cookies.txt \
                      "$url" 2>&1 | awk '/Content-Length/ {print $2}' | tr -d '\r\n')
    
    # 检查是否成功获取到有效的文件大小数值
    if ! [[ "$size" =~ ^[0-9]+$ ]]; then
        printf "\\t无法获取文件大小，将跳过该图片: %s\\n" "$url" >&2
        return 1
    fi

    # 判断文件大小是否在预设的合法范围内
    if [ "$size" -lt "$MIN_FILE_SIZE" ] || [ "$size" -gt "$MAX_FILE_SIZE" ]; then
        printf "\\t文件大小不合法（当前：%s 字节，要求范围：%s~%s 字节），将跳过该图片: %s\\n" "$size" "$MIN_FILE_SIZE" "$MAX_FILE_SIZE" "$url" >&2
        return 1
    fi
    return 0
} # /is_size_valid

#
# 下载包含壁纸缩略图的页面数据
#
function getPage {
    # 检查参数是否有效，若无效则打印错误信息并退出脚本
    if [ $# -lt 1 ]
    then
        printf "getPage 函数需要至少 1 个参数\\n"
        printf "参数1:\\twget -q 命令的附加参数\\n\\n"
        printf "按任意键退出脚本\\n"
        read -r
        exit
    fi

    # 参数验证通过，开始下载页面数据并保存为tmp文件
    WGET -O tmp "https://wallhaven.cc/api/v1/$1"
} # /getPage

#
# 下载当前页的所有达标图片，并返回本次成功下载的图片数量
# 返回值：本次成功下载的达标图片数量（仅纯数字，无其他额外输出）
#
function downloadWallpapers {
    local success_count=0  # 记录本次页面成功下载的达标图片数量

    # 将调试信息输出到标准错误（stderr），避免混入返回值影响统计
    exec 3>&1  # 保存标准输出(stdout)到文件描述符3

    if (( "$page" >= "$(jq -r ".meta.last_page" tmp)" ))
    then
        downloadEndReached=true
        exec 1>&3 3>&-  # 恢复标准输出，关闭临时文件描述符3
        echo 0  # 已到达最后一页，返回0表示无新图片可下载
        return
    fi

    # 先清理可能存在的下载临时文件，避免残留数据干扰
    [ -f ./download.txt ] && rm ./download.txt

    # 第一步：收集当前页所有符合条件（收藏数达标+大小合法+未重复下载）的图片索引
    local eligible_indices=()
    for ((i=0; i<THUMBS; i++))
    do
        imgURL=$(jq -r ".data[$i].path" tmp)
        favorites=$(jq -r ".data[$i].favorites" tmp)
        filename=$(echo "$imgURL"| sed "s/.*\///" )

        # 跳过值为null的无效图片链接
        if [[ "$imgURL" == "null" ]]; then
            continue
        fi

        # 检查收藏数是否达到设定阈值
        if ! is_favorite_ok "$favorites"; then
            printf "\\t跳过收藏数不足的图片 (当前收藏数: %s < 阈值: %s): %s\\n" "$favorites" "$MIN_FAVORITES" "$imgURL" >&2
            continue
        fi

        # 检查文件大小是否在合法范围
        if ! is_size_valid "$imgURL"; then
            continue
        fi

        # 检查该图片是否已经下载过，避免重复下载
        if grep -w "$filename" downloaded.txt >/dev/null; then
            printf "\\t该壁纸已下载过，将跳过: %s\\n" "$imgURL" >&2
            continue
        fi

        # 所有条件均达标，将该图片索引加入达标列表
        eligible_indices+=($i)
    done

    # 第二步：随机打乱达标图片索引顺序，实现页面内图片的随机选择
    local shuffled_indices=($(printf "%s\n" "${eligible_indices[@]}" | shuf))

    # 第三步：按随机顺序处理图片，直到达到总目标数量或当前页达标图片耗尽
    for i in "${shuffled_indices[@]}"
    do
        # 提前判断是否已满足总下载目标，若满足则停止处理当前页
        if [ $((total_success + success_count)) -ge $WPNUMBER ]; then
            break
        fi

        imgURL=$(jq -r ".data[$i].path" tmp)
        favorites=$(jq -r ".data[$i].favorites" tmp)
        filename=$(echo "$imgURL"| sed "s/.*\///" )

        # 并行下载模式：先将图片链接写入临时文件，后续统一批量处理
        if [ $PARALLEL == 1 ]
        then
            echo "$imgURL" >> download.txt
            success_count=$((success_count+1))
        else
            # 非并行下载模式：直接下载单个图片并统计成功数量
            if downloadWallpaper "$imgURL"
            then
                echo "$filename" >> downloaded.txt
                success_count=$((success_count+1))
                # 输出到标准错误，不影响函数返回值
                printf "\\t成功下载达标图片: %s (收藏数: %s)\\n" "$imgURL" "$favorites" >&2
            fi
        fi
    done

    # 处理并行下载，统计实际成功下载的图片数量
    if [ $PARALLEL == 1 ] && [ -f ./download.txt ]
    then
        # 导出所需函数和变量，供parallel子进程使用
        export -f WGET coolDown downloadWallpaper LOCATION MIN_FILE_SIZE MAX_FILE_SIZE
        # 先备份当前下载列表，用于后续统计成功数量
        cp ./download.txt ./download_tmp.txt
        # shellcheck disable=SC2016
        SHELL=$(type -p bash) parallel --gnu --no-notice \
            'imgURL={} && filename=$(echo "$imgURL"| sed "s/.*\///" ) && if downloadWallpaper $imgURL; then echo "$filename" >> downloaded.txt; fi' < download.txt
        
        # 通过对比下载前后的记录文件，统计并行下载的成功数量
        local pre_download_count=$(wc -l < downloaded.txt | awk '{print $1}')
        rm ./download.txt
        mv ./download_tmp.txt ./download.txt
        SHELL=$(type -p bash) parallel --gnu --no-notice \
            'imgURL={} && filename=$(echo "$imgURL"| sed "s/.*\///" ) && if downloadWallpaper $imgURL; then echo "$filename" >> downloaded.txt; fi' < download.txt
        local post_download_count=$(wc -l < downloaded.txt | awk '{print $1}')
        success_count=$((post_download_count - pre_download_count))
        
        # 清理并行下载产生的临时文件
        rm ./download.txt ./download_tmp.txt
    fi

    # 清理页面数据临时文件
    [ -f ./tmp ] && rm ./tmp

    # 恢复标准输出，关闭临时文件描述符
    exec 1>&3 3>&-

    # 仅返回纯数字的成功下载数量，无其他额外输出
    echo "$success_count"
    return
} # /downloadWallpapers

#
# 下载单个壁纸（通过猜测文件扩展名，无需下载壁纸详情页，仅需下载缩略图页即可完成下载）
#
function downloadWallpaper {
    if [[ "$1" != null ]]
    then
        # 明确指定下载目录为预设的保存路径，避免文件下载到错误目录
        WGET -P "$LOCATION" "$1"
        return $?
    else
        return 1
    fi
} # /downloadWallpaper

#
# 当检测到服务器速率限制时，休眠30秒后重新尝试下载
#
function coolDown {
    # 输出提示信息到标准错误，不影响其他输出逻辑
    printf "\\t -检测到服务器速率限制，将休眠30秒后重试\\n" >&2
    sleep 30
    # 冷却完成后，重新尝试下载并指定保存目录
    WGET -P "$LOCATION" "$@"
} # /coolDown

#
# wget 工具封装函数，包含默认配置参数
# 参数0: wget 附加参数（可选）
# 参数1: 要下载的文件网络地址
#
function WGET {
    # 检查参数是否有效，若无效则打印错误信息并退出脚本
    if [ $# -lt 1 ]
    then
        printf "WGET 函数需要至少 1 个参数\\n"
        printf "参数0:\\twget 附加参数（可选）\\n"
        printf "参数1:\\t要下载的文件网络地址\\n\\n"
        printf "按任意键退出脚本\\n"
        read -r
        exit 1
    fi

    # 默认wget命令配置，包含会话保持和速率限制处理
    wget -q --header="$httpHeader" --keep-session-cookies \
         --save-cookies cookies.txt --load-cookies cookies.txt "$@" 2>/dev/null | \
         grep "429 Too Many Requests" >/dev/null && coolDown "$@"

    return "${PIPESTATUS[0]}"
} # /WGET

#
# 显示脚本帮助信息（包含有效命令行参数说明）
#
function helpText {
    printf "使用方法: ./wallhaven.sh [可选参数]\\n"
    printf "从 wallhaven.cc 网站下载壁纸\\n\\n"
    printf "若未指定任何可选参数，将使用脚本内部预设的默认配置\\n\\n"
    printf " -l, --location\\t\\t壁纸保存目录路径\\n"
    printf " -n, --number\\t\\t要下载的壁纸总数量\\n"
    printf " -s, --startpage\\t开始下载的起始页码\\n"
    printf " -t, --type\\t\\t下载类型：standard, search, \\n\\t\\t\\tcollections, useruploads\\n"
    printf " -c, --categories\\t壁纸分类筛选，例如 111 表示启用通用、\\n\\t\\t\\t动漫、人物三类，1=启用，0=禁用\\n"
    printf " -f, --filter\\t\\t内容纯度过滤，例如 111 表示包含\\n\\t\\t\\tSFW、可疑、NSFW 内容，1=包含，0=排除\\n"
    printf " -r, --resolution\\t指定下载的分辨率，多个分辨率用\\n\\t\\t\\t英文逗号分隔\\n"
    printf " -g, --atleast\\t\\t最小分辨率限制，将显示所有分辨率大于\\n\\t\\t\\t该值的图片，请勿与 -r（--resolution）同时使用\\n"
    printf " -a, --aspectratio\\t仅下载指定宽高比的壁纸，多个宽高比\\n\\t\\t\\t用英文逗号分隔\\n"
    printf " -m, --mode\\t\\t壁纸排序模式：relevance, random,\\n\\t\\t\\tdate_added, views, favorites \\n"
    printf " -o, --order\\t\\t排序顺序：升序（asc）或降序（desc）\\n"
    printf " -b, --collection\\t要下载的收藏集名称\\n"
    printf " -q, --query\\t\\t搜索关键词，例如 'mario'，需用单引号包裹，\\n\\t\\t\\t搜索精确短语时，在单引号内使用双引号，\\n\\t\\t\\t例如 '\"super mario\"'\\n"
    printf " -d, --dye, --color\\t搜索包含指定颜色的壁纸，颜色值为\\n"
    printf "\\t\\t\\t不带 # 前缀的 RGB 十六进制值\\n"
    printf " -u, --user\\t\\t要下载其壁纸的用户账号名\\n"
    printf " -p, --parallel\\t\\t是否启用 GNU Parallel 加速下载（1=启用，0=禁用）\\n"
    printf " --min-page\\t\\t最小页码限制（默认1）\\n"
    printf " --max-page\\t\\t最大页码限制（默认100）\\n"
    printf " -v, --version\\t\\t显示当前脚本版本号\\n"
    printf " -h, --help\\t\\t显示此帮助信息并退出脚本\\n\\n"
    printf "使用示例:\\n"
    printf "./wallhaven.sh\\t-l ~/wp/ -n 48 -s 1 -t standard -c 101 -f 111"
    printf " -r 1920x1080 \\n\\t\\t-a 16x9 -m random -o desc -p 1 --min-page 5 --max-page 50\\n\\n"
    printf "该示例将下载 48 张随机壁纸，分辨率 1920x1080，宽高比 16x9，\\n保存到 ~/wp/ 目录，从第 1 页开始，分类为通用和人物，\\n包含 SFW、可疑、NSFW 内容，使用 GNU Parallel 加速下载，\\n并限制只从5-50页范围内下载\\n\\n"
    printf "脚本最新版本获取地址: "
    printf "<https://github.com/macearl/Wallhaven-Downloader>\\n"
} # /helpText

# 命令行参数解析逻辑
while [[ $# -ge 1 ]]
    do
    key="$1"

    case $key in
        -l|--location)
            LOCATION="$2"
            shift;;
        -n|--number)
            WPNUMBER="$2"
            shift;;
        -s|--startpage)
            STARTPAGE="$2"
            shift;;
        -t|--type)
            TYPE="$2"
            shift;;
        -c|--categories)
            CATEGORIES="$2"
            shift;;
        -f|--filter)
            FILTER="$2"
            shift;;
        -r|--resolution)
            RESOLUTION="$2"
            shift;;
        -g|--atleast)
            ATLEAST="$2"
            shift;;
        -a|--aspectratio)
            ASPECTRATIO="$2"
            shift;;
        -m|--mode)
            MODE="$2"
            shift;;
        -o|--order)
            ORDER="$2"
            shift;;
        -b|--collection)
            COLLECTION="$2"
            shift;;
        -q|--query)
            QUERY=${2//\'/}
            shift;;
        -d|--dye|--color)
            COLOR="$2"
            shift;;
        -u|--user)
            USR="$2"
            shift;;
        -p|--parallel)
            PARALLEL="$2"
            shift;;
        --min-page)
            MIN_PAGE="$2"
            shift;;
        --max-page)
            MAX_PAGE="$2"
            shift;;
        -h|--help)
            helpText
            exit
            ;;
        -v|--version)
            printf "Wallhaven 壁纸下载工具 %s\\n" "$REVISION"
            exit
            ;;
        *)
            printf "未知命令行选项: %s\\n" "$1"
            helpText
            exit
            ;;
    esac
    shift # 跳过已解析的参数或参数值
    done

# 验证页码范围有效性
if ! [[ "$MIN_PAGE" =~ ^[0-9]+$ ]] || [ "$MIN_PAGE" -lt 1 ]; then
    printf "错误：最小页码必须是大于等于1的整数，当前值: %s\\n" "$MIN_PAGE"
    exit 1
fi

if ! [[ "$MAX_PAGE" =~ ^[0-9]+$ ]] || [ "$MAX_PAGE" -lt "$MIN_PAGE" ]; then
    printf "错误：最大页码必须是大于等于最小页码的整数，当前值: %s\\n" "$MAX_PAGE"
    exit 1
fi

checkDependencies

# 若为搜索类型且启用独立子文件夹，创建对应的子文件夹用于保存搜索结果
# 注意：每个搜索关键词会生成独立的下载记录，可能导致重复下载相同壁纸
if [ "$TYPE" == search ] && [ "$SUBFOLDER" == 1 ]
then
    LOCATION+=/$(echo "$QUERY" | sed -e "s/ /_/g" -e "s/+/_/g" -e  "s/\\//_/g")
fi

# 若壁纸保存目录不存在，创建该目录
if [ ! -d "$LOCATION" ]
then
    mkdir -p "$LOCATION"
fi

cd "$LOCATION" || exit

# 若下载记录文件不存在，创建该文件用于记录已下载的壁纸
if [ ! -f ./downloaded.txt ]
then
    touch downloaded.txt
fi

# 仅在需要时设置认证请求头（如下载NSFW内容、收藏集、每页缩略图数量非24时）
if  [ "$FILTER" == 001 ] || [ "$FILTER" == 011 ] || [ "$FILTER" == 111 ] \
    || [ "$TYPE" == collections ] || [ "$THUMBS" != 24 ]
then
    setAPIkeyHeader "$APIKEY"
fi

# 全局变量初始化：统计总成功下载的达标图片数量
total_success=0
downloadEndReached=false

if [ "$TYPE" == standard ]
then
    # 初始化随机数生成器，确保每次运行脚本的随机序列不同
    RANDOM=$$
    
    # 先获取总页数，并将其限制在配置的页码范围内
    page=1
    s1="search?page=$page&categories=$CATEGORIES&purity=$FILTER&"
    s1+="atleast=$ATLEAST&resolutions=$RESOLUTION&ratios=$ASPECTRATIO"
    s1+="&sorting=$MODE&order=$ORDER&topRange=$TOPRANGE&colors=$COLOR"
    getPage "$s1"
    total_pages=$(jq -r ".meta.last_page" tmp)
    # 限制页数在配置的范围内
    if [ "$total_pages" -gt "$MAX_PAGE" ]; then
        total_pages="$MAX_PAGE"
    fi
    if [ "$total_pages" -lt "$MIN_PAGE" ]; then
        total_pages="$MIN_PAGE"
    fi
    rm -f tmp

    # 循环执行：直到总成功数达到目标数量，或已无更多页面可下载
    while [ $total_success -lt $WPNUMBER ] && [ "$downloadEndReached" != true ]
    do
        # 随机选择配置范围内的页码，实现页面级随机下载
        page=$((RANDOM % (total_pages - MIN_PAGE + 1) + MIN_PAGE))
        printf "\\n===== 正在随机获取第 %s 页数据（页码范围：%d-%d页）=====\\n" "$page" "$MIN_PAGE" "$total_pages"
        
        s1="search?page=$page&categories=$CATEGORIES&purity=$FILTER&"
        s1+="atleast=$ATLEAST&resolutions=$RESOLUTION&ratios=$ASPECTRATIO"
        s1+="&sorting=$MODE&order=$ORDER&topRange=$TOPRANGE&colors=$COLOR"
        getPage "$s1"
        printf "\\t- 第 %s 页数据获取完成!\\n" "$page"

        printf "正在处理第 %s 页的达标图片\\n" "$page"
        # 获取本次页面成功下载的达标图片数量
        current_success=$(downloadWallpapers)
        # 累加总成功下载数量
        total_success=$((total_success + current_success))

        printf "第 %s 页处理完成：本次成功下载 %s 张达标图片，累计成功下载 %s 张（目标 %s 张）\\n" \
               "$page" "$current_success" "$total_success" "$WPNUMBER"
    done

elif [ "$TYPE" == search ] || [ "$TYPE" == useruploads ]
then
    # 初始化随机数生成器，确保每次运行脚本的随机序列不同
    RANDOM=$$
    
    # 先获取总页数，并将其限制在配置的页码范围内
    page=1
    s1="search?page=$page&categories=$CATEGORIES&purity=$FILTER&"
    s1+="atleast=$ATLEAST&resolutions=$RESOLUTION&ratios=$ASPECTRATIO"
    s1+="&sorting=$MODE&order=desc&topRange=$TOPRANGE&colors=$COLOR"
    if [ "$TYPE" == search ]; then
        s1+="&q=$QUERY"
    elif [ "$TYPE" == useruploads ]; then
        s1+="&q=@$USR"
    fi
    getPage "$s1"
    total_pages=$(jq -r ".meta.last_page" tmp)
    # 限制页数在配置的范围内
    if [ "$total_pages" -gt "$MAX_PAGE" ]; then
        total_pages="$MAX_PAGE"
    fi
    if [ "$total_pages" -lt "$MIN_PAGE" ]; then
        total_pages="$MIN_PAGE"
    fi
    rm -f tmp

    # 循环执行：直到总成功数达到目标数量，或已无更多页面可下载
    while [ $total_success -lt $WPNUMBER ] && [ "$downloadEndReached" != true ]
    do
        # 随机选择配置范围内的页码，实现页面级随机下载
        page=$((RANDOM % (total_pages - MIN_PAGE + 1) + MIN_PAGE))
        printf "\\n===== 正在随机获取第 %s 页数据（页码范围：%d-%d页）=====\\n" "$page" "$MIN_PAGE" "$total_pages"
        
        s1="search?page=$page&categories=$CATEGORIES&purity=$FILTER&"
        s1+="atleast=$ATLEAST&resolutions=$RESOLUTION&ratios=$ASPECTRATIO"
        s1+="&sorting=$MODE&order=desc&topRange=$TOPRANGE&colors=$COLOR"
        if [ "$TYPE" == search ]; then
            s1+="&q=$QUERY"
        elif [ "$TYPE" == useruploads ]; then
            s1+="&q=@$USR"
        fi

        getPage "$s1"
        printf "\\t- 第 %s 页数据获取完成!\\n" "$page"

        printf "正在处理第 %s 页的达标图片\\n" "$page"
        # 获取本次页面成功下载的达标图片数量
        current_success=$(downloadWallpapers)
        # 累加总成功下载数量
        total_success=$((total_success + current_success))

        printf "第 %s 页处理完成：本次成功下载 %s 张达标图片，累计成功下载 %s 张（目标 %s 张）\\n" \
               "$page" "$current_success" "$total_success" "$WPNUMBER"
    done

elif [ "$TYPE" == collections ]
then
    if [ "$USR" == "" ]
    then
        printf "请检查 USR 变量的配置值\\n"
        printf "下载收藏集必须指定对应的用户账号名\\n\\n"
        printf "按任意键退出脚本\\n"
        read -r
        exit
    fi

    getPage "collections/$USR"

    i=0
    while
        label=$(jq -e -r ".data[$i].label" tmp)
        id=$(jq -e -r ".data[$i].id" tmp)
        collectionsize=$(jq -e -r ".data[$i].count" tmp)
        [[ $label != "$COLLECTION" && $label != null ]]
    do
        (( i++ ))
    done

    if [ -z "$id" ]
    then
        printf "请检查 COLLECTION 变量的配置值\\n"
        printf "似乎不存在名为 \"%s\" 的收藏集\\n\\n" \
                "$COLLECTION"
        printf "按任意键退出脚本\\n"
        read -r
        exit
    fi

    # 初始化随机数生成器，确保每次运行脚本的随机序列不同
    RANDOM=$$
    
    # 先获取收藏集总页数，并将其限制在配置的页码范围内
    page=1
    getPage "collections/$USR/$id?page=$page"
    total_pages=$(jq -r ".meta.last_page" tmp)
    # 限制页数在配置的范围内
    if [ "$total_pages" -gt "$MAX_PAGE" ]; then
        total_pages="$MAX_PAGE"
    fi
    if [ "$total_pages" -lt "$MIN_PAGE" ]; then
        total_pages="$MIN_PAGE"
    fi
    rm -f tmp

    # 循环执行：直到总成功数达到目标数量、收藏集图片耗尽，或已无更多页面可下载
    while [ $total_success -lt $WPNUMBER ] && [ $total_success -lt $collectionsize ] && [ "$downloadEndReached" != true ]
    do
        # 随机选择配置范围内的页码，实现收藏集页面级随机下载
        page=$((RANDOM % (total_pages - MIN_PAGE + 1) + MIN_PAGE))
        printf "\\n===== 正在随机获取收藏集第 %s 页数据（页码范围：%d-%d页）=====\\n" "$page" "$MIN_PAGE" "$total_pages"
        
        getPage "collections/$USR/$id?page=$page"
        printf "\\t- 收藏集第 %s 页数据获取完成!\\n" "$page"

        printf "正在处理收藏集第 %s 页的达标图片\\n" "$page"
        # 获取本次页面成功下载的达标图片数量
        current_success=$(downloadWallpapers)
        # 累加总成功下载数量
        total_success=$((total_success + current_success))

        printf "收藏集第 %s 页处理完成：本次成功下载 %s 张达标图片，累计成功下载 %s 张（目标 %s 张，收藏集总数量 %s 张）\\n" \
               "$page" "$current_success" "$total_success" "$WPNUMBER" "$collectionsize"
    done
else
    printf "TYPE 变量配置错误，请检查该变量的取值\\n"
    exit 1
fi

# 清理脚本运行过程中产生的临时文件
[ -f ./cookies.txt ] && rm ./cookies.txt
[ -f ./tmp ] && rm ./tmp

# 最终任务完成提示信息
printf "\\n=====================================\\n"
if [ $total_success -ge $WPNUMBER ]
then
    printf "✅ 任务完成：已成功下载 %s 张达标图片（目标 %s 张）\\n" "$total_success" "$WPNUMBER"
else
    printf "⚠️  任务终止：已无更多达标图片，最终成功下载 %s 张达标图片（目标 %s 张）\\n" "$total_success" "$WPNUMBER"
fi
printf "📁 图片保存目录：%s\\n" "$LOCATION"
printf "=====================================\\n"

exit 0
