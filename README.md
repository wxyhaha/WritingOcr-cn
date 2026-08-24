# 手写中文文章数字化工具 (Handwriting OCR Digitalizer)

![Version](https://img.shields.io/badge/version-1.0.0--MVP-blue.svg)
![Qt](https://img.shields.io/badge/Qt-6.5.3%20LTS-green.svg)
![C++](https://img.shields.io/badge/C%2B%2B-20-blue.svg)
![Python](https://img.shields.io/badge/Python-3.13-yellow.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)

一个专为个人打造的 **Windows 桌面端本地优先手写中文文章数字化与校对工具**。

将纸质手写中文文章拍照后导入电脑，通过本地 PaddleOCR (PP-OCRv5) 引擎转换为结构化电子文本，提供直观的**原图-文本双栏人工校对工作区**、**低置信度黄色高亮与快捷跳转**、**手机局域网扫码批量上传**以及 **TXT / Markdown / DOCX 导出**功能。

---

## 核心特性

- 📱 **局域网手机扫码批量上传**：电脑程序生成一次性二维码与动态 Session Token，手机浏览器扫码即可批量上传 1~10 张手稿照片，无需安装手机 App。
- ⚡ **本地优先 OCR**：基于独立 Python OCR Worker (PaddleOCR PP-OCRv5)，完全本地运行，不依赖云端，保护隐私。
- 🔍 **原图-文本双栏联动校对**：
  - 左侧原图查看器支持平移、缩放、双击适应、100% 原始比例。
  - 自动标出低置信度文字区域（默认 `< 0.75` 黄色边框高亮）。
  - 右侧富文本编辑器实时联动，支持点击跳转定位与「上一处 / 下一处低置信度」一键跳转。
- 💾 **数据隔离与实时自动保存**：原始 OCR 数据与用户校对文本严格分离存储，SQLite 数据库与文件系统目录规范管理。
- 📤 **多格式导出**：一键导出最终校对文本为 `.txt`、`.md` (Markdown) 或 `.docx` (Microsoft Word)。
- 🗑️ **级联删除确认**：删除任务时彻底清理原始图片、预处理图片、OCR 结果与数据库记录，杜绝孤儿文件。

---

## 系统运行与快速开始

### 1. 启动 OCR Worker
```powershell
py -3.13 ocr-worker/main.py
```
Worker 将监听在 `http://127.0.0.1:8766`，提供 `/health` 和 `/ocr` API。

### 2. 运行桌面程序
直接运行构建生成的二进制文件：
```powershell
./build/HandwritingOCR.exe
```

---

## 源码构建指南

### 环境要求
- Windows 10 / 11 64-bit
- Visual Studio 2022 (MSVC v143 / C++20)
- Qt 6.5.3 LTS (MSVC 2019/2022 64-bit)
- CMake 3.20+ & Ninja
- Python 3.10 ~ 3.13

### 构建命令
```powershell
# 1. 激活 MSVC 编译环境
call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"

# 2. 配置 CMake
cmake -B build -G Ninja -DCMAKE_PREFIX_PATH=C:/Qt/6.5.3/msvc2019_64 -DCMAKE_BUILD_TYPE=Release

# 3. 编译工程
cmake --build build

# 4. 运行单元测试
ctest --test-dir build --output-on-failure
```

---

## 许可证
本项目采用 [MIT License](LICENSE) 授权。
