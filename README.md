# 商安视界 · 商场宣传与应急终端

- `FPGA_PART/` 保存 FPGA 工程。
- `HOSTPC_PART/` 保存上位机工程及配套素材。
- 为满足单文件不超过 25,000,000 字节的要求，`ffmpeg.exe` 按原始字节顺序拆为 4 个分片，保存在 `HOSTPC_PART/MallGuardConsole/release/tools/ffmpeg.parts/`。其余原文件按原路径保存。

## 还原素材转换工具

下载或克隆仓库后，在仓库根目录打开 PowerShell，运行以下命令。需要使用上位机的 FFmpeg 素材转换功能时，先执行还原。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .estore_ffmpeg.ps1
```

脚本检查每个分片的字节数，并校验合并结果的 SHA-256。通过后生成 `HOSTPC_PART/MallGuardConsole/release/tools/ffmpeg.exe`。上传时保留分片，合并后的 EXE 仅供本地使用。

原始工具大小为 87,638,016 字节，SHA-256 为 `2ce797a0f88d7f067180338fb227f7b1928ea727bd9a4d7a1d022f7c52af71a3`。
