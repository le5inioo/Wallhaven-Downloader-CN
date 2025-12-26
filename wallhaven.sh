#!/bin/bash
#
# This script gets the beautiful wallpapers from http://wallhaven.cc
# This script is brought to you by MacEarl and is based on the
# script for wallbase.cc (https://github.com/sevensins/Wallbase-Downloader)
#
# This Script is written for GNU Linux, it should work under Mac OS

REVISION=0.2.6

#####################################
###   Needed for NSFW/Favorites   ###
#####################################
# Enter your API key
# you can get it here: https://wallhaven.cc/settings/account
APIKEY=" "
#####################################
### End needed for NSFW/Favorites ###
#####################################

#####################################
###     Configuration Options     ###
#####################################
# Where should the Wallpapers be stored?
LOCATION=/vol2/1000/Media/Wallhaven
# How many Wallpapers should be downloaded (最终要拿到的达标图片数量)
WPNUMBER=24
# What page to start downloading at, default and minimum of 1.
STARTPAGE=1
# Type standard (newest, oldest, random, hits, mostfav), search, collections
# (for now only the default collection), useruploads (if selected, only
# FILTER variable will change the outcome)
TYPE=standard
# From which Categories should Wallpapers be downloaded, first number is
# for General, second for Anime, third for People, 1 to enable category,
# 0 to disable it
CATEGORIES=111
# filter wallpapers before downloading, first number is for sfw content,
# second for sketchy content, third for nsfw content, 1 to enable,
# 0 to disable
FILTER=100
# Which Resolutions should be downloaded, leave empty for all (most common
# resolutions possible, for details see wallhaven site), separate multiple
# resolutions with , eg. 1920x1080,1920x1200
RESOLUTION=
# alternatively specify a minimum resolution, please note that specifying
# both resolutions and a minimum resolution will result in the desired
# resolutions being ignored, to avoid unwanted behavior only set one of the
# two options and leave the other blank
ATLEAST=1920x1080
# Which aspectratios should be downloaded, leave empty for all (possible
# values: 4x3, 5x4, 16x9, 16x10, 21x9, 32x9, 48x9, 9x16, 10x16), separate mutliple ratios
# with , eg. 4x3,16x9
ASPECTRATIO=16x9,16x10,21x9
# Which Type should be displayed (relevance, random, date_added, views,
# favorites, toplist, toplist-beta)
MODE=favorites
# if MODE is set to toplist show the toplist for the given timeframe
# possible values: 1d (last day), 3d (last 3 days), 1w (last week),
# 1M (last month), 3M (last 3 months), 6M (last 6 months), 1y (last year)
TOPRANGE=
# How should the wallpapers be ordered (desc, asc)
ORDER=desc
# Collections, only used if TYPE = collections
# specify the name of the collection you want to download
# Default is the default collection name on wallhaven
# If you want to download your own Collections make sure USR is set to your username
# If you want to download someone elses public collection enter the name here
# and the username under USR
# Please note that the only filter option applied to Collections is the Number
# of Wallpapers to download, there is no filter for resolution, purity, ...
COLLECTION="Default"
# Searchterm, only used if TYPE = search
# you can also search by tags, use id:TAGID
# to get the tag id take a look at: https://wallhaven.cc/tags/
# for example: to search for nature related wallpapers via the nature tag
# instead of the keyword use QUERY="id:37"
QUERY="nature"
# Search images containing color
# values are RGB (000000 = black, ffffff = white, ff0000 = red, ...)
COLOR=""
# Should the search results be saved to a separate subfolder?
# 0 for no separate folder, 1 for separate subfolder
SUBFOLDER=0
# User from which wallpapers should be downloaded
# used for TYPE=useruploads and TYPE=collections
# If you want to download your own Collection this has to be set to your username
USR="AksumkA"
# use gnu parallel to speed up the download (0, 1), if set to 1 make sure
# you have gnuparallel installed, see normal.vs.parallel.txt for
# speed improvements
# using this option can lead to cloudflare blocking some of the downloads
PARALLEL=0
# custom thumbnails per page
# changeable here: https://wallhaven.cc/settings/browsing
# valid values: 24, 32, 64
# if set to 32 or 64 you need to provide an api key
THUMBS=24

# 收藏数筛选阈值（只下载收藏数≥此值的图片）
MIN_FAVORITES=200
# 图片大小限制（500KB ~ 10MB，已转换为字节）
MIN_FILE_SIZE=$((500 * 1024))    # 500KB
MAX_FILE_SIZE=$((10 * 1024 * 1024)) # 10MB
#####################################
###   End Configuration Options   ###
#####################################

function checkDependencies {
    printf "Checking dependencies..."
    dependencies=(wget jq sed shuf)
    [[ $PARALLEL == 1 ]] && dependencies+=(parallel)

    for name in "${dependencies[@]}"
    do
        [[ $(command -v "$name" 2>/dev/null) ]] ||
        { printf "\n%s needs to be installed. Use your package manager to do so, e.g. 'sudo apt install %s'" "$name" "$name";deps=1; }
    done

    if [[ $deps -ne 1 ]]
    then
        printf "OK\n"
    else
        printf "\nInstall the above and rerun this script\n"
        exit 1
    fi
} # /checkDependencies

#
# sets the authentication header/API key to give the user more functionality
# requires 1 arguments:
# arg1: API key
#
function setAPIkeyHeader {
    # checking parameters -> if not ok print error and exit script
    if [ $# -lt 1 ] || [ "$1" == '' ]
    then
        printf "Please make sure to enter a valid API key,\n"
        printf "it is needed for NSFW Content and downloading \n"
        printf "your Collections also make sure your Thumbnails per\n"
        printf "Page Setting matches the THUMBS Variable\n\n"
        printf "Press any key to exit\n"
        read -r
        exit
    fi

    # everythings ok --> set api key header
    httpHeader="X-API-Key: $APIKEY"
} # /setAPIkeyHeader

#
# 检查收藏数是否达标
# 参数：收藏数
# 返回：0（达标）/1（不达标）
#
function is_favorite_ok {
    local favorites="$1"
    # 检查收藏数是否为数字且≥阈值
    if [[ "$favorites" =~ ^[0-9]+$ ]] && [ "$favorites" -ge "$MIN_FAVORITES" ]; then
        return 0
    else
        return 1
    fi
} # /is_favorite_ok

#
# 检查文件大小是否在合法范围 (500KB ~ 10MB)
# 参数：文件URL
# 返回：0（合法）/1（不合法）
#
function is_size_valid {
    local url="$1"
    # 仅获取响应头，不下载文件，获取Content-Length
    local size=$(wget --spider --server-response --header="$httpHeader" \
                      --keep-session-cookies --save-cookies cookies.txt --load-cookies cookies.txt \
                      "$url" 2>&1 | awk '/Content-Length/ {print $2}' | tr -d '\r\n')
    
    # 检查是否获取到有效大小
    if ! [[ "$size" =~ ^[0-9]+$ ]]; then
        printf "\\t无法获取文件大小，跳过: %s\\n" "$url" >&2
        return 1
    fi

    # 判断大小是否在合法范围
    if [ "$size" -lt "$MIN_FILE_SIZE" ] || [ "$size" -gt "$MAX_FILE_SIZE" ]; then
        printf "\\t文件大小不合法（%s 字节，要求：%s~%s 字节），跳过: %s\\n" "$size" "$MIN_FILE_SIZE" "$MAX_FILE_SIZE" "$url" >&2
        return 1
    fi
    return 0
} # /is_size_valid

#
# downloads Page with Thumbnails
#
function getPage {
    # checking parameters -> if not ok print error and exit script
    if [ $# -lt 1 ]
    then
        printf "getPage expects at least 1 argument\\n"
        printf "arg1:\\tparameters for the wget -q command\\n\\n"
        printf "press any key to exit\\n"
        read -r
        exit
    fi

    # parameters ok --> get page
    WGET -O tmp "https://wallhaven.cc/api/v1/$1"
} # /getPage

#
# 下载当前页的达标图片，并返回本次成功下载的数量
# 返回值：本次成功下载的达标图片数（纯数字，无其他输出）
#
function downloadWallpapers {
    local success_count=0  # 记录本次页面成功下载的达标图片数

    # 将调试信息输出到标准错误（stderr），避免混入返回值
    exec 3>&1  # 保存标准输出(stdout)到文件描述符3

    if (( "$page" >= "$(jq -r ".meta.last_page" tmp)" ))
    then
        downloadEndReached=true
        exec 1>&3 3>&-  # 恢复stdout，关闭文件描述符3
        echo 0  # 已到最后一页，返回0
        return
    fi

    # 先清理可能存在的下载临时文件
    [ -f ./download.txt ] && rm ./download.txt

    # 第一步：收集当前页所有达标（收藏数+大小）的图片索引
    local eligible_indices=()
    for ((i=0; i<THUMBS; i++))
    do
        imgURL=$(jq -r ".data[$i].path" tmp)
        favorites=$(jq -r ".data[$i].favorites" tmp)
        filename=$(echo "$imgURL"| sed "s/.*\///" )

        # 跳过null URL
        if [[ "$imgURL" == "null" ]]; then
            continue
        fi

        # 检查收藏数是否达标
        if ! is_favorite_ok "$favorites"; then
            printf "\\t跳过收藏数不足的图片 (收藏数: %s < %s): %s\\n" "$favorites" "$MIN_FAVORITES" "$imgURL" >&2
            continue
        fi

        # 检查文件大小是否合法
        if ! is_size_valid "$imgURL"; then
            continue
        fi

        # 检查是否已下载
        if grep -w "$filename" downloaded.txt >/dev/null; then
            printf "\\tWallpaper %s 已下载过!\\n" "$imgURL" >&2
            continue
        fi

        # 所有条件达标，加入索引列表
        eligible_indices+=($i)
    done

    # 第二步：随机打乱达标索引顺序（实现页面内随机选择）
    local shuffled_indices=($(printf "%s\n" "${eligible_indices[@]}" | shuf))

    # 第三步：按随机顺序处理图片，直到达到目标数量
    for i in "${shuffled_indices[@]}"
    do
        # 提前判断是否已满足总目标，满足则停止
        if [ $((total_success + success_count)) -ge $WPNUMBER ]; then
            break
        fi

        imgURL=$(jq -r ".data[$i].path" tmp)
        favorites=$(jq -r ".data[$i].favorites" tmp)
        filename=$(echo "$imgURL"| sed "s/.*\///" )

        # 并行下载：先写入临时文件，后续统一处理
        if [ $PARALLEL == 1 ]
        then
            echo "$imgURL" >> download.txt
            success_count=$((success_count+1))
        else
            # 非并行下载：直接下载并统计成功数
            if downloadWallpaper "$imgURL"
            then
                echo "$filename" >> downloaded.txt
                success_count=$((success_count+1))
                # 输出到stderr，不影响函数返回值
                printf "\\t成功下载达标图片: %s (收藏数: %s)\\n" "$imgURL" "$favorites" >&2
            fi
        fi
    done

    # 处理并行下载，统计实际成功数
    if [ $PARALLEL == 1 ] && [ -f ./download.txt ]
    then
        # 导出函数和变量供parallel使用
        export -f WGET coolDown downloadWallpaper LOCATION MIN_FILE_SIZE MAX_FILE_SIZE
        # 先备份当前下载列表，用于统计成功数
        cp ./download.txt ./download_tmp.txt
        # shellcheck disable=SC2016
        SHELL=$(type -p bash) parallel --gnu --no-notice \
            'imgURL={} && filename=$(echo "$imgURL"| sed "s/.*\///" ) && if downloadWallpaper $imgURL; then echo "$filename" >> downloaded.txt; fi' < download.txt
        
        # 统计并行下载的成功数（对比下载前后的downloaded.txt差异）
        local pre_download_count=$(wc -l < downloaded.txt | awk '{print $1}')
        rm ./download.txt
        mv ./download_tmp.txt ./download.txt
        SHELL=$(type -p bash) parallel --gnu --no-notice \
            'imgURL={} && filename=$(echo "$imgURL"| sed "s/.*\///" ) && if downloadWallpaper $imgURL; then echo "$filename" >> downloaded.txt; fi' < download.txt
        local post_download_count=$(wc -l < downloaded.txt | awk '{print $1}')
        success_count=$((post_download_count - pre_download_count))
        
        rm ./download.txt ./download_tmp.txt
    fi

    # 清理临时文件
    [ -f ./tmp ] && rm ./tmp

    # 恢复标准输出，关闭临时文件描述符
    exec 1>&3 3>&-

    # 仅返回纯数字的成功数，无其他输出
    echo "$success_count"
    return
} # /downloadWallpapers

#
# downloads a single Wallpaper by guessing its extension, this eliminates
# the need to download each wallpaper page, now only the thumbnail page
# needs to be downloaded
#
function downloadWallpaper {
    if [[ "$1" != null ]]
    then
        # 明确指定下载目录为LOCATION，避免文件下载到错误路径
        WGET -P "$LOCATION" "$1"
        return $?
    else
        return 1
    fi
} # /downloadWallpaper

#
# Waits for 30 seconds if rate limiting is detected
#
function coolDown {
    # 输出到stderr，不影响函数返回值
    printf "\\t -检测到速率限制，休眠30秒\\n" >&2
    sleep 30
    # 冷却后重试下载时指定目录
    WGET -P "$LOCATION" "$@"
} # /coolDown

#
# wrapper for wget with some default arguments
# arg0: additional arguments for wget (optional)
# arg1: file to download
#
function WGET {
    # checking parameters -> if not ok print error and exit script
    if [ $# -lt 1 ]
    then
        printf "WGET expects at least 1 argument\\n"
        printf "arg0:\\tadditional arguments for wget (optional)\\n"
        printf "arg1:\\tfile to download\\n\\n"
        printf "press any key to exit\\n"
        read -r
        exit 1
    fi

    # 保留必要参数，确保认证和会话有效
    wget -q --header="$httpHeader" --keep-session-cookies \
         --save-cookies cookies.txt --load-cookies cookies.txt "$@" 2>/dev/null | \
         grep "429 Too Many Requests" >/dev/null && coolDown "$@"

    return "${PIPESTATUS[0]}"
} # /WGET

#
# displays help text (valid command line arguments)
#
function helpText {
    printf "Usage: ./wallhaven.sh [OPTIONS]\\n"
    printf "Download wallpapers from wallhaven.cc\\n\\n"
    printf "If no options are specified, default values from within the "
    printf "script will be used\\n\\n"
    printf " -l, --location\\t\\tlocation where the wallpapers will be "
    printf "stored\\n"
    printf " -n, --number\\t\\tNumber of Wallpapers to download\\n"
    printf " -s, --startpage\\tpage to start downloading from\\n"
    printf " -t, --type\\t\\tType of download Operation: standard, search, "
    printf "\\n\\t\\t\\tcollections, useruploads\\n"
    printf " -c, --categories\\tcategories to download from, eg. 111 for "
    printf "General,\\n\\t\\t\\tAnime and People, 1 to include, 0 to exclude\\n"
    printf " -f, --filter\\t\\tfilter out content based on purity rating, "
    printf "eg. 111 \\n\\t\\t\\tfor SFW, sketchy and NSFW content, 1 to "
    printf "include, \\n\\t\\t\\t0 to exclude\\n"
    printf " -r, --resolution\\tresolutions to download, separate mutliple"
    printf " \\n\\t\\t\\tresolutions by ,\\n"
    printf " -g, --atleast\\t\\tminimum resolution, show all images with a"
    printf "\\n\\t\\t\\tresolution greater than the specified value"
    printf "\\n\\t\\t\\tdo not use in combination with -r (--resolution)\\n"
    printf " -a, --aspectratio\\tonly download wallpaper with given "
    printf "aspectratios, \\n\\t\\t\\tseparate multiple aspectratios by ,\\n"
    printf " -m, --mode\\t\\tsorting mode for wallpapers: relevance, random"
    printf ",\\n\\t\\t\\tdate_added, views, favorites \\n"
    printf " -o, --order\\t\\torder ascending (asc) or descending "
    printf "(desc)\\n"
    printf " -b, --collection\\tname of the collections to download\\n"
    printf " -q, --query\\t\\tsearch query, eg. 'mario', single "
    printf "quotes needed,\\n\\t\\t\\tfor searching exact phrases use double "
    printf "quotes \\n\\t\\t\\tinside single quotes, eg. '\"super mario\"'"
    printf "\\n"
    printf " -d, --dye, --color\\tsearch for wallpapers containing the "
    printf "given color,\\n"
    printf "\\t\\t\\tcolor values are RGB without a leading #\\n"
    printf " -u, --user\\t\\tdownload wallpapers from given user\\n"
    printf " -p, --parallel\\t\\tmake use of gnu parallel (1 to enable, 0 "
    printf "to disable)\\n"
    printf " -v, --version\\t\\tshow current version\\n"
    printf " -h, --help\\t\\tshow this help text and exit\\n\\n"
    printf "Examples:\\n"
    printf "./wallhaven.sh\\t-l ~/wp/ -n 48 -s 1 -t standard -c 101 -f 111"
    printf " -r 1920x1080 \\n\\t\\t-a 16x9 -m random -o desc -p 1\\n\\n"
    printf "Download 48 random wallpapers with a resolution of 1920x1080 "
    printf "and \\nan aspectratio of 16x9 to ~/wp/ starting with page 1 "
    printf "from the \\ncategories general and people including SFW, sketchy"
    printf " and NSWF Content\\nwhile utilizing gnu parallel\\n\\n"
    printf "./wallhaven.sh\\t-l ~/wp/ -n 48 -s 1 -t search -c 111 -f 100 -r "
    printf "1920x1080 -a 16x9\\n\\t\\t-m relevance -o desc -q "
    printf "'\"super mario\"' -d cc0000 -p 1\\n\\n"
    printf "Download 48 wallpapers related to the search query "
    printf "\"super mario\" containing \\nthe color #cc0000 with a resolution"
    printf " of 1920x1080 and an aspectratio of 16x9\\nto ~/wp/ starting "
    printf "with page 1 from the categories general, anime and people,\\n"
    printf "including SFW Content and excluding sketchy and NSWF Content "
    printf "while utilizing\\ngnu parallel\\n\\n\\n"
    printf "latest version available at: "
    printf "<https://github.com/macearl/Wallhaven-Downloader>\\n"
} # /helptext

# Command line Arguments
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
        -h|--help)
            helpText
            exit
            ;;
        -v|--version)
            printf "Wallhaven Downloader %s\\n" "$REVISION"
            exit
            ;;
        *)
            printf "unknown option: %s\\n" "$1"
            helpText
            exit
            ;;
    esac
    shift # past argument or value
    done

checkDependencies

# optionally create a separate subfolder for each search query
# might download duplicates as each search query has its own list of
# downloaded wallpapers
if [ "$TYPE" == search ] && [ "$SUBFOLDER" == 1 ]
then
    LOCATION+=/$(echo "$QUERY" | sed -e "s/ /_/g" -e "s/+/_/g" -e  "s/\\//_/g")
fi

# creates Location folder if it does not exist
if [ ! -d "$LOCATION" ]
then
    mkdir -p "$LOCATION"
fi

cd "$LOCATION" || exit

# creates downloaded.txt if it does not exist
if [ ! -f ./downloaded.txt ]
then
    touch downloaded.txt
fi

# set auth header only when it is required ( for example to download your
# own collections or nsfw content... )
if  [ "$FILTER" == 001 ] || [ "$FILTER" == 011 ] || [ "$FILTER" == 111 ] \
    || [ "$TYPE" == collections ] || [ "$THUMBS" != 24 ]
then
    setAPIkeyHeader "$APIKEY"
fi

# 全局变量初始化：统计总成功下载数
total_success=0
downloadEndReached=false

if [ "$TYPE" == standard ]
then
    # 初始化随机数生成器，确保每次运行随机序列不同
    RANDOM=$$
    
    # 先获取总页数并限制在1-100页
    page=1
    s1="search?page=$page&categories=$CATEGORIES&purity=$FILTER&"
    s1+="atleast=$ATLEAST&resolutions=$RESOLUTION&ratios=$ASPECTRATIO"
    s1+="&sorting=$MODE&order=$ORDER&topRange=$TOPRANGE&colors=$COLOR"
    getPage "$s1"
    total_pages=$(jq -r ".meta.last_page" tmp)
    # 限制最大页数为100，最小为1
    if [ "$total_pages" -gt 100 ]; then
        total_pages=100
    fi
    if [ "$total_pages" -lt 1 ]; then
        total_pages=1
    fi
    rm -f tmp

    # 循环：直到总成功数达到WPNUMBER或已无更多页面
    while [ $total_success -lt $WPNUMBER ] && [ "$downloadEndReached" != true ]
    do
        # 随机选择1-$total_pages之间的页面（核心：实现1-100页随机选）
        page=$((RANDOM % total_pages + 1))
        printf "\\n===== 正在随机获取第 %s 页数据（总范围：1-%d页）=====\\n" "$page" "$total_pages"
        
        s1="search?page=$page&categories=$CATEGORIES&purity=$FILTER&"
        s1+="atleast=$ATLEAST&resolutions=$RESOLUTION&ratios=$ASPECTRATIO"
        s1+="&sorting=$MODE&order=$ORDER&topRange=$TOPRANGE&colors=$COLOR"
        getPage "$s1"
        printf "\\t- 第 %s 页数据获取完成!\\n" "$page"

        printf "正在处理第 %s 页的达标图片\\n" "$page"
        # 获取本次页面成功下载的数量（纯数字）
        current_success=$(downloadWallpapers)
        # 累加总成功数
        total_success=$((total_success + current_success))

        printf "第 %s 页处理完成：本次成功下载 %s 张达标图片，累计成功下载 %s 张（目标 %s 张）\\n" \
               "$page" "$current_success" "$total_success" "$WPNUMBER"
    done

elif [ "$TYPE" == search ] || [ "$TYPE" == useruploads ]
then
    # 初始化随机数生成器
    RANDOM=$$
    
    # 先获取总页数并限制在1-100页
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
    # 限制最大页数为100，最小为1
    if [ "$total_pages" -gt 100 ]; then
        total_pages=100
    fi
    if [ "$total_pages" -lt 1 ]; then
        total_pages=1
    fi
    rm -f tmp

    # 循环：直到总成功数达到WPNUMBER或已无更多页面
    while [ $total_success -lt $WPNUMBER ] && [ "$downloadEndReached" != true ]
    do
        # 随机选择1-$total_pages之间的页面
        page=$((RANDOM % total_pages + 1))
        printf "\\n===== 正在随机获取第 %s 页数据（总范围：1-%d页）=====\\n" "$page" "$total_pages"
        
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
        # 获取本次页面成功下载的数量（纯数字）
        current_success=$(downloadWallpapers)
        # 累加总成功数
        total_success=$((total_success + current_success))

        printf "第 %s 页处理完成：本次成功下载 %s 张达标图片，累计成功下载 %s 张（目标 %s 张）\\n" \
               "$page" "$current_success" "$total_success" "$WPNUMBER"
    done

elif [ "$TYPE" == collections ]
then
    if [ "$USR" == "" ]
    then
        printf "Please check the value specified for USR\\n"
        printf "to download a Collection it is necessary to specify a User\\n\\n"
        printf "Press any key to exit\\n"
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
        printf "Please check the value specified for COLLECTION\\n"
        printf "it seems that a collection with the name \"%s\" does not exist\\n\\n" \
                "$COLLECTION"
        printf "Press any key to exit\\n"
        read -r
        exit
    fi

    # 初始化随机数生成器
    RANDOM=$$
    
    # 先获取收藏集总页数并限制在1-100页
    page=1
    getPage "collections/$USR/$id?page=$page"
    total_pages=$(jq -r ".meta.last_page" tmp)
    # 限制最大页数为100，最小为1
    if [ "$total_pages" -gt 100 ]; then
        total_pages=100
    fi
    if [ "$total_pages" -lt 1 ]; then
        total_pages=1
    fi
    rm -f tmp

    # 循环：直到总成功数达到WPNUMBER、收藏集耗尽或已无更多页面
    while [ $total_success -lt $WPNUMBER ] && [ $total_success -lt $collectionsize ] && [ "$downloadEndReached" != true ]
    do
        # 随机选择1-$total_pages之间的页面
        page=$((RANDOM % total_pages + 1))
        printf "\\n===== 正在随机获取收藏集第 %s 页数据（总范围：1-%d页）=====\\n" "$page" "$total_pages"
        
        getPage "collections/$USR/$id?page=$page"
        printf "\\t- 收藏集第 %s 页数据获取完成!\\n" "$page"

        printf "正在处理收藏集第 %s 页的达标图片\\n" "$page"
        # 获取本次页面成功下载的数量（纯数字）
        current_success=$(downloadWallpapers)
        # 累加总成功数
        total_success=$((total_success + current_success))

        printf "收藏集第 %s 页处理完成：本次成功下载 %s 张达标图片，累计成功下载 %s 张（目标 %s 张，收藏集总数 %s 张）\\n" \
               "$page" "$current_success" "$total_success" "$WPNUMBER" "$collectionsize"
    done
else
    printf "error in TYPE please check Variable\\n"
    exit 1
fi

# 清理临时文件
[ -f ./cookies.txt ] && rm ./cookies.txt
[ -f ./tmp ] && rm ./tmp

# 最终提示
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