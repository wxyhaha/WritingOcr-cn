# 手写中文文章数字化工具——开发与调试指南 (DEVELOPMENT.md)

本文档面向本项目的开发者，详细记录开发环境配置、编译构建、调试运行、单元测试与常见问题处理。

---

## 1. 开发环境要求

- **操作系统**: Windows 10 / 11 64-bit
- **C++ 编译器**: Visual Studio 2022 Community (MSVC v143 / C++20 支持)
- **Qt SDK**: Qt 6.5.3 LTS (MSVC 2019/2022 64-bit) 路径：`C:\Qt\6.5.3\msvc2019_64`
- **构建工具**: CMake 3.20+、Ninja 1.12+
- **Python**: Python 3.10 ~ 3.13 64-bit

---

## 2. Python 依赖安装

进入 `ocr-worker/` 目录并安装依赖：

```powershell
pip install -r requirements.txt
```

---

## 3. 构建与编译

在 Windows PowerShell 或命令提示符中执行：

```powershell
# 1. 激活 Visual Studio 编译环境（推荐使用 vcvars64.bat 自动配置）
call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"

# 2. CMake 配置（若 Qt 已加入 PATH，则无需手动指定 CMAKE_PREFIX_PATH）
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release

# 3. 执行编译
cmake --build build --config Release

# 4. (可选) 部署 Qt 运行时依赖
windeployqt --qmldir app/qml build/HandwritingOCR.exe
```

---

## 4. 运行单元测试

本项目集成了自动化单元测试：

```powershell
# 编译并运行全部单元测试
cmake --build build --target test_storage_db test_exporters
ctest --test-dir build --output-on-failure
```

测试覆盖内容：
- `test_storage_db`: SQLite 事务、任务与页面 CRUD、外键级联删除、目录清理。
- `test_exporters`: TXT 纯文本、Markdown 格式化、DOCX Word 规范导出。

---

## 5. 运行与联调

### 方式 A：一键启动（桌面端自动拉起 OCR Worker）
桌面程序启动时会自动检测并在后台拉起 `python ocr-worker/main.py`。
```powershell
./build/HandwritingOCR.exe
```

### 方式 B：手动分别启动（推荐调试使用）
**终端 1 (OCR Worker)**:
```powershell
python ocr-worker/main.py
```
访问 `http://127.0.0.1:8766/docs` 可查看交互式 API 文档。

**终端 2 (桌面端)**:
```powershell
./build/HandwritingOCR.exe
```

---

## 6. 常见问题 (FAQ)

1. **Q: 局域网手机无法访问上传页面？**
   - A: 请检查手机和电脑是否连接在同一个 WiFi 局域网下；检查 Windows 防火墙是否允许端口 8765 访问。
2. **Q: OCR 识别返回超时？**
   - A: 初次运行时 PaddleOCR 需要从官方源下载模型，模型下载完成后后续识别将非常迅速。可在 OCR 设置界面点击「检测」查看当前状态。
3. **Q: 如何修改低置信度黄色高亮判定阈值？**
   - A: 点击软件右上角「设置」，调节「低置信度阈值」滑块（默认 75%），校对界面将实时重算并刷新黄色高亮边框。
