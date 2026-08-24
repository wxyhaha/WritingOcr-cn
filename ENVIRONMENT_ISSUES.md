# 跨设备运行与多机环境差异问题排查记录 (Cross-Device Environment Issues)

**记录时间**：2026-08-24  
**目的**：记录在新设备（Clone 项目）上运行过程中发现的环境差异、报错原因与手写识别效果差异，供后续在主要开发电脑上统一排查与工程化规范修复。

---

## 📋 目录
1. [硬编码路径与环境依赖问题](#一硬编码路径与环境依赖问题)
2. [PaddleOCR 接口差异报错 (AttributeError: predict)](#二paddleocr-接口差异报错)
3. [手写中文识别效果差异原因分析](#三手写中文识别效果差异原因分析)
4. [开发机明日排查与根治建议清单](#四开发机明日排查与根治建议清单)

---

## 一、硬编码路径与环境依赖问题

### 1. 现象描述
项目在另一台新电脑 Clone 运行时，多个模块因依赖原开发电脑特有的绝对路径而无法直接运行。

### 2. 具体涉及文件与写死路径清单

| 模块 / 文件 | 原代码中的硬编码内容 | 导致的问题 |
| :--- | :--- | :--- |
| **`app/services/OcrService.cpp`** | `d:/otherCode/WritingOcr-cn/ocr-worker/main.py`<br>`C:/Users/Administrator/.../Python313/python.exe`<br>`py -3.13` | 新机目录为 `d:/studyPlace/...`，新机无 `Administrator` 目录，且新机安装的是 Python 3.12（无 3.13），导致桌面端无法自动拉起 OCR Worker。 |
| **`app/infrastructure/network/QrCodeGenerator.cpp`** | `d:/otherCode/WritingOcr-cn/scripts/generate_qrcode.py`<br>`C:/Users/Administrator/.../Python313/python.exe`<br>`py -3.13` | 生成二维码脚本寻找失败，依赖写死的 Python 3.13。 |
| **`app/infrastructure/export/DocxExporter.cpp`** | `d:/otherCode/WritingOcr-cn/scripts/export_docx.py` | DOCX 导出脚本绝对路径不存在。 |
| **`app/services/LanUploadService.cpp`** | `d:/otherCode/WritingOcr-cn/web-upload` | 手机扫码上传前端静态页面目录定位失败。 |
| **`app/main.cpp`** | `d:/otherCode/WritingOcr-cn/app/qml/Main.qml` | 备用 QML 加载路径写死。 |
| **`build_and_run.bat`** | `call ".../vcvars64.bat" 10.0.26100.0`<br>`set PATH=...14.44.35207...;...Administrator\AppData\...Python313;...` | Windows SDK 版本号、MSVC 具体子版本、Python 3.13 路径被写死，导致其他电脑批处理构建失败。 |
| **`tests/test_storage_db.cpp`**<br>**`tests/test_exporters.cpp`** | `d:/otherCode/WritingOcr-cn/test_data/...` | 单元测试输出目录写死，执行测试报错。 |

---

## 二、PaddleOCR 接口差异报错

### 1. 报错堆栈
```text
[ERROR] [ocr_worker] OCR processing failed: 'PaddleOCR' object has no attribute 'predict'
Traceback (most recent call last):
  File "build\ocr-worker\main.py", line 69, in ocr
    result = engine.recognize(norm_path, filter_printed_text=bool(req.filter_printed_text))
  File "build\ocr-worker\services\ocr_engine.py", line 243, in recognize
    return self.predict(...)
  File "build\ocr-worker\services\ocr_engine.py", line 302, in predict
    raw_result = self.ocr.predict(infer_path)
AttributeError: 'PaddleOCR' object has no attribute 'predict'
```

### 2. 根本原因
- **接口差异**：
  - 标准官方 **PaddleOCR 2.x**（如通过 `pip install paddleocr>=2.8.0` 安装的 2.8.1 版本）中，`PaddleOCR` 类的核心推理接口为 **`self.ocr.ocr(img_path)`** 或直接对象调用 `self.ocr(img_path)`。
  - 原开发电脑上可能安装了 PaddleOCR 3.x / PaddleX 或扩展包，其中提供了 `.predict()` 方法。
- **直接影响**：调用 `POST /ocr` 时后端抛出 500 异常，OCR 识别中断。

---

## 三、手写中文识别效果差异原因分析

在新设备上跑通后，手写识别效果相比原开发机明显变差，主要存在以下 4 大核心原因：

### 1. 模型版本与精度差异（核心主因）
- **日志记录**：新机环境默认自动从百度官方下载了 **Mobile 端轻量模型**：
  - 检测：`ch_PP-OCRv4_det_infer`
  - 识别：`ch_PP-OCRv4_rec_infer`
- **原开发机差异**：原开发机 `~/.paddleocr/` 缓存目录下可能配置或使用了：
  - **Server 端高精度大模型**（如 `ch_PP-OCRv4_rec_server_infer`，精度明显高于 Mobile 模型）；
  - **PP-OCRv5** 或专门针对手写中文微调过的权重模型。

### 2. 图像降采样尺寸阈值 (`MAX_INFER_DIM`)
- 在 `ocr_engine.py` 第 276-289 行：
  ```python
  MAX_INFER_DIM = 1920
  ```
- 手机拍摄的高分辨率手写原图（通常为 3000x4000 甚至更高）会被缩放至 1920 宽/高。对于细小密集的手写笔迹，降采样会导致连笔、笔锋细节丢失，降低识别置信度。

### 3. 像素形态学过滤可能存在误伤 (`filter_printed_text`)
- 项目内置了【基于像素形态学的手写与印刷体分类引擎】（计算笔画宽度方差与轴向梯度分布）。
- 如果开启了“过滤印刷体”，部分工整方正的手写字迹或极细圆珠笔字迹可能被判定为印刷体（`type: "printed"`）从而未在文本框中输出。

### 4. 文本方向与倾斜校正关闭 (`use_angle_cls`)
- `ocr_engine.py` 初始化时关闭了所有方向校正：
  ```python
  self.ocr = PaddleOCR(
      lang="ch",
      use_doc_orientation_classify=False,
      use_doc_unwarping=False,
      use_textline_orientation=False
  )
  ```
- 若拍照角度存在倾斜或微小旋转，未开启方向分类器会导致文本行截断或漏检。

---

## 四、开发机明日排查与根治建议清单

明日在主要开发机上，建议按以下步骤统一核对与规范化：

- [ ] **1. 核对开发机 Python 环境与包版本**：
  - 执行 `pip list | grep -i paddle`，查看具体的 `paddlepaddle`、`paddleocr`、`paddlex` 版本号并固化到 `requirements.txt`。
- [ ] **2. 检查开发机的模型缓存**：
  - 查看开发机的 `C:\Users\<用户名>\.paddleocr\whl\` 目录，确认原开发机使用的是哪个检测与识别模型（是否为 server 模型或定制模型）。
- [ ] **3. 统一使用相对路径与动态寻址**：
  - C++ 端统一使用 `QCoreApplication::applicationDirPath()` 定位 `ocr-worker/`、`web-upload/`、`scripts/`；
  - 启动脚本 `build_and_run.bat` 使用通用 VS 工具集检测，避免写死 SDK 版本号和绝对路径。
- [ ] **4. 优化 OCR 推理参数与模型配置**：
  - 评估将识别模型统一升级/配置为 Server 端模型（或在配置中支持可选高精度模式）；
  - 评估调整 `MAX_INFER_DIM` 阈值（如改为 2560 或保留原图细节）。
