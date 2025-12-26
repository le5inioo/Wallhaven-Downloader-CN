# Wallhaven-Downloader-CN
一个随机从wallhaven.cc下载壁纸的脚本，可自定义壁纸类型/下载数量等参数

由https://github.com/macearl/Wallhaven-Downloader 修改而来

中文版请下载：wallhaven-cn.sh

修改：

1.注释翻译成中文(机翻)

2.增加随机获取图片的相关函数

3.增加根据收藏两筛选图片的相关函数

4.增加页码限制和图片大小限制的相关函数

5.不想动脑子的话，只需要修改一下壁纸保存路径即可食用

6.默认配置是从favorites分类的1-100页随机下载24张500KB-10MB横屏壁纸

7.配合clear_wallhaven.sh+定时任务可实现每日自动化更新壁纸，例如把存放文件夹设置为openwrt的壁纸文件夹，每次登陆都是新鲜的随机壁纸

8.配合https://github.com/wscck/Random-Image-API 实现随机图片API，例如实现sun-panel每次打开都是新鲜的随机壁纸

