# Wallhaven-Downloader-CN
一个随机从wallhaven.cc下载壁纸的脚本，可自定义壁纸类型/下载数量等参数

由https://github.com/macearl/Wallhaven-Downloader 修改而来

download.sh 下载壁纸
compress.sh 压缩壁纸
clean.sh    清理已下载壁纸
start.sh    依次执行clean-download-compress
blacklist.sh处理黑名单（downloaded.txt）下载壁纸时会在目录内生成一个downloaded.txt文件，如果下到了不喜欢壁纸，直接手动删除图片，再执行一次blacklist.sh，以后就不会下载你删除过的图片了
