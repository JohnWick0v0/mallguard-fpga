# 第三方说明

本工具通过独立进程调用未修改的 FFmpeg 7.1 Windows x64 essentials build（Gyan）。二进制来自 imageio-ffmpeg 0.6.0 Windows wheel，未把 imageio Python 库打入上位机。FFmpeg 的实际版本、构建选项和许可通知保存在 licenses/ffmpeg-version.txt、ffmpeg-license-notice.txt；GPLv3 正文及 wheel 的 BSD 声明同目录保留。

FFmpeg 上游源码：https://github.com/FFmpeg/FFmpeg/tree/n7.1

Windows 构建与源码/依赖获取说明：https://www.gyan.dev/ffmpeg/builds/ （本包使用7.1，不是页面未来的最新版）。重分发时应连同本说明、许可及对应源码提供方式保留。

本地 ffmpeg.exe SHA256：`2ce797a0f88d7f067180338fb227f7b1928ea727bd9a4d7a1d022f7c52af71a3`
