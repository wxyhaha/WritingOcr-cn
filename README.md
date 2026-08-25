# 手写中文文章数字化工具 (Handwriting OCR Digitalizer)

![Version](https://img.shields.io/badge/version-1.0.0--MVP-blue.svg)
![Qt](https://img.shields.io/badge/Qt-6.5.3%20LTS-green.svg)
![C++](https://img.shields.io/badge/C%2B%2B-20-blue.svg)
![Python](https://img.shields.io/badge/Python-3.13-yellow.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)

一个专为个人打造的 **Windows 桌面端本地优先手写中文文章数字化与校对工具**。

将纸质手写中文文章拍照后导入电脑，通过本地 PaddleOCR (PP-OCRv5) 引擎转换为结构化电子文本，提供直观的**图文卡片工作台**、**原图-文本双栏人工校对工作区**、**低置信度黄色高亮与快捷跳转**、**基于像素形态学的智能手写/印刷体过滤**、**手机局域网扫码批量上传**以及 **TXT / Markdown / DOCX 导出**功能。

---

## 核心特性

- 📱 **局域网手机扫码批量上传**：电脑程序生成一次性二维码与动态 Session Token，手机浏览器扫码即可批量上传 1~10 张手稿照片，无需安装手机 App。
- ⚡ **本地优先 OCR 异步预热**：基于独立 Python OCR Worker (PaddleOCR PP-OCRv5)，完全本地运行，不依赖云端，启动 0.3s 秒级响应。
- 🔍 **原图-文本双栏联动校对**：
  - 左侧原图查看器支持平移、缩放、双击适应、1:1 原图、磨砂玻璃浮动 HUD。
  - 自动标出低置信度文字区域（默认 `< 0.75` 黄色边框高亮）。
  - 右侧文本编辑器实时联动，支持点击跳转定位与「上一处 / 下一处低置信度」一键跳转。
- ✍️ **智能过滤印刷体与相机水印**：基于像素形态学（笔画宽度方差与轴向梯度分布）精确区分手写笔迹与机械印刷体，支持实时开关与全篇响应式过滤。
- 💾 **数据隔离与实时自动保存**：原始 OCR 数据与用户校对文本严格分离存储，SQLite 数据库与文件系统目录规范管理。
- 📤 **多格式导出**：一键导出最终校对文本为 `.txt`、`.md` (Markdown) 或 `.docx` (Microsoft Word)。
- 🗑️ **级联删除确认**：删除任务时彻底清理原始图片、预处理图片、OCR 结果与数据库记录，杜绝孤儿文件。

---

## 🚀 新电脑 Clone 快速上手指南

如果您在另一台新电脑上 `git clone` 了本项目代码，请按照以下 4 步完成开箱配置与运行：

### 1. 前置环境要求
- **操作系统**：Windows 10 / 11 64-bit
- **编译工具**：[Visual Studio 2022 Community](https://visualstudio.microsoft.com/vs/community/)（勾选“使用 C++ 的桌面开发”，包含 MSVC v143 与 Windows 10/11 SDK）
- **Qt 开发框架**：[Qt 6.5.3 LTS 或更高版本](https://www.qt.io/download)（安装 MSVC 2019/2022 64-bit 组件）
- **CMake & Ninja**：CMake 3.20+（VS2022 自带或独立安装）
- **Python 环境**：Python 3.10 ~ 3.13 64-bit（建议添加到系统 PATH）

---

### 2. 第一步：安装 Python OCR 依赖
打开终端（PowerShell 或 CMD），进入项目根目录安装 Python 依赖（锁定的高精度 PP-OCRv6 依赖）：
```powershell
pip install -r requirements.txt
```

---

### 3. 第二步：CMake 编译 C++ 桌面端
打开 **x64 Native Tools Command Prompt for VS 2022**（或直接运行 `build_and_run.bat`）：

```powershell
# 1. 激活 MSVC 编译环境（如果在 VS 开发者终端中可跳过此行）
call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"

# 2. 配置 CMake（若 Qt6 已在 PATH 中则无需指定前缀）
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release

# 3. 编译工程
cmake --build build --config Release

# 4. (可选) 运行自动化测试验证
cd build
ctest --output-on-failure
cd ..
```

> **提示**：CMake 构建成功后，会自动触发 `POST_BUILD` 脚本将 `ocr-worker/`、`web-upload/`、`scripts/` 自动拷贝至输出目录 `build/` 中。

---

### 4. 第三步：启动程序
直接在项目根目录下双击运行批处理脚本：
```powershell
# 方式 A：直接启动桌面程序（桌面端会自动拉起后台 OCR Worker）
.\start.bat

# 方式 B：直接运行编译产物
.\build\HandwritingOCR.exe
```

---

## 🛠️ 常见问题排查 (FAQ)

1. **OCR Worker 端口冲突或启动失败**：
   - 默认 OCR 端口为 `8766`，局域网扫码端口为 `8765`。
   - 可以在桌面端右上角【⚙️ 设置】中检测 OCR 服务健康状态，或自定义端口。
2. **局域网手机扫码无法打开上传页面**：
   - 请确保手机与电脑连接在同一个 WiFi 局域网下；
   - 检查 Windows 防火墙是否允许应用程序/Python 接收局域网入站连接；
   - 若电脑有多张网卡（如虚拟网卡/VPN），在扫码弹窗下拉框中选择局域网真实 IP 即可。

---

## 许可证
本项目采用 [MIT License](LICENSE) 授权。
