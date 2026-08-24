# 手写中文文章数字化工具——MVP 开发任务书

## 1. 项目目标

开发一个 Windows 桌面端个人手写中文文章数字化工具。

核心用途：

> 将纸质手写中文文章拍照后导入电脑，通过本地 OCR 转换成可编辑电子文本，并提供高效人工校对、任务管理、图片保存和结果导出功能。

典型使用流程：

```text
纸质手写文章
    ↓
手机拍照
    ↓
电脑程序生成一次性二维码
    ↓
手机与电脑处于同一局域网
    ↓
手机扫码打开上传页面
    ↓
批量上传 1～10 张图片
    ↓
电脑创建/更新识别任务
    ↓
图片预处理
    ↓
本地 OCR
    ↓
OCR 文本 + 坐标 + confidence
    ↓
低置信度文字黄色框高亮
    ↓
用户在原稿和 OCR 文本之间人工校对
    ↓
保存最终结果
    ↓
导出 TXT / Markdown / DOCX
```

这是一个**个人本地优先工具**，不是 SaaS，不需要账号、登录、云同步或服务器后台。

---

# 2. 当前阶段明确范围

这是 MVP。

必须完成：

1. Windows 桌面应用
2. 本地图片导入
3. 手机局域网扫码上传
4. 批量上传图片
5. 一次任务最多 10 页
6. 任务创建、查看、删除
7. 原始图片保存
8. 图像预处理
9. 本地 OCR
10. 保存 OCR 原始结果
11. 保存文本位置和 confidence
12. 低置信度文字黄色框高亮
13. 原图与 OCR 文本双栏校对
14. OCR 文本编辑
15. 原图位置和文字位置双向联动
16. 上一个/下一个低置信度项快速跳转
17. OCR 结果自动保存
18. 删除任务时删除该任务全部相关数据
19. 导出 TXT
20. 导出 Markdown
21. 导出 DOCX
22. 清晰的错误提示、任务状态和识别进度

---

# 3. 当前阶段明确不要做

以下内容全部留到后续优化阶段，不要为了“架构完整”提前实现复杂功能：

### 暂不实现

- AI 辅助校对
- 云端 OCR
- OCR-VL
- PaddleOCR-VL
- 第二本地 OCR 的实际运行
- OCRScore 复杂算法
- 双 OCR 自动融合
- OCR Benchmark
- 自动模型选择
- 本地 VLM
- 全文搜索
- 标签系统
- 云同步
- 用户账号
- 手机 App
- 多设备同步
- 回收站
- 在线服务端
- 复杂文档管理
- 大规模批量处理

但是：

> **架构需要为这些未来功能预留扩展接口，但不能为了预留接口而过度设计。**

---

# 4. 技术栈

## 4.1 桌面端

使用：

- Qt 6
- Qt Quick / QML
- C++20
- CMake

优先使用 Qt 6.8 系列作为稳定基线；项目初始化时先检查当前可用 Qt 版本和许可条件，不要未经确认使用商业专属能力。Qt 6.8 是当前 LTS 系列，官方支持周期长期稳定，但开源版本和商业许可存在不同义务，项目必须明确遵守所选许可证。

UI 使用 QML，核心业务使用 C++。

原则：

```text
QML
↓
Presentation / ViewModel
↓
C++ Application Core
↓
Service Layer
↓
Infrastructure
```

不要把核心业务逻辑写进 QML。

---

# 5. OCR 技术路线

## 5.1 第一版主 OCR

使用：

> PaddleOCR + PP-OCRv5

作为当前唯一实际启用的本地 OCR 引擎。

PaddleOCR 当前版本体系中 PP-OCRv5 已针对复杂中文手写场景进行增强，因此先以它作为 MVP 本地 OCR 主引擎。具体模型与 API 版本不要凭记忆硬编码，开发时以当前官方文档和实际可安装版本为准。

要求：

- Python OCR Worker
- 本地运行
- 不依赖云端
- OCR 完成后返回结构化 JSON
- 返回文本
- 返回文本区域坐标
- 返回 confidence / rec_score
- 尽可能保留行级或文本块级结构

---

# 6. OCR Worker 架构

不要让 C++ 直接嵌入 Python 解释器。

采用独立 OCR Worker：

```text
Qt Desktop App
      │
      │ IPC / Local HTTP
      ↓
ocr-worker
      │
      ├── Python
      ├── PaddleOCR
      └── OCR Models
```

推荐：

> 本地 HTTP + JSON

例如：

```text
GET  /health
GET  /capabilities
POST /ocr
POST /ocr/batch
```

以后可以扩展：

```text
POST /ocr/secondary
POST /ocr/compare
```

但 MVP 中不要实现第二 OCR。

OCR Worker 必须可以独立启动、停止、检测健康状态。

桌面程序启动时检查：

```text
OCR Worker 是否存在
OCR Worker 是否能正常启动
OCR 模型是否完整
OCR 是否可用
```

如果 OCR 不可用，要明确提示用户原因。

---

# 7. OCR Provider 抽象

虽然第一版只有 PaddleOCR，但不要把整个业务层直接写死为 PaddleOCR。

定义抽象接口，例如：

```cpp
class IOcrProvider
{
public:
    virtual ~IOcrProvider() = default;

    virtual OcrResult recognize(
        const OcrRequest& request
    ) = 0;

    virtual ProviderInfo info() const = 0;
};
```

当前：

```text
OCR Provider
└── PaddleOcrProvider
```

预留：

```text
OCR Provider
├── PaddleOcrProvider
├── SecondaryOcrProvider   // 后续
└── CloudOcrProvider       // 后续
```

不要现在实现后两个 Provider。

---

# 8. 为什么预留第二 OCR

未来优化阶段可能采用：

```text
Primary OCR
+
Secondary OCR
```

再通过结果差异分析判断哪些文字需要人工检查。

但是当前阶段：

> **不要实现双 OCR。**

当前只需要确保 OcrResult 数据结构能够支持未来扩展。

---

# 9. OCR 结果数据结构

设计统一的 OCR 数据模型。

至少包含：

```text
OcrResult
├── engine
├── engineVersion
├── createdAt
├── imageWidth
├── imageHeight
├── blocks[]
└── rawText
```

每个 OCR Block 至少包含：

```text
OcrBlock
├── id
├── text
├── confidence
├── bbox
├── lineIndex
├── blockIndex
├── type
└── status
```

bbox：

```text
x
y
width
height
```

坐标必须以**原始图片像素坐标系**保存。

不要只保存屏幕坐标。

因为 UI 缩放后必须能够准确映射回原图。

---

# 10. 低置信度高亮功能

这是 MVP 核心功能。

OCR 返回：

```text
text
confidence
bbox
```

应用根据一个可配置阈值判断低置信度。

第一版默认：

```text
confidence < 0.75
```

视为低置信度。

但：

> 0.75 只是默认初始参数，不要当作理论标准。

后续优化阶段通过 Benchmark 调整。

---

# 11. 低置信度视觉设计

低置信度区域必须在原始图片上使用：

> **黄色矩形框**

例如：

```text
┌────────────────────┐
│ 今天下午天气很好   │
│ 我去了人民公园。   │
│        ┌───┐       │
│        │园 │       │
│        └───┘       │
└────────────────────┘
```

要求：

- 黄色边框
- 不遮挡原始文字
- 可缩放
- 可平移
- 原图放大后仍然准确
- 多个低置信度项可同时显示
- 当前选中项采用更明显的视觉状态

建议：

```text
普通低置信度：黄色框
当前选中项：黄色填充 + 高亮边框
```

不要把图片本身涂成黄色。

---

# 12. OCR 文本侧同步高亮

右侧文本编辑器中，对应的低置信度文本也要显示为：

> 黄色背景或黄色下划线。

例如：

```text
今天下午天气很好，我去了人民公园。
                  ↑
                黄色标记
```

必须实现：

> **原图区域 ↔ OCR 文本**

双向联动。

点击 OCR 文本：

```text
OCR 文本
↓
定位对应原图 bbox
↓
原图自动平移到对应位置
```

点击原图黄色框：

```text
原图 bbox
↓
定位对应 OCR 文本
↓
文本滚动并选中
```

---

# 13. 人工校对流程

识别完成后显示统计：

```text
识别完成

页面：8
字符：2731

高置信度：2583
低置信度：96

[开始校对]
```

用户点击：

> 开始校对

自动定位第一处低置信度内容。

页面提供：

```text
上一处
下一处
```

快捷键建议：

```text
Enter      确认修改
Esc        取消当前编辑
Ctrl+Enter 保存当前任务
```

允许直接编辑 OCR 文本。

---

# 14. 原始 OCR 与最终文本分离

绝对不能直接覆盖 OCR 原始结果。

数据必须区分：

```text
OCR Raw Result
↓
User Edited Result
```

例如：

```text
rawText
editedText
```

用户编辑后：

```text
OCR原始结果：
人民公圆

最终结果：
人民公园
```

这样未来可以追溯 OCR 原始结果。

---

# 15. 图片导入

支持：

- JPG
- JPEG
- PNG
- WEBP

第一版一次任务最多：

> 10 张图片

导入方式：

### 方式 1

文件选择器。

### 方式 2

拖拽图片到桌面程序。

### 方式 3

局域网手机上传。

图片导入后立即生成缩略图并加入当前任务。

---

# 16. 局域网手机上传

这是 MVP 核心功能。

电脑程序启动一个局域网 HTTP Server。

例如：

```text
http://192.168.1.100:8765
```

不要要求用户手动输入地址。

桌面端自动：

1. 获取本机局域网 IP
2. 启动 HTTP Server
3. 生成随机 Session Token
4. 生成一次性二维码
5. 在 UI 中显示二维码

二维码包含：

```text
IP
Port
Session Token
Upload Route
```

例如：

```text
http://192.168.1.100:8765/upload?t=xxxxx
```

---

# 17. 一次性二维码

二维码必须：

- 当前电脑启动/会话有效
- Session Token 随机生成
- 程序退出后失效
- 可以手动刷新
- 上传成功后不要自动使整个会话失效
- 但 token 不应永久有效

建议默认 Session 生命周期：

> 当前程序运行期间有效。

增加：

```text
[刷新二维码]
```

刷新后旧 token 立即失效。

---

# 18. 手机上传网页

不要开发手机 App。

直接由桌面程序提供一个简单 HTML 页面。

手机：

```text
扫码
↓
浏览器打开
↓
上传页面
```

页面支持：

```text
选择图片
拍照
多选
上传进度
上传完成提示
```

尽量兼容 Android/iOS 主流移动浏览器。

页面无需复杂设计。

---

# 19. 手机批量上传

必须支持一次选择多张图片。

例如：

```text
page01.jpg
page02.jpg
page03.jpg
...
page08.jpg
```

上传到电脑后：

```text
服务器收到 8 张图片
↓
按上传顺序创建页面
```

上传成功后桌面端实时显示：

```text
已收到 8 / 8 张图片
```

图片到达以后自动加入当前任务。

不要要求用户手动重新选择这些图片。

---

# 20. LAN 安全

这是个人局域网工具，不需要复杂鉴权，但必须至少做到：

- Session Token
- 只监听局域网地址，不主动暴露公网
- 拒绝无 token 上传
- 限制上传文件类型
- 限制单文件大小
- 限制单任务最多 10 页
- 文件名必须安全处理
- 禁止路径穿越
- 不允许通过上传接口访问本地任意文件

禁止直接根据客户端提供的 filename 写入任意路径。

---

# 21. 当前任务模型

一个识别任务包含：

```text
Task
├── id
├── title
├── createdAt
├── updatedAt
├── status
├── pageCount
├── totalCharacters
├── lowConfidenceCount
└── pages[]
```

Task 状态：

```text
Draft
Uploading
Ready
Processing
Reviewing
Completed
Failed
```

---

# 22. 页面模型

```text
Page
├── id
├── taskId
├── pageIndex
├── originalImagePath
├── processedImagePath
├── thumbnailPath
├── ocrResultPath
├── editedText
├── status
├── createdAt
└── updatedAt
```

页面状态：

```text
Pending
Preprocessing
OCRProcessing
Reviewing
Completed
Failed
```

---

# 23. 图片目录结构

建议：

```text
Documents/
└── HandwritingOCR/
    └── tasks/
        └── {taskId}/
            ├── source/
            │   ├── 001.jpg
            │   ├── 002.jpg
            │   └── ...
            │
            ├── processed/
            │   ├── 001.png
            │   ├── 002.png
            │   └── ...
            │
            ├── thumbnails/
            │   ├── 001.jpg
            │   ├── 002.jpg
            │   └── ...
            │
            ├── ocr/
            │   ├── 001.json
            │   ├── 002.json
            │   └── ...
            │
            └── exports/
```

原则：

> 原始图片永远不覆盖。

---

# 24. 任务删除

必须提供：

> 删除任务及其全部数据

删除任务时，同时删除：

- 原始图片
- 预处理图片
- 缩略图
- OCR JSON
- 数据库记录
- 任务缓存
- 任务临时文件

删除前必须弹出确认：

```text
删除任务？

将永久删除：
• 8 张原始图片
• 8 张预处理图片
• OCR结果
• 校对结果
• 任务数据

此操作不可恢复。

[取消] [删除]
```

第一版不要做回收站。

---

# 25. 保存策略

必须自动保存。

以下内容发生变化时立即或延迟几百毫秒自动保存：

- OCR 结果
- 用户修改文本
- 当前页面
- 当前任务状态

程序异常退出后，再次打开应尽可能恢复任务。

---

# 26. SQLite

使用 SQLite 保存：

```text
tasks
pages
ocr_results
ocr_blocks
settings
```

图片不要存进数据库。

数据库只存：

- 元数据
- 路径
- OCR 结构
- 状态
- 用户修改
- 配置

图片和 JSON 存文件系统。

---

# 27. 图像预处理

第一版只实现可靠、必要的处理：

```text
原图
↓
EXIF 方向修正
↓
文档边界/透视校正（能可靠识别时）
↓
尺寸控制
↓
适度增强
↓
OCR
```

原则：

> 宁可不处理，也不要因为过度处理损害手写笔迹。

必须保留原图。

用户可选择：

```text
自动增强
原图识别
```

如果自动增强不稳定，可以第一版只使用：

> 原图 + 基础方向修正 + 尺寸控制

不要为了“高级感”实现复杂图像算法。

---

# 28. 图片查看器

原稿查看器需要：

- 缩放
- 平移
- 适应窗口
- 100% 原始比例
- 鼠标滚轮缩放
- 拖拽平移
- 低置信度框
- 当前框定位
- 双击适应窗口

建议使用 Qt Quick 自身的图像/场景图能力，不要加载全尺寸图片后反复重建 UI。

---

# 29. OCR 文本编辑器

右侧文本编辑区要求：

- 可编辑
- 支持中文
- 支持 Ctrl+A / Ctrl+C / Ctrl+V
- 支持撤销/重做
- 支持普通文本编辑
- 支持定位
- 低置信度文本高亮
- 当前校对项高亮

文本与 OCR block 的映射必须保留。

不要简单地把所有 OCR 结果拼成纯字符串后丢掉 block 信息。

---

# 30. UI 信息架构

建议主窗口：

```text
┌──────────────────────────────────────────────────────┐
│ 手写文档数字化                              设置      │
├──────────────┬───────────────────────────────────────┤
│              │                                       │
│  页面列表     │              校对工作区               │
│              │                                       │
│  01          │   ┌────────────────┬───────────────┐ │
│  02          │   │                │               │ │
│  03          │   │    原稿图片     │   OCR文本     │ │
│  04          │   │                │               │ │
│  ...         │   │                │               │ │
│              │   └────────────────┴───────────────┘ │
│              │                                       │
├──────────────┴───────────────────────────────────────┤
│ 8页 · 2731字 · 低置信度 12        [上一处] [下一处] │
└──────────────────────────────────────────────────────┘
```

首页/任务页：

```text
新建任务
├── 文件导入
└── 手机扫码上传
```

任务完成后进入：

> 双栏校对界面

---

# 31. 任务首页

首页不需要复杂 Dashboard。

建议：

```text
┌────────────────────────────────────┐
│ 手写文档数字化                     │
│                                    │
│     [新建识别任务]                  │
│                                    │
│  拖拽图片到这里                     │
│                                    │
│  或                                 │
│                                    │
│  [选择图片]   [手机扫码上传]        │
│                                    │
└────────────────────────────────────┘
```

下面显示最近任务：

```text
最近任务

2026-08-24 手写文章
8 页
已完成

2026-08-21 读书笔记
5 页
待校对
```

---

# 32. 任务操作

任务列表支持：

```text
打开
重命名
导出
删除
```

删除必须明确提示。

---

# 33. 导出功能

必须支持：

### TXT

只输出最终文本。

### Markdown

保留：

- 标题
- 段落
- 换行

如果目前没有可靠标题识别，可以只按照页面/段落结构输出。

### DOCX

输出最终编辑文本。

不要把 OCR 原始文本作为默认导出内容。

导出的是：

> 当前用户最终确认后的文本。

---

# 34. 导出结构

建议：

```text
最终文本
↓
ExportService
├── TxtExporter
├── MarkdownExporter
└── DocxExporter
```

导出器全部使用统一接口：

```cpp
class IExporter
{
public:
    virtual bool exportDocument(
        const Document& document,
        const QString& outputPath
    ) = 0;
};
```

以后可加入：

```text
PdfExporter
HtmlExporter
```

---

# 35. 性能要求

当前单任务最多 10 页，所以：

> 不需要为了超大规模批处理进行过度优化。

但必须保证：

- UI 不因 OCR 卡死
- OCR 在后台线程/独立进程执行
- 图片加载不要一次把所有原图全部解码到内存
- 缩略图和大图分离
- OCR 过程显示进度
- 文件操作不阻塞 UI
- 任务状态实时更新

目标：

> “10 页手写文档稳定处理”优先于“处理 1000 页”。

---

# 36. 错误处理

任何以下情况都必须有明确错误：

- OCR Worker 无法启动
- OCR 模型缺失
- 图片格式错误
- 图片无法读取
- 上传失败
- LAN 服务启动失败
- OCR 超时
- OCR 返回非法数据
- 磁盘空间不足
- 导出失败
- 删除失败

禁止：

```text
catch (...)
{
}
```

禁止静默吞掉错误。

日志中记录详细原因。

UI 向用户展示简洁可理解的信息。

---

# 37. 日志

增加统一日志系统。

日志至少包括：

```text
INFO
WARN
ERROR
DEBUG
```

记录：

- App 启动
- OCR Worker 启停
- OCR 请求
- OCR 完成
- 上传
- 导出
- 删除任务
- 异常

不要把用户完整手写内容无意义地写进日志。

---

# 38. 配置

设置页面第一版只需要：

```text
OCR
├── OCR Engine
├── Low Confidence Threshold
└── 自动增强

LAN
├── 启用局域网上传
├── 上传端口
└── 自动生成二维码

Storage
└── 数据存储目录

UI
└── 主题
```

OCR 默认：

```text
Engine = Local / PaddleOCR
Low Confidence = 0.75
```

---

# 39. 未来扩展接口

只设计，不实现：

```text
IOcrProvider
├── PaddleOcrProvider
├── SecondaryOcrProvider
└── CloudOcrProvider
```

未来优化阶段：

```text
Primary OCR
+
Secondary OCR
↓
Diff Analysis
↓
OCRScore
↓
人工复核
```

再未来：

```text
OCR
↓
AI辅助校对
```

再未来：

```text
Local OCR-VL
```

Benchmark 也属于后续优化阶段。

---

# 40. Benchmark 未来规划

当前不要开发 Benchmark。

以后建立个人手写 Benchmark：

```text
真实手写图片
+
人工确认的 Ground Truth
```

然后比较不同 OCR：

```text
CER
插入错误
删除错误
替换错误
标点错误
结构错误
耗时
```

Benchmark 的数据来源必须优先使用用户近期真实手稿，不使用刻意重新书写的测试字迹作为唯一数据。

---

# 41. OCRScore 未来规划

当前不要实现复杂评分算法。

未来可以设计：

```text
OCR confidence
+
文本一致性
+
第二 OCR 差异
+
异常检测
```

形成自己的：

```text
OCRScore
```

第一阶段甚至可以只是简单规则：

```text
高 confidence + 无冲突
→ 直接采用

低 confidence
→ 高亮

双 OCR 不一致
→ 标记冲突
```

不要一开始训练机器学习评分模型。

---

# 42. 未来“双本地 OCR”架构

未来可能：

```text
                 Image
                   ↓
        ┌──────────┴──────────┐
        ↓                     ↓
   PP-OCRv5               OCR-VL
        ↓                     ↓
        └──────────┬──────────┘
                   ↓
              Diff Analysis
                   ↓
             Result Fusion
                   ↓
             Human Review
```

但当前只实现：

```text
PP-OCRv5
```

---

# 43. 本地 VLM 的硬件适配

未来支持本地 VLM 时：

不要把固定显卡型号写进代码。

实现：

```text
HardwareCapabilityService
```

检测：

- GPU
- GPU Vendor
- VRAM
- CUDA 可用性
- 模型运行能力

根据硬件动态决定是否允许使用本地 VLM。

当前不要实现 VLM。

---

# 44. 数据一致性

程序任何时刻都必须保证：

```text
数据库记录
```

与：

```text
任务目录
```

尽可能一致。

删除任务需要：

1. 标记删除中
2. 删除文件
3. 删除数据库记录
4. 成功后结束
5. 失败则保留错误状态并提示

不要先删数据库再发现文件删除失败导致孤儿文件。

---

# 45. AI Coding 工作方式

你是代码实现者，但不要一次生成一个巨大文件。

先建立：

```text
项目架构
↓
基础工程
↓
数据库
↓
任务管理
↓
图片导入
↓
LAN 上传
↓
OCR Worker
↓
OCR 集成
↓
校对 UI
↓
导出
↓
打包
```

每完成一个阶段：

- 编译
- 运行
- 自测
- 修复
- 再进入下一阶段

不要为了“快”而跳过验证。

---

# 46. 建议项目结构

推荐类似：

```text
handwriting-digitalizer/
│
├── CMakeLists.txt
├── CMakePresets.json
├── README.md
├── ARCHITECTURE.md
├── DEVELOPMENT.md
├── LICENSES/
│
├── app/
│   ├── main.cpp
│   ├── AppController.*
│   │
│   ├── services/
│   │   ├── TaskService.*
│   │   ├── ImageService.*
│   │   ├── OcrService.*
│   │   ├── LanUploadService.*
│   │   ├── ExportService.*
│   │   ├── StorageService.*
│   │   └── SettingsService.*
│   │
│   ├── models/
│   │   ├── Task.*
│   │   ├── Page.*
│   │   ├── OcrResult.*
│   │   └── OcrBlock.*
│   │
│   ├── infrastructure/
│   │   ├── database/
│   │   ├── filesystem/
│   │   └── network/
│   │
│   └── qml/
│       ├── pages/
│       ├── components/
│       ├── dialogs/
│       └── views/
│
├── ocr-worker/
│   ├── main.py
│   ├── api/
│   ├── services/
│   ├── providers/
│   │   └── paddleocr_provider.py
│   └── requirements.txt
│
├── web-upload/
│   ├── index.html
│   ├── styles.css
│   └── upload.js
│
├── tests/
│
└── scripts/
```

如果实际开发过程中有更合理的目录结构，可以调整，但必须保持：

> UI / Application / Domain / Infrastructure / OCR Worker 清晰分离。

---

# 47. C++ 与 QML 边界

QML：

负责：

- UI
- 动画
- 用户交互
- 页面状态展示

C++：

负责：

- Task
- Page
- OCR
- 文件系统
- SQLite
- LAN Server
- 导出
- 图片处理
- Worker 管理
- 业务规则

不要在 QML JavaScript 中实现：

- 数据库操作
- 文件系统操作
- OCR 调用
- 复杂任务逻辑

---

# 48. 第一阶段开发顺序

按照以下顺序开发。

## Phase 1：基础工程

完成：

```text
Qt 6
C++20
QML
CMake
SQLite
基础窗口
基础导航
```

要求可以成功：

```text
Debug Build
Release Build
```

---

## Phase 2：任务系统

实现：

```text
创建任务
任务列表
任务详情
删除任务
SQLite
文件目录
自动保存
```

---

## Phase 3：图片导入

实现：

```text
文件选择
拖拽
批量导入
缩略图
页面排序
删除页面
```

限制：

```text
1～10 页
```

---

## Phase 4：局域网上传

实现：

```text
LAN Server
Session Token
一次性二维码
手机上传页面
批量上传
上传进度
自动加入任务
```

---

## Phase 5：OCR Worker

实现：

```text
Python
PaddleOCR
PP-OCRv5
Local HTTP API
Health Check
OCR API
```

---

## Phase 6：OCR 集成

实现：

```text
图片预处理
OCR 调用
JSON解析
保存 OCR 结果
confidence
bbox
进度
错误处理
```

---

## Phase 7：校对工作区

实现：

```text
左侧原图
右侧 OCR 文本
缩放
平移
bbox
低置信度黄色框
文本高亮
原图 ↔ 文本双向定位
上一处 / 下一处
文本编辑
自动保存
```

这是 MVP 最核心阶段。

---

## Phase 8：导出

实现：

```text
TXT
Markdown
DOCX
```

导出最终用户编辑后的文本。

---

## Phase 9：完善

完成：

```text
错误处理
日志
设置
数据路径
安装包
README
使用说明
License
```

---

# 49. UI 设计要求

整体风格：

> 简洁、现代、工具型桌面软件。

不要：

- 过度装饰
- 大面积渐变
- 炫酷动画
- AI 风格发光效果
- 大量卡片
- 浪费屏幕空间

重点：

> **让用户快速完成“导入 → 识别 → 校对 → 导出”。**

校对页面优先保证：

- 原稿大
- OCR 文本大
- 两边同步
- 低置信度明显
- 操作路径短

---

# 50. 验收标准

完成 MVP 后，必须能够真实完成以下流程：

### 场景 1：本地导入

```text
启动程序
↓
新建任务
↓
拖入 5 张 JPG
↓
看到 5 个页面缩略图
↓
开始识别
↓
OCR 完成
↓
显示文本
```

### 场景 2：低置信度

存在低 confidence OCR block 时：

```text
原稿对应文字
↓
显示黄色框

OCR文本对应文字
↓
显示黄色高亮
```

点击黄色区域：

```text
原稿 ↔ 文本
```

必须能够定位。

### 场景 3：手机上传

```text
电脑启动
↓
生成二维码
↓
手机扫码
↓
选择 8 张图片
↓
上传
↓
电脑收到 8 张图片
↓
进入任务
```

### 场景 4：删除

```text
任务存在
↓
删除任务
↓
确认
↓
任务消失
↓
原图、预处理图、OCR结果全部删除
```

### 场景 5：导出

```text
OCR
↓
用户修改
↓
保存
↓
导出 DOCX
↓
DOCX 内容 = 最终编辑结果
```

---

# 51. 开发原则

1. 优先实现真实可用功能，不做演示型假功能。
2. 不要为了预留未来功能而过度设计。
3. 不要把暂时不需要的 AI/VLM/云 OCR 加入 MVP。
4. 不要把 OCR 原始结果覆盖掉。
5. 不要删除原始图片。
6. 不要让 UI 线程执行耗时任务。
7. 不要静默吞异常。
8. 所有外部依赖必须记录版本。
9. 所有依赖检查许可证。
10. 尽量使用成熟、维护良好的依赖。
11. 遇到 API/模型版本变化时，以当前官方文档为准，不要猜测参数。
12. 不要因为某个技术方案“看起来高级”就引入它。
13. 优先保证实际识别、校对和数据可靠性。

---

# 52. 当前阶段完成后的未来路线

不要现在实现，但在 ARCHITECTURE.md 中记录：

```text
MVP
│
├── 本地 PP-OCRv5
│
├── 人工校对
│
└── 文档导出
│
↓
Optimization 1
│
├── 个人 OCR Benchmark
├── 第二本地 OCR
└── Diff Analysis
│
↓
Optimization 2
│
├── OCRScore
├── 自动选择
└── 双 OCR 融合
│
↓
Optimization 3
│
├── 本地 VLM
└── 硬件自动检测
│
↓
Future
│
├── AI 辅助校对
├── 云 OCR
├── 全文搜索
└── 个人手写档案
```

---

# 53. 最终要求

不要只生成代码。

在开发过程中同步维护：

```text
README.md
ARCHITECTURE.md
DEVELOPMENT.md
```

其中：

### README.md

说明：

- 项目用途
- 如何运行
- 如何构建
- 如何安装 OCR Worker
- 如何安装/准备模型
- 如何使用
- 如何打包

### ARCHITECTURE.md

说明：

- 系统架构
- 模块职责
- 数据流
- OCR Worker 通信
- 数据模型
- 文件结构
- LAN 上传机制
- 未来扩展点

### DEVELOPMENT.md

说明：

- 开发环境
- 构建命令
- Debug
- Release
- OCR Worker 启动
- 测试方法
- 常见问题

---

# 54. 开始执行

现在直接开始开发。

第一步：

1. 检查当前 Windows 开发环境。
2. 检查 Qt / CMake / C++ 编译器。
3. 检查 Python 环境。
4. 检查 NVIDIA CUDA 环境，但不要因此阻塞 MVP。
5. 初始化项目。
6. 创建上述基础架构。
7. 完成 Phase 1。
8. 编译运行。
9. 验证通过后继续 Phase 2。
10. 按阶段持续实现，不要一次性生成所有代码。

如果当前环境缺少某个依赖：

- 优先选择稳定方案；
- 修改安装/配置说明；
- 不要偷偷换成完全不同的技术栈；
- 不要为了继续开发而使用假的 OCR 实现。

最终目标不是展示代码，而是得到一个：

> **Windows 上真正能够把本人手写中文文章转换为可编辑电子文档的本地优先工具。**