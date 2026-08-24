# 手写中文文章数字化工具——系统架构文档 (ARCHITECTURE.md)

## 1. 总体系统架构

本项目采用清晰的分层架构（Layered Clean Architecture），将界面展示、核心业务逻辑、数据持久化与外部 OCR 引擎完全解耦：

```text
┌─────────────────────────────────────────────────────────────┐
│                      Presentation (QML)                     │
│  - Main Window                                              │
│  - TaskHomeView / ProofreadingView                          │
│  - ImageViewer (Bbox / Low-Confidence Yellow Highlighting)  │
│  - TextEditorView / PageSidebar                             │
└──────────────────────────────┬──────────────────────────────┘
                               │ Q_PROPERTY / Invokable Signals
┌──────────────────────────────▼──────────────────────────────┐
│                  Application Controller                     │
│  - AppController (C++ Qt Context Property)                   │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                        Service Layer                        │
│  - TaskService (CRUD, Auto-Save Debounce, Page Manager)     │
│  - ImageService (EXIF Correction, Scaling, Thumbnails)      │
│  - OcrService (Async Worker Manager, Batch Dispatch)        │
│  - LanUploadService (Token, QR Generation, IP Discovery)    │
│  - ExportService (TXT, Markdown, DOCX Dispatcher)           │
│  - StorageService (Task Folder Lifecycle, Clean Deletion)   │
│  - SettingsService (Persistent Configuration)               │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                    Infrastructure Layer                     │
│  - DatabaseManager (SQLite WAL, Foreign Keys, Cascades)     │
│  - LanHttpServer (QTcpServer, Multipart Upload, Security)   │
│  - IOcrProvider / PaddleOcrProvider (HTTP IPC Client)       │
│  - IExporter (TxtExporter, MarkdownExporter, DocxExporter)  │
│  - Logger (Thread-safe File & Console Log)                  │
└──────────────────────────────┬──────────────────────────────┘
                               │ HTTP / JSON (127.0.0.1:8766)
┌──────────────────────────────▼──────────────────────────────┐
│                      OCR Worker (Python)                    │
│  - FastAPI Server (/health, /capabilities, /ocr)            │
│  - PaddleOCR PP-OCRv5 Inference Engine                      │
│  - Original Pixel Bounding Box & Confidence Extractor       │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 核心数据模型

### 2.1 Task (识别任务)
- `id`: UUID 任务唯一标识符
- `title`: 任务名称（默认为「YYYY-MM-DD HH:mm 手写文章」）
- `status`: `Draft`, `Uploading`, `Ready`, `Processing`, `Reviewing`, `Completed`, `Failed`
- `pageCount`: 页面数量（1~10）
- `totalCharacters`: 统计字数
- `lowConfidenceCount`: 低置信度项数量（根据动态阈值计算）

### 2.2 Page (页面)
- `id`: UUID 页面唯一标识符
- `taskId`: 所属任务 ID
- `pageIndex`: 页面在任务中的排序索引 (0-based)
- `originalImagePath`: 原始图片路径 (`source/{pageIndex}_{id}.jpg`)
- `processedImagePath`: 预处理图片路径 (`processed/{pageIndex}_{id}.png`)
- `thumbnailPath`: 缩略图路径 (`thumbnails/{pageIndex}_{id}_thumb.jpg`)
- `editedText`: 用户人工校对后的最终文本
- `ocrResult`: 关联的原始 OCR 结构化结果（独立保留，永不覆盖）

### 2.3 OcrBlock (文本块)
- `id`: Block 唯一 ID
- `text`: 识别文本片段
- `confidence`: 置信度分数（0.0 ~ 1.0）
- `bbox`: 原始图片像素坐标系矩形 `{ x, y, width, height }`
- `lineIndex` / `blockIndex`: 行序号与块序号
- `isLowConfidence(threshold)`: 置信度低于阈值判断（默认 `< 0.75`）

---

## 3. 存储与目录结构

所有任务文件统一存放在系统文档目录 `Documents/HandwritingOCR/` 下：

```text
HandwritingOCR/
├── handwriting_ocr.db           # SQLite 数据库文件
├── logs/
│   └── app.log                  # 结构化运行日志
└── tasks/
    └── {taskId}/
        ├── source/              # 原始图片（只读保存，绝不覆盖）
        │   ├── 001_xxxx.jpg
        │   └── 002_xxxx.jpg
        ├── processed/           # 预处理图片
        │   ├── 001_xxxx.png
        │   └── 002_xxxx.png
        ├── thumbnails/          # 缩略图
        │   ├── 001_xxxx_thumb.jpg
        │   └── 002_xxxx_thumb.jpg
        ├── ocr/                 # OCR 结果 JSON 存档
        │   ├── 001.json
        │   └── 002.json
        └── exports/             # 导出文件暂存
```

---

## 4. 局域网扫码上传机制与安全

1. **IP 发现**：程序自动检测本机活跃局域网 IPv4 地址（自动过滤 127.0.0.1、WSL、VMware 等虚拟网卡）。
2. **Session Token**：生成 12 位随机 Token，每次刷新二维码即废弃旧 Token。
3. **安全防护**：
   - 拒绝无 Token 或 Token 错误的 HTTP 请求。
   - 文件名在服务端统一重命名生成 UUID，防止路径穿越攻击（Path Traversal）。
   - 严格限制 MIME 类型及单任务 10 张上限。

---

## 5. 未来扩展点（未来路线规划）

本项目架构完全遵循模块化和抽象接口设计，为后续版本预留了以下无缝升级通道：

1. **第二本地 OCR (Secondary OCR Provider)**：
   - 实现 `IOcrProvider` 接口增加 `SecondaryOcrProvider` (例如基于 ONNX Runtime 或其他本地模型)。
2. **差异比对与双 OCR 融合 (Diff Analysis & Result Fusion)**：
   - 基于 `OcrBlock` 坐标与文本计算 Levenshtein 距离与冲突区域。
3. **个人手写 Benchmark 系统**：
   - 对比真实手写原稿与 Ground Truth，自动评估 Character Error Rate (CER)。
4. **本地视觉大模型 (Local VLM) 与硬件检测**：
   - 增加 `HardwareCapabilityService` 检测 GPU 显存与算力，动态启用本地 VLM。
5. **AI 辅助校对**：
   - 在人工校对侧提供一键上下文语法与错别字纠错建议。
